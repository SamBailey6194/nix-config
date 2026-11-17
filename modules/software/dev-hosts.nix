# /etc/hosts names for syntek-base-style dev stacks (Copier projects).
#
# Those projects publish each story worktree's stack on its own loopback IP and
# expect /etc/hosts to name it:
#   127.0.0.<N>  dev-us<NNN>.<slug>.localhost  test-us<NNN>.<slug>.localhost
# Every name also gets an api. twin (api.dev-us<NNN>.<slug>.localhost, ...)
# for the API host: Django REST/Ninja or Axum + Utoipa, with Leptos or the
# Django templates on the plain name. Which service answers which name is the
# project's reverse proxy's job (nginx server_name / Host routing); this only
# makes both names resolve to the stack's IP.
#
# The IP here is the HOST side: compose publishes "127.0.0.N:<port>:<container
# port>". Inside the container the server must listen on 0.0.0.0 (Leptos'
# LEPTOS_SITE_ADDR / site-addr, `manage.py runserver 0.0.0.0:8000`, gunicorn
# --bind 0.0.0.0), or Docker's forwarded traffic never reaches it. 0.0.0.0 is
# a listen address, never a destination, so it never appears in /etc/hosts.
# Run natively (cargo leptos watch, runserver) instead, bind 127.0.0.N:<port>
# directly: Linux answers the whole 127.0.0.0/8 on lo without configuration.
# Their hosts-story-add.sh writes that line with `sudo tee -a /etc/hosts`, which
# cannot work on NixOS: /etc/hosts is a read-only link into the store, and any
# hand edit is gone at the next rebuild. So the lines are generated here
# instead, for every story the script accepts (1-253, the same range and
# padding), plus dev.<slug>.localhost for the main stack on 127.0.0.1.
#
# The slugs live in ./dev-hosts.json so they can be edited without touching
# Nix: `just dev-hosts`, `just dev-host-add <slug>`, `just dev-host-remove
# <slug>`, then `just rebuild`. An empty list adds nothing.
#
# Interim: DDEV (one project per worktree on *.ddev.site, public DNS) is the
# long-term replacement for this per-story IP bookkeeping.
{ lib, ... }:

let
  inherit (builtins) fromJSON readFile;
  slugs = (fromJSON (readFile ./dev-hosts.json)).slugs;

  # Same rule as scripts/dev-hosts.py: one DNS label, lower case, no
  # underscores (syntek-base's copier.yml refuses those for PROJECT_SLUG too).
  valid = s: builtins.match "[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?" s != null;

  pad = n: lib.fixedWidthNumber 3 n;
  withApi = name: [ name "api.${name}" ];
  storyHosts = slug: n: lib.concatMap withApi [ "dev-us${pad n}.${slug}.localhost" "test-us${pad n}.${slug}.localhost" ];

  perIp = n: lib.concatMap (slug: storyHosts slug n) slugs
    ++ lib.optionals (n == 1) (lib.concatMap (slug: withApi "dev.${slug}.localhost") slugs);
in
{
  assertions = map (slug: {
    assertion = valid slug;
    message = "modules/software/dev-hosts.json: \"${slug}\" is not a valid hostname label (lower-case letters, digits and inner hyphens, at most 63).";
  }) slugs;

  networking.hosts = lib.mkIf (slugs != [ ]) (lib.listToAttrs (map (n: {
    name = "127.0.0.${toString n}";
    # After NixOS's own names, so 127.0.0.2 still reverse-resolves to this
    # machine's hostname rather than to story 2's stack.
    value = lib.mkAfter (perIp n);
  }) (lib.range 1 253)));
}
