# Phase IV: Tables and data loading

## What is prepared

- The dependency-ordered table DDL is in [the Phase II schema script](../phase2/oracle_phase2_schema.sql): source dataset/batch/document, geography, crop/indicator/season lookups, raw staging, fact table, quality issues, correction requests, and audit events.
- [phase4_prepare.sql](phase4_prepare.sql) seeds the source metadata and an import batch.
- [phase4_load.sql](phase4_load.sql) checks the source shape and values, assigns imported rows to the batch, inserts dimensions, loads nonmissing facts, and logs missing values.
- [phase4_validation.sql](phase4_validation.sql) reports expected totals and checks duplicates, foreign keys, and indicator units.

These are implementation scripts, not proof of an executed Oracle load. The local environment does not have an Oracle client, and no Oracle instance output/screenshots are available yet.

## Import workflow

1. Connect to the project schema in SQL Developer. Create a fresh project schema using the Phase II DDL; do not run the DDL twice against an existing schema.
2. Run `phase4_prepare.sql`.
3. Use **Tools → Import Data** on `STAGE_CROP_OBSERVATION`, selecting `data/raw/adm_crop_data_raw_RW.csv`.
4. In the import wizard, use the CSV header and map only these 39 retained source fields to the corresponding staging columns. Do not map the blank first CSV header/row-counter, the 28 constant/empty columns, `stage_row_id`, `batch_id`, or `row_status`. Map source `id` to `source_record_id`; keep date and measurement values as text in the staging columns ending `_raw`.
5. Confirm the wizard preview shows 13,725 rows and 39 mapped source fields before starting the import. The `batch_id` field is nullable only during this import; the ETL assigns the prepared batch.
6. Run `phase4_load.sql`. It stops with an explicit error if counts, values, units, natural keys, or the fresh-schema precondition do not match the known source profile.
7. Run `phase4_validation.sql`. It fails with an explicit error if the staged, fact, missing-value, duplicate-key, or foreign-key totals differ from the required profile.
8. Save the SQL output and SQL Developer screenshots as Oracle execution evidence:
   - successful `phase4_prepare.sql` output;
   - successful `phase4_load.sql` output with its batch status;
   - the `PASS` validation message;
   - the lookup-count, duplicate, orphan, and unit queries;
   - the five required table counts and the 9,123 fact count.

## Expected results

| Check | Expected |
|---|---:|
| Raw CSV observations in `STAGE_CROP_OBSERVATION` | 13,725 |
| Populated values loaded into `AGG_CROP_STATISTIC` | 9,123 |
| `MISSING_VALUE` rows in `DATA_QUALITY_ISSUE` | 4,602 |
| `ADMIN_AREA` / `CROP` / `INDICATOR` / `SEASON_YEAR` / `SEASON` | 51 / 38 / 3 / 15 / 3 |
| Duplicate fact natural keys | 0 |
| Orphan fact foreign keys | 0 |
| Unit mismatch among loaded facts | 0 |

`IMPORT_BATCH.rejected_rows` counts the 4,602 rows withheld from the fact table because the source value is blank. The original rows remain in staging and are traceable to quality issues; no missing value is replaced with zero.

The fact table's natural-key uniqueness constraint is `(fnid, crop_id, indicator_id, season_year_id)`, equivalent to the supplied source key `(fnid, product, indicator, season_year)`. The import/ETL is intended for an empty project schema and is not an incremental reload utility.

Because the batch contains accepted facts and missing-value rejections, its final status is `VALIDATED` (not `LOADED`), consistent with the Phase III validation rule. `LOADED` means the expected fact and staging profile was created successfully for this mixed-source batch; missing values are intentionally retained as quality records rather than facts.
