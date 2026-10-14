# Merge the declared Antigravity CLI settings into its settings.json.
# Input (jq -s): every JSON document in the file, so none for a missing or
# blank file, which starts from {}. Anything but a single object is an error,
# and so is a `permissions` that is not an object or an `allow` that is not a
# list. $d: { colorScheme, allow, remove } from antigravity.nix.
(if length == 0 then {}
 elif length == 1 and (.[0] | type) == "object" then .[0]
 else error("not a single JSON object") end)
| .colorScheme = $d.colorScheme
| (.permissions // {}) as $p
| if ($p | type) != "object" then error("permissions is not an object") else . end
| ($p.allow // []) as $allow
| if ($allow | type) != "array" then error("permissions.allow is not a list") else . end
# Retired entries go (exact matches only); the user's own entries stay, in
# their order, and declared entries that are missing are appended.
| [$allow[] | . as $rule | select($d.remove | any(.[]; . == $rule) | not)] as $kept
| .permissions = $p + {allow: ($kept + [$d.allow[] | . as $rule
                                     | select($kept | any(.[]; . == $rule) | not)])}
