-- Phase IV, step 1: run after installing docs/phase2/oracle_phase2_schema.sql.
-- Then use SQL Developer's Import Data wizard to load the retained CSV fields
-- into STAGE_CROP_OBSERVATION, leaving stage_row_id, batch_id, and row_status
-- unmapped. Run phase4_load.sql after the import completes.

SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

MERGE INTO source_dataset target
USING (
    SELECT 'HARVESTSTAT_RW' AS dataset_code,
           'HarvestStat Africa - Rwanda crop statistics' AS dataset_name,
           'https://data.humdata.org/dataset/harveststat-africa' AS source_url,
           'HarvestStat Consortium; Humanitarian Data Exchange' AS attribution_text
      FROM dual
) source
ON (target.dataset_code = source.dataset_code)
WHEN NOT MATCHED THEN
    INSERT (dataset_code, dataset_name, source_url, attribution_text)
    VALUES (source.dataset_code, source.dataset_name, source.source_url,
            source.attribution_text);

MERGE INTO import_batch target
USING (
    SELECT dataset_id, 'RW_HARVESTSTAT_001' AS batch_code,
           'adm_crop_data_raw_RW.csv' AS file_name
      FROM source_dataset
     WHERE dataset_code = 'HARVESTSTAT_RW'
) source
ON (target.dataset_id = source.dataset_id
    AND target.batch_code = source.batch_code)
WHEN NOT MATCHED THEN
    INSERT (dataset_id, batch_code, file_name)
    VALUES (source.dataset_id, source.batch_code, source.file_name);

COMMIT;

SELECT d.dataset_code, b.batch_code, b.file_name, b.import_status
  FROM source_dataset d
  JOIN import_batch b ON b.dataset_id = d.dataset_id
 WHERE d.dataset_code = 'HARVESTSTAT_RW'
   AND b.batch_code = 'RW_HARVESTSTAT_001';
