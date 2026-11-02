# Spec NNN: <Title>

- **Status**: Draft | Proposed | Approved | Implemented | Superseded
- **Author**: <Author>
- **Created**: YYYY-MM-DD
- **Target Version**: v1.2.N
- **Branch**: feat/NNN-<short-name>

---

## Problem
<Describe the problem, vulnerability, bug, or missing capability concisely.
Explain WHY this change is required and WHAT breaks or leaks if not addressed.>

---

## Requirements
- **R1**: <Specific requirement>
- **R2**: <Specific requirement>
- **R3**: <Specific requirement>

---

## Acceptance Criteria
- [ ] **AC1**: <Testable, observable condition>
- [ ] **AC2**: <Testable, observable condition>
- [ ] **AC3**: <Testable, observable condition>
- [ ] **AC4**: All tests pass (`pytest tests/`).
- [ ] **AC5**: Shell startup remains silent and fast (`ziro doctor` reports healthy).

---

## Out of Scope
- <Explicitly state what is NOT included in this spec to prevent scope creep.>
- <Work that belongs to future specs.>

---

## Dependencies
- <Prerequisite specs, external tools, or versions required.>

---

## Reality Check
*(To be completed after implementation during verification)*

- **Shipped in commit**: `<hash>`
- **Actual deviations from spec**: None | `<details>`
- **Observed test results**: `<test count and timing>`
- **Verification evidence**: `<commands and output>`
