{ pkgs, ... }:

# Email client (Claws Mail)
#
# WHY CLAWS AND NOT THUNDERBIRD
#
# The requirement was a desktop mail client that is not a browser in disguise.
# Thunderbird is Gecko; Geary, Evolution, Balsa and KMail all link WebKitGTK to
# render the message pane, because HTML email is web content. Claws is the one
# GUI client where the web engine is optional, and nixpkgs exposes it as a
# build flag - so the override below produces a mail client with no browser
# engine in its closure at all. Verified on 4.4.0:
#
#   default build   fancy.so -> libwebkit2gtk-4.1.so.0
#                            -> libjavascriptcoregtk-4.1.so.0
#   this build      litehtml_viewer.so -> libgumbo.so.3 only
#                   claws-mail binary  -> zero webkit/JS libraries
#
# litehtml + gumbo is a small C/C++ HTML/CSS renderer with NO JavaScript
# engine, so HTML mail still renders properly; it just cannot execute anything.
# For an email client that is a feature, not a limitation.
#
# AUTHENTICATION - WHY THERE IS NO oama HERE
#
# Gmail app passwords are being phased out and Microsoft finished retiring
# Basic Auth for IMAP/POP/SMTP in April 2026, so Outlook is OAuth2-only now.
# Claws implements OAuth2 itself (since 3.18): it both obtains AND refreshes
# tokens, via a browser consent flow on localhost:8888, using the libcurl this
# package already links.
#
# That is why the oama / cyrus-sasl-xoauth2 stack this was originally scoped
# around is absent. oama exists for clients that speak XOAUTH2 but cannot
# acquire or renew tokens - mbsync, msmtp, aerc, neomutt. Claws is not one of
# them, and cyrus-sasl-xoauth2 is only needed by mbsync
# (isync.override { withCyrusSaslXoauth2 = true; }). No mbsync, no SASL plugin.
#
# CONFIGURATION IS DELIBERATELY NOT DECLARATIVE
#
# There is no home-manager module for Claws, and the ~/.aws/config pattern in
# aws.nix does NOT transfer here. That pattern works because the AWS CLI only
# ever READS its config - aws.nix even documents that `aws configure sso`
# cannot write to the managed file. Claws is the opposite: it owns and rewrites
# clawsrc, accountrc, folderitemrc and folderlist.xml on exit and on every
# settings or folder-state change. Pointing any of those at a read-only
# /run/agenix symlink would stop Claws saving and lose folder state.
#
# So accounts are set up once through the GUI. What IS declarative lives in the
# repo: this package, the workspace 6 window rule (config/hypr/00-vars.lua) and
# the SUPER + E keybind (config/hypr/60-keybinds.lua).

{
  home.packages = [
    (pkgs.claws-mail.override {
      # The two browser engines, both off.
      enablePluginFancy = false; # WebKitGTK + JavaScriptCore
      enablePluginDillo = false; # the Dillo browser

      # HTML rendering without a browser: deps = [ gumbo ].
      enablePluginLitehtmlViewer = true;
    })
  ];
}
