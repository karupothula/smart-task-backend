from fastapi import FastAPI, HTTPException
from supabase import create_client, Client
from dotenv import load_dotenv
import os
import time
import httpx 
from schemas import TaskBase, TaskUpdate
from logic import analyze_task

# --- SECURITY CONFIGURATION ---
# Load environment variables from .env file.
# This ensures sensitive keys (DB URL, API Key) are never hardcoded in the source code.
load_dotenv()

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")

if not url or not key:
    raise RuntimeError("Critical Error: SUPABASE_URL or SUPABASE_KEY missing in .env")

# Initialize Supabase Client (Singleton pattern)
supabase: Client = create_client(url, key)

app = FastAPI()
# --- NEW: HEALTH CHECK (Required for Render) ---
@app.get("/healthz")
def health_check():
    return {"status": "ok", "service": "smart-task-backend"}

# --- NEW: ROOT URL (Fixes 404) ---
@app.get("/")
def read_root():
    return {"message": "Smart Task Backend is Running!"}

# --- UTILITY: RETRY LOGIC (RESILIENCE PATTERN) ---
# Network calls to cloud databases (Supabase) can occasionally timeout or fail.
# Instead of crashing with a 500 error immediately, we retry the request 3 times.
def safe_execute(query, retries=3):
    for i in range(retries):
        try:
            return query.execute().data
        except (httpx.ReadError, httpx.ConnectError, httpx.PoolTimeout):
            # Exponential backoff or simple sleep to allow network recovery
            if i == retries - 1: raise 
            time.sleep(0.2)
    return []

# --- AUDIT LOGGING (COMPLIANCE) ---
# Tracks every modification to tasks. This is crucial for enterprise applications
# to maintain a history of who changed what and when.
def log_history(task_id: str, action: str, old_val: dict = None, new_val: dict = None):
    entry = {
        "task_id": task_id,
        "action": action,
        "old_value": old_val,
        "new_value": new_val,
        "changed_at": "now()"
    }
    try:
        # We wrap this in try/except because logging failure should NOT block the user action.
        # "Fire and forget" strategy.
        safe_execute(supabase.table("task_history").insert(entry))
    except Exception as e:
        print(f"Audit Log Warning: Failed to save history - {e}")

# --- ENDPOINT: DASHBOARD STATISTICS ---
# Optimization: Fetches ONLY the 'status' column instead of full rows.
# This reduces payload size significantly, making the dashboard load faster.
@app.get("/api/stats")
def get_stats(category: str = None, priority: str = None):
    query = supabase.table("tasks").select("status")

    # Apply Filters (Dynamic Query Building)
    if category and category != "All":
        # Smart Filter: If user selects a priority label (High/Med/Low) in category dropdown, handle it.
        if category.lower() in ["high", "medium", "low"]:
             query = query.eq("priority", category.lower())
        else:
             query = query.eq("category", category.lower())
    
    if priority and priority != "All":
        query = query.eq("priority", priority.lower())

    data = safe_execute(query)

    # Aggregation done in Python to avoid multiple COUNT(*) queries to DB
    return {
        "pending": sum(1 for t in data if t.get("status") == "pending"),
        "in_progress": sum(1 for t in data if t.get("status") == "in_progress"),
        "completed": sum(1 for t in data if t.get("status") == "completed")
    }

# --- ENDPOINT: AI PREVIEW ---
# Stateless endpoint that runs the NLP logic without saving to DB.
# Used by the frontend to show "Predicted Category" before the user clicks Save.
@app.post("/api/classify")
def preview_classification(task: TaskBase):
    full_text = f"{task.title} {task.description or ''}"
    cat, prio, entities, actions = analyze_task(full_text)
    return {
        "category": cat, 
        "priority": prio, 
        "extracted_entities": entities, 
        "suggested_actions": actions
    }

# --- ENDPOINT: CREATE TASK ---
@app.post("/api/tasks")
def create_task(task: TaskBase):
    # Fallback Logic: If frontend didn't provide category (e.g. quick add), run AI analysis here.
    if not task.category or not task.priority:
        cat, prio, entities, actions = analyze_task(f"{task.title} {task.description or ''}")
        final_category = task.category or cat
        final_priority = task.priority or prio
    else:
        # Even if category is set, we still want to extract entities (dates/people)
        _, _, entities, actions = analyze_task(f"{task.title} {task.description or ''}")
        final_category = task.category
        final_priority = task.priority
    
    task_data = task.dict()
    if task.due_date: task_data["due_date"] = task.due_date.isoformat()
    
    # Enrich data before insert
    task_data.update({
        "category": final_category, 
        "priority": final_priority,
        "extracted_entities": entities, 
        "suggested_actions": actions,
        "created_at": "now()", 
        "status": "pending"
    })
    
    res_data = safe_execute(supabase.table("tasks").insert(task_data))
    if not res_data: raise HTTPException(status_code=500, detail="Failed to create task")
    
    # Audit: Log creation event
    log_history(res_data[0]['id'], "created", new_val=res_data[0])
    
    return res_data[0]

# --- ENDPOINT: LIST TASKS (PAGINATION & SORTING) ---
@app.get("/api/tasks")
def list_tasks(
    category: str = None, priority: str = None, status: str = None,
    limit: int = 10, offset: int = 0
):
    query = supabase.table("tasks").select("*")

    # Filters
    if category and category != "All":
        if category.lower() in ["high", "medium", "low"]:
            query = query.eq("priority", category.lower())
        else:
            query = query.eq("category", category.lower())

    if priority and priority != "All": query = query.eq("priority", priority.lower())
    if status and status != "All": query = query.eq("status", status.lower())

    # --- ARCHITECTURE DECISION: SORTING ---
    # 1. Status DESC: Forces 'pending'/'in_progress' to top, 'completed' to bottom.
    # 2. Created_At DESC: Newest items first within those groups.
    # This prevents the "striped list" issue where done tasks mix with pending ones.
    query = query.order("status", desc=True).order("created_at", desc=True)
    
    # Pagination using Range (Limit/Offset)
    query = query.range(offset, offset + limit - 1)
    
    return safe_execute(query)

# --- ENDPOINT: GET DETAILS (WITH HISTORY) ---
@app.get("/api/tasks/{task_id}")
def get_task_detail(task_id: str):
    # Fetch core task
    task_res = safe_execute(supabase.table("tasks").select("*").eq("id", task_id))
    if not task_res: raise HTTPException(status_code=404, detail="Task not found")
    task = task_res[0]

    # Fetch audit trail (History)
    history_res = safe_execute(
        supabase.table("task_history").select("*").eq("task_id", task_id).order("changed_at", desc=True)
    )
    task['history'] = history_res
    return task

# --- ENDPOINT: UPDATE TASK ---
@app.patch("/api/tasks/{task_id}")
def update_task(task_id: str, updates: TaskUpdate):
    # 1. Get current state (for audit comparison)
    current_res = safe_execute(supabase.table("tasks").select("*").eq("id", task_id))
    if not current_res: raise HTTPException(status_code=404, detail="Task not found")
    old_task = current_res[0]


    # 2. Prepare payload (filter out None values)
    data = {k: v for k, v in updates.dict().items() if v is not None}
    if "due_date" in data and data["due_date"]: data["due_date"] = data["due_date"].isoformat()
    if not data: return {"message": "No changes sent"}
    
    # 3. Update
    res_data = safe_execute(supabase.table("tasks").update(data).eq("id", task_id))
    if not res_data: raise HTTPException(status_code=500, detail="Update failed")
    new_task = res_data[0]

    # 4. Determine Action Type for Log
    action = "updated"
    if "status" in data and data["status"] != old_task["status"]:
        action = "completed" if data["status"] == "completed" else "status_changed"

    # 5. Log changes
    log_history(task_id, action, old_val=old_task, new_val=new_task)

    return new_task

@app.delete("/api/tasks/{task_id}")
def delete_task(task_id: str):
    safe_execute(supabase.table("tasks").delete().eq("id", task_id))
    return {"message": "Task deleted"}

# --- REQUIRED: ENTRY POINT FOR RENDER ---
if __name__ == "__main__":
    import uvicorn
    # Render assigns a dynamic PORT variable. 
    # We use os.environ.get("PORT") to ensure we listen on the correct port.
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)