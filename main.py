from fastapi import FastAPI, HTTPException, Query
from supabase import create_client, Client
from dotenv import load_dotenv
import os
from schemas import TaskBase, TaskUpdate
from logic import analyze_task
load_dotenv()

# Debugging: Print to see if they are loading (DELETE THESE PRINTS AFTER IT WORKS)
url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

#print(f"DEBUG: URL is {url}") 
#print(f"DEBUG: KEY is {key}")

if not url or not key:
    raise ValueError("Supabase keys not found! Make sure .env file exists and has SUPABASE_URL and SUPABASE_KEY.")

# Initialize Supabase

app = FastAPI()
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)


# 1. CREATE Task
@app.post("/api/tasks")
def create_task(task: TaskBase):
    # Auto-classify
    cat, prio, entities, actions = analyze_task(task.description)
    
    task_data = task.dict()
    task_data.update({
        "category": cat,
        "priority": prio,
        "extracted_entities": entities,
        "suggested_actions": actions
    })
    
    # Insert Task
    res = supabase.table("tasks").insert(task_data).execute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to create task")
    
    new_task = res.data[0]
    
    # Insert History
    supabase.table("task_history").insert({
        "task_id": new_task['id'],
        "action": "created",
        "new_value": new_task
    }).execute()
    
    return new_task

# 2. LIST Tasks (with Filters & Pagination)
@app.get("/api/tasks")
def list_tasks(
    category: str = None, 
    priority: str = None, 
    status: str = None,
    limit: int = 10,
    offset: int = 0
):
    query = supabase.table("tasks").select("*")
    if category: query = query.eq('category', category)
    if priority: query = query.eq('priority', priority)
    if status: query = query.eq('status', status)
    
    # Pagination
    return query.range(offset, offset + limit - 1).execute().data

# 3. GET Task Details
@app.get("/api/tasks/{task_id}")
def get_task(task_id: str):
    task = supabase.table("tasks").select("*").eq("id", task_id).execute()
    history = supabase.table("task_history").select("*").eq("task_id", task_id).execute()
    
    if not task.data:
        raise HTTPException(status_code=404, detail="Task not found")
        
    return {"task": task.data[0], "history": history.data}

# 4. UPDATE Task
@app.patch("/api/tasks/{task_id}")
def update_task(task_id: str, updates: TaskUpdate):
    # Get old value for history
    old = supabase.table("tasks").select("*").eq("id", task_id).execute()
    if not old.data:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Update
    data = {k: v for k, v in updates.dict().items() if v is not None}
    res = supabase.table("tasks").update(data).eq("id", task_id).execute()
    
    # History Log
    supabase.table("task_history").insert({
        "task_id": task_id,
        "action": "updated",
        "old_value": old.data[0],
        "new_value": res.data[0]
    }).execute()
    
    return res.data[0]

# 5. DELETE Task
@app.delete("/api/tasks/{task_id}")
def delete_task(task_id: str):
    supabase.table("tasks").delete().eq("id", task_id).execute()
    return {"message": "Task deleted"}