# Agricultural Production and Harvest Tracking System

**Student:** Ishimwe Zacharie  
**Student ID:** 28737  
**Course:** INSY 8311 — Database Development with PL/SQL  
**Project repository:** [`ishimwe_28737_agri_harvest`](https://github.com/ishimwezacharie1-netizen/ishimwe_28737_agri_harvest)

## Problem statement

Rwanda has existing digital agriculture services, including the Smart Nkunganire System, a value-chain management system created for the Rwanda Agriculture Board. This project does not claim that Rwanda lacks agricultural systems. It addresses a narrower complementary need: analyzing real subnational crop area, production, and yield statistics across crops, seasons, and historical areas in an accessible, database-backed dashboard.

HarvestStat Africa gives the project a real benchmark dataset. Its Rwanda extract contains **13,725 rows but only 9,123 populated values** (4,602 missing; **33.5%**). It has no farmer/cooperative/farm/plot identifiers, so the project will analyze aggregate observations as aggregate observations. No benchmark record will be attached to a fictitious farmer. Farm-level operations are a separate future extension contingent on an appropriate, consented dataset.

## Objectives

**Main objective:** Design and demonstrate an Oracle database and analytics application for monitoring real Rwanda subnational crop-production and harvest benchmarks.

**Specific objectives:**
1. Normalize and load HarvestStat Rwanda crop, season, indicator, area, unit, and source metadata into a relational Oracle schema.
2. Measure and report value completeness and unit/data-quality issues by crop, indicator, and decade.
3. Build an Oracle APEX dashboard with interactive crop, season, area, and indicator filters, backed by tested PL/SQL analytics.

## Innovation

**Option:** Analytics dashboard. **Tool:** Oracle APEX connected to the project Oracle database. The application will let users explore real seasonal production/yield benchmarks, compare areas, and see completeness warnings. PL/SQL routines will validate staging data and supply filtered summaries. This is not a static mock-up.

## Phase 0 deliverables

- [Two-page Phase 0 proposal (DOCX)](docs/proposal/Phase0_Proposal.docx)
- [Two-page Phase 0 proposal (PDF)](docs/proposal/Phase0_Proposal.pdf)
- [12-slide Phase 0 presentation](docs/presentation/Phase0_Presentation.pptx)
- [Research log](docs/research/research_log.md)
- [Instructor submission email draft](docs/instructor_email_draft.md)
- [Rwanda HarvestStat extract](data/raw/adm_crop_data_raw_RW.csv)
- [World Bank Rwanda agriculture indicators](data/raw/agriculture-and-rural-development_rwa.csv)

## Data source

- Main source: [HarvestStat Africa on HDX](https://data.humdata.org/dataset/harveststat-africa); the Rwanda file was extracted from `fdw_raw_data_v1.0.zip`.
- HDX lists HarvestStat Africa under CC0 1.0. The secondary World Bank Rwanda indicators dataset is listed under CC BY; retain source attribution when redistributing it.
- 13,725 source rows; 9,123 populated values; 4,602 missing values (33.5%).
- 38 crop/product names and 42 distinct `geographic_unit_name` labels; indicators are `Area Planted`, `Quantity Produced`, and `Yield`.
- Source units include `ha`, `t`, and `MT/ha`. Validate unit/indicator pairs before use.
- All-indicator missingness by decade: 1980s 33.2%, 2000s 58.6%, 2010s 1.0%.
- Most-complete yield rows by crop: yams 76.9%, mixed beans 72.2%, Irish potato 70.9%, and cassava 70.8%. These rates do not imply continuous time-series coverage.
- Data are historical subnational statistics, not current farmer/plot transactions. Historical area labels, missingness, the unnamed first CSV column, and source redistribution terms need careful handling.

## Planned tables

| Table | Role | Data scope |
|---|---|---|
| `SOURCE_DATASET` | Source citation, license note, file/version and provenance | Current benchmark core |
| `IMPORT_BATCH` | File/batch status, timestamps and load counts | Current benchmark core |
| `ADMIN_AREA` | Original geographic labels/codes and historical period | Current benchmark core |
| `CROP` | Crop/product dimension | Current benchmark core |
| `SEASON` | Source season name/type/year and date labels | Current benchmark core |
| `INDICATOR` | Indicator definition and permitted unit | Current benchmark core |
| `AGG_CROP_STATISTIC` | One sourced aggregate observation and numeric value | Current benchmark fact table |
| `DATA_QUALITY_ISSUE` | Missing, invalid-unit, duplicate or rejected observations | Current benchmark core |
| `AUDIT_EVENT` | Controlled changes to curated records | Current benchmark core |
| `FARMER`, `COOPERATIVE`, `FARM`, `PLOT`, `PLANTING_RECORD`, `HARVEST_RECORD` | Possible future operational extension | Out of scope until real, consented farm data exists |

## Planned PL/SQL Features

| Feature | Planned use |
|---|---|
| `PKG_HARVEST_BENCHMARK` | Package for staging validation, completeness, safe calculations, and APEX report operations. |
| Procedure `P_VALIDATE_STAGE` | Validate staged values, indicator/unit pairs, required period/geography, and duplicate source keys; log rejects. |
| Procedure `P_REFRESH_QUALITY_SUMMARY` | Use a cursor to summarize populated/missing values by crop, indicator, and decade for the quality dashboard. |
| Function `F_COMPLETENESS_PCT` | Return nonmissing-value percentage for selected crop/indicator/decade filters. |
| Function `F_SAFE_YIELD` | Calculate quantity ÷ area only for compatible units and positive area; signal invalid inputs. |
| Cursor `C_QUALITY_GAPS` | Iterate crop/indicator/decade groups with missing or rejected rows for the data-quality report. |
| Rule trigger `TRG_AGG_INDICATOR_UNIT` | Enforce allowed units for area, quantity, or yield on benchmark insert/update. |
| Restriction trigger `TRG_AGG_VALUE_RESTRICT` | Reject negative numeric values and invalid benchmark keys/status. |
| Audit trigger `TRG_AGG_AUDIT` | Record benchmark insert/update/delete metadata in `AUDIT_EVENT`. |
| Custom exceptions | `E_INVALID_UNIT`, `E_NEGATIVE_VALUE`, `E_DUPLICATE_SOURCE_ROW`, `E_MISSING_PERIOD_GEO` provide clear rule failures. |

## Repository structure

```text
data/
  raw/
docs/
  presentation/
  proposal/
  research/
```

## References

The [research log](docs/research/research_log.md) records source type, link, key finding, evidence gap, and source-read status, plus the dataset quality profile.

- BK Techouse. (n.d.). *Smart Nkunganire System*. https://smartnkunganire.rw
- Gaspard, N., et al. (2021). Rwanda maize postharvest losses in Gatsibo and Nyagatare. https://doi.org/10.11648/j.ajmse.20210606.14
- Khusaini, N. A., & Yusuf, M. S. A. (2025). Digital record-keeping in urban agriculture. https://doi.org/10.35631/jistm.1040012
- Lee, D., et al. (2025). HarvestStat Africa. https://doi.org/10.1038/s41597-025-05001-z
- Tuyizere, J. D., et al. (2025). Conservation agriculture practices in Rwanda. https://doi.org/10.5539/jas.v17n3p14
- Warner, J., et al. (2023). Rwanda smallholder commercialization survey. https://hdl.handle.net/10568/132209

## Next phases

1. Model workflows and confirm that the scope remains benchmark analytics rather than fabricated individual-farm tracking.
2. Normalize the benchmark schema and document source keys, units, and historical geography.
3. Load and validate the raw extract; report exact missingness and rejected rows.
4. Implement and test PL/SQL package routines, triggers, exceptions, and audit behavior.
5. Build and live-demo the Oracle APEX dashboard using the real imported benchmark data.
