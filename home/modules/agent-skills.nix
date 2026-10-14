{ lib, pkgs, ... }:

let
  source = ../../config/agent-skills/typesafe-ai;
  policy = ../../config/agents/nix-source-policy.md;
in
{
  # One vendored skill, available offline on activation. Model providers
  # (cloud APIs or local llama.cpp) use the same client skill directories.
  home.file = {
    ".agents/skills/typesafe-ai".source = source;
    ".claude/skills/typesafe-ai".source = source;
    ".config/opencode/skills/typesafe-ai".source = source;
    # Antigravity CLI (agy): global skills live in ~/.gemini/config/skills/
    # (the root of its machine-wide customisations, per agy 1.3.0's bundled
    # agy-customizations and migrate-workflows skills). ~/.gemini/skills/ was
    # Gemini CLI's, which was removed (modules/software/development.nix).
    ".gemini/config/skills/typesafe-ai".source = source;
    ".claude/rules/nix-source.md".source = policy;
    ".agents/skills/nix-source/SKILL.md".text = ''
      ---
      name: nix-source
      description: Safe source handling when evaluating or building Nix flakes in repositories.
      ---
      ${builtins.readFile policy}
    '';
  };

  # Also support additional clients and hosted development environments.
  home.packages = [ (pkgs.writeShellApplication {
    name = "install-agent-skills";
    runtimeInputs = [ pkgs.nodejs pkgs.git ];
    text = builtins.readFile ../../scripts/install-agent-skills.sh;
  }) (pkgs.writeShellScriptBin "with-typesafe" ''
    exec ${pkgs.python3}/bin/python3 ${../../scripts/with-typesafe-env.py} "$@"
  '') ];
}
