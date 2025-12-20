from logic import analyze_task

def test_scheduling_high():
    cat, prio, _, _ = analyze_task("Schedule urgent meeting with Team")
    assert cat == "scheduling"
    assert prio == "high"

def test_finance_medium():
    cat, prio, _, _ = analyze_task("Check invoice soon")
    assert cat == "finance"
    assert prio == "medium"

def test_extraction():
    _, _, ent, _ = analyze_task("Meet with Alice today")
    assert "Alice" in ent["people"]