# Phase II data dictionary

Oracle types, nullability, keys, and defaults below match [oracle_phase2_schema.sql](oracle_phase2_schema.sql). `PK` is primary key, `FK` is foreign key, and `UK` is a unique constraint. “System” means generated or operational metadata, not a source CSV field. Source columns are named as they appear in the HarvestStat extract; staging preserves raw text for fields that require later parsing.

## SOURCE_DATASET

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `dataset_id` | NUMBER identity | PK | No | Internal dataset identifier. | System |
| `dataset_code` | VARCHAR2(100) | UK | No | Stable project code for the dataset. | System |
| `dataset_name` | VARCHAR2(255) | — | No | Dataset's display name. | Dataset metadata |
| `source_url` | VARCHAR2(500) | — | No | Canonical dataset URL. | Dataset metadata |
| `license_name` | VARCHAR2(255) | — | Yes | License label; nullable until the specific file terms are confirmed. | Dataset metadata |
| `license_reviewed_at` | DATE | — | Yes | Date license terms were checked. | System |
| `attribution_text` | VARCHAR2(1000) | — | Yes | Attribution to retain with the source. | Dataset metadata |
| `created_at` | TIMESTAMP | — | No | Row creation timestamp. | System |

## IMPORT_BATCH

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `batch_id` | NUMBER identity | PK | No | Internal import batch identifier. | System |
| `dataset_id` | NUMBER | FK → `SOURCE_DATASET.dataset_id` | No | Dataset imported in this batch. | System |
| `batch_code` | VARCHAR2(100) | UK with `dataset_id` | No | Unique batch label within its dataset. | System |
| `file_name` | VARCHAR2(255) | — | No | Name of the imported source file. | File metadata |
| `import_status` | VARCHAR2(20) | CHECK | No | `STAGED`, `VALIDATED`, `LOADED`, or `REJECTED`. | System |
| `imported_at` | TIMESTAMP | — | No | Batch creation/import timestamp. | System |
| `total_rows` | NUMBER | CHECK | No | Number of source rows in the batch. | Import measurement |
| `loaded_rows` | NUMBER | CHECK | No | Number of accepted fact rows. | Import measurement |
| `rejected_rows` | NUMBER | CHECK | No | Number of rows not loaded as facts. | Import measurement |

## SOURCE_DOCUMENT

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `source_document_id` | NUMBER identity | PK | No | Internal document identifier. | System |
| `dataset_id` | NUMBER | FK → `SOURCE_DATASET.dataset_id` | No | Dataset containing the source document. | System |
| `source_document_code` | VARCHAR2(50) | UK with `dataset_id` | No | Source document identifier. | `datasourcedocument` |
| `source_document_name` | VARCHAR2(500) | — | No | Source document title/name. | `source_document` |
| `source_organization_code` | VARCHAR2(50) | — | Yes | Source organization identifier. | `datasourceorganization` |
| `source_organization_name` | VARCHAR2(500) | — | Yes | Source organization name. | `source_organization` |

## ADMIN_1

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `admin_1_id` | NUMBER identity | PK | No | Internal administrative level-one identifier. | System |
| `admin_1_name` | VARCHAR2(100) | UK | No | Administrative level-one name, including historical labels as present in source. | `admin_1` |

## ADMIN_2

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `admin_2_id` | NUMBER identity | PK | No | Internal administrative level-two identifier. | System |
| `admin_2_name` | VARCHAR2(100) | UK | No | Administrative level-two name. | `admin_2` |
| `admin_1_id` | NUMBER | FK → `ADMIN_1.admin_1_id` | No | Parent level-one geography; observed mapping is one parent per level-two name. | `admin_1` (resolved) |

## ADMIN_AREA

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `fnid` | VARCHAR2(50) | PK | No | Stable source area code; authoritative area key, with 51 codes for 42 names. | `fnid` |
| `geographic_unit_name` | VARCHAR2(200) | — | No | Source area display name. | `geographic_unit_name` |
| `geographic_unit_full_name` | VARCHAR2(500) | — | Yes | Full source geography label. | `geographic_unit_full_name` |
| `admin_2_id` | NUMBER | FK → `ADMIN_2.admin_2_id` | Conditional | Resolved current level-two geography; mutually exclusive with `legacy_admin_1_id`. | `admin_2` (resolved) |
| `legacy_admin_1_id` | NUMBER | FK → `ADMIN_1.admin_1_id` | Conditional | Historical area-level parent used where no source level-two name exists; mutually exclusive with `admin_2_id`. | `admin_1` (resolved) |

## CROP

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `crop_id` | NUMBER identity | PK | No | Internal crop identifier. | System |
| `crop_code` | VARCHAR2(50) | UK | No | Source crop/product code. | `cpcv2` |
| `crop_name` | VARCHAR2(200) | UK | No | Source product/crop label. | `product` |
| `crop_description` | VARCHAR2(300) | — | Yes | Crop description. | `cpcv2_description` |

## INDICATOR

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `indicator_id` | NUMBER identity | PK | No | Internal indicator identifier. | System |
| `indicator_code` | VARCHAR2(50) | UK | No | Source indicator abbreviation/code. | `indicator_abbreviation` |
| `indicator_name` | VARCHAR2(100) | UK | No | Indicator label (`Area Planted`, `Quantity Produced`, or `Yield`). | `indicator` |
| `allowed_unit` | VARCHAR2(30) | Unique with `indicator_id` | No | Canonical permitted unit for this indicator. | Derived from `unit` |
| `unit_name` | VARCHAR2(100) | — | No | Source unit label retained for interpretation. | `unit_name` |

## SEASON

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `season_id` | NUMBER identity | PK | No | Internal season identifier. | System |
| `season_name` | VARCHAR2(50) | UK | No | Source season name (three values in this extract). | `season_name` |

## SEASON_YEAR

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `season_year_id` | NUMBER identity | PK | No | Internal season-period identifier. | System |
| `season_id` | NUMBER | FK → `SEASON.season_id` | No | Season associated with the observation year. | `season_name` (resolved) |
| `observation_year` | NUMBER(4) | Unique with `season_id`; CHECK | No | Four-digit year parsed from source period label. | Derived from `season_year` |
| `season_year_label` | VARCHAR2(50) | UK | No | Original source season-year label. | `season_year` |
| `start_date` | DATE | — | Yes | Parsed start date, if supplied. | `start_date` |
| `period_date` | DATE | — | Yes | Parsed period date, if supplied. | `period_date` |
| `season_date` | DATE | — | Yes | Parsed season date, if supplied. | `season_date` |

## STAGE_CROP_OBSERVATION

Raw staging contains 39 source fields. Non-date/non-numeric values are kept as source text; raw date/value strings are deliberately not typed or coerced at this stage. All fields are nullable except the generated row ID, batch FK, source record ID, and row status.

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `stage_row_id` | NUMBER identity | PK | No | Internal staging-row identifier. | System |
| `batch_id` | NUMBER | FK → `IMPORT_BATCH.batch_id` | Yes until assigned after CSV import; No for processed rows | Import batch that supplied this row. CSV import leaves it null; the Phase IV load script assigns the prepared batch before normalization. | System |
| `source_organization` | VARCHAR2(500) | — | Yes | Source organization name. | `source_organization` |
| `source_document` | VARCHAR2(500) | — | Yes | Source document title/name. | `source_document` |
| `geographic_unit_full_name` | VARCHAR2(500) | — | Yes | Full area label. | `geographic_unit_full_name` |
| `geographic_unit_name` | VARCHAR2(200) | — | Yes | Area display label. | `geographic_unit_name` |
| `fnid` | VARCHAR2(50) | — | Yes | Source area code. | `fnid` |
| `admin_1` | VARCHAR2(100) | — | Yes | Administrative level-one label. | `admin_1` |
| `admin_2` | VARCHAR2(100) | — | Yes | Administrative level-two label. | `admin_2` |
| `start_date_raw` | VARCHAR2(40) | — | Yes | Unparsed source start date. | `start_date` |
| `period_date_raw` | VARCHAR2(40) | — | Yes | Unparsed source period date. | `period_date` |
| `season_name` | VARCHAR2(50) | — | Yes | Source season label. | `season_name` |
| `season_date_raw` | VARCHAR2(40) | — | Yes | Unparsed source season date. | `season_date` |
| `season_year` | VARCHAR2(50) | — | Yes | Source period label; natural-key component. | `season_year` |
| `indicator_name` | VARCHAR2(100) | — | Yes | Indicator name. | `indicator` |
| `source_status` | VARCHAR2(50) | — | Yes | Source observation status. | `status` |
| `value_raw` | VARCHAR2(100) | — | Yes | Raw measure text; blank values are logged, not converted to zero. | `value` |
| `population_raw` | VARCHAR2(100) | — | Yes | Raw population value. | `population` |
| `value_per_capita_raw` | VARCHAR2(100) | — | Yes | Raw per-capita value. | `value_per_capita` |
| `product_name` | VARCHAR2(200) | — | Yes | Crop/product label. | `product` |
| `locality_name` | VARCHAR2(200) | — | Yes | Source locality label. | `locality_name` |
| `unit_code` | VARCHAR2(30) | — | Yes | Unit code. | `unit` |
| `unit_name` | VARCHAR2(100) | — | Yes | Unit display label. | `unit_name` |
| `crop_code` | VARCHAR2(50) | — | Yes | Crop code. | `cpcv2` |
| `crop_description` | VARCHAR2(300) | — | Yes | Crop description. | `cpcv2_description` |
| `source_record_id` | VARCHAR2(50) | UK with `batch_id` | No | Stable source record identifier; not the discarded row counter. | `id` |
| `data_collection_period` | VARCHAR2(50) | — | Yes | Collection-period label. | `datacollectionperiod` |
| `data_collection_code` | VARCHAR2(50) | — | Yes | Collection-period code. | `datacollection` |
| `source_document_code` | VARCHAR2(50) | — | Yes | Source-document code. | `datasourcedocument` |
| `source_organization_code` | VARCHAR2(50) | — | Yes | Source-organization code. | `datasourceorganization` |
| `indicator_code` | VARCHAR2(50) | — | Yes | Indicator abbreviation/code. | `indicator_abbreviation` |
| `locality_code` | VARCHAR2(50) | — | Yes | Locality code. | `locality` |
| `geographic_unit_code` | VARCHAR2(50) | — | Yes | Geographic-unit code. | `geographic_unit` |
| `season_code` | VARCHAR2(50) | — | Yes | Season code. | `season` |
| `data_series` | VARCHAR2(1000) | — | Yes | Source data-series label. | `dataseries` |
| `data_series_name` | VARCHAR2(1000) | — | Yes | Source data-series display name. | `dataseries_name` |
| `created_raw` | VARCHAR2(40) | — | Yes | Unparsed source creation timestamp. | `created` |
| `modified_raw` | VARCHAR2(40) | — | Yes | Unparsed source modification timestamp. | `modified` |
| `status_changed_raw` | VARCHAR2(40) | — | Yes | Unparsed source status-change timestamp. | `status_changed` |
| `collection_status_changed_raw` | VARCHAR2(40) | — | Yes | Unparsed collection-status-change timestamp. | `collection_status_changed` |
| `collection_date_raw` | VARCHAR2(40) | — | Yes | Unparsed source collection date. | `collection_date` |
| `row_status` | VARCHAR2(20) | CHECK | No | Pipeline state: `PENDING`, `ACCEPTED`, or `REJECTED`. | System |

## AGG_CROP_STATISTIC

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `statistic_id` | NUMBER identity | PK | No | Internal curated fact identifier. | System |
| `batch_id` | NUMBER | FK → `IMPORT_BATCH.batch_id` | No | Import batch that loaded the fact. | System |
| `source_document_id` | NUMBER | FK → `SOURCE_DOCUMENT.source_document_id` | Yes | Resolved source document. | `source_document_code` (resolved) |
| `fnid` | VARCHAR2(50) | FK → `ADMIN_AREA.fnid` | No | Source area key. | `fnid` |
| `crop_id` | NUMBER | FK → `CROP.crop_id` | No | Resolved crop. | `product` (resolved) |
| `indicator_id` | NUMBER | FK → `INDICATOR.indicator_id` | No | Resolved measurement indicator and unit rule. | `indicator` (resolved) |
| `season_year_id` | NUMBER | FK → `SEASON_YEAR.season_year_id` | No | Resolved season-year. | `season_year` (resolved) |
| `source_record_id` | VARCHAR2(50) | UK | No | Source record identifier for traceability. | `id` |
| `numeric_value` | NUMBER(18,8) | CHECK | No | Validated nonnegative numeric value. | `value` |
| `quality_status` | VARCHAR2(20) | CHECK | No | Fact quality state: `VALID`, `FLAGGED`, or `CORRECTED`. | System |
| `created_at` | TIMESTAMP | — | No | Fact insertion timestamp. | System |
| `updated_at` | TIMESTAMP | — | No | Last fact update timestamp. | System |

Natural key: `(fnid, crop_id, indicator_id, season_year_id)`, corresponding to source `(fnid, product, indicator, season_year)`. The schema enforces this key as unique.

## DATA_QUALITY_ISSUE

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `issue_id` | NUMBER identity | PK | No | Internal quality-issue identifier. | System |
| `stage_row_id` | NUMBER | FK → `STAGE_CROP_OBSERVATION.stage_row_id` | Yes | Staging row associated with issue. | System |
| `statistic_id` | NUMBER | FK → `AGG_CROP_STATISTIC.statistic_id` | Yes | Curated fact associated with issue. | System |
| `issue_type` | VARCHAR2(40) | CHECK | No | Controlled issue category, including `MISSING_VALUE`. | System |
| `severity` | VARCHAR2(20) | CHECK | No | Issue severity (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`). | System |
| `issue_description` | VARCHAR2(1000) | — | No | Human-readable issue details. | System |
| `reported_at` | TIMESTAMP | — | No | Issue creation timestamp. | System |
| `resolved_flag` | CHAR(1) | CHECK | No | Resolution state (`Y` or `N`). | System |

## DATA_CORRECTION_REQUEST

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `correction_id` | NUMBER identity | PK | No | Internal correction-request identifier. | System |
| `statistic_id` | NUMBER | FK → `AGG_CROP_STATISTIC.statistic_id` | No | Fact proposed for correction. | System |
| `requested_by` | VARCHAR2(100) | — | No | User submitting correction request. | System |
| `request_date` | TIMESTAMP | — | No | Request creation time. | System |
| `original_value` | NUMBER(18,8) | CHECK | No | Value observed before correction. | `value` (resolved fact) |
| `proposed_value` | NUMBER(18,8) | CHECK | No | Proposed replacement value. | User submission |
| `reason_text` | CLOB | — | No | Reason for the request. | User submission |
| `evidence_text` | CLOB | — | Yes | Supporting evidence. | User submission |
| `request_status` | VARCHAR2(20) | CHECK | No | `PENDING`, `APPROVED`, `REJECTED`, or `APPLIED`. | System |
| `reviewer_user` | VARCHAR2(100) | — | Yes | Reviewing user. | System |
| `reviewed_at` | TIMESTAMP | — | Yes | Review timestamp. | System |

## AUDIT_EVENT

| Column | Oracle type | Key | Nullable | Description | Source column |
|---|---|---|---|---|---|
| `audit_id` | NUMBER identity | PK | No | Internal audit-event identifier. | System |
| `statistic_id` | NUMBER | FK → `AGG_CROP_STATISTIC.statistic_id` | No | Fact changed. | System |
| `correction_id` | NUMBER | FK → `DATA_CORRECTION_REQUEST.correction_id` | Yes | Related approved correction request, if any. | System |
| `old_value` | NUMBER(18,8) | — | Yes | Value before change. | `value` (resolved fact) |
| `new_value` | NUMBER(18,8) | — | Yes | Value after change. | User submission |
| `changed_by` | VARCHAR2(100) | — | No | User responsible for the change. | System |
| `changed_at` | TIMESTAMP | — | No | Change timestamp. | System |
| `change_reason` | VARCHAR2(1000) | — | Yes | Reason recorded for the change. | User submission |
