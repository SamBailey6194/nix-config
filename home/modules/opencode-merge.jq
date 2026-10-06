(if length == 0 then {}
 elif length == 1 and (.[0] | type) == "object" then .[0]
 else error("not a single JSON object") end)
| (if has("$schema") then . else {"$schema": $d.schema} + . end)
| (if has("permissions") or has("permission") then .
   else .permissions = $d.permissions end)
| reduce ($d.servers | to_entries[]) as $s (.;
    (if .mcp.servers[$s.key]? != null then ["mcp", "servers", $s.key]
     elif .mcp[$s.key]? != null then ["mcp", $s.key]
     else ["mcp", "servers", $s.key] end) as $sp
    | (getpath($sp) // {}) as $old
    | setpath($sp; (($old | del(.command, .args, .url, .type)) + $s.value)))
| reduce ($d.remove // [])[] as $n (.;
    (if (.mcp.servers? | type) == "object" then del(.mcp.servers[$n]) else . end)
    | (if (.mcp? | type) == "object" then del(.mcp[$n]) else . end))
| if $d.provider == null then . else
    (if .providers[$d.provider.id]? != null then ["providers", $d.provider.id]
     elif .provider[$d.provider.id]? != null then ["provider", $d.provider.id]
     else ["providers", $d.provider.id] end) as $p
    | (if getpath($p) == null then setpath($p; $d.provider.value) else . end)
    | reduce ($d.provider.value.models | to_entries[]) as $m (.;
        ($p + ["models", $m.key]) as $mp
        | getpath($mp) as $old
        | if $old == null then setpath($mp; $m.value)
          elif $m.key == "qwen3.6-35b-a3b"
            and $old.modelID? == "unsloth/Qwen3.6-35B-A3B-GGUF:UD-IQ4_XS"
            and $old.limit.context? == 32768
          then setpath($mp; ($old | .modelID = $m.value.modelID
                                | .limit.context = $m.value.limit.context))
          else . end)
    | if has("model") then . else .model = $d.provider.model end
  end
