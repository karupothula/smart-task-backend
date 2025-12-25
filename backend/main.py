from fastapi import FastAPI, HTTPException
from supabase import create_client, Client
from dotenv import load_dotenv
import os
import time
import httpx 
from schemas import TaskBase, TaskUpdate
from logic import analyze_task

load_dotenv()

url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)

app = FastAPI()

# --- HELPER: SAFE EXECUTE (Prevents Network Crashes) ---
def safe_execute(query, retries=3):
    for i in range(retries):
        try:
            return query.execute().data
        except (httpx.ReadError, httpx.ConnectError, httpx.PoolTimeout):
            if i == retries - 1: raise 
            time.sleep(0.2)
    return []

# --- HELPER: AUDIT LOGGING (Required by PDF) ---
def log_history(task_id: str, action: str, old_val: dict = None, new_val: dict = None):
    """
    Inserts a record into task_history.
    Required fields per PDF: task_id, action, old_value, new_value
    """
    entry = {
        "task_id": task_id,
        "action": action,
        "old_value": old_val,
        "new_value": new_val,
        "changed_at": "now()"
    }
    # We use safe_execute but catch errors silently so logging never breaks the app
    try:
        safe_execute(supabase.table("task_history").insert(entry))
    except Exception as e:
        print(f"Failed to log history: {e}")

# --- ENDPOINTS ---

@app.get("/api/stats")
def get_stats(category: str = None, priority: str = None):
    query = supabase.table("tasks").select("status")

    if category and category != "All":
        if category.lower() in ["high", "medium", "low"]:
             query = query.eq("priority", category.lower())
        else:
             query = query.eq("category", category.lower())
    
    if priority and priority != "All":
        query = query.eq("priority", priority.lower())

    data = safe_execute(query)

    pending = sum(1 for t in data if t.get("status") == "pending")
    in_progress = sum(1 for t in data if t.get("status") == "in_progress")
    completed = sum(1 for t in data if t.get("status") == "completed")

    return {"pending": pending, "in_progress": in_progress, "completed": completed}

@app.post("/api/classify")
def preview_classification(task: TaskBase):
    full_text = f"{task.title} {task.description or ''}"
    cat, prio, entities, actions = analyze_task(full_text)
    return {"category": cat, "priority": prio, "extracted_entities": entities, "suggested_actions": actions}

# 1. CREATE TASK (Logs 'created' action)
@app.post("/api/tasks")
def create_task(task: TaskBase):
    if not task.category or not task.priority:
        cat, prio, entities, actions = analyze_task(f"{task.title} {task.description or ''}")
        final_category = task.category or cat
        final_priority = task.priority or prio
    else:
        cat, prio, entities, actions = analyze_task(f"{task.title} {task.description or ''}")
        final_category = task.category
        final_priority = task.priority
    
    task_data = task.dict()
    if task.due_date: task_data["due_date"] = task.due_date.isoformat()
    task_data.update({
        "category": final_category, "priority": final_priority,
        "extracted_entities": entities, "suggested_actions": actions,
        "created_at": "now()", "status": "pending"
    })
    
    # Insert Task
    res_data = safe_execute(supabase.table("tasks").insert(task_data))
    if not res_data: raise HTTPException(status_code=500, detail="Failed to create task")
    
    new_task = res_data[0]
    
    # LOG HISTORY [Requirement: Track Creation]
    log_history(new_task['id'], "created", new_val=new_task)
    
    return new_task

# 2. LIST TASKS (Smart Sort: Active First, Done Last)
@app.get("/api/tasks")
def list_tasks(
    category: str = None, priority: str = None, status: str = None,
    limit: int = 10, offset: int = 0
):
    query = supabase.table("tasks").select("*")

    if category and category != "All":
        if category.lower() in ["high", "medium", "low"]:
            query = query.eq("priority", category.lower())
        else:
            query = query.eq("category", category.lower())

    if priority and priority != "All":
        query = query.eq("priority", priority.lower())
    if status and status != "All":
        query = query.eq("status", status.lower())

    # Sort: Status DESC (Active > Done), then Date DESC
    query = query.order("status", desc=True).order("created_at", desc=True)
    query = query.range(offset, offset + limit - 1)
    
    return safe_execute(query)

# 3. GET SINGLE TASK (With History) [Requirement: /api/tasks/{id}]
@app.get("/api/tasks/{task_id}")
def get_task_detail(task_id: str):
    # Fetch Task
    task_res = safe_execute(supabase.table("tasks").select("*").eq("id", task_id))
    if not task_res:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task = task_res[0]

    # Fetch History
    history_res = safe_execute(
        supabase.table("task_history").select("*").eq("task_id", task_id).order("changed_at", desc=True)
    )
    
    # Attach history to response
    task['history'] = history_res
    return task

# 4. UPDATE TASK (Logs 'updated' or 'status_changed')
@app.patch("/api/tasks/{task_id}")
def update_task(task_id: str, updates: TaskUpdate):
    # 1. Fetch current state (Old Value)
    current_res = safe_execute(supabase.table("tasks").select("*").eq("id", task_id))
    if not current_res:
        raise HTTPException(status_code=404, detail="Task not found")
    old_task = current_res[0]

    # 2. Prepare Updates
    data = {k: v for k, v in updates.dict().items() if v is not None}
    if "due_date" in data and data["due_date"]: data["due_date"] = data["due_date"].isoformat()
    if not data: return {"message": "No changes sent"}
    
    # 3. Perform Update
    res_data = safe_execute(supabase.table("tasks").update(data).eq("id", task_id))
    if not res_data: raise HTTPException(status_code=500, detail="Update failed")
    new_task = res_data[0]

    # 4. DETERMINE LOG ACTION [Requirement: Track changes]
    action = "updated"
    if "status" in data and data["status"] != old_task["status"]:
        if data["status"] == "completed":
            action = "completed"
        else:
            action = "status_changed"

    # 5. Log History
    log_history(task_id, action, old_val=old_task, new_val=new_task)

    return new_task

@app.delete("/api/tasks/{task_id}")
def delete_task(task_id: str):
    safe_execute(supabase.table("tasks").delete().eq("id", task_id))
    return {"message": "Task deleted"}