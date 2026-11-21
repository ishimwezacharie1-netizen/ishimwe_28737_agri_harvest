-- Phase IV validation queries. Expected counts are for the provided Rwanda CSV.

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    c_expected_staged CONSTANT PLS_INTEGER := 13725;
    c_expected_facts CONSTANT PLS_INTEGER := 9123;
    c_expected_missing CONSTANT PLS_INTEGER := 4602;
    v_staged PLS_INTEGER;
    v_facts PLS_INTEGER;
    v_missing PLS_INTEGER;
    v_orphans PLS_INTEGER;
    v_duplicates PLS_INTEGER;
    v_areas PLS_INTEGER;
    v_crops PLS_INTEGER;
    v_indicators PLS_INTEGER;
    v_seasons PLS_INTEGER;
    v_season_years PLS_INTEGER;
    v_unit_mismatches PLS_INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO v_staged
      FROM stage_crop_observation s
      JOIN import_batch b ON b.batch_id = s.batch_id
      JOIN source_dataset d ON d.dataset_id = b.dataset_id
     WHERE d.dataset_code = 'HARVESTSTAT_RW'
       AND b.batch_code = 'RW_HARVESTSTAT_001';

    SELECT COUNT(*)
      INTO v_facts
      FROM agg_crop_statistic f
      JOIN import_batch b ON b.batch_id = f.batch_id
      JOIN source_dataset d ON d.dataset_id = b.dataset_id
     WHERE d.dataset_code = 'HARVESTSTAT_RW'
       AND b.batch_code = 'RW_HARVESTSTAT_001';

    SELECT COUNT(*)
      INTO v_missing
      FROM data_quality_issue qi
      JOIN stage_crop_observation s ON s.stage_row_id = qi.stage_row_id
      JOIN import_batch b ON b.batch_id = s.batch_id
      JOIN source_dataset d ON d.dataset_id = b.dataset_id
     WHERE d.dataset_code = 'HARVESTSTAT_RW'
       AND b.batch_code = 'RW_HARVESTSTAT_001'
       AND qi.issue_type = 'MISSING_VALUE';

    SELECT COUNT(*)
      INTO v_duplicates
      FROM (
          SELECT fnid, crop_id, indicator_id, season_year_id
            FROM agg_crop_statistic
           GROUP BY fnid, crop_id, indicator_id, season_year_id
          HAVING COUNT(*) > 1
      );

    SELECT
        (SELECT COUNT(*) FROM agg_crop_statistic f
          LEFT JOIN admin_area a ON a.fnid = f.fnid WHERE a.fnid IS NULL)
      + (SELECT COUNT(*) FROM agg_crop_statistic f
          LEFT JOIN crop c ON c.crop_id = f.crop_id WHERE c.crop_id IS NULL)
      + (SELECT COUNT(*) FROM agg_crop_statistic f
          LEFT JOIN indicator i ON i.indicator_id = f.indicator_id
         WHERE i.indicator_id IS NULL)
      + (SELECT COUNT(*) FROM agg_crop_statistic f
          LEFT JOIN season_year sy ON sy.season_year_id = f.season_year_id
         WHERE sy.season_year_id IS NULL)
      INTO v_orphans
      FROM dual;

    SELECT COUNT(*) INTO v_areas FROM admin_area;
    SELECT COUNT(*) INTO v_crops FROM crop;
    SELECT COUNT(*) INTO v_indicators FROM indicator;
    SELECT COUNT(*) INTO v_seasons FROM season;
    SELECT COUNT(*) INTO v_season_years FROM season_year;

    SELECT COUNT(*)
      INTO v_unit_mismatches
      FROM agg_crop_statistic f
      JOIN indicator i ON i.indicator_id = f.indicator_id
     WHERE (i.indicator_name = 'Area Planted' AND i.allowed_unit <> 'ha')
        OR (i.indicator_name = 'Quantity Produced' AND i.allowed_unit <> 't')
        OR (i.indicator_name = 'Yield' AND i.allowed_unit <> 'MT/ha');

    IF v_staged != c_expected_staged
       OR v_facts != c_expected_facts
       OR v_missing != c_expected_missing
       OR v_duplicates != 0
       OR v_orphans != 0
       OR v_areas != 51
       OR v_crops != 38
       OR v_indicators != 3
       OR v_seasons != 3
       OR v_season_years != 15
       OR v_unit_mismatches != 0 THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'Phase IV validation failed: staged=' || v_staged
            || ', facts=' || v_facts
            || ', missing=' || v_missing
            || ', duplicate natural keys=' || v_duplicates
            || ', orphan facts=' || v_orphans
            || ', areas=' || v_areas
            || ', crops=' || v_crops
            || ', indicators=' || v_indicators
            || ', seasons=' || v_seasons
            || ', season_years=' || v_season_years
            || ', unit mismatches=' || v_unit_mismatches
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        'PASS: Phase IV counts and keys are valid '
        || '(staged=' || v_staged
        || ', facts=' || v_facts
        || ', missing=' || v_missing
        || ', duplicates=' || v_duplicates
        || ', orphans=' || v_orphans
        || ').'
    );
END;
/

SELECT b.batch_code, b.import_status, b.total_rows, b.loaded_rows, b.rejected_rows,
       COUNT(s.stage_row_id) AS staged_rows
  FROM import_batch b
  JOIN source_dataset d ON d.dataset_id = b.dataset_id
  LEFT JOIN stage_crop_observation s ON s.batch_id = b.batch_id
 WHERE d.dataset_code = 'HARVESTSTAT_RW'
   AND b.batch_code = 'RW_HARVESTSTAT_001'
 GROUP BY b.batch_code, b.import_status, b.total_rows,
          b.loaded_rows, b.rejected_rows;

SELECT 'ADMIN_AREA' AS table_name, COUNT(*) AS row_count FROM admin_area
UNION ALL SELECT 'CROP', COUNT(*) FROM crop
UNION ALL SELECT 'INDICATOR', COUNT(*) FROM indicator
UNION ALL SELECT 'SEASON_YEAR', COUNT(*) FROM season_year
UNION ALL SELECT 'SEASON', COUNT(*) FROM season
UNION ALL SELECT 'ADMIN_1', COUNT(*) FROM admin_1
UNION ALL SELECT 'ADMIN_2', COUNT(*) FROM admin_2
UNION ALL SELECT 'STAGE_CROP_OBSERVATION', COUNT(*) FROM stage_crop_observation
UNION ALL SELECT 'AGG_CROP_STATISTIC', COUNT(*) FROM agg_crop_statistic
UNION ALL SELECT 'DATA_QUALITY_ISSUE', COUNT(*) FROM data_quality_issue
ORDER BY table_name;

-- Should return no rows.
SELECT fnid, crop_id, indicator_id, season_year_id, COUNT(*) AS duplicate_count
  FROM agg_crop_statistic
 GROUP BY fnid, crop_id, indicator_id, season_year_id
HAVING COUNT(*) > 1;

-- Should return zero for every orphan count.
SELECT
    (SELECT COUNT(*) FROM agg_crop_statistic f
      LEFT JOIN admin_area a ON a.fnid = f.fnid WHERE a.fnid IS NULL)
  + (SELECT COUNT(*) FROM agg_crop_statistic f
      LEFT JOIN crop c ON c.crop_id = f.crop_id WHERE c.crop_id IS NULL)
  + (SELECT COUNT(*) FROM agg_crop_statistic f
      LEFT JOIN indicator i ON i.indicator_id = f.indicator_id
     WHERE i.indicator_id IS NULL)
  + (SELECT COUNT(*) FROM agg_crop_statistic f
      LEFT JOIN season_year sy ON sy.season_year_id = f.season_year_id
     WHERE sy.season_year_id IS NULL) AS orphan_foreign_key_count
  FROM dual;

-- Should return 4,602.
SELECT COUNT(*) AS missing_value_issue_count
  FROM data_quality_issue
 WHERE issue_type = 'MISSING_VALUE';

-- Confirm each indicator has only its permitted source unit.
SELECT i.indicator_name, i.allowed_unit, COUNT(*) AS fact_count
  FROM agg_crop_statistic f
  JOIN indicator i ON i.indicator_id = f.indicator_id
 GROUP BY i.indicator_name, i.allowed_unit
 ORDER BY i.indicator_name;

-- Expected lookup counts: 51, 38, 3, 15, 3; plus normalized geography tables.
SELECT COUNT(*) AS area_count FROM admin_area;
SELECT COUNT(*) AS crop_count FROM crop;
SELECT COUNT(*) AS indicator_count FROM indicator;
SELECT COUNT(*) AS season_year_count FROM season_year;
SELECT COUNT(*) AS season_count FROM season;
