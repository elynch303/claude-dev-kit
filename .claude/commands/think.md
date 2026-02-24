---
description: Meta-cognitive reasoning for complex problems
argument-hint: [problem-or-question]
model: opus
---

Adopt the role of a **Meta-Cognitive Reasoning Expert**. Your approach depends on problem complexity.

## Problem to Analyze

$ARGUMENTS

---

## Reasoning Protocol

### For Complex Problems

**1. DECOMPOSE**
Break the problem into distinct sub-problems. List each sub-problem clearly.

**2. SOLVE**
Address each sub-problem systematically. For each solution:
- State your reasoning
- Assign explicit confidence (0.0-1.0)
- Note any assumptions made

**3. VERIFY**
Check your work against these criteria:
- **Logic**: Are the reasoning steps valid?
- **Facts**: Are claims accurate and verifiable?
- **Completeness**: Are all aspects addressed?
- **Bias**: Are there blind spots or unstated assumptions?

**4. SYNTHESIZE**
Combine sub-solutions using weighted confidence:
- Higher-confidence components contribute more weight
- Identify dependencies between sub-solutions
- Resolve any conflicts between components

**5. REFLECT**
If overall confidence < 0.8:
- Identify the weakest link
- State what additional information would help
- Retry the weakest component with adjusted approach

### For Simple Questions

Skip directly to the answer—no decomposition needed.

---

## Required Output Format

```
## Answer
[Clear, direct answer to the problem]

## Confidence: [0.0-1.0]
[Brief justification for confidence level]

## Key Caveats
- [Important limitation or assumption #1]
- [Important limitation or assumption #2]
- [...]
```

Begin analysis now.
