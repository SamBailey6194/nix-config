{ config, pkgs, ... }:

let
  # Language servers that nixpkgs does not carry, plus one it carries too old to
  # be usable. All three are wired into Zed and Neovim in
  # home/modules/{editor,neovim}.nix; see the files themselves for why they are
  # built here rather than pulled from nixpkgs. These `let` bindings shadow the
  # `with pkgs;` names in the package list below.
  laravel-ls = pkgs.callPackage ../../pkgs/laravel-ls.nix { };
  django-template-lsp = pkgs.callPackage ../../pkgs/django-template-lsp.nix { };
  htmx-lsp = pkgs.callPackage ../../pkgs/htmx-lsp.nix { };

  # uv, wrapped so the Python processes it launches can load manylinux wheels and
  # find the nixpkgs Playwright browsers. Without it, any wheel that dlopens
  # libstdc++ (greenlet, and so all of playwright and scrapling) fails to import.
  # See pkgs/uv-manylinux.nix for the full reasoning, and for why this is scoped
  # to uv rather than exported into the session — the short version is that an
  # exported LD_LIBRARY_PATH outranks DT_RUNPATH and takes out hyprlock.
  uv-manylinux = pkgs.callPackage ../../pkgs/uv-manylinux.nix { };

  # Virtual Pixel 8 Pro (Android 17, Google Play) for testing APKs without a
  # phone. See pkgs/android-emulator.nix.
  android-emulator = pkgs.callPackage ../../pkgs/android-emulator.nix { };

  # AI agent CLIs. antigravity-cli is nixpkgs' derivation bumped to the release
  # Google currently serves, wrapped with its auto-updater off; perplexity-cli is
  # not in nixpkgs at all. See the files for why. A callPackage here rather than
  # an overlay beside codex's in modules/core/base-configuration.nix: that file is
  # only imported by the full configs, so an overlay would leave stages 3–5 on
  # 1.2.3 with the updater live. home/modules/antigravity.nix calls the same file
  # for its MCP registration, so both resolve to one store path in every stage.
  antigravity-cli = pkgs.callPackage ../../pkgs/antigravity-cli.nix { };
  perplexity-cli = pkgs.callPackage ../../pkgs/perplexity-cli.nix { };

  # OpenCode v2 (2.0.18); nixpkgs is still on the 1.x line. Prebuilt npm binary,
  # self-updater off — see the file.
  opencode = pkgs.callPackage ../../pkgs/opencode.nix { };
in
{
  # Development tools and environment
  # IDEs, language servers, build tools, version control

  # services.localLlm.* options: llama.cpp with CUDA + OpenBLAS for NVIDIA
  # hosts. Off unless a host enables it, so importing it here only makes the
  # option available from the dev stage upward (devtower-intel turns it on).
  imports = [ ./local-llm.nix ];

  # androidenv (the SDK behind android-emulator) refuses to evaluate until the
  # Android SDK licence is accepted — this line is that acceptance. Scoped to the
  # hosts that import this module, which are the ones that get the emulator.
  nixpkgs.config.android_sdk.accept_license = true;

  environment.systemPackages = with pkgs; [
    # Version Control
    git
    gh                  # GitHub CLI
    git-lfs            # Git Large File Storage

    # Environment management
    direnv            # Auto-load dev environments per directory

    # Build tools
    gnumake
    cmake
    ninja

    # Container tools
    docker
    docker-compose
    ddev              # Docker-based local PHP+Node.js dev environments
    bubblewrap        # bwrap: unprivileged sandboxing. syntek-evaluation's
                      #   Antigravity catalog runs `agy --version` inside it

    # Database tools
    postgresql
    sqlite
    mariadb           # MySQL-compatible database (client + server)
    mycli             # Better MySQL/MariaDB CLI with auto-completion

    # API testing
    postman
    insomnia

    # Node.js — fnm for per-project version management
    # Usage: fnm install 20, fnm use 20, or auto-switch via .node-version
    nodejs              # System-level Node.js (latest LTS, for global tools)
    fnm                 # Fast Node Manager (per-project Node.js versions)
    yarn
    pnpm

    # Python — uv handles version management and virtual environments
    # Usage: uv python install 3.12, uv venv, uv pip install ...
    python314           # Default for new projects
    python314Packages.pip
    python314Packages.virtualenv
    python313           # For legacy projects
    python313Packages.pip
    python313Packages.virtualenv
    uv-manylinux        # Fast Python package installer + version manager (uv,
                        #   wrapped — see the let block above)
    copier              # Project scaffolding from templates (copier copy/update)

    # Rust toolchain via rustup (provides rustc, cargo, rustfmt, clippy)
    # After install: rustup default stable && rustup component add rust-analyzer
    rustup

    # PHP — used by DDEV projects and Blade templates
    php                 # PHP interpreter
    phpPackages.composer # PHP dependency manager
    # Intelephense LSP is downloaded automatically by Zed's PHP extension

    # ── Language servers ────────────────────────────────────────────────
    # One system-wide set, shared by Zed and Neovim. Both editors are pointed at
    # these exact store paths (home/modules/editor.nix pins `lsp.<server>.binary`,
    # home/modules/neovim.nix pins each server's `cmd`) so neither downloads its
    # own copy at runtime and both report identical diagnostics.

    # Web — TypeScript, JavaScript, React / React Native
    typescript-language-server  # tsserver-backed LSP (Neovim)
    vtsls                       # same tsserver via the VS Code TS service (Zed's default)
    vscode-langservers-extracted  # HTML, CSS, JSON and ESLint servers
    tailwindcss-language-server   # Tailwind class completion + linting
    emmet-language-server         # Emmet abbreviations in HTML/JSX/Blade
    htmx-lsp                      # hx-* attribute completion (see pkgs/htmx-lsp.nix)

    # Python / Django
    pyright                     # Python type checking
    django-template-lsp         # {% %} tags, template/static/url names (djlsp)

    # PHP / Laravel / Livewire / Blade
    intelephense                # PHP LSP; also serves Blade via Zed's blade extension
    laravel-ls                  # Laravel routes, views, config keys, env vars

    # Rust — rust-analyzer comes from rustup (rustup component add rust-analyzer)

    # Slint (UI markup)
    slint-lsp                   # Slint LSP (wired into Zed and Neovim)
    slint-viewer                # Live preview/reload of a .slint file
    slint-tr-extractor          # Extract translatable strings -> gettext .pot

    # ── AI coding agents ─────────────────────────────────────────────────────
    # claude-code is added per-host (hosts/*/configuration-full.nix) alongside
    # its home-manager module; these are plain CLIs, so they live here and land
    # from stage 3 (dev) upward. codex, agy and opencode do have small
    # home-manager modules (home/modules/{codex,antigravity,opencode}.nix), but
    # those only register the MCP servers shared with Claude Code
    # (home/modules/mcp-servers.nix) — plus, for opencode, the local llama.cpp
    # provider on hosts that run one.
    #
    # codex resolves to the codex-cli-nix overlay in
    # modules/core/base-configuration.nix, NOT the nixpkgs attr — see the
    # comment there — on the full configs, which are the only ones importing
    # that file; stages 3–5 get nixpkgs' codex. Auth: `codex login` (ChatGPT
    # sign-in) or OPENAI_API_KEY.
    codex                       # OpenAI Codex CLI (Apache-2.0)
    antigravity-cli             # Google Antigravity CLI, binary `agy` (unfree;
                                #   1.2.12, see the let block above). Auth:
                                #   Google sign-in on first `agy` run (tokens in
                                #   the Secret Service keyring) or GEMINI_API_KEY.
    perplexity-cli              # Perplexity Search API CLI, binary `pplx` (unfree,
                                #   binary-only). Auth: `pplx auth login` or
                                #   PERPLEXITY_API_KEY.
    opencode                    # OpenCode v2 agent CLI (MIT; 2.0.18, see the let
                                #   block above). Local Qwen via llama-server on
                                #   devtower-intel; hosted providers: `opencode
                                #   auth login` (credentials in its SQLite db).

    # REMOVED 20/09/2026: gemini-cli-bin (and gemini-cli). Google retired Gemini
    # CLI for unpaid, Pro and Ultra accounts in favour of Antigravity CLI, and
    # nixpkgs now carries meta.problems.removal on the package — it still builds
    # but warns on every eval, and will be dropped outright. It was already
    # unusable here: auth needs an enterprise account or a GEMINI_API_KEY.
    #
    # The successor is `antigravity-cli` above (binary `agy`, not `gemini`) — a
    # different tool, not a rename, added deliberately on 27/09/2026 rather than
    # as a drop-in swap. It shares ~/.gemini with the old CLI (settings in
    # ~/.gemini/config, state in ~/.gemini/antigravity-cli).
    # https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/

    # Swift
    # NOTE: nixpkgs' Swift on Linux is 5.10.1 and has been static for some time —
    # well behind upstream Swift 6.x. Fine for tooling/LSP on existing code; if a
    # project needs a 6.x toolchain, use swiftly or the official Linux tarball
    # under nix-ld rather than expecting `nix flake update` to move this.
    swift                       # Swift compiler + Foundation
    sourcekit-lsp               # Swift/C/C++/ObjC LSP (ships with the toolchain)
    swiftformat                 # Swift formatter
    swiftlint                   # Swift linter

    # Kotlin
    kotlin                      # Kotlin compiler (kotlinc)
    kotlin-language-server      # Kotlin LSP
    ktlint                      # Kotlin linter + formatter
    ktfmt                       # Kotlin formatter (Facebook/Meta style)

    # Android
    # No udev rules or adbusers group needed: systemd 258+ grants the logged-in
    # user access to Android devices via uaccess, which is why nixpkgs retired
    # `programs.adb` (its removal notice says to add android-tools instead). The
    # first connection still needs "Allow USB debugging" accepted on the phone.
    android-tools               # adb + fastboot (sideload APKs, logcat, flashing)
    android-emulator            # virtual Pixel 8 Pro: `android-emulator app.apk`
                                #   (see the let block above; needs KVM)

    # TeX
    texlab                      # LaTeX/BibTeX LSP (build, forward search, refs)

    # Shell
    bash-language-server        # sh/bash/zsh, backed by shellcheck below

    # Config / infra languages
    terraform-ls                               # Terraform / OpenTofu HCL language server
    tflint                                     # Terraform linter
    nixd                                       # Nix language server (used by Zed)
    nil                                        # Nix language server (used by Neovim)
    lua-language-server                        # Lua (for Neovim config)
    taplo                                      # TOML language server + formatter
    yaml-language-server                       # YAML + schema validation
    nginx-language-server                      # nginx.conf completion + hover
    systemd-lsp                                # systemd unit files (Neovim only)

    # ── Linters and formatters (shared by all editors) ──────────────────
    ruff                        # Python linter + formatter (fast!)
    prettier                    # JS/TS/JSON/YAML/Markdown formatter
    eslint                      # JavaScript/TypeScript linter
    shellcheck                  # Shell static analysis (bash-language-server uses it)
    shfmt                       # Shell formatter
    blade-formatter             # Laravel Blade template formatter
    phpPackages.php-cs-fixer    # PHP formatter (PSR-12 etc.)

    # TeX engines — pdflatex, xelatex, lualatex, latexmk, biber, full CTAN set.
    # texliveFull is a large closure (~7GB); texliveMedium is the same engines with
    # a trimmed package set if that ever needs reclaiming.
    texliveFull

    # Document conversion (markdown/html/docx/... -> PDF and between formats)
    pandoc                                     # universal document converter
    wkhtmltopdf                                # HTML -> PDF (also pandoc --pdf-engine=wkhtmltopdf)

    # ── Native build dependencies (pkg-config-discoverable) ──────────────────
    # Rust crates that bind C libraries resolve them through pkg-config in a
    # build script, which runs BEFORE any of the crate's own code compiles — so
    # a missing .pc file aborts `cargo check`/`clippy` for the whole workspace,
    # not just the crate that needs it.
    #
    # The concrete case: Slint's desktop backend pulls
    #   slint -> i-slint-common -> fontique -> yeslogic-fontconfig-sys
    # which needs `fontconfig.pc`. On Debian/Fedora fontconfig-dev is usually
    # already present, so this only bites on NixOS.
    #
    # Two things are required, and the second is the one that is easy to miss:
    #   1. the `dev` output (the `out` output carries no .pc file at all), and
    #   2. PKG_CONFIG_PATH, set below — pkg-config's compiled-in search path
    #      does not include the NixOS system profile, so even a linked .pc is
    #      invisible without it.
    #
    # This is a convenience for ad-hoc work. The reproducible answer is still a
    # per-project flake devShell listing these in buildInputs; that keeps the
    # dependency recorded in the project that actually needs it.
    pkg-config
    fontconfig.dev              # fontconfig.pc — Slint/fontique, cosmic-text, ab_glyph
    freetype.dev                # freetype2.pc — font rasterisation, pulled with fontconfig
  ];

  # Make the .pc files above discoverable. pkg-config does not search the NixOS
  # system profile by default; without this the packages are installed but every
  # build script still reports them missing.
  #
  # Unlike LD_LIBRARY_PATH — which outranks DT_RUNPATH and has broken hyprlock in
  # this config before (see pkgs/uv-manylinux.nix) — PKG_CONFIG_PATH is read only
  # by pkg-config at build time and never by the dynamic loader, so exporting it
  # session-wide is safe.
  #
  # SCOPE: this only applies OUTSIDE a Nix build. nixpkgs' pkg-config is a
  # wrapper that does, when its setup hook has run (i.e. inside a derivation or
  # `nix develop`):
  #     PKG_CONFIG_PATH=$PKG_CONFIG_PATH_<target> exec .../pkg-config "$@"
  # so it REPLACES the value below with one derived from that shell's
  # buildInputs. A project devShell therefore still has to list fontconfig and
  # pkg-config itself — this setting will not leak into it, by design.
  environment.sessionVariables.PKG_CONFIG_PATH =
    "/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";

  # `/lib` is in the default pathsToLink (so /lib/pkgconfig already populates);
  # /share/pkgconfig is not, and some packages ship their .pc there instead.
  environment.pathsToLink = [ "/share/pkgconfig" ];

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Enable virtualization for VMs
  virtualisation.libvirtd = {
    enable = true;
  };
}
