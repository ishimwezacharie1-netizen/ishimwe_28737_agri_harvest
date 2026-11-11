# Phase 3: PL/SQL implementation

## Scope and status

Phase 3 implements the Phase 2 Oracle schema's validation, quality reporting, safe-yield calculation, and controlled correction workflow. It remains within the project's aggregate Rwanda benchmark scope; it does not add farmer, farm, or plot records.

The implementation has not been compiled or run against an Oracle instance in this environment. The course's Phase 3 rubric was not available, so confirm that these deliverables match the instructor's requirements before submission.

## Deliverables

- `phase3_implementation.sql`: creates reviewer and quality-summary tables, the `PKG_HARVEST_BENCHMARK` package, and fact-data protection, audit, and correction-request triggers.
- `phase3_smoke_test.sql`: transaction-scoped checks for validation, missing values, invalid units, completeness calculations, safe yield, self-approval prevention, unapproved corrections, and direct fact-table update protection.

## Install and test

Use an Oracle 12c-or-later schema. First run the Phase 2 DDL, then the Phase 3 installer, then the smoke test in a dedicated session. For example, from SQL*Plus at the repository root:

```sql
@docs/phase2/oracle_phase2_schema.sql
@docs/phase3/phase3_implementation.sql
@docs/phase3/phase3_smoke_test.sql
```

The installer is one-time DDL; it does not drop or replace existing Phase 2 tables. The smoke test rolls its fixture data back to a savepoint and does not commit. The installer and smoke test have not been run here because SQL*Plus/Oracle is unavailable.

## Load and validate data

Before calling `p_validate_stage`, populate the `CROP`, `ADMIN_AREA`, `SEASON`, and `INDICATOR` reference tables with canonical labels and units. Import the original observation labels into `STAGE_CROP_OBSERVATION`, with `SOURCE_RECORD_ID` carrying the source row's `id`, `SOURCE_STATUS` carrying the source collection status, `VALUE_TEXT` carrying the source value as text, and season/year fields preserving the source labels.

`p_validate_stage(batch_id)` accepts only a batch in `STAGED` status. It resolves dimensions by case-insensitive trimmed labels, accepts only the configured indicator/unit pair and a nonnegative decimal within `NUMBER(18,4)`, and logs missing, invalid, duplicate, or unresolved source rows to `DATA_QUALITY_ISSUE`. The batch becomes `LOADED` if every row is accepted, `VALIDATED` if it has both accepted and rejected rows, or `REJECTED` if no rows are accepted. It records counts on `IMPORT_BATCH`.

The supplied Rwanda source uses the indicator/unit pairs `Area Planted / ha`, `Quantity Produced / t`, and `Yield / MT/ha`. Seed these exact permitted unit values in `INDICATOR`; curate dimension labels before validation so ambiguous labels fail closed into quality issues rather than loading to the wrong entity. The installer adds case-insensitive unique indexes for crop and indicator names to keep summary joins unambiguous; remove any duplicate labels before installation.

## Quality and correction workflow

- `p_refresh_quality_summary` refreshes staged completeness summaries by crop, indicator, and year.
- `f_completeness_pct` returns a percentage for the matching staged observations, or `NULL` when no denominator exists.
- `f_safe_yield` computes tonnes per hectare only for supported area/quantity units and a positive area; it raises a clear error for incompatible units or invalid values.
- `p_submit_correction` creates a pending request using the current database session user and captures the existing value.
- A database administrator must insert authorized reviewer usernames into `AUTHORIZED_REVIEWER`. Reviewers use `p_review_correction`; the requester cannot approve their own request.
- `p_apply_approved_correction` applies only an approved request. Direct insert, update, and delete against `AGG_CROP_STATISTIC` is blocked; approved numeric changes are written to `AUDIT_EVENT`.

Reviewer enrollment is an administrative action, for example:

```sql
INSERT INTO authorized_reviewer (reviewer_username)
VALUES ('ORACLE_REVIEWER_USERNAME');
COMMIT;
```

Run reviewer enrollment as an authorized administrator, not as an ordinary dashboard user. Database grants should restrict changes to `AUTHORIZED_REVIEWER` and direct DML on curated tables to trusted administrators.

## Verification still required

Compile the install script on the actual Oracle version, run the smoke test, then test a full source batch after seeding the dimensions. Review any rejected rows and confirm the completeness denominator and reviewer usernames against the instructor's requirements. The smoke test deliberately verifies that an unprivileged user cannot self-approve a correction; the successful two-user approval-and-application path requires two Oracle sessions and separate reviewer credentials.
