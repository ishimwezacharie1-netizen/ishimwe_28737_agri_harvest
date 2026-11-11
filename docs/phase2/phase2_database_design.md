# Phase 2: Oracle relational schema and validation design

## 1. Purpose

Phase 2 translates the approved business process for Rwanda crop benchmarking into a normalized Oracle relational design. The objective is to preserve source provenance, separate validated benchmark facts from staged data, and enforce data-quality rules before values are exposed in the dashboard.

This is the Phase 2 relational schema design, based on the project scope and the Phase I process model. It has not been run against an Oracle instance, and the course's Phase 2 rubric was not available for comparison.

The design follows the stated project principles:

- Keep source data read-mostly and traceable.
- Accept only valid crop/indicator/unit combinations.
- Treat aggregate benchmark rows as curated statistics, not as farm records.
- Support correction requests with approval workflow and audit logs.

## 2. Business rules implemented in the schema

1. Each source dataset must be traceable to a citation, version, and import batch.
2. Source rows first enter staging, which preserves the source identifiers, labels, status, value text, unit, period, and season fields needed for validation.
3. Only numeric observations with resolved crop, area, season, and indicator references belong in the fact table. Missing or rejected rows remain traceable in staging and can be associated with a quality issue.
4. The fact table's foreign keys enforce batch/dataset consistency and indicator/unit compatibility.
5. Correction requests record the proposed change and reviewer decision. Applying and authorizing a correction requires later PL/SQL implementation; the table definitions alone do not enforce the workflow.
6. The audit table is provided for approved changes. Automatic auditing and blocking direct DML require later trigger/package implementation.

## 3. Entity model

### Core dimensions

- `SOURCE_DATASET`: stores dataset metadata, licensing, and provenance. One dataset can have many batches.
- `IMPORT_BATCH`: stores import loads, counts, and timestamps for one dataset.
- `ADMIN_AREA`: stores historical administrative geography labels and period context.
- `CROP`: stores crop or product names and grouping information.
- `SEASON`: stores season names and reporting periods.
- `INDICATOR`: stores metric type and permitted unit.

### Fact and quality tables

- `STAGE_CROP_OBSERVATION`: stores source rows before validation, including incomplete and rejected rows.
- `AGG_CROP_STATISTIC`: stores numeric observations that have been resolved to crop, area, season, and indicator dimensions.
- `DATA_QUALITY_ISSUE`: stores quality issues linked to a staged row and/or a curated statistic.
- `DATA_CORRECTION_REQUEST`: stores the proposed change, reviewer decision, and evidence.
- `AUDIT_EVENT`: stores every approved change and the associated user and correction request.

## 4. Relational design summary

- `SOURCE_DATASET` 1 -> many `IMPORT_BATCH`
- `IMPORT_BATCH` 1 -> many `STAGE_CROP_OBSERVATION`
- `IMPORT_BATCH` 1 -> many `AGG_CROP_STATISTIC`
- `ADMIN_AREA` 1 -> many `AGG_CROP_STATISTIC`
- `CROP` 1 -> many `AGG_CROP_STATISTIC`
- `SEASON` 1 -> many `AGG_CROP_STATISTIC`
- `INDICATOR` 1 -> many `AGG_CROP_STATISTIC`
- `STAGE_CROP_OBSERVATION` 1 -> many `DATA_QUALITY_ISSUE`
- `AGG_CROP_STATISTIC` 1 -> many `DATA_QUALITY_ISSUE`
- `AGG_CROP_STATISTIC` 1 -> many `AUDIT_EVENT`
- `DATA_CORRECTION_REQUEST` 1 -> many `AUDIT_EVENT`

## 5. Key constraints and controls

- Primary keys on all dimension and fact tables.
- Foreign keys from all dependent tables to the referenced master tables.
- `CHECK` constraints to enforce valid status flags and nonnegative benchmark values.
- `NOT NULL` constraints on required identifiers and source keys.
- `UNIQUE` constraints on dataset, batch, crop, season, and indicator identifiers.
- Composite foreign keys ensure a fact row's batch belongs to its dataset and its unit is the indicator's permitted unit.
- The SQL schema does not yet include authorization, direct-DML restriction, or automatic audit triggers; these are implementation requirements for a later PL/SQL phase.

## 6. Oracle implementation outline

The SQL companion contains Oracle DDL for the dimensions, import batch, staging, fact, quality, correction, and audit tables. It intentionally contains no empty PL/SQL stubs: package bodies and triggers should be added and tested in the implementation phase rather than presented as working code here. Identity columns require Oracle Database 12c or later.

## 7. Expected Phase 2 outputs

- Relational schema with master tables and fact tables
- Data-validity constraints for indicator/unit compatibility and nonnegative numeric values
- Staging and correction workflow tables, plus an audit-event table
- A clear boundary between schema DDL and PL/SQL implementation still to be completed

## 8. Deliverable status

This document and its SQL companion provide the Phase 2 schema-design deliverable. They have not been executed against Oracle; syntax and behavior must be confirmed in the target Oracle version before deployment.
