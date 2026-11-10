# Phase 0 — Research, Data Source and Project Proposal

## Title

**Agricultural Production and Harvest Tracking System**  
**Student:** Ishimwe Zacharie | **Student ID:** 28737  
**GitHub repository:** https://github.com/ishimwezacharie1-netizen/ishimwe_28737_agri_harvest  
**INSY 8311 — Database Development with PL/SQL | Instructor: Eric Maniraguha**

## Problem Statement

Rwanda already has digital agricultural services, including the Smart Nkunganire System, a value-chain management system created for the Rwanda Agriculture Board (BK Techouse, n.d.). This project addresses a complementary need: exploring real subnational crop area, production, and yield statistics across historical seasons. A study of 110 maize farmers in Gatsibo and Nyagatare examined post-harvest losses and related factors (Gaspard et al., 2021). A benchmark dashboard can help review where indicators vary, but cannot establish individual causes.

## Proposed Solution

Build an Oracle database and Oracle APEX analytics application centered on the Rwanda HarvestStat Africa extract. Users will filter aggregate observations by crop, season/year, historical area, and indicator; compare area planted, production, and yield; and inspect missingness and unit-quality flags. This real dataset is the project’s primary evidence. It has no farmer, cooperative, farm, or plot identifiers, so no observation will be assigned to an individual. Farm-level tables are deferred until an authorized, consented source exists.

## Data Source

The primary source is the Rwanda extract of HarvestStat Africa (https://data.humdata.org/dataset/harveststat-africa), a harmonized subnational crop-statistics resource (Lee et al., 2025). HDX lists the dataset under CC0 1.0. The inspected CSV has **13,725 rows**, **9,123 populated values**, and **4,602 missing values (33.5%)**. It covers 38 product names, 42 distinct `geographic_unit_name` labels, three indicators, and season-year labels from 1984 to 2017. Units are mixed (`ha`, `t`, `MT/ha`) and will be validated against each indicator. All-indicator missingness is 33.2% in the 1980s (645 rows), 58.6% in the 2000s (7,383 rows), and 1.0% in the 2010s (5,697 rows). Yield values are most complete for yams (170/221; 76.9%), mixed beans (109/151; 72.2%), and Irish potato (202/285; 70.9%); these are populated-row rates, not continuous-series measures.

This real data fits the project because it contains the crop, season, area, production, and yield dimensions the reports will explore (Lee et al., 2025). Rwanda coverage is historical and irregular; names reflect historical boundaries. Validate units and duplicate keys, preserve source attribution, and display missingness.

## Planned Tables

Current tables: `SOURCE_DATASET` and `IMPORT_BATCH` (provenance); `ADMIN_AREA`, `CROP`, `SEASON`, and `INDICATOR` (dimensions); `AGG_CROP_STATISTIC` (real fact rows); `DATA_QUALITY_ISSUE` (missing/invalid/rejected rows); `AUDIT_EVENT` (curated changes). Farmer, cooperative, farm, plot, planting, and harvest tables are a future extension, not inferred from aggregate data.

## Planned PL/SQL Features

`PKG_HARVEST_BENCHMARK` will centralize the import rules and APEX analytics:

- **Procedure `P_VALIDATE_STAGE`:** before batch acceptance, check required keys, numeric values, indicator/unit pairs, and duplicate source keys; log rejected rows.
- **Procedure `P_REFRESH_QUALITY_SUMMARY`:** refresh crop/indicator/decade completeness metrics for the dashboard.
- **Function `F_COMPLETENESS_PCT`:** return the nonmissing-value percentage for the selected filters.
- **Function `F_SAFE_YIELD`:** calculate quantity/area only for compatible units and positive area; otherwise signal an error.
- **Cursor `C_QUALITY_GAPS`:** iterate incomplete crop/indicator/decade groups for the quality report.
- **Rule trigger `TRG_AGG_INDICATOR_UNIT`:** before insert/update, enforce the permitted unit for each indicator.
- **Restriction trigger `TRG_AGG_VALUE_RESTRICT`:** reject negative values and invalid benchmark keys/status.
- **Audit trigger `TRG_AGG_AUDIT`:** record insert/update/delete metadata for curated benchmark rows.
- **Custom exceptions:** `E_INVALID_UNIT`, `E_NEGATIVE_VALUE`, `E_DUPLICATE_SOURCE_ROW`, and `E_MISSING_PERIOD_GEO` provide clear rejection reasons.

APEX will call the package for quality summaries, filtered reports, and safe calculations. Triggers protect `AGG_CROP_STATISTIC`, not farmer transactions.

## Innovation

**Option:** Analytics dashboard. **Tool:** Oracle APEX connected to Oracle. Users explore real seasonal benchmarks and completeness warnings; PL/SQL supplies validated summaries. The demo uses imported data, not a static mock-up.

## References (APA)

BK Techouse. (n.d.). *Smart Nkunganire System* [Web application]. Rwanda Agriculture Board. https://smartnkunganire.rw (Accessed November 10, 2026).

Gaspard, N., Tuyisenge, J. C., Tumukunde, R., Izamuhaye, J. C., Mburu, D. M., Majuga, J. C. N., & Mbabazize, M. (2021). Analysis of the factors influencing maize postharvest losses and effect of agricultural inputs supply on productivity in Rwanda: A case of Gatsibo and Nyagatare. *American Journal of Management Science and Engineering, 6*(6), 203. https://doi.org/10.11648/j.ajmse.20210606.14

HarvestStat Consortium. (2026). *HarvestStat Africa—Harmonized subnational crop statistics for Sub-Saharan Africa* [Dataset]. Humanitarian Data Exchange. https://data.humdata.org/dataset/harveststat-africa

Lee, D., et al. (2025). HarvestStat Africa—Harmonized subnational crop statistics for Sub-Saharan Africa. *Scientific Data, 12*. https://doi.org/10.1038/s41597-025-05001-z

Oracle. (n.d.). *Oracle APEX*. https://www.oracle.com/application-development/apex/ (Accessed November 10, 2026).
