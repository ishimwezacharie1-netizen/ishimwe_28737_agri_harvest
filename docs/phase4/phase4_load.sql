-- Phase IV, step 2: run after importing the retained CSV columns into
-- STAGE_CROP_OBSERVATION and after running phase4_prepare.sql.
-- Designed for a fresh Phase IV load in an otherwise empty project schema.

SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
    c_dataset_code CONSTANT VARCHAR2(100) := 'HARVESTSTAT_RW';
    c_batch_code   CONSTANT VARCHAR2(100) := 'RW_HARVESTSTAT_001';
    c_expected_rows CONSTANT PLS_INTEGER := 13725;
    c_expected_missing CONSTANT PLS_INTEGER := 4602;
    v_dataset_id source_dataset.dataset_id%TYPE;
    v_batch_id import_batch.batch_id%TYPE;
    v_count PLS_INTEGER;
    v_missing PLS_INTEGER;
    v_invalid PLS_INTEGER;
BEGIN
    SELECT dataset_id
      INTO v_dataset_id
      FROM source_dataset
     WHERE dataset_code = c_dataset_code;

    SELECT batch_id
      INTO v_batch_id
      FROM import_batch
     WHERE dataset_id = v_dataset_id
       AND batch_code = c_batch_code;

    SELECT COUNT(*) INTO v_count
      FROM stage_crop_observation
     WHERE batch_id IS NULL;

    IF v_count != c_expected_rows THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Expected 13,725 unassigned imported staging rows; found ' || v_count);
    END IF;

    SELECT COUNT(*) INTO v_count FROM agg_crop_statistic;
    IF v_count != 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Fact table is not empty. This load script is for a fresh schema.');
    END IF;

    SELECT COUNT(*) INTO v_missing
      FROM stage_crop_observation
     WHERE batch_id IS NULL
       AND TRIM(value_raw) IS NULL;
    IF v_missing != c_expected_missing THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Expected 4,602 blank values; found ' || v_missing);
    END IF;

    SELECT COUNT(*) INTO v_invalid
      FROM stage_crop_observation s
     WHERE s.batch_id IS NULL
       AND TRIM(s.value_raw) IS NOT NULL
       AND (
           NOT REGEXP_LIKE(TRIM(s.value_raw),
               '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$')
           OR TO_NUMBER(TRIM(s.value_raw),
               '999999999999999999D99999999',
               'NLS_NUMERIC_CHARACTERS=''.,''') < 0
       );
    IF v_invalid != 0 THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Nonblank rows with invalid or negative values: ' || v_invalid);
    END IF;

    SELECT COUNT(*) INTO v_invalid
      FROM stage_crop_observation s
     WHERE s.batch_id IS NULL
       AND (
           s.fnid IS NULL OR s.product_name IS NULL OR s.indicator_name IS NULL
           OR s.season_year IS NULL OR s.season_name IS NULL
           OR s.crop_code IS NULL OR s.indicator_code IS NULL
           OR s.unit_code IS NULL OR s.source_record_id IS NULL
           OR NOT REGEXP_LIKE(TRIM(s.season_year), '[0-9]{4}')
       );
    IF v_invalid != 0 THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Rows with missing natural-key/dimension data or unparseable year: '
            || v_invalid);
    END IF;

    SELECT COUNT(*) INTO v_invalid
      FROM stage_crop_observation s
     WHERE s.batch_id IS NULL
       AND (
           (s.indicator_name = 'Area Planted' AND s.unit_code <> 'ha')
           OR (s.indicator_name = 'Quantity Produced' AND s.unit_code <> 't')
           OR (s.indicator_name = 'Yield' AND s.unit_code <> 'MT/ha')
           OR s.indicator_name NOT IN
              ('Area Planted', 'Quantity Produced', 'Yield')
       );
    IF v_invalid != 0 THEN
        RAISE_APPLICATION_ERROR(-20006,
            'Rows with indicator/unit mismatch or unknown indicator: '
            || v_invalid);
    END IF;

    SELECT COUNT(*) INTO v_invalid
      FROM (
          SELECT fnid, product_name, indicator_name, season_year
            FROM stage_crop_observation
           WHERE batch_id IS NULL
           GROUP BY fnid, product_name, indicator_name, season_year
          HAVING COUNT(*) > 1
      );
    IF v_invalid != 0 THEN
        RAISE_APPLICATION_ERROR(-20007,
            'Duplicate source natural-key groups: ' || v_invalid);
    END IF;

    UPDATE stage_crop_observation
       SET batch_id = v_batch_id
     WHERE batch_id IS NULL;

    UPDATE import_batch
       SET total_rows = c_expected_rows,
           import_status = 'STAGED'
     WHERE batch_id = v_batch_id;

    INSERT INTO admin_1 (admin_1_name)
    SELECT DISTINCT TRIM(admin_1)
      FROM stage_crop_observation
     WHERE batch_id = v_batch_id
       AND TRIM(admin_1) IS NOT NULL;

    INSERT INTO admin_2 (admin_2_name, admin_1_id)
    SELECT DISTINCT TRIM(s.admin_2), a.admin_1_id
      FROM stage_crop_observation s
      JOIN admin_1 a ON a.admin_1_name = TRIM(s.admin_1)
     WHERE s.batch_id = v_batch_id
       AND TRIM(s.admin_2) IS NOT NULL
       AND TRIM(s.admin_1) IS NOT NULL;

    INSERT INTO admin_area (
        fnid, geographic_unit_name, geographic_unit_full_name,
        admin_2_id, legacy_admin_1_id
    )
    SELECT x.fnid, x.geographic_unit_name, x.geographic_unit_full_name,
           a2.admin_2_id,
           CASE WHEN a2.admin_2_id IS NULL THEN a1.admin_1_id END
      FROM (
          SELECT fnid,
                 MAX(TRIM(geographic_unit_name)) AS geographic_unit_name,
                 MAX(TRIM(geographic_unit_full_name)) AS geographic_unit_full_name,
                 MAX(TRIM(admin_2)) AS admin_2_name,
                 MAX(TRIM(admin_1)) AS admin_1_name
            FROM stage_crop_observation
           WHERE batch_id = v_batch_id
           GROUP BY fnid
      ) x
      LEFT JOIN admin_2 a2 ON a2.admin_2_name = x.admin_2_name
      LEFT JOIN admin_1 a1 ON a1.admin_1_name = x.admin_1_name;

    INSERT INTO crop (crop_code, crop_name, crop_description)
    SELECT DISTINCT TRIM(crop_code), TRIM(product_name),
           MAX(TRIM(crop_description))
      FROM stage_crop_observation
     WHERE batch_id = v_batch_id
     GROUP BY TRIM(crop_code), TRIM(product_name);

    INSERT INTO indicator (
        indicator_code, indicator_name, allowed_unit, unit_name
    )
    SELECT DISTINCT
           NVL(TRIM(indicator_code), TRIM(indicator_name)),
           TRIM(indicator_name),
           TRIM(unit_code),
           MAX(TRIM(unit_name))
      FROM stage_crop_observation
     WHERE batch_id = v_batch_id
     GROUP BY NVL(TRIM(indicator_code), TRIM(indicator_name)),
              TRIM(indicator_name), TRIM(unit_code);

    INSERT INTO season (season_name)
    SELECT DISTINCT TRIM(season_name)
      FROM stage_crop_observation
     WHERE batch_id = v_batch_id;

    INSERT INTO season_year (
        season_id, observation_year, season_year_label
    )
    SELECT DISTINCT se.season_id,
           TO_NUMBER(REGEXP_SUBSTR(TRIM(s.season_year), '[0-9]{4}')),
           TRIM(s.season_year)
      FROM stage_crop_observation s
      JOIN season se ON se.season_name = TRIM(s.season_name)
     WHERE s.batch_id = v_batch_id;

    INSERT INTO source_document (
        dataset_id, source_document_code, source_document_name,
        source_organization_code, source_organization_name
    )
    SELECT DISTINCT v_dataset_id,
           TRIM(source_document_code),
           NVL(TRIM(source_document), TRIM(source_document_code)),
           TRIM(source_organization_code),
           TRIM(source_organization)
      FROM stage_crop_observation
     WHERE batch_id = v_batch_id
       AND TRIM(source_document_code) IS NOT NULL;

    UPDATE stage_crop_observation s
       SET row_status =
           CASE WHEN TRIM(value_raw) IS NULL THEN 'REJECTED' ELSE 'ACCEPTED' END
     WHERE batch_id = v_batch_id;

    INSERT INTO data_quality_issue (
        stage_row_id, issue_type, severity, issue_description
    )
    SELECT s.stage_row_id, 'MISSING_VALUE', 'MEDIUM',
           'Source value is blank; retained in staging and not loaded as zero.'
      FROM stage_crop_observation s
     WHERE s.batch_id = v_batch_id
       AND TRIM(s.value_raw) IS NULL;

    INSERT INTO agg_crop_statistic (
        batch_id, source_document_id, fnid, crop_id, indicator_id,
        season_year_id, source_record_id, numeric_value
    )
    SELECT v_batch_id,
           d.source_document_id,
           s.fnid,
           c.crop_id,
           i.indicator_id,
           sy.season_year_id,
           s.source_record_id,
           TO_NUMBER(TRIM(s.value_raw),
               '999999999999999999D99999999',
               'NLS_NUMERIC_CHARACTERS=''.,''')
      FROM stage_crop_observation s
      JOIN crop c ON c.crop_code = TRIM(s.crop_code)
                 AND c.crop_name = TRIM(s.product_name)
      JOIN indicator i ON i.indicator_name = TRIM(s.indicator_name)
                      AND i.allowed_unit = TRIM(s.unit_code)
      JOIN season se ON se.season_name = TRIM(s.season_name)
      JOIN season_year sy
        ON sy.season_id = se.season_id
       AND sy.season_year_label = TRIM(s.season_year)
      LEFT JOIN source_document d
        ON d.dataset_id = v_dataset_id
       AND d.source_document_code = TRIM(s.source_document_code)
     WHERE s.batch_id = v_batch_id
       AND TRIM(s.value_raw) IS NOT NULL;

    UPDATE import_batch
       SET loaded_rows = (SELECT COUNT(*) FROM agg_crop_statistic
                           WHERE batch_id = v_batch_id),
           rejected_rows = (SELECT COUNT(*) FROM data_quality_issue qi
                             JOIN stage_crop_observation st
                               ON st.stage_row_id = qi.stage_row_id
                            WHERE st.batch_id = v_batch_id),
           import_status = 'LOADED'
     WHERE batch_id = v_batch_id;

    SELECT COUNT(*) INTO v_count
      FROM agg_crop_statistic
     WHERE batch_id = v_batch_id;
    IF v_count != c_expected_rows - c_expected_missing THEN
        RAISE_APPLICATION_ERROR(-20008,
            'Expected 9,123 facts; loaded ' || v_count);
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM data_quality_issue qi
      JOIN stage_crop_observation s ON s.stage_row_id = qi.stage_row_id
     WHERE s.batch_id = v_batch_id
       AND qi.issue_type = 'MISSING_VALUE';
    IF v_count != c_expected_missing THEN
        RAISE_APPLICATION_ERROR(-20009,
            'Expected 4,602 missing-value issues; logged ' || v_count);
    END IF;

    UPDATE import_batch
       SET import_status = 'VALIDATED'
     WHERE batch_id = v_batch_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE(
        'Phase IV load complete: 13,725 staged, 9,123 facts, 4,602 missing-value issues; '
        || 'batch status VALIDATED.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
