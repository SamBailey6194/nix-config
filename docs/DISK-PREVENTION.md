# devtower-intel disk prevention and agent skills

The NixOS migration creates fresh encrypted `@nix` and `@docker` subvolumes.
Ubuntu's cleaned store and Docker data remain read-only recovery mounts until
the 870 EVO is itself encrypted and takes over `/nix` and Docker
([BACKUP-AND-DATA-ENCRYPTION.md](BACKUP-AND-DATA-ENCRYPTION.md#encrypt-one-drive-at-a-time)).

## Nix and Cargo

`hosts/devtower-intel/disk-prevention.nix` enables low-space GC below 5 GiB,
aiming for 15 GiB free. It disables `keep-derivations` and `keep-outputs`.
The shared weekly `nix-gc-custom` retains the three newest system generations
and other system generations up to 90 days old. Its timer now catches up after
downtime, and now applies to every devtower-intel stage. Existing GC roots,
including the Ubuntu `tidy-2026-10-06` pins, remain
protected; this configuration does not release them.

The devtower-intel user environment and this repository's development shell
set `CARGO_TARGET_DIR` outside repositories at `~/.cache/cargo-target`.
Existing targets are not moved or deleted. A first build in the new location
will rebuild its dependencies. The dev shell's PATH follows the target directory.

All agents must follow `config/agents/nix-source-policy.md`. Claude also gets
a Bash PreToolUse hook that rejects direct `path:` references to Git working
trees and unresolved shell variables. This hook is a guardrail: shell scripts,
aliases and constructed commands still require the rule to be followed.

Use `.` for Git-backed evaluation. For untracked source, use a fresh filtered
copy without changing the Git index:

```sh
python3 scripts/prepare-nix-source.py /tmp/nix-config-review-UNIQUE
nix eval --raw 'path:/tmp/nix-config-review-UNIQUE#nixosConfigurations.devtower-intel.config.system.build.toplevel.drvPath'
```

## Docker

The fresh NixOS Docker store uses classic `overlay2`, with
`features.containerd-snapshotter = false`, to avoid the containerd image-store
lease problem observed on Ubuntu. Do not switch an existing containerd-backed
daemon to this configuration: Docker hides the other backend's containers
and images. Restore DDEV projects using the migration backup procedure.
See [Docker's storage-backend documentation](https://docs.docker.com/engine/storage/containerd/).

BuildKit's GC target is 20 GB. A persistent weekly
`docker-build-cache-gc.timer` prunes build cache unused for seven days while
retaining a 20 GB cache allowance. This is a cache policy, not a hard quota.
Images, containers, networks, database volumes and raw containerd leases are
not pruned by the scheduled command. Local-driver logs rotate at 10 MB with
three files per container (applies to newly created containers).
See [Docker's cache GC documentation](https://docs.docker.com/build/cache/garbage-collection/).

After switching to NixOS, inspect:

```sh
systemctl list-timers nix-gc-custom.timer docker-build-cache-gc.timer
docker info --format '{{.Driver}} {{json .DriverStatus}}'
docker system df
journalctl -u nix-gc-custom -u docker-build-cache-gc
```

## TypeSafe/Jev skill and API key

The vendored skill in `config/agent-skills/typesafe-ai` is deployed by every
Home Manager development stage to Codex/shared agents, Claude, OpenCode and
Gemini. It works with either local or cloud model providers. Cloud workspaces
can read the vendored skill through `AGENTS.md`; run the setup command below
for native skill discovery across supported clients:

```sh
bash scripts/install-agent-skills.sh
```

This executes `npx --yes skills add typesafe-ai/skills --skill typesafe-ai -g --agent '*' -y`.
The wildcard installs to all supported agents, including clients not currently
detected. Eve and PromptScript do not support global installation. NixOS also
provides `install-agent-skills` for refreshing the global upstream skill.
See [the Skills CLI documentation](https://github.com/vercel-labs/skills).

The SDK uses `TYPESAFE_API_KEY` ([official SDK documentation](https://docs.typesafe.ai/sdk/python)).
Provision dedicated encrypted files for both devices from Ubuntu or a laptop:

```sh
python3 scripts/set-typesafe-api-key.py
```

Paste only the key at the hidden prompt. The script encrypts it into
`secrets/typesafe-api-key-laptop-intel.age` and
`secrets/typesafe-api-key-devtower-intel.age`, using the existing per-device
public recipient groups. Encryption needs no private identity. Plaintext
stays in memory; only ciphertext is staged on disk. Both new files need to
be included in the source deployed for a rebuild. Git-backed flakes require
new files to be tracked, or use the filtered-copy workflow above while reviewing.

The NixOS secret modules pick up the dedicated file when it exists, installing
it at `/run/agenix/typesafe-api-key` with mode `0400`, owned by the host's user.
The desktop's real host key must still be registered and its secrets rekeyed
as specified by the installation guide. The existing Claude/MCP bundles and
all recipient permissions remain unchanged.

To edit an existing Claude/MCP bundle instead, use a recovery identity already
authorised for **both** bundles:

```sh
python3 scripts/set-typesafe-api-key.py --bundled --identity /path/to/recovery-key
```

Ubuntu's `sam-ubuntu` identity is not a recipient for those bundles, so
`just edit-secret claude-secrets-devtower-intel` cannot decrypt them with that
identity. The recipe now supplies agenix without requiring `agenix-helper`.
Override its identity with `AGENIX_IDENTITY=/path/to/recovery-key` if needed.

After rebuilding, run SDK commands as `with-typesafe python your_script.py`
(or `with-typesafe node your_script.js`). The helper loads the dedicated key,
falling back to `TYPESAFE_API_KEY` in `/run/agenix/claude-secrets`, and passes it
only to the command without printing it. An already injected `TYPESAFE_API_KEY`
takes priority. For Ubuntu or cloud environments, inject the key through the
local process environment or the provider's secret settings; local agenix
files do not deploy a credential into a remote account.

### Interactive Jev requests

Run `just jev` for a guided request builder using the
[TypeSafe Python SDK](https://docs.typesafe.ai/sdk/python). It asks for the state
(multiline text, JSON or a file), a question type, a question ID and instructions.
Finish multiline input with a line containing only `.`. JSON state files are
parsed when their extension is `.json`; other files are read as text.

Choice asks for named options and optional descriptions. Noul asks a yes/no
question with optional definitions of true and false. Score asks for 2–10
descriptive levels, ordered from lowest to highest. Question IDs identify the
answers in code, so put the complete judgment in the instructions.

Review the generated JSON, then choose `s` to send, `a` to add another question,
`t` to change the state, `e` to edit the full JSON or `q` to quit. Several question
types can share the same state in one request. Responses show a readable answer
summary and formatted JSON, including probabilities, confidence where applicable,
and token usage. The SDK supplies typed question objects and handles retries.

The helper loads the API key through `with-typesafe` only when sending (using
the repository's equivalent wrapper if the installed command is unavailable).
It removes `TYPESAFE_API_KEY` from the editor's environment.

```sh
just jev                              # Guided state and question-type selection
just jev --choice                     # Guide for selecting one option
just jev --noul                       # Guide for a yes/no question
just jev --score                      # Guide for an ordered rating question
just jev --request /tmp/my-jev.json    # Keep/reuse a request draft
just jev --dry-run                    # Build and print one question without sending
just jev --json --editor nvim         # Start with an editable JSON template
just jev --json --choice              # JSON template with just a Choice question
```

Without `--request`, the draft lives in a private temporary directory and is
removed when the session ends. Use `--request` to keep your work; existing drafts
open at the review menu without replacing their content. `--json` or an explicit
`--editor` starts in the editor instead. It uses `$VISUAL` or `$EDITOR`, falling
back to an installed terminal editor. Zed and VS Code automatically receive
`--wait` so the script waits for the editor.

The recipe uses `uv run --script`, which installs the pinned `typesafe-sdk==0.7.2`
dependency into uv's cache on first use. The development packages already provide
uv with the NixOS library support needed by Python wheels. Elsewhere, install uv
before running the recipe. You can also run `uv run scripts/jev.py` directly.
`--model NAME` changes the model for a new request (default: `jev-latest`); saved
drafts keep their own model. Neither a key nor an API call is needed for dry runs.

Verify the guided flow and SDK serialization without making live API calls:

```sh
uv run --no-project --with typesafe-sdk==0.7.2 python -m unittest discover -s scripts/tests -p test_jev.py
```
