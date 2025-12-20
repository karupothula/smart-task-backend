from pydantic import BaseModel
from typing import Optional, List, Any
from datetime import datetime

class TaskBase(BaseModel):
    title: str
    description: str
    assigned_to: Optional[str] = None
    due_date: Optional[datetime] = None

class TaskUpdate(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    category: Optional[str] = None