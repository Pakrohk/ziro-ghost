# PR Checklist & Review Gate

Before opening or merging a PR for Spec NNN, verify every item below:

## 1. Spec Alignment & Scope Boundaries
- [ ] Spec exists at `.specify/specs/NNN-<name>/spec.md` with status `Approved`.
- [ ] PR implements strictly the requirements listed in the spec (no out-of-scope additions).
- [ ] Every commit references the spec requirement (e.g. `feat(core): ... (R1 of Spec NNN)`).
- [ ] Out of Scope boundaries respected — no drive-by refactorings or unapproved features.

## 2. Code Quality & Engineering Conventions
- [ ] Follows `.specify/CONVENTIONS.md` (Python typing, dataclasses, Zsh `emulate -L zsh`).
- [ ] No bare `except:` blocks; specific exceptions handled with descriptive context.
- [ ] Path handling strictly uses `core/paths.py::get_paths()` without hardcoded home directories.
- [ ] Files and directories created with secure permissions (`0o700` / `0o600` where applicable).
- [ ] No command substitutions `$(...)` introduced in hot-path shell startup.

## 3. Test & Verification Gate
- [ ] Acceptance Criteria (AC) verification: every AC in the spec is covered by an automated test.
- [ ] Full test suite executes and passes 100%:
  ```bash
  PYTHONPATH=. uv run --with pytest pytest tests/ -q
  ```
- [ ] Interactive and non-interactive startup is verified clean and silent:
  ```bash
  zsh -f -c 'source ~/.zshrc'
  ```
- [ ] Health diagnostic reports healthy with zero errors:
  ```bash
  ziro doctor
  ```

## 4. Documentation & Ledger Synchronization
- [ ] Reality Check section in `.specify/specs/NNN-<name>/spec.md` filled with commit hash and test output.
- [ ] ADL entry added append-only to `.specify/HANDOFF.md` referencing Spec NNN.
- [ ] Version bumped in:
  - `pyproject.toml`
  - `core/constants.py` (`VERSION = "1.2.N"`)
  - `ziro.zsh`
- [ ] `CHANGELOG.md` updated with release notes and user-facing impact.
