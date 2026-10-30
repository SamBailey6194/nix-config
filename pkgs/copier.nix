# copier, bumped ahead of nixpkgs (9.17.1 at the time of writing). Upstream's
# runtime dependencies are identical between the two releases, so only the
# source changes; the build, wrapper and meta all come from the nixpkgs package.
#
# To bump: change `version` (https://pypi.org/project/copier/), set `hash` to
# lib.fakeHash and rebuild to get the new one, and compare the `dependencies`
# in upstream's pyproject.toml against the nixpkgs package. Drop this file once
# nixpkgs catches up.
{ copier, fetchFromGitHub }:

copier.overridePythonAttrs (old: rec {
  version = "9.19.1";

  src = fetchFromGitHub {
    owner = "copier-org";
    repo = "copier";
    tag = "v${version}";
    # Same as nixpkgs: this test file conflicts on APFS on darwin
    postFetch = ''
      rm $out/tests/demo/doc/ma*ana.txt
    '';
    hash = "sha256-ekxe6pnbbAf5Lp1MfZyhAYtQoMtQPaBdgNLjxs9DXm0=";
  };

  env = (old.env or { }) // {
    POETRY_DYNAMIC_VERSIONING_BYPASS = version;
  };
})
