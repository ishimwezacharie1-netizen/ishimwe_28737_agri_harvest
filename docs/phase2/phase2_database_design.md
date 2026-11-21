# Phase II: Data sourcing and normalization

## Deliverables

- [Normalized schema DDL](oracle_phase2_schema.sql)
- [ERD](phase2_erd.mmd)
- [Data dictionary](phase2_data_dictionary.md)

This design follows the instructor's Phase II brief. It replaces the earlier generic schema draft and uses source keys and lookup cardinalities measured from the supplied Rwanda CSV.

## Source evidence and scope

- **Dataset:** Rwanda extract from [HarvestStat Africa on HDX](https://data.humdata.org/dataset/harveststat-africa), supplied in `data/raw/adm_crop_data_raw_RW.csv`.
- **Attribution:** HarvestStat Consortium; retain the dataset/source-document attribution in `SOURCE_DATASET` and `SOURCE_DOCUMENT`.
- **Licence:** HDX currently describes the dataset licence as “Other”; an older resource listing refers to CC0 1.0, but that is not enough to establish the exact terms for this extracted file. Verify the file/resource licence before redistribution. The schema deliberately allows `license_name` to remain unconfirmed rather than asserting CC0.
- **Rows:** 13,725 source observations. The unique natural key is present on every source row.
- **Measurements:** 9,123 nonblank `value` cells and 4,602 missing `value` cells (33.5%). Missing values are quality issues, not zeros and not fact rows.
- **Coverage:** 8 observed years (1984, 2006, 2008, 2009, 2010, 2012, 2013, 2017), 15 observed `season_year` labels, three seasons, 38 products, three indicators, and 51 `fnid` area codes representing 42 area names.
- **Units:** `Area Planted / ha`, `Quantity Produced / t`, and `Yield / MT/ha`. Enforce the permitted unit for each indicator.
- **Scope:** observations are aggregate historical crop statistics. The source does not identify a farmer, farm, or plot.

The source inspection also confirmed 51 unique `fnid` values, 38 distinct products, 3 indicators, 15 `season_year` values, 3 season names, no duplicate rows under `(fnid, product, indicator, season_year)`, and no `admin_2` label associated with more than one `admin_1` label.

### Cleaning and retention decisions

The CSV has 68 columns, including a blank-header sequential row counter (`H1`). The supplied file has **28 named columns that are constant or entirely empty**, plus that row counter. We exclude the 28 non-informative named columns and the row counter; all other source columns are retained in raw staging.

The non-informative named columns excluded from the analytical model are:

`country`, `admin_0`, `admin_3`, `admin_4`, `population_group`, `crop_production_system`, `season_type`, `planting_start_date`, `planting_end_date`, `harvest_start_date`, `harvest_end_date`, `vegetative_start_date`, `vegetative_end_date`, `reproductive_start_date`, `reproductive_end_date`, `document_type`, `preference_rating`, `indicator_group`, `country_code`, `geographic_group`, `fewsnet_region`, `specialization_type`, `dataseries_specialization_type`, `data_usage_policy`, `collection_status`, `collection_schedule`, `publication_name`, and `submitted_by`.

The source `id` is **not** the row counter; it is retained as `source_record_id`.

The raw staging table retains all other source values as text, including date-like and numeric fields. This preserves the source text and lets Phase IV validation reject malformed values explicitly. CSV import leaves the staging `batch_id` blank so the identity and operational columns can be omitted from the import mapping; the Phase IV load script assigns the prepared batch immediately after import. The curated fact table receives only rows with a valid numeric `value` and resolved lookup keys.

## Normalization

### First normal form (1NF)

Each retained CSV field is a single source attribute. The raw source is loaded one observation per staging row, with the original `id` retained as `source_record_id`. The unnamed sequential row counter is not a business attribute and is discarded. Dates, source values, and labels remain atomic text in staging; they are parsed into typed date/number/dimension columns only during validation.

### Second normal form (2NF)

The fact table's natural key is `(fnid, crop_id, indicator_id, season_year_id)`, corresponding to the source key `(fnid, product, indicator, season_year)`. All non-key facts (`numeric_value`, source record/document reference, batch, and quality status) describe the complete observation, not a proper subset of the natural key. Crop, indicator, area, season, and source-document attributes are moved to their own lookup tables instead of being repeated on each fact.

### Third normal form (3NF)

- Crop names/descriptions depend on `crop_id`; indicator name and permitted unit depend on `indicator_id`; season name depends on `season_id`.
- The composite source period is split into `SEASON` and `SEASON_YEAR`; each season-year row refers to one season and year.
- Geography is separated into `ADMIN_1`, `ADMIN_2`, and `ADMIN_AREA`. In the supplied data, all 30 populated district (`admin_2`) labels map to exactly one `admin_1`; there were zero conflicting parent mappings. Storing both district and parent name on every area row would repeat the transitive dependency `admin_2 -> admin_1`, so the parent is stored once in `ADMIN_2`. Historical area codes without a source `admin_2` use `ADMIN_AREA.legacy_admin_1_id` to preserve their source level-one label without pretending those historic labels are current provinces.
- Dataset metadata, batch metadata, and source document/organization metadata are separated from observations.
- `DATA_QUALITY_ISSUE`, `DATA_CORRECTION_REQUEST`, and `AUDIT_EVENT` record quality and controlled-change workflow data without adding those attributes to the crop fact.

## Keys and expected cardinalities

| Entity | Key | Expected source count | Notes |
|---|---|---:|---|
| `ADMIN_AREA` | `fnid` | 51 | 42 distinct display names; historical codes can share a name |
| `CROP` | `crop_id`; unique `crop_code` and `crop_name` | 38 | `crop_code` maps source `cpcv2`; name maps `product` |
| `INDICATOR` | `indicator_id`; unique `indicator_code` and `indicator_name` | 3 | Stores permitted unit and source unit label |
| `SEASON_YEAR` | `season_year_id`; unique `(season_id, observation_year)` | 15 | Source natural value is `season_year` |
| `SEASON` | `season_id`; unique `season_name` | 3 | Season A, B, C |
| `ADMIN_1` | `admin_1_id`; unique `admin_1_name` | 16 | Includes historical source labels; not all are current provinces |
| `ADMIN_2` | `admin_2_id`; unique `admin_2_name` | 30 | District names map to one `ADMIN_1` |
| `AGG_CROP_STATISTIC` | `statistic_id`; unique natural key below | 9,123 populated facts | Missing values remain staged and are logged |

The natural-key uniqueness rule is `UNIQUE (fnid, crop_id, indicator_id, season_year_id)`, equivalent to the supplied source key `(fnid, product, indicator, season_year)`. A separate unique source record id prevents reloading the same source observation.

The three exact source-table target counts given in the brief (51, 38, 3, 15, 3) correspond to area, crop, indicator, season-year, and season. `ADMIN_1` (16) and `ADMIN_2` (30) are additional normalization tables required by the observed geography dependency.

## Raw-to-3NF flow and loading interpretation

1. Load **all 13,725 source observations** into `STAGE_CROP_OBSERVATION` for traceable staging.
2. Resolve and populate the source document, geography, crop, indicator, season, and season-year lookups.
3. Load **9,123 nonmissing valid observations** into `AGG_CROP_STATISTIC`.
4. Insert **4,602 `MISSING_VALUE` quality issues** linked to their staging rows. Never substitute zero for a missing source value.
5. Record validation totals in `IMPORT_BATCH`: 13,725 staged, 9,123 accepted facts, 4,602 rejected/missing-value rows, subject to value/key/unit validation.

Thus “13,725 loaded” means loaded into staging and accounted for; it does not mean 13,725 non-null fact values. Validation must also report zero natural-key duplicates and zero orphan foreign keys.

## Verification still required

The current environment has no Oracle/SQL*Plus client, so the DDL has not been compiled or run. During the database/data-loading phases, verify the exact dimension counts, fact/staging/quality counts, key uniqueness, orphan checks, mixed-unit rules, and script output on the Oracle instance. The course's formal grading rubric beyond the supplied instructions was not available.
