import re

def analyze_task(text_input: str):
    if not text_input:
        return "general", "low", {"dates": [], "people": []}, ["Review task"]

    text_lower = text_input.lower()
    
    # --- 1. CATEGORY LOGIC (Fixed Order) ---
    # We check Specific categories FIRST. If it matches, we stop.
    # This prevents "Safety call" from becoming "Scheduling".
    category = "general"
    
    # Safety (Highest Priority Check)
    if any(w in text_lower for w in ["safety", "hazard", "inspection", "compliance", "mask", "ppe", "checklist", "danger", "incident", "report"]):
        category = "safety"
    
    # Technical
    elif any(w in text_lower for w in ["bug", "fix", "error", "code", "install", "repair", "server", "app", "crash", "technician", "resources", "database", "api", "deploy"]):
        category = "technical"
    
    # Finance
    elif any(w in text_lower for w in ["pay", "invoice", "bill", "budget", "cost", "expense", "price", "$", "money", "audit", "account"]):
        category = "finance"

    # Scheduling (Lowest Priority Check - only if no others match)
    elif any(w in text_lower for w in ["meeting", "schedule", "call", "zoom", "teams", "appointment", "deadline", "calendar", "invite", "event"]):
        category = "scheduling"
    
    # --- 2. PRIORITY LOGIC ---
    priority = "low"
    if any(w in text_lower for w in ["urgent", "asap", "immediately", "today", "now", "critical", "emergency", "deadline", "fail", "high"]):
        priority = "high"
    elif any(w in text_lower for w in ["soon", "tomorrow", "this week", "important", "review", "check", "update", "medium"]):
        priority = "medium"

    # --- 3. ENTITY EXTRACTION (Fixed Regex) ---
    extracted_entities = {
        "dates": [],
        "people": []
    }

    # FIX: Removed "call" and "meet" from triggers to prevent "call by raj" capturing "by"
    # Now strictly looks for assignment prepositions.
    people_pattern = re.compile(r'(?:with|by|assign to|contact|ask)\s+([a-zA-Z]+)', re.IGNORECASE)
    matches = people_pattern.findall(text_input)
    
    date_keywords = ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    
    clean_people = []
    for match in matches:
        # Stop words: if the captured "name" is actually a preposition or date, ignore it.
        if match.lower() not in date_keywords and match.lower() not in ["the", "a", "an", "to", "for"]:
            clean_people.append(match.title()) 
    extracted_entities["people"] = clean_people

    # Extract Dates
    extracted_entities["dates"] = [word for word in text_lower.split() if word in date_keywords]

    # --- 4. SUGGESTED ACTIONS ---
    actions_map = {
        "scheduling": ["Block calendar", "Send invite", "Prepare agenda", "Set reminder"],
        "finance": ["Check budget", "Get approval", "Generate invoice", "Update records"],
        "technical": ["Diagnose issue", "Check resources", "Assign technician", "Document fix"],
        "safety": ["Conduct inspection", "File report", "Notify supervisor", "Update checklist"],
        "general": ["Review task", "Set due date", "Prioritize"]
    }
    suggested_actions = actions_map.get(category, ["Review task"])

    return category, priority, extracted_entities, suggested_actions