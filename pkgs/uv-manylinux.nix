# uv, wrapped so the Python processes it launches can load manylinux wheels and
# find the nixpkgs Playwright browsers.
#
# ── The bug this exists for ──────────────────────────────────────────────────
#
# A PyPI manylinux wheel ships a prebuilt .so. auditwheel gives it a DT_RUNPATH
# for the libraries it vendors, but deliberately none for the external ones the
# manylinux policy lets it assume — those are expected at /usr/lib. CPython
# dlopen()s that .so at import time and on NixOS the loader has nowhere to look:
# no /etc/ld.so.cache, no /usr/lib. Verified end to end on this host:
#
#     $ uvx --from 'scrapling[fetchers]' python -c "import greenlet"
#     ImportError: libstdc++.so.6: cannot open shared object file
#
# greenlet is a C++ extension and playwright imports greenlet, so that one missing
# soname takes out both consumers at once: the Scrapling MCP server, and every
# pytest-playwright suite. Wheels needing nothing beyond libc (curl_cffi, lxml,
# orjson, msgspec) import fine unaided.
#
# ── Why programs.nix-ld does not already cover it ────────────────────────────
#
# nix-ld looks like the answer and is not. It IS the loader installed at
# /lib64/ld-linux-x86-64.so.2, so it is only ever entered by an ELF whose PT_INTERP
# already points there. uv runs the *store* CPython, whose PT_INTERP is the real
# ld.so — the shim is never entered, NIX_LD_LIBRARY_PATH is never read, and the
# import fails even though libstdc++.so.6 is sitting in nix-ld's directory.
#
# ── Why this list is one package, and must stay short ────────────────────────
#
# The loader's search order is: DT_RPATH of the loading object (only when it has
# no DT_RUNPATH) -> LD_LIBRARY_PATH -> DT_RUNPATH -> ld.so.cache -> /lib:/usr/lib.
# nixpkgs emits DT_RUNPATH, never DT_RPATH, so every soname put on
# LD_LIBRARY_PATH OUTRANKS the store path a binary was actually linked against,
# for every process that inherits the variable.
#
# That is not theoretical here. Putting the whole nix-ld set on LD_LIBRARY_PATH
# breaks the Hyprland stack outright, because those packages come from the
# `hyprland` flake input — which does not `follows` nixpkgs — and are built by
# gcc 16.2.0, while nixpkgs' stdenv here is gcc 15.3.0:
#
#     $ LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH hyprctl version
#     hyprctl: .../gcc-15.3.0-lib/lib/libstdc++.so.6: version `GLIBCXX_3.4.36'
#       not found (required by hyprctl)
#
# Note the direction: libstdc++ is BACKWARD compatible, so a newer one serves an
# older consumer and shadowing with an OLDER one is what breaks. Hence gcc16 —
# the newest in this nixpkgs, matching what the Hyprland closure was built with.
#
# Measured with exactly this one package on the path: greenlet imports, all three
# Playwright browsers (chromium, firefox, webkit) launch, and hyprctl and hyprlock
# still exit 0 as children of a uv-launched Python process. Adding the rest of the
# nix-ld set changes none of those outcomes except to break the last two, so it is
# cost with no benefit.
#
# If a future wheel fails on some other soname, the ImportError names it — add
# that one package here rather than widening this to nix-ld's list wholesale, and
# check the addition against the Playwright browsers, whose autoPatchelfHook
# runpaths pin their own icu, GL and ssl.
#
# If the GLIBCXX error above ever appears from this wrapper, something on the host
# is built against a newer gcc than this attribute — bump it to match.
#
# ── Playwright ───────────────────────────────────────────────────────────────
#
# Playwright pins an exact Chromium *revision* per release and the prebuilt
# browsers it downloads will not run on NixOS, so point it at the nixpkgs bundle.
# Same reasoning as the mcp-mermaid pin in home/modules/claude.nix, which solves
# this for the Node side.
#
# PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD covers the *automatic* download paths only —
# the driver reads it in installBrowsersForNpmInstall and
# ensureConfiguredBrowserInstalled, not in the explicit `playwright install`
# command, which still tries. That one is stopped by the store being read-only: it
# fails with EROFS on .../playwright-browsers/__dirlock and leaves the bundle
# untouched, so a download fallback is structurally impossible rather than merely
# discouraged. Scripts that run `playwright install` as a pre-flight (syntek-base's
# code/src/scripts/tests/e2e-py.sh does) log a warning and carry on.
#
# These are `--set-default`, not `--set`: a project that genuinely needs its own
# browsers can still export its own value without being wrapped out of it.
#
# NOTE the coupling this creates: the Python `playwright` release must be the one
# whose revisions this bundle ships. `just check-playwright` reports it — it reads
# pkgs.python3Packages.playwright.version, which nixpkgs bumps in the same
# update-script run as playwright-driver, so it cannot drift from the bundle. Do
# not derive it from playwright-driver.version by hand: that is the npm release
# number, and there is no PyPI 1.61.1 to match driver 1.61.1. A mismatch fails
# loudly with "Executable doesn't exist at .../chromium_headless_shell-<rev>",
# never silently.
{
  lib,
  uv,
  symlinkJoin,
  makeWrapper,
  playwright-driver,
  # Newest gcc in this nixpkgs. Must be >= the gcc every other closure on the host
  # was built with — see "Why this list is one package" above.
  gcc16,
}:

symlinkJoin {
  name = "uv-manylinux-${uv.version}";
  paths = [ uv ];

  nativeBuildInputs = [ makeWrapper ];

  # Both entrypoints: `uvx` is a separate binary, not a `uv` subcommand alias, so
  # wrapping only `uv` would leave every `uvx ...` invocation unfixed.
  postBuild = ''
    for prog in uv uvx; do
      wrapProgram "$out/bin/$prog" \
        --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ gcc16.cc.lib ]}" \
        --set-default PLAYWRIGHT_BROWSERS_PATH "${playwright-driver.browsers}" \
        --set-default PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1"
    done
  '';

  # symlinkJoin does not carry passthru across, which would drop uv's updateScript
  # and tests from the wrapped attribute. `unwrapped` is the escape hatch for
  # anything that genuinely needs the bare binary.
  passthru = (uv.passthru or { }) // { unwrapped = uv; };

  meta = uv.meta // {
    description = "${uv.meta.description}, wrapped for manylinux wheels and the nixpkgs Playwright browsers";
    mainProgram = "uv";
  };
}
