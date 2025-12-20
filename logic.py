import re
from datetime import datetime

def analyze_task(description: str):
    desc = description.lower()
    
    # 1. Category Detection
    categories = {
        "scheduling": ["meeting", "schedule", "call", "appointment", "deadline"],
        "finance": ["payment", "invoice", "bill", "budget", "cost"],
        "technical": ["bug", "fix", "error", "install", "repair", "server"],
        "safety": ["safety", "hazard", "inspection", "compliance", "ppe"]
    }
    category = "general"
    for cat, keywords in categories.items():
        if any(kw in desc for kw in keywords):
            category = cat
            break

    # 2. Priority Detection
    priority = "low"
    if any(kw in desc for kw in ["urgent", "asap", "immediately", "today", "critical"]):
        priority = "high"
    elif any(kw in desc for kw in ["soon", "important", "this week"]):
        priority = "medium"

    # 3. Entity Extraction (Regex)
    people = re.findall(r'(?:with|by|assign to)\s+([a-zA-Z]+)', description)
    dates = re.findall(r'(today|tomorrow|monday|tuesday|wednesday|thursday|friday)', desc)

    # 4. Suggested Actions
    actions_map = {
        "scheduling": ["Block calendar", "Send invite"],
        "finance": ["Check budget", "Generate invoice"],
        "technical": ["Diagnose issue", "Document fix"],
        "safety": ["Conduct inspection", "File report"]
    }
    actions = actions_map.get(category, ["Review task"])

    return category, priority, {"people": people, "dates": dates}, actions