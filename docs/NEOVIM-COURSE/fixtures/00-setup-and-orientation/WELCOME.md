# Lesson 00 fixture

**Last Updated**: 27/09/2026
**Version**: 1.0.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

`tapes/00-setup-and-orientation.tape` copies this folder to
`/tmp/nvim-course/00-setup-and-orientation` and starts a bare `nvim` there. The
tree then shows this small, stable folder instead of your real nix-config
checkout, so every re-recording looks the same.

The two sub-folders only mark where the capstones will live in the real
repository: `rust/just-panel` and `python/session-browser`. Nothing here is
built, run or opened by the tape.
