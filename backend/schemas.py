from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime

# --- DATA MODELS ---
# Using Pydantic ensures strictly typed API inputs, preventing runtime errors.

class TaskBase(BaseModel):
    title: str  # Required field
    description: Optional[str] = None
    assigned_to: Optional[str] = None
    due_date: Optional[datetime] = None
    status: Optional[str] = "pending"
    category: Optional[str] = None
    priority: Optional[str] = None


class TaskUpdate(BaseModel):
    """
    Model for PATCH requests. 
    All fields are Optional because a user might update just the 'status' 
    without sending the whole task object again.
    """
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[str] = None
    assigned_to: Optional[str] = None 
    due_date: Optional[datetime] = None