# VBW Structured Handoff Schemas

JSON-structured SendMessage schemas with `type` discriminator. Receivers: `JSON.parse` content; fall back to plain markdown on parse failure.

## `scout_findings` (Scout -> Map Lead)

Research findings from a Scout investigating a specific domain.

```json
{
  "type": "scout_findings",
  "domain": "tech-stack | architecture | quality | concerns",
  "documents": [
    { "name": "STACK.md", "content": "## Tech Stack\n..." }
  ],
  "cross_cutting": [
    { "target_domain": "architecture", "finding": "...", "relevance": "high | medium | low" }
  ],
  "confidence": "high | medium | low",
  "confidence_rationale": "Brief justification"
}
```

## `dev_progress` (Dev -> Execute Lead)

Status update after completing a task.

```json
{
  "type": "dev_progress",
  "task": "03-01/task-3",
  "plan_id": "03-01",
  "commit": "abc1234",
  "status": "complete | partial | failed",
  "concerns": ["Interface changed — downstream plans may need update"]
}
```

## `dev_blocker` (Dev -> Execute Lead)

Escalation when blocked and cannot proceed.

```json
{
  "type": "dev_blocker",
  "task": "03-02/task-1",
  "plan_id": "03-02",
  "blocker": "Dependency module from plan 03-01 not yet committed",
  "needs": "03-01 to complete first",
  "attempted": ["Checked git log for 03-01 commits — none found"]
}
```

## `qa_result` (QA -> Lead)

Structured verification results.

```json
{
  "type": "qa_result",
  "tier": "quick | standard | deep",
  "result": "PASS | FAIL | PARTIAL",
  "checks": { "passed": 18, "failed": 2, "total": 20 },
  "failures": [
    {
      "check": "CONVENTIONS.md link integrity",
      "expected": "All cross-references resolve",
      "actual": "references/missing-file.md not found",
      "evidence": "grep output showing broken link at line 42"
    }
  ],
  "body": "## Must-Have Checks\n| # | Truth | Status | Evidence |\n..."
}
```

## `debugger_report` (Debugger -> Debug Lead)

Investigation findings from competing hypotheses mode.

```json
{
  "type": "debugger_report",
  "hypothesis": "Race condition in session middleware causes intermittent 401s",
  "evidence_for": [
    "Mutex not held during token refresh (src/middleware/auth.ts:45)",
    "Reproduction shows 401s only under concurrent requests"
  ],
  "evidence_against": [
    "Token TTL is 30min — unlikely to expire mid-request in normal flow"
  ],
  "confidence": "high | medium | low",
  "recommended_fix": "Add mutex lock around token refresh, or 'Insufficient evidence' if low confidence"
}
```
