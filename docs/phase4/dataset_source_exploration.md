# Phase IV: Additional project and dataset-source exploration

## Purpose

This exploration responds to the instruction to examine additional sources of project ideas and real-world datasets. It reviews the UCI Machine Learning Repository and Google Dataset Search, then assesses how the discoveries relate to the existing Rwanda crop-benchmark project.

## Sources explored

### UCI Machine Learning Repository

The UCI repository's [Paddy Dataset](https://archive.ics.uci.edu/dataset/1186/paddy+dataset) contains 2,790 records and 45 features, with no missing values reported on its page. Listed fields include hectares, agriblock, paddy variety, soil type, seed rate, and fertilizer or land-preparation measures. The repository lists classification, regression, and clustering as potential tasks and provides a downloadable CSV. Its page identifies a CC BY 4.0 license.

**Possible real-world project idea:** analyze how recorded soil, variety, and input factors relate to paddy production, or compare varieties using the dataset's measured attributes. Such a tool could help agricultural researchers explore input/variety patterns. It should not be framed as causal proof or operational advice without validating the study design and context.

**Fit to the current project:** useful as an alternative project dataset, but not a direct extension of the Rwanda benchmark system. The UCI page does not establish that the observations are from Rwanda, and its variables and intended tasks are different from the current source's aggregate area, production, and yield indicators. Do not combine the two datasets or imply a Rwanda application without verifying the Paddy dataset's geography and provenance.

### Google Dataset Search

Google Dataset Search was queried for Rwanda agriculture and crop-yield datasets. It is a discovery tool, not the underlying data publisher. A search result led to Schaedel's [Rwanda nitrogen-cycling dataset on Mendeley Data](https://doi.org/10.17632/5h66s39r5j.1), published in 2023.

The Mendeley landing page describes 335 bulk-soil samples from two locations in Rwanda across a dry-to-rainy-season transition. `soil_data.csv` records measures including nitrification potential, denitrification activity, soil carbon and nitrogen measures, pH, moisture, location, treatment, block, and collection timepoint. A second `NiCE_data.csv` file records qPCR nitrogen-cycle gene measurements linked to soil samples.

**Possible real-world project idea:** build a research dashboard that compares soil measurements across the recorded plant treatments, locations, and collection timepoints. The practical value could be helping researchers inspect treatment-associated soil-nitrogen patterns and identify questions for further field trials.

**Fit to the current project:** this is Rwanda-specific but represents a small experimental soil dataset, not national crop benchmarks or farm-level harvest tracking. It may support a separate soil research project, but it should not be used to claim national representativeness or to recommend fertilizer and crop practices directly to farmers. The landing page does not state a data license; confirm reuse permissions with the dataset contributor before redistribution or deployment.

Google Dataset Search also surfaced a Rwanda crop-production-index series from a third-party data page. This is country-level context and appears related to the already-listed World Bank/FAO indicator coverage; it is not evidence of additional subnational crop observations. Prefer a primary source and verify the download, license, indicator definition, and revision history before using it.

### OpenML

OpenML's [dataset search](https://www.openml.org/search?type=data) is a JavaScript-based catalog, so its public dataset API was used to verify a candidate record. The [Soybean dataset (ID 42, version 1)](https://www.openml.org/d/42) is identified in its metadata as the UCI Large Soybean Database, dated 1988. It contains 683 instances, 35 categorical attributes, and a 19-class soybean disease diagnosis target. OpenML reports 121 instances with missing values and 2,337 missing attribute values. Metadata describes disease symptoms and conditions such as weather, crop history, plant/leaf/stem/seed symptoms, and lists `?` for unknown values. Four of the 19 classes have very few examples, according to its description. Its metadata says the data is public, which is not the same as a clearly specified reuse license; verify the original UCI terms before redistributing.

**Possible real-world project idea:** create an educational crop-disease classification and data-quality demo that shows how missing entries and rare classes affect model performance. It may help demonstrate data preprocessing and diagnostic-model evaluation, but it is historical, has no confirmed Rwanda provenance in the OpenML metadata, and must not be used as a current farmer-facing disease diagnosis tool without external validation.

**Fit to the current project:** an alternative ML dataset, not an extension of the current aggregate crop-statistics database. It records plant cases and symptoms rather than Rwanda crop-area/production benchmarks, and it has a different observation grain, label set, and era. Do not merge it into HarvestStat.

## Comparison and decision

| Candidate | Geographic and data scope | Good fit | Main limitation | Decision for this project |
|---|---|---|---|---|
| HarvestStat Rwanda (existing) | Aggregate crop area, production, and yield; historical geography; sparse observed years | District/season/crop benchmark comparisons and completeness reporting | Missing values and sparse temporal coverage; no farm identifiers | Keep as the core dataset |
| UCI Paddy Dataset | 2,790 tabular records, 45 features; paddy inputs, soil, and variety fields | Alternative classification/regression research project | Rwanda provenance is not established by the repository page; different subject and grain | Do not merge; retain as an alternative idea pending provenance confirmation |
| Rwanda nitrogen-cycling dataset | 335 soil samples at two locations, with treatment and timepoint metadata plus qPCR data | Rwanda-specific exploratory soil-treatment research dashboard | Narrow experiment, not nationally representative crop production; license not stated on landing page | Alternative Rwanda research direction; not a benchmark-system extension |
| OpenML Soybean dataset | 683 historical soybean disease cases, 35 categorical attributes, 19 classes | Educational classification and missing-data/imbalance analysis | 1988 data, geographic provenance not established in metadata, 121 records contain missing values, license needs confirmation | Alternative ML demonstration only; do not merge or present as current Rwanda disease guidance |
| Rwanda crop-production index result | Country-level annual production index | National context and broad trend visualization | Secondary search result; not subnational crop records and may duplicate existing World Bank coverage | Use primary World Bank/FAO source only if needed for contextual comparison |

## Recommendation and practical impact

Keep the current project focused on its verified HarvestStat Rwanda extract. Its value is transparent, quality-aware comparison of real aggregate crop observations, not farm-level tracking or causal agricultural recommendations. The newly found Rwanda soil data offers a meaningful alternative research direction if the project is formally re-scoped, but combining it with the HarvestStat fact table would mix incompatible observation units, methods, and meanings.

Before adopting any alternative, verify its full documentation, geographic coverage, sampling design, data dictionary, license, and permission to redistribute. Treat exploratory associations as research leads rather than causal effects.

## Sources

- Subramaniyan, M. (2023). *Paddy Dataset* [Data set]. UCI Machine Learning Repository. https://doi.org/10.24432/C55W3J
- Schaedel, M. (2023). *Nitrogen cycling functional gene abundance and potential activity in novel perennial forage cropping systems in Rwanda* [Data set]. Mendeley Data, Version 1. https://doi.org/10.17632/5h66s39r5j.1
- Google. (n.d.). *Google Dataset Search*. https://datasetsearch.research.google.com/
- Michalski, R. S., & Chilausky, R. L. (1980). *Soybean* [Data set, 1988 source]. OpenML dataset 42, version 1. https://www.openml.org/d/42
- OpenML. (n.d.). *Dataset search*. https://www.openml.org/search?type=data
