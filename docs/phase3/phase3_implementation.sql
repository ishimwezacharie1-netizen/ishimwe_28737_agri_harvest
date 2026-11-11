-- Phase 3 implementation for Oracle Database 12c or later.
-- Run after docs/phase2/oracle_phase2_schema.sql.
-- This is a one-time installer; drop the Phase 3 objects before reinstalling.

CREATE TABLE authorized_reviewer (
    reviewer_username VARCHAR2(100) PRIMARY KEY,
    is_active CHAR(1) DEFAULT 'Y' NOT NULL
        CHECK (is_active IN ('Y', 'N')),
    added_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE quality_summary (
    crop_id NUMBER NOT NULL,
    indicator_id NUMBER NOT NULL,
    observation_year NUMBER NOT NULL,
    total_observations NUMBER NOT NULL,
    populated_observations NUMBER NOT NULL,
    completeness_pct NUMBER(5,2) NOT NULL,
    refreshed_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_quality_summary PRIMARY KEY (crop_id, indicator_id, observation_year),
    CONSTRAINT fk_quality_summary_crop FOREIGN KEY (crop_id) REFERENCES crop(crop_id),
    CONSTRAINT fk_quality_summary_indicator FOREIGN KEY (indicator_id) REFERENCES indicator(indicator_id),
    CONSTRAINT ck_quality_summary_counts CHECK (
        total_observations >= 0
        AND populated_observations >= 0
        AND populated_observations <= total_observations
    ),
    CONSTRAINT ck_quality_summary_pct CHECK (completeness_pct BETWEEN 0 AND 100)
);

CREATE UNIQUE INDEX uq_crop_name_normalized
    ON crop (UPPER(TRIM(crop_name)));
CREATE UNIQUE INDEX uq_indicator_name_normalized
    ON indicator (UPPER(TRIM(indicator_name)));

CREATE OR REPLACE PACKAGE pkg_harvest_benchmark AS
    e_invalid_unit EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_unit, -20001);
    e_correction_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_correction_not_found, -20002);
    e_correction_not_approved EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_correction_not_approved, -20003);
    e_unauthorized_reviewer EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_unauthorized_reviewer, -20004);

    PROCEDURE p_validate_stage(p_batch_id IN NUMBER);
    PROCEDURE p_refresh_quality_summary(
        p_crop_id IN NUMBER DEFAULT NULL,
        p_indicator_id IN NUMBER DEFAULT NULL,
        p_year_number IN NUMBER DEFAULT NULL
    );
    PROCEDURE p_submit_correction(
        p_statistic_id IN NUMBER,
        p_proposed_value IN NUMBER,
        p_reason IN VARCHAR2,
        p_evidence IN VARCHAR2 DEFAULT NULL,
        p_correction_id OUT NUMBER
    );
    PROCEDURE p_review_correction(
        p_correction_id IN NUMBER,
        p_decision IN VARCHAR2
    );
    PROCEDURE p_apply_approved_correction(p_correction_id IN NUMBER);
    FUNCTION f_completeness_pct(
        p_crop_id IN NUMBER DEFAULT NULL,
        p_indicator_id IN NUMBER DEFAULT NULL,
        p_year_number IN NUMBER DEFAULT NULL
    ) RETURN NUMBER;
    FUNCTION f_safe_yield(
        p_area_value IN NUMBER,
        p_quantity_value IN NUMBER,
        p_area_unit IN VARCHAR2,
        p_quantity_unit IN VARCHAR2
    ) RETURN NUMBER;

    FUNCTION f_fact_dml_allowed RETURN BOOLEAN;
    FUNCTION f_correction_apply_allowed RETURN BOOLEAN;
    FUNCTION f_current_correction_id RETURN NUMBER;

    CURSOR c_quality_gaps(p_max_completeness_pct IN NUMBER DEFAULT 100) IS
        SELECT crop_id, indicator_id, observation_year, total_observations,
               populated_observations, completeness_pct
        FROM quality_summary
        WHERE completeness_pct < p_max_completeness_pct
        ORDER BY completeness_pct, crop_id, indicator_id, observation_year;
END pkg_harvest_benchmark;
/

CREATE OR REPLACE PACKAGE BODY pkg_harvest_benchmark AS
    g_allow_fact_dml BOOLEAN := FALSE;
    g_allow_correction_apply BOOLEAN := FALSE;
    g_current_correction_id NUMBER;

    FUNCTION f_fact_dml_allowed RETURN BOOLEAN IS
    BEGIN
        RETURN g_allow_fact_dml;
    END f_fact_dml_allowed;

    FUNCTION f_correction_apply_allowed RETURN BOOLEAN IS
    BEGIN
        RETURN g_allow_correction_apply;
    END f_correction_apply_allowed;

    FUNCTION f_current_correction_id RETURN NUMBER IS
    BEGIN
        RETURN g_current_correction_id;
    END f_current_correction_id;

    PROCEDURE p_validate_stage(p_batch_id IN NUMBER) IS
        l_dataset_id import_batch.dataset_id%TYPE;
        l_batch_status import_batch.import_status%TYPE;
        l_accepted NUMBER := 0;
        l_rejected NUMBER := 0;
        l_total NUMBER := 0;

        CURSOR c_stage_rows IS
            SELECT s.*
            FROM stage_crop_observation s
            WHERE s.batch_id = p_batch_id
              AND s.row_status = 'PENDING'
            ORDER BY s.stage_row_id
            FOR UPDATE OF s.row_status;

        PROCEDURE log_issue(
            p_stage_row_id IN NUMBER,
            p_issue_type IN VARCHAR2,
            p_description IN VARCHAR2
        ) IS
        BEGIN
            INSERT INTO data_quality_issue (
                stage_row_id, issue_type, severity, issue_description
            ) VALUES (
                p_stage_row_id, p_issue_type, 'HIGH', p_description
            );
        END log_issue;
    BEGIN
        SELECT dataset_id, import_status
        INTO l_dataset_id, l_batch_status
        FROM import_batch
        WHERE batch_id = p_batch_id
        FOR UPDATE;

        IF l_batch_status <> 'STAGED' THEN
            RAISE_APPLICATION_ERROR(-20010, 'Only a STAGED batch can be validated.');
        END IF;

        FOR r IN c_stage_rows LOOP
            l_total := l_total + 1;
            DECLARE
                l_year NUMBER;
                l_value NUMBER;
                l_crop_id crop.crop_id%TYPE;
                l_area_id admin_area.admin_area_id%TYPE;
                l_season_id season.season_id%TYPE;
                l_indicator_id indicator.indicator_id%TYPE;
                l_unit indicator.allowed_unit%TYPE;
                l_match_count NUMBER;
                l_valid BOOLEAN := TRUE;
            BEGIN
                IF r.source_status IS NULL
                   OR UPPER(TRIM(r.source_status)) <> 'COLLECTED'
                   OR r.value_text IS NULL THEN
                    log_issue(r.stage_row_id, 'MISSING_VALUE',
                              'Source row is not marked Collected or has no value.');
                    l_valid := FALSE;
                ELSIF NOT REGEXP_LIKE(TRIM(r.value_text), '^[0-9]{1,14}([.][0-9]{1,4})?$') THEN
                    log_issue(r.stage_row_id, 'REJECTED_IMPORT',
                              'Value is not a nonnegative number within NUMBER(18,4) limits.');
                    l_valid := FALSE;
                ELSE
                    l_value := TO_NUMBER(
                        TRIM(r.value_text),
                        '99999999999999D9999',
                        'NLS_NUMERIC_CHARACTERS=''.,'''
                    );
                END IF;

                IF r.source_record_id IS NULL THEN
                    log_issue(r.stage_row_id, 'REJECTED_IMPORT',
                              'Source record identifier is required.');
                    l_valid := FALSE;
                ELSE
                    SELECT COUNT(*)
                    INTO l_match_count
                    FROM agg_crop_statistic
                    WHERE dataset_id = l_dataset_id
                      AND source_record_id = r.source_record_id;
                    IF l_match_count > 0 THEN
                        log_issue(r.stage_row_id, 'DUPLICATE_RECORD',
                                  'Source record has already been loaded for this dataset.');
                        l_valid := FALSE;
                    END IF;
                END IF;

                IF r.product_name IS NULL THEN
                    l_match_count := 0;
                ELSE
                    SELECT COUNT(*), MAX(crop_id)
                    INTO l_match_count, l_crop_id
                    FROM crop
                    WHERE UPPER(TRIM(crop_name)) = UPPER(TRIM(r.product_name));
                END IF;
                IF l_match_count <> 1 THEN
                    log_issue(r.stage_row_id, 'INCOMPLETE_SOURCE',
                              'Crop name does not resolve to exactly one CROP row.');
                    l_valid := FALSE;
                END IF;

                IF r.geographic_unit_name IS NULL THEN
                    l_match_count := 0;
                ELSE
                    SELECT COUNT(*), MAX(admin_area_id)
                    INTO l_match_count, l_area_id
                    FROM admin_area
                    WHERE UPPER(TRIM(geographic_unit_name)) =
                          UPPER(TRIM(r.geographic_unit_name));
                END IF;
                IF l_match_count <> 1 THEN
                    log_issue(r.stage_row_id, 'INCOMPLETE_SOURCE',
                              'Geographic unit does not resolve to exactly one ADMIN_AREA row.');
                    l_valid := FALSE;
                END IF;

                IF r.indicator_name IS NULL OR r.unit_code IS NULL THEN
                    l_match_count := 0;
                ELSE
                    SELECT COUNT(*), MAX(indicator_id), MAX(allowed_unit)
                    INTO l_match_count, l_indicator_id, l_unit
                    FROM indicator
                    WHERE UPPER(TRIM(indicator_name)) = UPPER(TRIM(r.indicator_name))
                      AND UPPER(TRIM(allowed_unit)) = UPPER(TRIM(r.unit_code));
                END IF;
                IF l_match_count <> 1 THEN
                    log_issue(r.stage_row_id, 'INVALID_UNIT',
                              'Indicator name and unit do not resolve to exactly one allowed pair.');
                    l_valid := FALSE;
                END IF;

                l_year := NULL;
                IF r.season_year IS NOT NULL THEN
                    l_year := TO_NUMBER(REGEXP_SUBSTR(r.season_year, '[0-9]{4}'));
                END IF;
                IF l_year IS NULL AND r.period_date IS NOT NULL THEN
                    l_year := EXTRACT(YEAR FROM r.period_date);
                END IF;
                IF l_year IS NULL OR l_year < 1000 OR l_year > 9999
                   OR r.season_name IS NULL THEN
                    log_issue(r.stage_row_id, 'INVALID_PERIOD',
                              'Season name and a four-digit observation year are required.');
                    l_valid := FALSE;
                ELSE
                    SELECT COUNT(*), MAX(season_id)
                    INTO l_match_count, l_season_id
                    FROM season
                    WHERE UPPER(TRIM(season_name)) = UPPER(TRIM(r.season_name))
                      AND year_number = l_year;
                    IF l_match_count <> 1 THEN
                        log_issue(r.stage_row_id, 'INVALID_PERIOD',
                                  'Season name and year do not resolve to exactly one SEASON row.');
                        l_valid := FALSE;
                    END IF;
                END IF;

                IF l_valid THEN
                    g_allow_fact_dml := TRUE;
                    INSERT INTO agg_crop_statistic (
                        batch_id, dataset_id, source_record_id,
                        admin_area_id, crop_id, season_id, indicator_id,
                        numeric_value, unit_code, observation_year,
                        quality_status, source_record_hash
                    ) VALUES (
                        p_batch_id, l_dataset_id, r.source_record_id,
                        l_area_id, l_crop_id, l_season_id, l_indicator_id,
                        l_value, l_unit, l_year, 'VALID', r.source_record_hash
                    );
                    g_allow_fact_dml := FALSE;

                    UPDATE stage_crop_observation
                    SET row_status = 'ACCEPTED'
                    WHERE CURRENT OF c_stage_rows;
                    l_accepted := l_accepted + 1;
                ELSE
                    UPDATE stage_crop_observation
                    SET row_status = 'REJECTED'
                    WHERE CURRENT OF c_stage_rows;
                    l_rejected := l_rejected + 1;
                END IF;
            END;
        END LOOP;

        UPDATE import_batch
        SET total_rows = l_total,
            accepted_rows = l_accepted,
            rejected_rows = l_rejected,
            import_status = CASE
                WHEN l_total = 0 THEN 'REJECTED'
                WHEN l_rejected = 0 THEN 'LOADED'
                WHEN l_accepted = 0 THEN 'REJECTED'
                ELSE 'VALIDATED'
            END
        WHERE batch_id = p_batch_id;

        g_allow_fact_dml := FALSE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            g_allow_fact_dml := FALSE;
            RAISE_APPLICATION_ERROR(-20011, 'Import batch was not found.');
        WHEN OTHERS THEN
            g_allow_fact_dml := FALSE;
            RAISE;
    END p_validate_stage;

    PROCEDURE p_refresh_quality_summary(
        p_crop_id IN NUMBER DEFAULT NULL,
        p_indicator_id IN NUMBER DEFAULT NULL,
        p_year_number IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        MERGE INTO quality_summary q
        USING (
            SELECT c.crop_id,
                   i.indicator_id,
                   COALESCE(
                       TO_NUMBER(REGEXP_SUBSTR(s.season_year, '[0-9]{4}')),
                       EXTRACT(YEAR FROM s.period_date)
                   ) AS observation_year,
                   COUNT(*) AS total_observations,
                   SUM(CASE
                       WHEN UPPER(TRIM(s.source_status)) = 'COLLECTED'
                        AND REGEXP_LIKE(TRIM(s.value_text), '^[0-9]{1,14}([.][0-9]{1,4})?$')
                        AND s.row_status = 'ACCEPTED'
                       THEN 1 ELSE 0
                   END) AS populated_observations
            FROM stage_crop_observation s
            JOIN crop c
              ON UPPER(TRIM(c.crop_name)) = UPPER(TRIM(s.product_name))
            JOIN indicator i
              ON UPPER(TRIM(i.indicator_name)) = UPPER(TRIM(s.indicator_name))
            WHERE (p_crop_id IS NULL OR c.crop_id = p_crop_id)
              AND (p_indicator_id IS NULL OR i.indicator_id = p_indicator_id)
              AND (
                    p_year_number IS NULL
                    OR COALESCE(
                        TO_NUMBER(REGEXP_SUBSTR(s.season_year, '[0-9]{4}')),
                        EXTRACT(YEAR FROM s.period_date)
                    ) = p_year_number
              )
            GROUP BY c.crop_id, i.indicator_id,
                     COALESCE(
                         TO_NUMBER(REGEXP_SUBSTR(s.season_year, '[0-9]{4}')),
                         EXTRACT(YEAR FROM s.period_date)
                     )
            HAVING COALESCE(
                       TO_NUMBER(REGEXP_SUBSTR(s.season_year, '[0-9]{4}')),
                       EXTRACT(YEAR FROM s.period_date)
                   ) IS NOT NULL
        ) src
        ON (
            q.crop_id = src.crop_id
            AND q.indicator_id = src.indicator_id
            AND q.observation_year = src.observation_year
        )
        WHEN MATCHED THEN UPDATE SET
            total_observations = src.total_observations,
            populated_observations = src.populated_observations,
            completeness_pct = ROUND(
                100 * src.populated_observations / NULLIF(src.total_observations, 0), 2
            ),
            refreshed_at = SYSTIMESTAMP
        WHEN NOT MATCHED THEN INSERT (
            crop_id, indicator_id, observation_year, total_observations,
            populated_observations, completeness_pct, refreshed_at
        ) VALUES (
            src.crop_id, src.indicator_id, src.observation_year,
            src.total_observations, src.populated_observations,
            ROUND(100 * src.populated_observations / NULLIF(src.total_observations, 0), 2),
            SYSTIMESTAMP
        );
    END p_refresh_quality_summary;

    PROCEDURE p_submit_correction(
        p_statistic_id IN NUMBER,
        p_proposed_value IN NUMBER,
        p_reason IN VARCHAR2,
        p_evidence IN VARCHAR2 DEFAULT NULL,
        p_correction_id OUT NUMBER
    ) IS
        l_current_value agg_crop_statistic.numeric_value%TYPE;
        l_username VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    BEGIN
        IF p_proposed_value IS NULL OR p_proposed_value < 0
           OR TRIM(p_reason) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20012, 'A nonnegative proposed value and reason are required.');
        END IF;

        SELECT numeric_value
        INTO l_current_value
        FROM agg_crop_statistic
        WHERE statistic_id = p_statistic_id
        FOR UPDATE;

        INSERT INTO data_correction_request (
            statistic_id, requested_by, original_value, proposed_value,
            reason_text, evidence_text, request_status
        ) VALUES (
            p_statistic_id, l_username, l_current_value, p_proposed_value,
            TRIM(p_reason), p_evidence, 'PENDING'
        )
        RETURNING correction_id INTO p_correction_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20013, 'Statistic for correction was not found.');
    END p_submit_correction;

    PROCEDURE p_review_correction(
        p_correction_id IN NUMBER,
        p_decision IN VARCHAR2
    ) IS
        l_status data_correction_request.request_status%TYPE;
        l_requester data_correction_request.requested_by%TYPE;
        l_username VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
        l_authorized NUMBER;
    BEGIN
        IF p_decision IS NULL
           OR UPPER(TRIM(p_decision)) NOT IN ('APPROVED', 'REJECTED') THEN
            RAISE_APPLICATION_ERROR(-20014, 'Decision must be APPROVED or REJECTED.');
        END IF;

        SELECT request_status, requested_by
        INTO l_status, l_requester
        FROM data_correction_request
        WHERE correction_id = p_correction_id
        FOR UPDATE;

        IF l_status <> 'PENDING' THEN
            RAISE_APPLICATION_ERROR(-20015, 'Only a PENDING correction can be reviewed.');
        END IF;

        SELECT COUNT(*)
        INTO l_authorized
        FROM authorized_reviewer
        WHERE UPPER(reviewer_username) = UPPER(l_username)
          AND is_active = 'Y';
        IF l_authorized = 0 OR UPPER(l_requester) = UPPER(l_username) THEN
            RAISE_APPLICATION_ERROR(-20004, 'Reviewer is unauthorized or is the requester.');
        END IF;

        UPDATE data_correction_request
        SET request_status = UPPER(TRIM(p_decision)),
            reviewer_user = l_username,
            reviewed_at = SYSTIMESTAMP
        WHERE correction_id = p_correction_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Correction request was not found.');
    END p_review_correction;

    PROCEDURE p_apply_approved_correction(p_correction_id IN NUMBER) IS
        l_statistic_id data_correction_request.statistic_id%TYPE;
        l_proposed_value data_correction_request.proposed_value%TYPE;
        l_status data_correction_request.request_status%TYPE;
    BEGIN
        SELECT statistic_id, proposed_value, request_status
        INTO l_statistic_id, l_proposed_value, l_status
        FROM data_correction_request
        WHERE correction_id = p_correction_id
        FOR UPDATE;

        IF l_status <> 'APPROVED' THEN
            RAISE_APPLICATION_ERROR(-20003, 'Correction request must be APPROVED before application.');
        END IF;

        g_current_correction_id := p_correction_id;
        g_allow_fact_dml := TRUE;
        g_allow_correction_apply := TRUE;

        UPDATE agg_crop_statistic
        SET numeric_value = l_proposed_value,
            quality_status = 'CORRECTED',
            updated_at = SYSTIMESTAMP
        WHERE statistic_id = l_statistic_id;

        UPDATE data_correction_request
        SET request_status = 'APPLIED'
        WHERE correction_id = p_correction_id;

        g_allow_fact_dml := FALSE;
        g_allow_correction_apply := FALSE;
        g_current_correction_id := NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            g_allow_fact_dml := FALSE;
            g_allow_correction_apply := FALSE;
            g_current_correction_id := NULL;
            RAISE_APPLICATION_ERROR(-20002, 'Correction request was not found.');
        WHEN OTHERS THEN
            g_allow_fact_dml := FALSE;
            g_allow_correction_apply := FALSE;
            g_current_correction_id := NULL;
            RAISE;
    END p_apply_approved_correction;

    FUNCTION f_completeness_pct(
        p_crop_id IN NUMBER DEFAULT NULL,
        p_indicator_id IN NUMBER DEFAULT NULL,
        p_year_number IN NUMBER DEFAULT NULL
    ) RETURN NUMBER IS
        l_total NUMBER;
        l_populated NUMBER;
    BEGIN
        SELECT COUNT(*),
               NVL(SUM(CASE
                   WHEN UPPER(TRIM(s.source_status)) = 'COLLECTED'
                    AND REGEXP_LIKE(TRIM(s.value_text), '^[0-9]{1,14}([.][0-9]{1,4})?$')
                    AND s.row_status = 'ACCEPTED'
                   THEN 1 ELSE 0
               END), 0)
        INTO l_total, l_populated
        FROM stage_crop_observation s
        JOIN crop c
          ON UPPER(TRIM(c.crop_name)) = UPPER(TRIM(s.product_name))
        JOIN indicator i
          ON UPPER(TRIM(i.indicator_name)) = UPPER(TRIM(s.indicator_name))
        WHERE (p_crop_id IS NULL OR c.crop_id = p_crop_id)
          AND (p_indicator_id IS NULL OR i.indicator_id = p_indicator_id)
          AND (
                p_year_number IS NULL
                OR COALESCE(
                    TO_NUMBER(REGEXP_SUBSTR(s.season_year, '[0-9]{4}')),
                    EXTRACT(YEAR FROM s.period_date)
                ) = p_year_number
          );

        IF l_total = 0 THEN
            RETURN NULL;
        END IF;
        RETURN ROUND(100 * l_populated / l_total, 2);
    END f_completeness_pct;

    FUNCTION f_safe_yield(
        p_area_value IN NUMBER,
        p_quantity_value IN NUMBER,
        p_area_unit IN VARCHAR2,
        p_quantity_unit IN VARCHAR2
    ) RETURN NUMBER IS
        l_area_unit VARCHAR2(30) := LOWER(TRIM(p_area_unit));
        l_quantity_unit VARCHAR2(30) := LOWER(TRIM(p_quantity_unit));
    BEGIN
        IF l_area_unit IS NULL
           OR l_quantity_unit IS NULL
           OR l_area_unit NOT IN ('ha', 'hectare', 'hectares')
           OR l_quantity_unit NOT IN ('t', 'mt', 'tonne', 'tonnes', 'metric ton', 'metric tons') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Safe yield requires area in hectares and quantity in metric tonnes.');
        END IF;
        IF p_area_value IS NULL OR p_area_value <= 0
           OR p_quantity_value IS NULL OR p_quantity_value < 0 THEN
            RAISE_APPLICATION_ERROR(-20016, 'Area must be positive and quantity must be nonnegative.');
        END IF;
        RETURN ROUND(p_quantity_value / p_area_value, 4);
    END f_safe_yield;
END pkg_harvest_benchmark;
/

CREATE OR REPLACE TRIGGER trg_agg_restrict_direct_dml
BEFORE INSERT OR UPDATE OR DELETE ON agg_crop_statistic
BEGIN
    IF NOT pkg_harvest_benchmark.f_fact_dml_allowed THEN
        RAISE_APPLICATION_ERROR(-20020, 'Use PKG_HARVEST_BENCHMARK to change curated statistics.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_agg_audit
AFTER UPDATE OF numeric_value ON agg_crop_statistic
FOR EACH ROW
BEGIN
    INSERT INTO audit_event (
        statistic_id, correction_id, old_value, new_value,
        changed_by, change_reason, application_context
    )
    SELECT :NEW.statistic_id,
           c.correction_id,
           :OLD.numeric_value,
           :NEW.numeric_value,
           SYS_CONTEXT('USERENV', 'SESSION_USER'),
           DBMS_LOB.SUBSTR(c.reason_text, 255, 1),
           'PKG_HARVEST_BENCHMARK'
    FROM data_correction_request c
    WHERE c.correction_id = pkg_harvest_benchmark.f_current_correction_id;
END;
/

CREATE OR REPLACE TRIGGER trg_corr_request_validate
BEFORE INSERT OR UPDATE ON data_correction_request
FOR EACH ROW
DECLARE
    l_username VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    l_authorized NUMBER;
BEGIN
    IF INSERTING THEN
        IF UPPER(:NEW.requested_by) <> UPPER(l_username)
           OR :NEW.request_status <> 'PENDING'
           OR :NEW.proposed_value IS NULL
           OR :NEW.proposed_value < 0
           OR :NEW.reason_text IS NULL
           OR DBMS_LOB.GETLENGTH(:NEW.reason_text) = 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'New correction requests must be valid PENDING requests submitted by the current user.');
        END IF;
    ELSE
        IF :NEW.statistic_id <> :OLD.statistic_id
           OR :NEW.requested_by <> :OLD.requested_by
           OR :NEW.request_date <> :OLD.request_date
           OR :NEW.original_value <> :OLD.original_value
           OR :NEW.proposed_value <> :OLD.proposed_value
           OR (:NEW.reason_text IS NULL AND :OLD.reason_text IS NOT NULL)
           OR (:NEW.reason_text IS NOT NULL AND :OLD.reason_text IS NULL)
           OR (:NEW.reason_text IS NOT NULL AND :OLD.reason_text IS NOT NULL
               AND DBMS_LOB.COMPARE(:NEW.reason_text, :OLD.reason_text) <> 0)
           OR (:NEW.evidence_text IS NULL AND :OLD.evidence_text IS NOT NULL)
           OR (:NEW.evidence_text IS NOT NULL AND :OLD.evidence_text IS NULL)
           OR (:NEW.evidence_text IS NOT NULL AND :OLD.evidence_text IS NOT NULL
               AND DBMS_LOB.COMPARE(:NEW.evidence_text, :OLD.evidence_text) <> 0) THEN
            RAISE_APPLICATION_ERROR(-20022, 'Correction details are immutable after submission.');
        END IF;

        IF :OLD.request_status = 'PENDING'
           AND :NEW.request_status IN ('APPROVED', 'REJECTED') THEN
            SELECT COUNT(*)
            INTO l_authorized
            FROM authorized_reviewer
            WHERE UPPER(reviewer_username) = UPPER(l_username)
              AND is_active = 'Y';
            IF l_authorized = 0
               OR UPPER(:NEW.reviewer_user) <> UPPER(l_username)
               OR UPPER(:OLD.requested_by) = UPPER(l_username)
               OR :NEW.reviewed_at IS NULL THEN
                RAISE_APPLICATION_ERROR(-20004, 'Only an active, independent reviewer may decide a correction.');
            END IF;
        ELSIF :OLD.request_status = 'APPROVED'
              AND :NEW.request_status = 'APPLIED' THEN
            IF NOT pkg_harvest_benchmark.f_correction_apply_allowed
               OR pkg_harvest_benchmark.f_current_correction_id <> :OLD.correction_id THEN
                RAISE_APPLICATION_ERROR(-20023, 'Only the correction package may mark a request APPLIED.');
            END IF;
        ELSE
            RAISE_APPLICATION_ERROR(-20024, 'Invalid correction request status transition.');
        END IF;
    END IF;
END;
/
