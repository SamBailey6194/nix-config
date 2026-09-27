# just-panel: review notes

Edge cases worth a unit test in `src/sections.rs`:

- a banner that holds only sub-sections
- a sub-section above the first banner
- a recipe header with a quoted default, such as `fuzz TARGET TIME="300":`
- a ruler made of only two `=` signs
