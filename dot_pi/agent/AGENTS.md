# Global instructions

Conventions for every project on this machine.
A project's own `AGENTS.md` adds to these, and where the two overlap the project's file wins — it knows its stack.

## Commits

Conventional Commits everywhere: `type(scope): summary`.

- Subject only by default: no body, no bullets — the summary is the whole message.
- Any type is fine: `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `content`, `perf`, `test`, `revert`.
- A scope names the area when it helps: `feat(motif): add the palette page`.
- Lowercase summary, no trailing period.
- The exception is a commit that closes a tracked issue.
  It gets a body: the part a reviewer cannot infer from the diff, then the closing keyword on its own line.

  ```
  fix(dufs): give the file server its own account

  The share root and auth file move with it, so the Caddy upstream is unchanged.

  Closes #12
  ```

  Closing keywords are `close`/`closes`/`closed`, `fix`/`fixes`/`fixed` and `resolve`/`resolves`/`resolved`.
  The keyword precedes the reference, and both Forgejo and GitHub act on it only for commits that reach the default branch — so the issue closes when the change is pushed, not when it is committed.
- Reference work in another repository by its qualified path, and point at wherever that project actually tracks it.
  A repository can live on one forge and take its issues on another, in which case a reference to the forge it happens to sit on links to nothing.

## Comments

Code carries the what through names.
A comment states a *why* the code cannot show: a constraint, a platform quirk, a workaround, a deliberate omission.
A comment that restates the code is noise — delete it.
Do not restate types; the types already say it.

Documentation takes the form the language has:

- **TypeScript / JavaScript:** [JSDoc](https://jsdoc.app/) — `/** ... */` with `@param`, `@returns`, `@example` on exported functions, modules and non-obvious contracts.
- **Rust:** rustdoc — `///` on items, `//!` at file level.
- **Shell (sh/bash):** [shdoc](https://github.com/reconquest/shdoc) — a file header with `@file`, `@brief` and `@description`; each function gets `@description` plus `@arg`/`@noargs`, and `@exitcode`/`@stdout` where they apply.
- **fish:** a `--description` on every function.
  File headers and longer comments are written in Markdown — backticks for commands, paths and flags, `-` for lists — and formatted with `fish_indent`.

## Text wrapping

Never wrap text by hand.
One sentence is one line — comments, documentation prose, Markdown, YAML, commit subjects.
Do not wrap at 80 columns.

- Tags that are one-per-line by convention (`@param`, `@returns`) stay one per line; that is structure, not wrapping.
- If a spec would force wrapping that adds nothing, prefer the minimal form.

## Scripts

No decorative section banners (`# ── 1. Setup ─────`).
Structure a script with functions instead, and document those.
