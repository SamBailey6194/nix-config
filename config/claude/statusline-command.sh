#!/usr/bin/env bash
# Claude Code status line — mirrors zsh PROMPT style from ~/.zshrc
# Bold green → | bold cyan <dir> | git branch | model | ctx% | rate limit | todos

input=$(cat)

# Current working directory — shorten $HOME to ~
raw_dir=$(echo "$input" | jq -r '.cwd // ""')
home_dir="$HOME"
dir="${raw_dir/#$home_dir/\~}"

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // ""')

# Context remaining percentage (null until first API call)
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Rate limit — try known field paths, skip if absent
rate_limit=$(echo "$input" | jq -r '
  if .rateLimit.requests_remaining != null then "rl:\(.rateLimit.requests_remaining)"
  elif .api_usage.rate_limit_remaining != null then "rl:\(.api_usage.rate_limit_remaining)"
  else ""
  end' 2>/dev/null)

# Todos — try .todos array, show count + first pending subject
todo_summary=""
todo_count=$(echo "$input" | jq -r '(.todos // []) | length' 2>/dev/null)
if [ -n "$todo_count" ] && [ "$todo_count" -gt 0 ] 2>/dev/null; then
    pending=$(echo "$input" | jq -r '[.todos[] | select(.status == "pending")] | length' 2>/dev/null)
    done_count=$(echo "$input" | jq -r '[.todos[] | select(.status == "completed")] | length' 2>/dev/null)
    todo_summary="✓${done_count}/${todo_count}"
    if [ -n "$pending" ] && [ "$pending" -gt 0 ] 2>/dev/null; then
        next=$(echo "$input" | jq -r '[.todos[] | select(.status == "pending")][0].content // ""' 2>/dev/null)
        if [ -n "$next" ]; then
            # Truncate long task names
            next="${next:0:30}"
            todo_summary="${todo_summary} → ${next}"
        fi
    fi
fi

# Git branch — read from cwd directly (no JSON field needed)
git_branch=""
if [ -n "$raw_dir" ] && [ -d "$raw_dir" ]; then
    git_branch=$(git -C "$raw_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# ANSI colours
green='\033[32m'
cyan='\033[36m'
yellow='\033[33m'
magenta='\033[35m'
blue='\033[34m'
red='\033[31m'
reset='\033[0m'

# Build the line
line=$(printf "${green}→${reset} ${cyan}%s${reset}" "$dir")

if [ -n "$git_branch" ]; then
    line="$line  ${magenta}${git_branch}${reset}"
fi

if [ -n "$model" ]; then
    line="$line  ${yellow}${model}${reset}"
fi

if [ -n "$remaining" ]; then
    pct=$(printf '%.0f' "$remaining")
    if [ "$pct" -lt 20 ] 2>/dev/null; then
        line="$line  ${red}ctx:${pct}%%${reset}"
    else
        line="$line  ctx:${pct}%%"
    fi
fi

if [ -n "$rate_limit" ]; then
    line="$line  ${blue}${rate_limit}${reset}"
fi

if [ -n "$todo_summary" ]; then
    line="$line  ${yellow}[${todo_summary}]${reset}"
fi

printf "%b\n" "$line"
