# code-review-graph — a Tree-sitter graph of a repository's functions, classes,
# imports and tests in SQLite (<repo>/.code-review-graph/graph.db), so a coding
# agent can ask for the blast radius of a change instead of reading every file.
# Its sibling is graphify (pkgs/graphify): that one also reads docs and media.
#
# Not in nixpkgs, and not buildable from it as-is: 2.3.9 requires
# tree-sitter-language-pack < 1 and nixpkgs has 1.4.1, the Rust rewrite with a
# different API. So this is the same pinned-uvx arrangement as the Scrapling and
# ElevenLabs MCP servers (home/modules/mcp-launch.py): the wrapped uv
# (./uv-manylinux.nix) fetches exactly this release once into its cache, run
# under the nixpkgs Python. Every wheel it pulls needs only libc, libpthread and
# libgcc_s (checked with readelf), so nothing beyond what uv-manylinux supplies.
#
# What it gives you is a real `code-review-graph` on PATH. Before, the projects
# that use it (syntek-base and friends) only ran `uvx code-review-graph serve`
# from .mcp.json, so their hooks — which call the bare command — silently did
# nothing: Claude's PostToolUse graph refresh, the SessionStart `status`, the
# lefthook pre-commit `detect-changes`. The same binary is the shared MCP server
# (home/modules/mcp-servers.nix), so the CLI and every client run one version.
#
# No self-updater to turn off: code-review-graph has none, and FastMCP's PyPI
# check only runs with its banner, which stdio hides. FASTMCP_CHECK_FOR_UPDATES
# is still set off for `serve --http`, which shows it.
#
# CRG_HOME (its per-user registry, daemon config and logs) moves from
# ~/.code-review-graph to $XDG_STATE_HOME/code-review-graph. A directory holding
# `.code-review-graph` counts as a project, so with the default every server a
# client starts outside a git repository (from ~) treated the home directory as
# one: queries created ~/.code-review-graph/graph.db and a build indexed all of
# ~. Outside a repository the tools now refuse unless given a repo_root.
#
# To bump: change `version` (https://pypi.org/project/code-review-graph/), check
# the release's dependencies still install, and re-run the per-repo
# `code-review-graph build` where the graph schema changed (CHANGELOG upstream).
{
  callPackage,
  python3,
  writeShellApplication,
}:

let
  version = "2.3.9";
  uv = callPackage ./uv-manylinux.nix { };
in
(writeShellApplication {
  name = "code-review-graph";
  text = ''
    export FASTMCP_CHECK_FOR_UPDATES="''${FASTMCP_CHECK_FOR_UPDATES-off}"
    export CRG_HOME="''${CRG_HOME:-''${XDG_STATE_HOME:-$HOME/.local/state}/code-review-graph}"
    exec ${uv}/bin/uvx --python ${python3}/bin/python3 --from "code-review-graph==${version}" code-review-graph "$@"
  '';
}).overrideAttrs (prev: {
  passthru = (prev.passthru or { }) // { inherit version; };
})
