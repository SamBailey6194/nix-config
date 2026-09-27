# Your keybinding system

Every binding in this course comes from one list in `home/modules/neovim.nix`.
That list writes the Lua that creates the mappings and the Markdown reference
that the dev layout shows next to Neovim.

## Three questions to ask about any key

1. Which mode is it defined in?
2. Is it global, or local to this buffer?
3. Does a longer mapping start with the same keys?

## Tools that answer them

- `:map` and `:nmap` list mappings.
- `:verbose` adds where each mapping was set.
- `:WhichKey` opens the popup on demand.
- `:checkhealth which-key` reports keys that are also prefixes.
