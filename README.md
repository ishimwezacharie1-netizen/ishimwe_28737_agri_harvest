# Agricultural Production and Harvest Tracking System

## Real Rwanda Crop Benchmark Analytics

- **Student:** Ishimwe Zacharie
- **Student ID:** 28737
- **Course:** INSY 8311 - Database Development with PL/SQL
- **Project repository:** <https://github.com/ishimwezacharie1-netizen/ishimwe_28737_agri_harvest>

## Problem statement

Rwanda already has agricultural digital services, including the Smart Nkunganire System. A study of 110 maize farmers in Gatsibo and Nyagatare examined post-harvest losses and input supply (Gaspard et al., 2021). This project addresses a complementary analytics gap, not a lack of agricultural systems: district planners and cooperative advisers need consistent, quality-checked crop benchmarks to compare results across seasons and areas. Without them, missing values and incompatible units can be mistaken for real performance differences, misdirecting planning and advice. Aggregate benchmarks support comparisons but cannot explain individual farm-level causes.

The project is titled **Agricultural Production and Harvest Tracking System**; its Phase I scope is specifically **real Rwanda crop benchmark analytics**. The Rwanda HarvestStat extract contains 13,725 rows but only 9,123 populated values (4,602 missing; 33.5%). It has no farmer, cooperative, farm, or plot identifiers. Therefore, the system will analyze aggregate observations as aggregate observations and will not promise individual farm/harvest tracking or link statistics to fictitious farms.

## Objectives

**Main objective:** Design and demonstrate an Oracle database and analytics application for exploring Rwanda subnational crop-production benchmarks.

**Specific objectives:**
1. Normalize and load HarvestStat Rwanda crop, season, indicator, area, unit, and source metadata into a relational Oracle schema.
2. Measure completeness and flag unit, period, and source-quality issues.
3. Build an Oracle APEX dashboard for comparisons by crop, historical area, season, and available year, supported by tested PL/SQL routines.

## Data source

- Main source: [HarvestStat Africa on HDX](https://data.humdata.org/dataset/harveststat-africa); the Rwanda file was extracted from `fdw_raw_data_v1.0.zip`.
- HDX identifies HarvestStat Consortium as the dataset organization. Dataset metadata lists the license as "Other"; an earlier resource listing identified CC0 1.0, but the current resource API has no file-level license value. Preserve attribution and verify the exact file terms before redistribution.
- 13,725 rows; 9,123 populated values; 4,602 missing values (33.5%).
- 38 crop/product names, 42 distinct `geographic_unit_name` labels, and three indicators: `Area Planted`, `Quantity Produced`, and `Yield`.
- Source units include `ha`, `t`, and `MT/ha`; validate indicator-unit pairs before analysis.
- Only eight distinct years have records: **1984, 2006, 2008, 2009, 2010, 2012, 2013, and 2017**. There is no 1990s coverage and only one year in the 1980s. The dashboard will focus on crop, historical area, and season comparisons, not continuous or long-term yield trends.
- All-indicator missingness by decade: 1980s 33.2%, 2000s 58.6%, 2010s 1.0%. Missingness varies by crop and indicator; the dashboard must show denominators and completeness alongside comparisons.
- The secondary [World Bank Rwanda agriculture indicators dataset](https://data.humdata.org/dataset/world-bank-agriculture-and-rural-development-indicators-for-rwanda) supplies country-level context only. It is not a substitute for subnational or farm records.

## Innovation

**Option:** Analytics dashboard. **Tool:** Oracle APEX connected to the project Oracle database. Users will filter real aggregate observations by crop, historical area, season, and available year, compare indicators, and inspect missingness and correction status. PL/SQL validates imports and supplies quality summaries and unit-safe calculations; the demonstration uses loaded data, not a static mock-up.

## Planned tables

| Table | Role | Data scope |
|---|---|---|
| `SOURCE_DATASET` | Citation, license, file/version, and provenance | Current benchmark core |
| `IMPORT_BATCH` | Import status, timestamps, and load counts | Current benchmark core |
| `ADMIN_AREA` | Original geography labels/codes and historical period | Current benchmark core |
| `CROP` | Crop/product dimension | Current benchmark core |
| `SEASON` | Source season name/type and year labels | Current benchmark core |
| `INDICATOR` | Indicator definition and permitted unit | Current benchmark core |
| `AGG_CROP_STATISTIC` | Sourced aggregate observation and numeric value | Current benchmark fact table |
| `DATA_QUALITY_ISSUE` | Missing, invalid-unit, duplicate, or rejected observations | Current benchmark core |
| `DATA_CORRECTION_REQUEST` | Proposed, reviewed corrections to flagged benchmark values | Controlled correction workflow |
| `AUDIT_EVENT` | Approved changes and audit metadata | Current benchmark core |
| `FARMER`, `COOPERATIVE`, `FARM`, `PLOT`, `PLANTING_RECORD`, `HARVEST_RECORD` | Possible future operational extension | Out of scope; no suitable farm-level source |

## Planned PL/SQL features

| Feature | Planned use |
|---|---|
| Package `PKG_HARVEST_BENCHMARK` | Centralize staging validation, quality summaries, correction approval/application, and APEX report operations. |
| Procedure `P_VALIDATE_STAGE` | Validate required source keys, indicator/unit pairs, period/geography, and duplicate source keys; log rejected rows before a batch is accepted. |
| Procedure `P_REFRESH_QUALITY_SUMMARY` | Use a cursor to refresh crop/indicator/decade completeness metrics for APEX. |
| Procedure `P_APPLY_APPROVED_CORRECTION` | Check reviewer authorization and request status, apply an approved correction, and set a protected application context for the restricted update. |
| Function `F_COMPLETENESS_PCT` | Return the nonmissing-value percentage for the selected crop/indicator/period filters. |
| Function `F_SAFE_YIELD` | Calculate quantity divided by area only for compatible units and positive area; raise a clear custom exception otherwise. |
| Cursor `C_QUALITY_GAPS` | Iterate incomplete crop/indicator/decade groups for the data-quality report. |
| Rule trigger `TRG_CORR_REQUEST_VALIDATE` | Validate correction-request target, reason, proposed value, and indicator/unit consistency before a request is stored. |
| Restriction trigger `TRG_AGG_RESTRICT_DIRECT_DML` | Block direct edits/deletes to curated benchmark rows; permit changes only when the package has authorized an approved correction. |
| Audit trigger `TRG_AGG_AUDIT` | Record old/new values, user, timestamp, and correction-request ID for approved changes to curated statistics. |
| Custom exceptions | `E_INVALID_UNIT`, `E_CORRECTION_NOT_FOUND`, `E_CORRECTION_NOT_APPROVED`, and `E_UNAUTHORIZED_REVIEWER` explain rejected imports or correction actions. |

The correction workflow keeps the sourced data read-mostly: users propose a correction with evidence and rationale; an authorized reviewer approves or rejects it; the package applies approved changes; and the audit trigger records them. Phase I will define and test the authorization and application-context rules.

## Phase 0 deliverables

- [Two-page Phase 0 proposal (DOCX)](docs/proposal/Phase0_Proposal.docx)
- [Two-page Phase 0 proposal (PDF)](docs/proposal/Phase0_Proposal.pdf)
- [12-slide Phase 0 presentation](docs/presentation/Phase0_Presentation.pptx)
- [Research log](docs/research/research_log.md)
- [Instructor submission email draft](docs/instructor_email_draft.md)
- [Rwanda HarvestStat extract](data/raw/adm_crop_data_raw_RW.csv)
- [World Bank Rwanda agriculture indicators](data/raw/agriculture-and-rural-development_rwa.csv)

## Phase 2 deliverables

- [Phase 2 database design summary](docs/phase2/phase2_database_design.md)
- [Oracle Phase 2 schema script](docs/phase2/oracle_phase2_schema.sql)

## References

The [research log](docs/research/research_log.md) contains the required source type, link, key finding, evidence gap, and personal source-read tracking column.

- BK Techouse. (n.d.). *Smart Nkunganire System* [Web application]. Retrieved November 10, 2026, from https://smartnkunganire.rw
- Gaspard, N., Tuyisenge, J. C., Tumukunde, R., Izamuhaye, J. C., Mburu, D. M., Majuga, J. C. N., & Mbabazize, M. (2021). Analysis of the factors influencing maize postharvest losses and effect of agricultural inputs supply on productivity in Rwanda: A case of Gatsibo and Nyagatare. *American Journal of Management Science and Engineering, 6*(6), 203-212. https://doi.org/10.11648/j.ajmse.20210606.14
- HarvestStat Consortium. (n.d.). *HarvestStat Africa* [Data set]. Humanitarian Data Exchange. Retrieved November 10, 2026, from https://data.humdata.org/dataset/harveststat-africa
- Lee, D., Anderson, W., Chen, X., Davenport, F., Shukla, S., Sahajpal, R., Budde, M., Rowland, J., Verdin, J., You, L., Ahouangbenon, M., Davis, K. F., Kebede, E., Ehrmann, S., Justice, C., & Meyer, C. (2025). HarvestStat Africa - Harmonized subnational crop statistics for Sub-Saharan Africa. *Scientific Data, 12*(1). https://doi.org/10.1038/s41597-025-05001-z

## Repository structure

```text
data/
  raw/
docs/
  presentation/
  proposal/
  research/
```

## Phase I direction

The Phase I scope is set: build the real-data Rwanda crop benchmark analytics database and Oracle APEX dashboard. Do not model or claim individual-farm tracking without a suitable, authorized, consented farm-level dataset. Phase I will finalize the schema, source keys, unit rules, correction workflow, and test cases within this benchmark-analytics scope.
