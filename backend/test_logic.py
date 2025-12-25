from logic import analyze_task

def test_scheduling_high_priority():
    desc = "Schedule urgent meeting with John today"
    cat, prio, entities, actions = analyze_task(desc)
    assert cat == "scheduling"
    assert prio == "high"
    assert "John" in entities["people"]
    assert "today" in entities["dates"]

def test_finance_medium_priority():
    desc = "Check budget invoice soon"
    cat, prio, entities, actions = analyze_task(desc)
    assert cat == "finance"
    assert prio == "medium"
    assert "Check budget" in actions


def test_technical_low_priority():
    desc = "Fix small bug in header"
    cat, prio, entities, actions = analyze_task(desc)
    assert cat == "technical"
    assert prio == "low"