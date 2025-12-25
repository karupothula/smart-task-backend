from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime

class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None
    assigned_to: Optional[str] = None
    due_date: Optional[datetime] = None
    status: Optional[str] = "pending"
    category: Optional[str] = None
    priority: Optional[str] = None

# FIX: Added assigned_to and due_date here so Edits save!
class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    assigned_to: Optional[str] = None  # <--- NEW
    due_date: Optional[datetime] = None # <--- NEW