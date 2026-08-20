# django-template-lsp (`djlsp`) — language server for Django templates.
#
# Not packaged in nixpkgs (verified against the pinned nixpkgs: no
# `django-template-lsp`/`djlsp` at top level or in python3Packages), so it is
# built here from the PyPI sdist. It covers what pyright/ruff cannot: `{% %}` tag
# and filter completion, template/static/url name resolution, and context
# variables — the template half of a Django project.
#
# Consumed by Neovim's `djlsp` lspconfig entry and by Zed's `django` extension
# (which otherwise pip-installs its own copy at runtime).
#
# To bump: change `version` and `hash`. Get the new hash with:
#   nix store prefetch-file --unpack \
#     https://files.pythonhosted.org/packages/source/d/django-template-lsp/django_template_lsp-<VERSION>.tar.gz
{
  lib,
  python3Packages,
}:

let
  # djlsp 1.3.1 — and upstream main — pin `pygls>=1.0.0,<2.0.0`, and import
  # `pygls.server.LanguageServer` and `pygls.protocol.LanguageServerProtocol`,
  # both of which moved in pygls 2.x. Relaxing the bound would only trade a build
  # failure for an ImportError on first request. nixpkgs ships pygls 2.1.1, so the
  # 1.x line (and the exact lsprotocol it pins) is built here and used by nothing
  # else — this is a private closure, not an override of the global package set.
  lsprotocol_2023 = python3Packages.buildPythonPackage rec {
    pname = "lsprotocol";
    version = "2023.0.1";
    pyproject = true;

    src = python3Packages.fetchPypi {
      inherit pname version;
      hash = "sha256-zFwVEw0kA8GLc0MEM55RJC0wGKBcT30PGYrW4M0hhh0=";
    };

    build-system = [ python3Packages.flit-core ];
    dependencies = with python3Packages; [ attrs cattrs ];

    doCheck = false;
    pythonImportsCheck = [ "lsprotocol" ];
  };

  pygls_1 = python3Packages.buildPythonPackage rec {
    pname = "pygls";
    version = "1.3.1";
    pyproject = true;

    src = python3Packages.fetchPypi {
      inherit pname version;
      hash = "sha256-FA7c7voNoOmzxTNUfIkqQqfS/ZIXroSMMwxT0malUBg=";
    };

    build-system = [ python3Packages.poetry-core ];
    dependencies = [ lsprotocol_2023 python3Packages.cattrs ];

    doCheck = false;
    pythonImportsCheck = [ "pygls" ];
  };
in
python3Packages.buildPythonApplication rec {
  pname = "django-template-lsp";
  version = "1.3.1";
  pyproject = true;

  src = python3Packages.fetchPypi {
    pname = "django_template_lsp";
    inherit version;
    hash = "sha256-AmHt6XSIAe2qaG5QhVBsACPzWIBqynnIKL385iHHmRQ=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = [
    pygls_1
    python3Packages.jedi
  ];

  # Upstream's suite drives a full Django project fixture (tests/django_test) that
  # expects a writable venv, which the build sandbox does not provide.
  doCheck = false;

  pythonImportsCheck = [ "djlsp" ];

  meta = {
    description = "Language server for Django templates";
    homepage = "https://github.com/fourdigits/django-template-lsp";
    license = lib.licenses.gpl3Only;
    mainProgram = "djlsp";
  };
}
