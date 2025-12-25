import re

def analyze_task(text_input: str):
    """
    Analyzes raw text to extract structured metadata.
    Architecture: Uses deterministic Rule-Based NLP (Regex/Keywords) rather than LLMs
    for speed, reliability, and zero cost.
    """
    if not text_input:
        return "general", "low", {"dates": [], "people": []}, ["Review task"]

    text_lower = text_input.lower()
    
    # --- 1. CATEGORY CLASSIFICATION (Priority Waterfall) ---
    # We check high-risk categories (Safety/Tech) first.
    # If a match is found, we stop. This prevents "Safety Inspection" being misclassified as "General".
    category = "general"
    
    if any(w in text_lower for w in ["safety", "hazard", "inspection", "compliance", "ppe", "danger"]):
        category = "safety"
    elif any(w in text_lower for w in ["bug", "fix", "error", "server", "deploy", "database", "api"]):
        category = "technical"
    elif any(w in text_lower for w in ["invoice", "budget", "cost", "price", "$", "bill", "audit"]):
        category = "finance"
    elif any(w in text_lower for w in ["meeting", "schedule", "call", "zoom", "deadline", "calendar"]):
        category = "scheduling"
    
    # --- 2. PRIORITY DETECTION ---
    # Keywords mapped to urgency levels.
    priority = "low"
    if any(w in text_lower for w in ["urgent", "asap", "immediate", "critical", "high", "deadline"]):
        priority = "high"
    elif any(w in text_lower for w in ["soon", "tomorrow", "week", "review", "medium"]):
        priority = "medium"

    # --- 3. ENTITY EXTRACTION (Regex) ---
    extracted_entities = {"dates": [], "people": []}

    # Regex logic: Looks for patterns like "with John" or "assign to Sarah".
    # We purposefully exclude "call" to avoid matching "call by" as a name.
    people_pattern = re.compile(r'(?:with|by|assign to|contact|ask)\s+([a-zA-Z]+)', re.IGNORECASE)
    matches = people_pattern.findall(text_input)
    
    # Stopword Filtering: Remove false positives like "tomorrow" or "the" captured as names.
    date_keywords = ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    clean_people = []
    for match in matches:
        if match.lower() not in date_keywords and match.lower() not in ["the", "a", "an", "to", "for"]:
            clean_people.append(match.title()) 
    extracted_entities["people"] = clean_people

    # Extract Dates: Simple keyword matching
    extracted_entities["dates"] = [word for word in text_lower.split() if word in date_keywords]

    # --- 4. ACTION SUGGESTION ENGINE ---
    # Maps category to actionable steps to help the user start immediately.
    actions_map = {
        "scheduling": ["Block calendar", "Send invite", "Prepare agenda"],
        "finance": ["Check budget", "Get approval", "Generate invoice"],
        "technical": ["Diagnose issue", "Check resources", "Assign technician"],
        "safety": ["Conduct inspection", "File report", "Update checklist"],
        "general": ["Review task", "Set due date", "Prioritize"]
    }
    suggested_actions = actions_map.get(category, ["Review task"])

    return category, priority, extracted_entities, suggested_actions