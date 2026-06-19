#!/usr/bin/env bash
# Block writes to auto-memory files — all project memory must go in .claude/MEMORY.md

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Match any .md file inside ~/.claude/projects/*/memory/
if echo "$FILE_PATH" | grep -qE "/\.claude/projects/[^/]+/memory/.+\.md$"; then
    BASENAME=$(basename "$FILE_PATH")
    if [ "$BASENAME" != "MEMORY.md" ]; then
        echo '{"decision": "block", "reason": "Auto-memory writes are disabled. Use .claude/MEMORY.md inside the project repository for all project memory."}'
        exit 0
    fi
fi

exit 0
