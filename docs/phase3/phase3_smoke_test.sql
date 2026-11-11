-- Phase 3 smoke test. Run in a dedicated Oracle session after the Phase 2
-- schema, reference rows, and docs/phase3/phase3_implementation.sql are installed.
-- All fixture data is rolled back; the test does not commit.

SET SERVEROUTPUT ON

DECLARE
    l_dataset_id NUMBER;
    l_batch_id NUMBER;
    l_area_id NUMBER;
    l_crop_id NUMBER;
    l_season_id NUMBER;
    l_indicator_id NUMBER;
    l_statistic_id NUMBER;
    l_correction_id NUMBER;
    l_accepted NUMBER;
    l_rejected NUMBER;
    l_issue_count NUMBER;
    l_yield NUMBER;
    l_completeness NUMBER;
    l_error_raised BOOLEAN := FALSE;
    l_guard_raised BOOLEAN := FALSE;
BEGIN
    SAVEPOINT phase3_smoke_test;

    INSERT INTO source_dataset (
        dataset_code, dataset_name, organization_name, file_name
    ) VALUES (
        'PHASE3_TEST_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF3'),
        'Phase 3 smoke test fixture', 'Local test', 'phase3_smoke_test.csv'
    ) RETURNING dataset_id INTO l_dataset_id;

    INSERT INTO import_batch (
        dataset_id, batch_code, file_name, import_status
    ) VALUES (
        l_dataset_id, 'PHASE3_TEST', 'phase3_smoke_test.csv', 'STAGED'
    ) RETURNING batch_id INTO l_batch_id;

    INSERT INTO admin_area (geographic_unit_name, country_code)
    VALUES ('PHASE3 TEST AREA', 'RW')
    RETURNING admin_area_id INTO l_area_id;

    INSERT INTO crop (crop_code, crop_name)
    VALUES ('PHASE3_TEST_CROP', 'Phase 3 Test Crop')
    RETURNING crop_id INTO l_crop_id;

    INSERT INTO season (season_code, season_name, year_number)
    VALUES ('PHASE3_TEST_SEASON', 'Season T', 2020)
    RETURNING season_id INTO l_season_id;

    INSERT INTO indicator (indicator_code, indicator_name, allowed_unit)
    VALUES ('PHASE3_TEST_IND', 'Phase 3 Test Indicator', 'ha')
    RETURNING indicator_id INTO l_indicator_id;

    INSERT INTO stage_crop_observation (
        batch_id, dataset_id, source_record_id, product_name,
        geographic_unit_name, indicator_name, source_status,
        value_text, unit_code, season_name, season_year
    ) VALUES (
        l_batch_id, l_dataset_id, 'TEST-001', 'Phase 3 Test Crop',
        'PHASE3 TEST AREA', 'Phase 3 Test Indicator', 'Collected',
        '125.5', 'ha', 'Season T', 'Season T 2020'
    );

    INSERT INTO stage_crop_observation (
        batch_id, dataset_id, source_record_id, product_name,
        geographic_unit_name, indicator_name, source_status,
        value_text, unit_code, season_name, season_year
    ) VALUES (
        l_batch_id, l_dataset_id, 'TEST-002', 'Phase 3 Test Crop',
        'PHASE3 TEST AREA', 'Phase 3 Test Indicator', 'Not Collected',
        NULL, 'ha', 'Season T', 'Season T 2020'
    );

    INSERT INTO stage_crop_observation (
        batch_id, dataset_id, source_record_id, product_name,
        geographic_unit_name, indicator_name, source_status,
        value_text, unit_code, season_name, season_year
    ) VALUES (
        l_batch_id, l_dataset_id, 'TEST-003', 'Phase 3 Test Crop',
        'PHASE3 TEST AREA', 'Phase 3 Test Indicator', 'Collected',
        '140', 't', 'Season T', 'Season T 2020'
    );

    pkg_harvest_benchmark.p_validate_stage(l_batch_id);

    SELECT accepted_rows, rejected_rows
    INTO l_accepted, l_rejected
    FROM import_batch
    WHERE batch_id = l_batch_id;

    IF l_accepted <> 1 OR l_rejected <> 2 THEN
        RAISE_APPLICATION_ERROR(-20990, 'Validation counts did not match expected results.');
    END IF;

    SELECT COUNT(*)
    INTO l_issue_count
    FROM data_quality_issue q
    JOIN stage_crop_observation s ON s.stage_row_id = q.stage_row_id
    WHERE s.batch_id = l_batch_id;

    IF l_issue_count <> 2 THEN
        RAISE_APPLICATION_ERROR(-20991, 'Expected one missing-value issue and one invalid-unit issue.');
    END IF;

    l_completeness := pkg_harvest_benchmark.f_completeness_pct(
        l_crop_id, l_indicator_id, 2020
    );
    IF l_completeness <> 33.33 THEN
        RAISE_APPLICATION_ERROR(-20992, 'Completeness percentage was not 33.33.');
    END IF;

    pkg_harvest_benchmark.p_refresh_quality_summary(
        l_crop_id, l_indicator_id, 2020
    );

    SELECT completeness_pct
    INTO l_completeness
    FROM quality_summary
    WHERE crop_id = l_crop_id
      AND indicator_id = l_indicator_id
      AND observation_year = 2020;

    IF l_completeness <> 33.33 THEN
        RAISE_APPLICATION_ERROR(-20993, 'Quality summary completeness was not 33.33.');
    END IF;

    l_yield := pkg_harvest_benchmark.f_safe_yield(50, 100, 'ha', 't');
    IF l_yield <> 2 THEN
        RAISE_APPLICATION_ERROR(-20994, 'Safe yield calculation returned an unexpected value.');
    END IF;

    BEGIN
        l_yield := pkg_harvest_benchmark.f_safe_yield(50, 100, 'acres', 't');
    EXCEPTION
        WHEN pkg_harvest_benchmark.e_invalid_unit THEN
            l_error_raised := TRUE;
    END;

    IF NOT l_error_raised THEN
        RAISE_APPLICATION_ERROR(-20995, 'Safe yield did not reject incompatible units.');
    END IF;

    l_error_raised := FALSE;
    BEGIN
        l_yield := pkg_harvest_benchmark.f_safe_yield(50, 100, NULL, 't');
    EXCEPTION
        WHEN pkg_harvest_benchmark.e_invalid_unit THEN
            l_error_raised := TRUE;
    END;
    IF NOT l_error_raised THEN
        RAISE_APPLICATION_ERROR(-20999, 'Safe yield did not reject a missing unit.');
    END IF;

    SELECT statistic_id
    INTO l_statistic_id
    FROM agg_crop_statistic
    WHERE dataset_id = l_dataset_id
      AND source_record_id = 'TEST-001';

    pkg_harvest_benchmark.p_submit_correction(
        l_statistic_id, 130, 'Smoke test correction request',
        'Test evidence', l_correction_id
    );

    l_error_raised := FALSE;
    BEGIN
        pkg_harvest_benchmark.p_review_correction(l_correction_id, 'APPROVED');
    EXCEPTION
        WHEN pkg_harvest_benchmark.e_unauthorized_reviewer THEN
            l_error_raised := TRUE;
    END;
    IF NOT l_error_raised THEN
        RAISE_APPLICATION_ERROR(-20996, 'Requester was able to approve their own correction.');
    END IF;

    l_error_raised := FALSE;
    BEGIN
        pkg_harvest_benchmark.p_apply_approved_correction(l_correction_id);
    EXCEPTION
        WHEN pkg_harvest_benchmark.e_correction_not_approved THEN
            l_error_raised := TRUE;
    END;
    IF NOT l_error_raised THEN
        RAISE_APPLICATION_ERROR(-20997, 'Unapproved correction was applied.');
    END IF;

    BEGIN
        UPDATE agg_crop_statistic
        SET numeric_value = 126
        WHERE statistic_id = l_statistic_id;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20020 THEN
                l_guard_raised := TRUE;
            ELSE
                RAISE;
            END IF;
    END;
    IF NOT l_guard_raised THEN
        RAISE_APPLICATION_ERROR(-20998, 'Direct update to curated fact data was not blocked.');
    END IF;

    ROLLBACK TO phase3_smoke_test;
    DBMS_OUTPUT.PUT_LINE('Phase 3 smoke tests passed.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO phase3_smoke_test;
        RAISE;
END;
/
