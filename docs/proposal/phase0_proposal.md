# Phase 0 — Research, Data Source and Project Proposal

## Title

**Agricultural Production and Harvest Tracking System**

**Subtitle: Real Rwanda Crop Benchmark Analytics**

**Student:** Ishimwe Zacharie | **Student ID:** 28737

**GitHub repository:** https://github.com/ishimwezacharie1-netizen/ishimwe_28737_agri_harvest

**INSY 8311 — Database Development with PL/SQL | Instructor: Eric Maniraguha**

## Problem Statement

Rwanda already has agricultural digital services, including the Smart Nkunganire System, powered by BK Techouse (BK Techouse, n.d.). A study of 110 maize farmers in Gatsibo and Nyagatare examined post-harvest losses and input supply (Gaspard et al., 2021). This proposal does not claim that Rwanda lacks agricultural systems. It addresses a complementary analytics gap: district planners and cooperative advisers need consistent, quality-checked crop benchmarks to compare outcomes across seasons and areas. Without them, missing values and incompatible units can be mistaken for real performance differences and misdirect planning or advice. Aggregate benchmarks support comparisons but cannot explain individual farm-level causes.

## Proposed Solution

Build an Oracle database and Oracle APEX analytics application centered on the Rwanda HarvestStat Africa extract. Users will compare aggregate crop-area, production, and yield observations by crop, historical area, season, and available year, and inspect completeness and unit-quality warnings. The title is retained as registered, but this phase is specifically real Rwanda crop benchmark analytics; it is not individual farm or harvest tracking.

The CSV contains 13,725 rows, 9,123 populated values, and 4,602 missing values (33.5%). It has no farmer, cooperative, farm, or plot identifiers. No observation will be attached to a fictitious farm; operational farm-level tables remain out of scope unless an authorized, consented source becomes available.

## Data Source and Fit

The primary source is the Rwanda extract of HarvestStat Africa, a harmonized subnational crop-statistics resource (HarvestStat Consortium, n.d.; Lee et al., 2025). It directly provides crop, season, geographic-area, indicator, value, and unit fields for the planned benchmark comparisons. HDX identifies HarvestStat Consortium as the dataset organization. Dataset metadata lists the license as "Other"; an earlier resource listing identified CC0 1.0, but the current resource API has no file-level license value. Preserve attribution and verify the exact file terms before redistribution.

The inspected extract has 38 crop/product names, 42 distinct `geographic_unit_name` labels, three indicators, and mixed units (`ha`, `t`, `MT/ha`) that must be validated against each indicator. Its year labels occur in only **1984, 2006, 2008, 2009, 2010, 2012, 2013, and 2017**: there is no 1990s coverage and only one observed year in the 1980s. This is sparse, irregular historical coverage—not a continuous time series. The dashboard will emphasize comparisons by crop, historical area, and season, and will not present long-term yield trends.

## Planned Tables

`SOURCE_DATASET` and `IMPORT_BATCH` preserve provenance; `ADMIN_AREA`, `CROP`, `SEASON`, and `INDICATOR` are dimensions; `AGG_CROP_STATISTIC` stores the real aggregate fact rows; `DATA_QUALITY_ISSUE` stores missing, invalid, duplicate, or rejected observations; `DATA_CORRECTION_REQUEST` stores proposed and reviewed corrections; and `AUDIT_EVENT` records approved changes. Farm, plot, planting, and harvest entities are not part of this phase because the source contains no farm-level identifiers.

## Planned PL/SQL Features

`PKG_HARVEST_BENCHMARK` will centralize import, quality, correction, and APEX report logic.

- **Procedure `P_VALIDATE_STAGE`:** before batch acceptance, validate required source keys, period/geography, indicator/unit pairs, and duplicate keys; log rejected rows.
- **Procedure `P_REFRESH_QUALITY_SUMMARY`:** refresh crop/indicator/decade completeness metrics used by the APEX quality dashboard.
- **Procedure `P_APPLY_APPROVED_CORRECTION`:** verify reviewer authorization and request status, apply the accepted correction, and set a protected application context for the permitted update.
- **Function `F_COMPLETENESS_PCT`:** return nonmissing-value percentage for selected crop, indicator, and period filters.
- **Function `F_SAFE_YIELD`:** calculate quantity divided by area only for compatible units and positive area; otherwise raise a custom exception.
- **Cursor `C_QUALITY_GAPS`:** iterate incomplete crop/indicator/decade groups for the APEX quality report.
- **Rule trigger `TRG_CORR_REQUEST_VALIDATE`:** before a correction request is stored, verify its target, rationale, proposed value, and indicator/unit consistency.
- **Restriction trigger `TRG_AGG_RESTRICT_DIRECT_DML`:** block direct updates/deletes of curated statistics; allow changes only through an authorized package operation for an approved request.
- **Audit trigger `TRG_AGG_AUDIT`:** record old/new values, user, timestamp, and correction-request ID when a curated row changes.
- **Custom exceptions:** `E_INVALID_UNIT`, `E_CORRECTION_NOT_FOUND`, `E_CORRECTION_NOT_APPROVED`, and `E_UNAUTHORIZED_REVIEWER` give actionable validation and permission failures.

Users will submit a reasoned correction proposal; an authorized reviewer will approve or reject it; the package will apply only approved changes; and the audit trigger will record the change. Phase I will implement and test the authorization/context guard. This gives the triggers meaningful rule, restriction, and audit responsibilities without duplicating simple `CHECK` constraints.

## Innovation

**Option:** Analytics dashboard. **Tool:** Oracle APEX connected to Oracle. Users will filter real aggregate observations by crop, historical area, season, and available year, and view data-quality warnings. PL/SQL supplies validated imports, completeness summaries, and unit-safe calculations. The demonstration will use imported data, not a static mock-up.

## References

BK Techouse. (n.d.). *Smart Nkunganire System* [Web application]. Retrieved November 10, 2026, from https://smartnkunganire.rw

Gaspard, N., Tuyisenge, J. C., Tumukunde, R., Izamuhaye, J. C., Mburu, D. M., Majuga, J. C. N., & Mbabazize, M. (2021). Analysis of the factors influencing maize postharvest losses and effect of agricultural inputs supply on productivity in Rwanda: A case of Gatsibo and Nyagatare. *American Journal of Management Science and Engineering, 6*(6), 203–212. https://doi.org/10.11648/j.ajmse.20210606.14

HarvestStat Consortium. (n.d.). *HarvestStat Africa* [Data set]. Humanitarian Data Exchange. Retrieved November 10, 2026, from https://data.humdata.org/dataset/harveststat-africa

Lee, D., Anderson, W., Chen, X., Davenport, F., Shukla, S., Sahajpal, R., Budde, M., Rowland, J., Verdin, J., You, L., Ahouangbenon, M., Davis, K. F., Kebede, E., Ehrmann, S., Justice, C., & Meyer, C. (2025). HarvestStat Africa—Harmonized subnational crop statistics for Sub-Saharan Africa. *Scientific Data, 12*(1). https://doi.org/10.1038/s41597-025-05001-z
