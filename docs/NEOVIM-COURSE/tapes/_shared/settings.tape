# tapes/_shared/settings.tape
#
# Pulled in by every lesson tape with `Source tapes/_shared/settings.tape` as
# its FIRST command. Only Set lines belong here: Source drops Output lines, and
# any non-Set command (Env, Hide, Type...) would make every later Set in the
# lesson tape be ignored ("WARN: 'Set ...' has been ignored").
#
# Paths in every tape resolve against the directory vhs is RUN from, so always
# run tapes from docs/NEOVIM-COURSE/:  vhs tapes/NN-slug.tape
#
# Theme "ayu" is VHS's built-in theme whose background/foreground/cursor match
# ayu-vim's dark palette, which is what neovim.nix loads - so the padding and
# the Neovim background are seamless. 1440 px is the 75% share of a 1920 px
# screen that the dev layout gives Neovim.
#
# Units matter: a bare number is SECONDS in VHS (TypingSpeed 75 = 75 s/key).
Set Shell "bash"
Set FontFamily "JetBrainsMono Nerd Font,JetBrains Mono,DejaVu Sans Mono,monospace"
Set FontSize 20
Set Width 1440
Set Height 900
Set Padding 20
Set WindowBar Colorful
Set WindowBarSize 36
Set Theme "ayu"
Set TypingSpeed 60ms
Set Framerate 30
Set CursorBlink false
Set WaitTimeout 20s
