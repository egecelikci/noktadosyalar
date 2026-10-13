# Commits

Follow Conventional Commits everywhere: `type(scope): summary`.

- Subject only. No body, no bullets — the summary is the whole message.
- Any Conventional Commits type is fine: `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `content`, `perf`, `test`, `revert`, and so on.
- Scope names the area when it helps: `feat(motif): add the palette page`.
- Lowercase summary, no trailing period.

# Comments in scripts

No decorative section banners (`# ── 1. Setup ─────`) anywhere. Structure a script with functions instead, and document those.

- **Shell (sh/bash):** [shdoc](https://github.com/reconquest/shdoc) annotations. A file header with `@file`, `@brief` and `@description`; each function gets `@description` plus `@arg`/`@noargs`, and `@exitcode`, `@stdout` where they apply.
- **fish:** every function gets `--description`. File headers and longer comments are written in Markdown: backticks for commands, paths and flags; `-` lists. Format with `fish_indent`.
- Comments explain why, not what the next line does.
