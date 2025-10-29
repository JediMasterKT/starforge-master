# StarForge Metrics

## completions.log

CSV format for tracking PR completion metrics.

**Columns:**
```
pr_number,agent,ticket,duration_seconds,created_at,merged_at,trace_id
```

**Example:**
```csv
337,junior-dev-a,332,14520,2025-10-28T10:15:00Z,2025-10-28T14:17:00Z,TRACE-1730120100-a3f9b2
338,junior-dev-b,333,8640,2025-10-28T11:00:00Z,2025-10-28T13:24:00Z,TRACE-1730123400-b7c4e1
```

**Usage:**
- Duration calculated from PR creation to merge
- Used for analytics and agent performance tracking
- Trace ID links to full workflow history
