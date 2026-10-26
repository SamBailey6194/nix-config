# graphify — turns a folder of code, docs, papers and images into a queryable
# knowledge graph (graphify-out/graph.json), for coding agents. It sits beside
# code-review-graph (pkgs/code-review-graph.nix): that one indexes code only and
# answers "what does this change touch"; graphify also reads docs and media and
# answers "how do these parts fit together".
#
# Uses nixpkgs' version and source, with these integrations:
#
#   - the extras the skill can reach: `mcp` (mcp, starlette) for `graphify-mcp`,
#     the stdio server in home/modules/mcp-servers.nix; `watch` (watchdog);
#     `pdf` (pypdf, markdownify); `video` (faster-whisper, yt-dlp), which the
#     skill uses whenever a folder holds audio or video; and `gemini`/`openai`
#     (openai, tiktoken), used when GEMINI_API_KEY or an OpenAI key is set.
#     Without them those paths print "pip install 'graphifyy[...]'" and drop the
#     files. Whisper downloads its model to ~/.cache/huggingface on first use.
#     No `leiden`: on Python 3.13+ it wants graspologic-native >= 1.3.1 and
#     nixpkgs has 1.2.5; graphify falls back to networkx's Louvain on its own
#     (graphify/cluster.py). The remaining extras (neo4j, postgres, office,
#     extra grammars) are opt-in exports the skill never reaches by itself.
#   - GRAPHIFY_NO_AUTO_REFRESH. Every CLI call otherwise re-copies any user skill
#     whose .graphify_version stamp is older than the package, replacing the
#     home-manager link with a copy. The skills below ship no stamp, which also
#     skips it; the variable covers a stamp left by an earlier `graphify install`.
#   - `graphify-python`, an interpreter that can import graphify. The skill runs
#     its whole pipeline through `python -c "from graphify… import …"`, so it
#     needs one; nixpkgs ships only the `graphify` and `graphify-mcp`
#     launchers. Both run through it here as well (see `bins`).
#   - `graphify hook install` pins skillPython. Upstream writes sys.executable
#     (a /nix/store path) into .git/hooks and the merge.graphify.driver git
#     config; after a bump and a garbage collection the hooks would silently stop
#     rebuilding, as their fallbacks cannot find a Nix interpreter either.
#   - share/graphify/skills/<variant>, the SKILL.md + references/ bundles that
#     `graphify install` would copy, patched by ./patch-skill.py to use
#     `graphify-python` instead of `uv tool run --from graphifyy` / `pip install`
#     (see that file). home/modules/agent-skills.nix links them per client.
#
# `skillPython` is what the patched skills record in graphify-out/.graphify_python
# and what git hooks pin:
# the system profile link, not a store path, so a garbage collection after a bump
# cannot leave every project's graphify-out/ pointing at a deleted interpreter.
# It is valid because modules/software/development.nix installs this package
# system-wide, and home/stages/dev.nix (which links the skills) is only ever used
# with a system that imports development.nix.
#
{
  lib,
  graphify,
  python3,
  runCommand,
  symlinkJoin,
  makeWrapper,
  skillPython ? "/run/current-system/sw/bin/graphify-python",
}:

let
  version = graphify.version;

  pinnedPython = "def _pinned_python() -> str:\n"
    + "    if os.access(\"${skillPython}\", os.X_OK):  # nix-config pkgs/graphify\n"
    + "        return \"${skillPython}\"";

  unwrapped = graphify.overridePythonAttrs (prev: {
    dependencies = prev.dependencies ++ (with python3.pkgs; [
      mcp
      starlette
      watchdog
      pypdf
      markdownify
      faster-whisper
      yt-dlp
      openai
      tiktoken
    ]);
    # Prefer the profile link while it exists; otherwise upstream's behaviour.
    postPatch = (prev.postPatch or "") + ''
      substituteInPlace graphify/hooks.py --replace-fail \
        'def _pinned_python() -> str:' ${lib.escapeShellArg pinnedPython}
    '';
    pythonImportsCheck = prev.pythonImportsCheck ++ [ "graphify.hooks" ];
  });

  env = python3.withPackages (_: [ (python3.pkgs.toPythonModule unwrapped) ]);

  # All three commands run the env's interpreter, never nixpkgs' launchers:
  # those put graphify on sys.path but leave sys.executable a bare python3, and
  # `graphify update` re-runs itself as `sys.executable -m graphify`
  # (graphify/__main__.py), which then cannot import it.
  bins = runCommand "graphify-bin-${version}" { nativeBuildInputs = [ makeWrapper ]; } ''
    makeWrapper ${env}/bin/python3 $out/bin/graphify-python \
      --set-default GRAPHIFY_NO_AUTO_REFRESH 1
    makeWrapper $out/bin/graphify-python $out/bin/graphify --add-flags "-m graphify"
    makeWrapper $out/bin/graphify-python $out/bin/graphify-mcp --add-flags "-m graphify.serve"
  '';

  # skill file and references bundle per client, as graphify's own installer
  # pairs them (graphify/install.py _PLATFORM_CONFIG). agy uses Claude's.
  variants = {
    claude = { skill = "skill.md"; references = "claude"; };
    codex = { skill = "skill-codex.md"; references = "codex"; };
    opencode = { skill = "skill-opencode.md"; references = "opencode"; };
  };

  skills = runCommand "graphify-skills-${version}" { nativeBuildInputs = [ python3 ]; } (
    lib.concatStrings (lib.mapAttrsToList (name: v: ''
      dir=$out/share/graphify/skills/${name}
      mkdir -p $dir
      python3 -I ${./patch-skill.py} ${unwrapped.src}/graphify/${v.skill} $dir/SKILL.md ${lib.escapeShellArg skillPython}
      cp -r ${unwrapped.src}/graphify/skills/${v.references}/references $dir/references
    '') variants)
  );
in
symlinkJoin {
  name = "graphify-${version}";
  paths = [ bins skills ];
  passthru = {
    inherit version unwrapped;
    skillsDir = "${skills}/share/graphify/skills";
  };
  meta = unwrapped.meta // { mainProgram = "graphify"; };
}
