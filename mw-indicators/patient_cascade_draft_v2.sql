WITH pre_mdt_confirmed AS (
    SELECT
        ptm.patient_id,
        'PreMDT' AS confirmed_malignancy_source,
        ptm.encounter_id,
        ptm.patient_program_id,
        ptm.form_field_path,
        ptm.date_recorded AS confirmed_mdt_date,
        ROW_NUMBER() OVER (
            PARTITION BY ptm.patient_id
            ORDER BY ptm.date_recorded
        ) AS row,
        ptm.agreed_figo_staging_for_cancer_of_the_vulva AS vulva_figo,
        ptm.agreed_figo_staging_for_cancer_of_the_vagina AS vagina_figo,
        ptm.agreed_figo_staging_for_cancer_of_the_cervix AS cervix_figo,
        ptm.agreed_figo_staging_for_cancer_of_the_uterus AS uterus_figo,
        ptm.agreed_figo_staging_for_cancer_of_the_ovary AS ovary_figo
    FROM "10_pre_treatment_mdt" ptm
    WHERE EXISTS (
        SELECT 1
        FROM clinical_diagnosis cdcm
        WHERE cdcm.encounter_id = ptm.encounter_id
          AND cdcm.reference_form_field_path = ptm.form_field_path
          AND cdcm.clinical_diagnosis = 'Confirmed malignancy'
    )
),
follow_up_mdt_confirmed_surgical AS (
    SELECT
        fum.patient_id,
        'Follow-up MDT' AS confirmed_malignancy_source,
        fum.encounter_id,
        fum.patient_program_id,
        fum.form_field_path,
        fum.date_recorded AS confirmed_mdt_date,
        ROW_NUMBER() OVER (
            PARTITION BY fum.patient_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row,
        fum.post_operative_figo_staging_for_cancer_of_the_vulva AS vulva_figo,
        fum.post_operative_figo_staging_for_cancer_of_the_vagina AS vagina_figo,
        fum.post_operative_figo_staging_for_cancer_of_the_cervix AS cervix_figo,
        fum.post_operative_figo_staging_for_cancer_of_the_uterus AS uterus_figo,
        fum.post_operative_figo_staging_for_cancer_of_the_ovary AS ovary_figo
    FROM public."11_follow_up_mdt" fum
    WHERE EXISTS (
        SELECT 1
        FROM public.post_operative_diagnosis pod
        WHERE pod.encounter_id = fum.encounter_id
          AND pod.reference_form_field_path = fum.form_field_path
AND pod.post_operative_diagnosis = 'Confirmed malignancy'
    )
    AND EXISTS (
        SELECT 1
        FROM proposed_management_plan pmp
        WHERE pmp.encounter_id = fum.encounter_id
          AND pmp.reference_form_field_path = fum.form_field_path
          AND pmp.proposed_management_plan = 'Surgical procedure'
    )
),
confirmed_mdt_first AS (
    SELECT *
    FROM pre_mdt_confirmed
    WHERE row = 1

    UNION ALL

    SELECT fum.*
    FROM follow_up_mdt_confirmed_surgical fum
    WHERE fum.row = 1
      AND NOT EXISTS (
          SELECT 1
          FROM pre_mdt_confirmed ptm
          WHERE ptm.patient_id = fum.patient_id
      )
),
initial_consultation AS (
    SELECT
        patient_id,
        patient_program_id,
        MIN(date_recorded) AS initial_consultation_date
    FROM "05_initial_consultation"
    GROUP BY patient_id, patient_program_id
),
topography_dedup AS (
    SELECT DISTINCT
        encounter_id,
        topography_of_the_tumour
    FROM topography_of_the_tumour

    UNION

    SELECT DISTINCT
        pot.encounter_id,
        pot.post_operative_topography_of_the_tumour AS topography_of_the_tumour
    FROM public.post_operative_topography_of_the_tumour pot
),
topography_list AS (
    SELECT
        encounter_id,
        STRING_AGG(
            topography_of_the_tumour,
            ', '
            ORDER BY topography_of_the_tumour
        ) AS topography_of_the_tumour_list
    FROM topography_dedup
    GROUP BY encounter_id
),
proposed_management_by_form AS (
    SELECT
        pmp.encounter_id,
        pmp.reference_form_field_path,
        STRING_AGG(
            DISTINCT pmp.proposed_management_plan,
            ', '
            ORDER BY pmp.proposed_management_plan
        ) AS proposed_management_plan
    FROM proposed_management_plan pmp
    GROUP BY
        pmp.encounter_id,
        pmp.reference_form_field_path
),
next_follow_up_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        next_follow_up_mdt_encounter_id,
        next_follow_up_mdt_form_field_path,
        date_next_follow_up_mdt
    FROM (
        SELECT
            cmf.encounter_id AS confirmed_mdt_encounter_id,
            fum.encounter_id AS next_follow_up_mdt_encounter_id,
            fum.form_field_path AS next_follow_up_mdt_form_field_path,
            fum.date_recorded AS date_next_follow_up_mdt,
            ROW_NUMBER() OVER (
                PARTITION BY cmf.encounter_id
                ORDER BY fum.date_recorded, fum.encounter_id
            ) AS row
        FROM confirmed_mdt_first cmf
        JOIN public."11_follow_up_mdt" fum
          ON fum.patient_id = cmf.patient_id
         AND fum.date_recorded > cmf.confirmed_mdt_date
    ) candidates
    WHERE row = 1
),
upfront_surgery AS (
    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        MIN(csr.date_of_surgery) AS date_upfront_surgery
    FROM confirmed_mdt_first cmf
    LEFT JOIN next_follow_up_mdt nfm
      ON nfm.confirmed_mdt_encounter_id = cmf.encounter_id
    JOIN "19_cervical_surgical_report" csr
      ON csr.patient_id = cmf.patient_id
     AND csr.date_of_surgery > cmf.confirmed_mdt_date
     AND (
         nfm.date_next_follow_up_mdt IS NULL
         OR csr.date_of_surgery < nfm.date_next_follow_up_mdt
     )
    WHERE EXISTS (
        SELECT 1
        FROM proposed_management_plan pmp
        WHERE pmp.encounter_id = cmf.encounter_id
          AND pmp.reference_form_field_path = cmf.form_field_path
          AND pmp.proposed_management_plan = 'Surgical procedure'
    )
    GROUP BY cmf.encounter_id
),
post_upfront_surgery_crt_candidates AS (
    SELECT
        us.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY us.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM upfront_surgery us
    JOIN next_follow_up_mdt nfm
      ON nfm.confirmed_mdt_encounter_id = us.confirmed_mdt_encounter_id
     AND nfm.date_next_follow_up_mdt > us.date_upfront_surgery
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = us.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = nfm.next_follow_up_mdt_encounter_id
     AND pmp.reference_form_field_path = nfm.next_follow_up_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > nfm.date_next_follow_up_mdt
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
     )
),
post_upfront_surgery_crt AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM post_upfront_surgery_crt_candidates
    WHERE row = 1
),
cycle_3_chemotherapy_candidates AS (
    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        chemo.date_recorded AS cycle_3_chemotherapy_date,
        chemo.type_of_chemotherapy AS cycle_3_chemotherapy_type,
        ROW_NUMBER() OVER (
            PARTITION BY cmf.encounter_id
            ORDER BY chemo.date_recorded, chemo.encounter_id
        ) AS row
    FROM confirmed_mdt_first cmf
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = cmf.patient_id
     AND chemo.date_recorded > cmf.confirmed_mdt_date
     AND chemo.cycle_number = 3
),
cycle_3_chemotherapy AS (
    SELECT
        confirmed_mdt_encounter_id,
        cycle_3_chemotherapy_date,
        cycle_3_chemotherapy_type
    FROM cycle_3_chemotherapy_candidates
    WHERE row = 1
),
cycle_3_surgery AS (
    SELECT
        c3c.confirmed_mdt_encounter_id,
        MIN(csr.date_of_surgery) AS date_cycle_3_surgery
    FROM cycle_3_chemotherapy c3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3c.confirmed_mdt_encounter_id
    JOIN "19_cervical_surgical_report" csr
      ON csr.patient_id = cmf.patient_id
     AND csr.date_of_surgery > c3c.cycle_3_chemotherapy_date
    WHERE NOT EXISTS (
        SELECT 1
        FROM "27_chemotherapy_clinical_assessment_and_treatment" chemo
        WHERE chemo.patient_id = cmf.patient_id
          AND chemo.date_recorded > c3c.cycle_3_chemotherapy_date
          AND chemo.date_recorded <= csr.date_of_surgery
          AND chemo.cycle_number > 3
    )
    GROUP BY c3c.confirmed_mdt_encounter_id
),
more_than_3_cycles_candidates AS (
    SELECT
       cmf.encounter_id AS confirmed_mdt_encounter_id,
       chemo.date_recorded AS date_more_than_3_cycles,
       chemo.type_of_chemotherapy AS more_than_3_cycles_chemotherapy_type,
       MAX(chemo.cycle_number) OVER (
           PARTITION BY cmf.encounter_id
       ) AS max_cycle_number,
       ROW_NUMBER() OVER (
           PARTITION BY cmf.encounter_id
           ORDER BY chemo.date_recorded DESC, chemo.encounter_id DESC
       ) AS row
    FROM confirmed_mdt_first cmf
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
     ON chemo.patient_id = cmf.patient_id
     AND chemo.date_recorded > cmf.confirmed_mdt_date
     AND chemo.cycle_number > 3
),
more_than_3_cycles AS (
    SELECT
       confirmed_mdt_encounter_id,
       date_more_than_3_cycles,
       more_than_3_cycles_chemotherapy_type,
       max_cycle_number
    FROM more_than_3_cycles_candidates
    WHERE row = 1
),
more_than_3_cycles_surgery AS (
    SELECT
       m3c.confirmed_mdt_encounter_id,
       MIN(csr.date_of_surgery) AS date_surgery_after_more_than_3_cycles
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first cmf
     ON cmf.encounter_id = m3c.confirmed_mdt_encounter_id
    JOIN "19_cervical_surgical_report" csr
     ON csr.patient_id = cmf.patient_id
     AND csr.date_of_surgery > m3c.date_more_than_3_cycles
    GROUP BY m3c.confirmed_mdt_encounter_id
),
cycle_3_post_surgery_chemo_cycles AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemo_cycles_after_cycle_3_surgery,
        last_post_surgery_chemo_date
    FROM (
        SELECT
            c3s.confirmed_mdt_encounter_id,
            chemo.date_recorded AS last_post_surgery_chemo_date,
            COUNT(*) OVER (
                PARTITION BY c3s.confirmed_mdt_encounter_id
            ) AS chemo_cycles_after_cycle_3_surgery,
            ROW_NUMBER() OVER (
                PARTITION BY c3s.confirmed_mdt_encounter_id
                ORDER BY chemo.date_recorded DESC, chemo.encounter_id DESC
            ) AS row
        FROM cycle_3_surgery c3s
        JOIN confirmed_mdt_first cmf
          ON cmf.encounter_id = c3s.confirmed_mdt_encounter_id
        JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
          ON chemo.patient_id = cmf.patient_id
         AND chemo.date_recorded > c3s.date_cycle_3_surgery
         AND chemo.cycle_number IS NOT NULL
    ) post_surgery_chemo
    WHERE row = 1
),
post_gt3_cycle_chemo AS (
    SELECT
        confirmed_mdt_encounter_id,
        last_post_surgery_chemo_date
    FROM cycle_3_post_surgery_chemo_cycles
    WHERE chemo_cycles_after_cycle_3_surgery > 3
),
subsequent_consultation_response_thresholds AS (
    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        cmf.patient_id,
        'cycle_3' AS response_source,
        c3c.cycle_3_chemotherapy_date AS response_after_date
    FROM cycle_3_chemotherapy c3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3c.confirmed_mdt_encounter_id

    UNION ALL

    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        cmf.patient_id,
        'more_than_3_cycles' AS response_source,
        m3c.date_more_than_3_cycles AS response_after_date
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3c.confirmed_mdt_encounter_id

    UNION ALL

    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        cmf.patient_id,
        'post_gt3_cycle' AS response_source,
        c3pc.last_post_surgery_chemo_date AS response_after_date
    FROM post_gt3_cycle_chemo c3pc
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3pc.confirmed_mdt_encounter_id
),
subsequent_consultation_response_candidates AS (
    SELECT
        thresholds.confirmed_mdt_encounter_id,
        thresholds.response_source,
        sc.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY
                thresholds.confirmed_mdt_encounter_id,
                thresholds.response_source
            ORDER BY sc.date_recorded, sc.encounter_id
        ) AS row
    FROM subsequent_consultation_response_thresholds thresholds
    JOIN "07_subsequent_consultation" sc
      ON sc.patient_id = thresholds.patient_id
     AND sc.date_recorded > thresholds.response_after_date
     AND NULLIF(sc.chemotherapy_response, '') IS NOT NULL
),
subsequent_consultation_response AS (
    SELECT
        confirmed_mdt_encounter_id,
        response_source,
        chemotherapy_response
    FROM subsequent_consultation_response_candidates
    WHERE row = 1
),
post_gt3_cycle_chemo_response AS (
    SELECT
        c3pc.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(mdt.chemotherapy_response, ''),
            NULLIF(sc.chemotherapy_response, '')
        ) AS chemotherapy_response,
        CASE
            WHEN NULLIF(mdt.chemotherapy_response, '') IS NOT NULL
            THEN mdt.response_mdt_encounter_id
        END AS response_mdt_encounter_id,
        CASE
            WHEN NULLIF(mdt.chemotherapy_response, '') IS NOT NULL
            THEN mdt.response_mdt_form_field_path
        END AS response_mdt_form_field_path,
        CASE
            WHEN NULLIF(mdt.chemotherapy_response, '') IS NOT NULL
            THEN mdt.response_mdt_date
        END AS response_mdt_date
    FROM post_gt3_cycle_chemo c3pc
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3pc.confirmed_mdt_encounter_id
    LEFT JOIN LATERAL (
        SELECT
            fum.encounter_id AS response_mdt_encounter_id,
            fum.form_field_path AS response_mdt_form_field_path,
            fum.date_recorded AS response_mdt_date,
            fum.chemotherapy_response
        FROM public."11_follow_up_mdt" fum
        WHERE fum.patient_id = cmf.patient_id
          AND fum.date_recorded > c3pc.last_post_surgery_chemo_date
          AND fum.treatment_type = 'Chemotherapy follow up'
        ORDER BY fum.date_recorded, fum.encounter_id
        LIMIT 1
    ) mdt ON TRUE
    LEFT JOIN subsequent_consultation_response sc
      ON sc.confirmed_mdt_encounter_id = c3pc.confirmed_mdt_encounter_id
     AND sc.response_source = 'post_gt3_cycle'
),
post_gt3_cycle_response_mdt_crt_candidates AS (
    SELECT
        c3pcr.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY c3pcr.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM post_gt3_cycle_chemo_response c3pcr
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = c3pcr.response_mdt_encounter_id
     AND pmp.reference_form_field_path = c3pcr.response_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3pcr.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > c3pcr.response_mdt_date
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
     )
),
post_gt3_cycle_response_mdt_crt AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM post_gt3_cycle_response_mdt_crt_candidates
    WHERE row = 1
),
cycle_3_post_surgery_mdt_candidates AS (
    SELECT
       c3s.confirmed_mdt_encounter_id,
       fum.encounter_id AS cycle_3_post_surgery_mdt_encounter_id,
       fum.form_field_path AS cycle_3_post_surgery_mdt_form_field_path,
       fum.date_recorded AS cycle_3_post_surgery_mdt_date,
       ROW_NUMBER() OVER (
           PARTITION BY c3s.confirmed_mdt_encounter_id
           ORDER BY fum.date_recorded, fum.encounter_id
       ) AS row
    FROM cycle_3_surgery c3s
    JOIN confirmed_mdt_first cmf
     ON cmf.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
     ON fum.patient_id = cmf.patient_id
     AND fum.date_recorded > c3s.date_cycle_3_surgery
),
cycle_3_post_surgery_mdt AS (
    SELECT
       confirmed_mdt_encounter_id,
       cycle_3_post_surgery_mdt_encounter_id,
       cycle_3_post_surgery_mdt_form_field_path,
       cycle_3_post_surgery_mdt_date
    FROM cycle_3_post_surgery_mdt_candidates
    WHERE row = 1
),
cycle_3_post_surgery_crt_candidates AS (
    SELECT
       c3m.confirmed_mdt_encounter_id,
       cr.chemoradiotherapy_start_date,
       cr.radiotherapy_outcome,
       ROW_NUMBER() OVER (
           PARTITION BY c3m.confirmed_mdt_encounter_id
           ORDER BY cr.chemoradiotherapy_start_date
       ) AS row
    FROM cycle_3_post_surgery_mdt c3m
    JOIN confirmed_mdt_first cmf
     ON cmf.encounter_id = c3m.confirmed_mdt_encounter_id
    JOIN cycle_3_chemotherapy c3c
     ON c3c.confirmed_mdt_encounter_id = c3m.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
     ON pmp.encounter_id = c3m.cycle_3_post_surgery_mdt_encounter_id
     AND pmp.reference_form_field_path = c3m.cycle_3_post_surgery_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
     ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > c3m.cycle_3_post_surgery_mdt_date
     AND cr.radiotherapy_outcome IN (
        'Completed without delay',
        'Completed with delay'
     )
    WHERE NOT EXISTS (
        SELECT 1
        FROM "27_chemotherapy_clinical_assessment_and_treatment" chemo
        WHERE chemo.patient_id = cmf.patient_id
          AND chemo.date_recorded > c3c.cycle_3_chemotherapy_date
          AND chemo.date_recorded <= cr.chemoradiotherapy_start_date
          AND chemo.cycle_number > 3
    )
),
cycle_3_post_surgery_crt AS (
    SELECT
       confirmed_mdt_encounter_id,
       chemoradiotherapy_start_date,
       radiotherapy_outcome
    FROM cycle_3_post_surgery_crt_candidates
    WHERE row = 1
),
cycle_3_follow_up_mdt_candidates AS (
    SELECT
        c3c.confirmed_mdt_encounter_id,
        fum.encounter_id AS cycle_3_follow_up_mdt_encounter_id,
        fum.form_field_path AS cycle_3_follow_up_mdt_form_field_path,
        fum.date_recorded AS cycle_3_follow_up_mdt_date,
        fum.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY c3c.confirmed_mdt_encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row
    FROM cycle_3_chemotherapy c3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3c.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = cmf.patient_id
     AND fum.date_recorded > c3c.cycle_3_chemotherapy_date
     AND fum.treatment_type = 'Chemotherapy follow up'
),
cycle_3_follow_up_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        cycle_3_follow_up_mdt_encounter_id,
        cycle_3_follow_up_mdt_form_field_path,
        cycle_3_follow_up_mdt_date,
        chemotherapy_response
    FROM cycle_3_follow_up_mdt_candidates
    WHERE row = 1
),
cycle_3_follow_up_mdt_crt_candidates AS (
    SELECT
        c3fum.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY c3fum.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM cycle_3_follow_up_mdt c3fum
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = c3fum.cycle_3_follow_up_mdt_encounter_id
     AND pmp.reference_form_field_path = c3fum.cycle_3_follow_up_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3fum.confirmed_mdt_encounter_id
    JOIN cycle_3_chemotherapy c3c
      ON c3c.confirmed_mdt_encounter_id = c3fum.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > c3fum.cycle_3_follow_up_mdt_date
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
     )
    WHERE NOT EXISTS (
        SELECT 1
        FROM "27_chemotherapy_clinical_assessment_and_treatment" chemo
        WHERE chemo.patient_id = cmf.patient_id
          AND chemo.date_recorded > c3c.cycle_3_chemotherapy_date
          AND chemo.date_recorded <= cr.chemoradiotherapy_start_date
          AND chemo.cycle_number > 3
    )
),
cycle_3_follow_up_mdt_crt AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM cycle_3_follow_up_mdt_crt_candidates
    WHERE row = 1
),
cycle_3_chemo_response AS (
    SELECT
        c3c.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(mdt.chemotherapy_response, ''),
            NULLIF(sc.chemotherapy_response, '')
        ) AS chemotherapy_response
    FROM cycle_3_chemotherapy c3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3c.confirmed_mdt_encounter_id
    LEFT JOIN cycle_3_follow_up_mdt mdt
      ON mdt.confirmed_mdt_encounter_id = c3c.confirmed_mdt_encounter_id
    LEFT JOIN subsequent_consultation_response sc
      ON sc.confirmed_mdt_encounter_id = c3c.confirmed_mdt_encounter_id
     AND sc.response_source = 'cycle_3'
),
lymph_node_results AS (
    SELECT
        bcs.patient_id,
        bcs.patient_program_id,
        bcs.encounter_id,
        bcs.microbiology_date_of_result,
        SUM(
            COALESCE(bcs.microbiology_number_of_positive_left_lymph_nodes, 0)
            + COALESCE(bcs.microbiology_number_of_positive_right_lymph_nodes, 0)
        ) AS ln_pos
    FROM bacteriology_concept_set bcs
    WHERE bcs.microbiology_date_of_result IS NOT NULL
      AND (
          bcs.microbiology_number_of_positive_left_lymph_nodes IS NOT NULL
          OR bcs.microbiology_number_of_positive_right_lymph_nodes IS NOT NULL
      )
    GROUP BY
        bcs.patient_id,
        bcs.patient_program_id,
        bcs.encounter_id,
        bcs.microbiology_date_of_result
),
ln_pos_candidates AS (
    SELECT
        cmf.encounter_id AS confirmed_mdt_encounter_id,
        lnr.encounter_id AS biopsy_encounter_id,
        lnr.microbiology_date_of_result AS biopsy_date,
        lnr.ln_pos,
        ROW_NUMBER() OVER (
            PARTITION BY cmf.encounter_id
            ORDER BY lnr.microbiology_date_of_result, lnr.encounter_id
        ) AS row
    FROM confirmed_mdt_first cmf
    JOIN upfront_surgery us
      ON us.confirmed_mdt_encounter_id = cmf.encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = cmf.patient_id
     AND lnr.patient_program_id = cmf.patient_program_id
     AND lnr.microbiology_date_of_result >= us.date_upfront_surgery
),
ln_pos_first AS (
    SELECT
        confirmed_mdt_encounter_id,
        biopsy_encounter_id,
        biopsy_date,
        ln_pos
    FROM ln_pos_candidates
    WHERE row = 1
),
upfront_surgery_histology_candidates AS (
    SELECT
        us.confirmed_mdt_encounter_id,
        bcs.microbiology_margin_status_invasive,
        bcs.microbiology_margin_status_pre_invasive,
        bcs.microbiology_parametrial_invasion,
        ROW_NUMBER() OVER (
            PARTITION BY us.confirmed_mdt_encounter_id
            ORDER BY bcs.microbiology_date_of_result, bcs.encounter_id
        ) AS row
    FROM upfront_surgery us
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = us.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = cmf.patient_id
     AND bcs.patient_program_id = cmf.patient_program_id
     AND bcs.microbiology_date_of_result >= us.date_upfront_surgery
    WHERE bcs.microbiology_margin_status_invasive IS NOT NULL
       OR bcs.microbiology_margin_status_pre_invasive IS NOT NULL
       OR bcs.microbiology_parametrial_invasion IS NOT NULL
),
upfront_surgery_histology AS (
    SELECT
        confirmed_mdt_encounter_id,
        CASE
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'positive'
              OR LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'positive'
                THEN 'Positive'
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'negative'
             AND LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'negative'
                THEN 'Negative'
        END AS margins,
        CASE
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'yes' THEN 'Yes'
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'no' THEN 'No'
        END AS parameters
    FROM upfront_surgery_histology_candidates
    WHERE row = 1
),
cycle_3_ln_pos_candidates AS (
    SELECT
        c3s.confirmed_mdt_encounter_id,
        lnr.ln_pos,
        ROW_NUMBER() OVER (
            PARTITION BY c3s.confirmed_mdt_encounter_id
            ORDER BY lnr.microbiology_date_of_result, lnr.encounter_id
        ) AS row
    FROM cycle_3_surgery c3s
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = cmf.patient_id
     AND lnr.patient_program_id = cmf.patient_program_id
     AND lnr.microbiology_date_of_result >= c3s.date_cycle_3_surgery
),
cycle_3_ln_pos AS (
    SELECT
        confirmed_mdt_encounter_id,
        ln_pos
    FROM cycle_3_ln_pos_candidates
    WHERE row = 1
),
cycle_3_histology_candidates AS (
    SELECT
        c3s.confirmed_mdt_encounter_id,
        bcs.microbiology_margin_status_invasive,
        bcs.microbiology_margin_status_pre_invasive,
        bcs.microbiology_parametrial_invasion,
        ROW_NUMBER() OVER (
            PARTITION BY c3s.confirmed_mdt_encounter_id
            ORDER BY bcs.microbiology_date_of_result, bcs.encounter_id
        ) AS row
    FROM cycle_3_surgery c3s
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = cmf.patient_id
     AND bcs.patient_program_id = cmf.patient_program_id
     AND bcs.microbiology_date_of_result >= c3s.date_cycle_3_surgery
    WHERE bcs.microbiology_margin_status_invasive IS NOT NULL
       OR bcs.microbiology_margin_status_pre_invasive IS NOT NULL
       OR bcs.microbiology_parametrial_invasion IS NOT NULL
),
cycle_3_histology AS (
    SELECT
        confirmed_mdt_encounter_id,
        CASE
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'positive'
              OR LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'positive'
                THEN 'Positive'
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'negative'
             AND LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'negative'
                THEN 'Negative'
        END AS histology_margins,
        CASE
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'yes' THEN 'Yes'
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'no' THEN 'No'
        END AS histology_parameters
    FROM cycle_3_histology_candidates
    WHERE row = 1
),
more3c_ln_pos_candidates AS (
    SELECT
        m3s.confirmed_mdt_encounter_id,
        lnr.ln_pos,
        ROW_NUMBER() OVER (
            PARTITION BY m3s.confirmed_mdt_encounter_id
            ORDER BY lnr.microbiology_date_of_result, lnr.encounter_id
        ) AS row
    FROM more_than_3_cycles_surgery m3s
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = cmf.patient_id
     AND lnr.patient_program_id = cmf.patient_program_id
     AND lnr.microbiology_date_of_result >= m3s.date_surgery_after_more_than_3_cycles
),
more3c_ln_pos AS (
    SELECT
        confirmed_mdt_encounter_id,
        ln_pos
    FROM more3c_ln_pos_candidates
    WHERE row = 1
),
more3c_histology_candidates AS (
    SELECT
        m3s.confirmed_mdt_encounter_id,
        bcs.microbiology_margin_status_invasive,
        bcs.microbiology_margin_status_pre_invasive,
        bcs.microbiology_parametrial_invasion,
        ROW_NUMBER() OVER (
            PARTITION BY m3s.confirmed_mdt_encounter_id
            ORDER BY bcs.microbiology_date_of_result, bcs.encounter_id
        ) AS row
    FROM more_than_3_cycles_surgery m3s
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = cmf.patient_id
     AND bcs.patient_program_id = cmf.patient_program_id
     AND bcs.microbiology_date_of_result >= m3s.date_surgery_after_more_than_3_cycles
    WHERE bcs.microbiology_margin_status_invasive IS NOT NULL
       OR bcs.microbiology_margin_status_pre_invasive IS NOT NULL
       OR bcs.microbiology_parametrial_invasion IS NOT NULL
),
more3c_histology AS (
    SELECT
        confirmed_mdt_encounter_id,
        CASE
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'positive'
              OR LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'positive'
                THEN 'Positive'
            WHEN LOWER(BTRIM(microbiology_margin_status_invasive)) = 'negative'
             AND LOWER(BTRIM(microbiology_margin_status_pre_invasive)) = 'negative'
                THEN 'Negative'
        END AS margins,
        CASE
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'yes' THEN 'Yes'
            WHEN LOWER(BTRIM(microbiology_parametrial_invasion)) = 'no' THEN 'No'
        END AS parameters
    FROM more3c_histology_candidates
    WHERE row = 1
),
more3c_follow_up_mdt_candidates AS (
    SELECT
        m3c.confirmed_mdt_encounter_id,
        fum.encounter_id AS more3c_follow_up_mdt_encounter_id,
        fum.form_field_path AS more3c_follow_up_mdt_form_field_path,
        fum.date_recorded AS more3c_follow_up_mdt_date,
        fum.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY m3c.confirmed_mdt_encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3c.confirmed_mdt_encounter_id
    LEFT JOIN cycle_3_follow_up_mdt c3fum
      ON c3fum.confirmed_mdt_encounter_id = m3c.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = cmf.patient_id
     AND fum.date_recorded > m3c.date_more_than_3_cycles
     AND (
         c3fum.cycle_3_follow_up_mdt_date IS NULL
         OR fum.date_recorded > c3fum.cycle_3_follow_up_mdt_date
     )
     AND (
         c3fum.cycle_3_follow_up_mdt_encounter_id IS NULL
         OR fum.encounter_id <> c3fum.cycle_3_follow_up_mdt_encounter_id
     )
     AND fum.treatment_type = 'Chemotherapy follow up'
),
more3c_follow_up_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        more3c_follow_up_mdt_encounter_id,
        more3c_follow_up_mdt_form_field_path,
        more3c_follow_up_mdt_date,
        chemotherapy_response
    FROM more3c_follow_up_mdt_candidates
    WHERE row = 1
),
more3c_follow_up_mdt_crt_candidates AS (
    SELECT
        m3fum.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY m3fum.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM more3c_follow_up_mdt m3fum
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = m3fum.more3c_follow_up_mdt_encounter_id
     AND pmp.reference_form_field_path = m3fum.more3c_follow_up_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3fum.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > m3fum.more3c_follow_up_mdt_date
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
     )
),
more3c_follow_up_mdt_crt AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM more3c_follow_up_mdt_crt_candidates
    WHERE row = 1
),
more3c_chemo_response AS (
    SELECT
        m3c.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(mdt.chemotherapy_response, ''),
            NULLIF(sc.chemotherapy_response, '')
        ) AS chemotherapy_response
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3c.confirmed_mdt_encounter_id
    LEFT JOIN more3c_follow_up_mdt mdt
      ON mdt.confirmed_mdt_encounter_id = m3c.confirmed_mdt_encounter_id
    LEFT JOIN subsequent_consultation_response sc
      ON sc.confirmed_mdt_encounter_id = m3c.confirmed_mdt_encounter_id
     AND sc.response_source = 'more_than_3_cycles'
),
more3c_post_surgery_mdt_candidates AS (
    SELECT
        m3s.confirmed_mdt_encounter_id,
        fum.encounter_id AS more3c_post_surgery_mdt_encounter_id,
        fum.form_field_path AS more3c_post_surgery_mdt_form_field_path,
        fum.date_recorded AS more3c_post_surgery_mdt_date,
        ROW_NUMBER() OVER (
            PARTITION BY m3s.confirmed_mdt_encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row
    FROM more_than_3_cycles_surgery m3s
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = cmf.patient_id
     AND fum.date_recorded > m3s.date_surgery_after_more_than_3_cycles
),
more3c_post_surgery_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        more3c_post_surgery_mdt_encounter_id,
        more3c_post_surgery_mdt_form_field_path,
        more3c_post_surgery_mdt_date
    FROM more3c_post_surgery_mdt_candidates
    WHERE row = 1
),
more3c_post_surgery_crt_candidates AS (
    SELECT
        m3m.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY m3m.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM more3c_post_surgery_mdt m3m
    JOIN confirmed_mdt_first cmf
      ON cmf.encounter_id = m3m.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = m3m.more3c_post_surgery_mdt_encounter_id
     AND pmp.reference_form_field_path = m3m.more3c_post_surgery_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = cmf.patient_id
     AND cr.chemoradiotherapy_start_date > m3m.more3c_post_surgery_mdt_date
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
     )
),
more3c_post_surgery_crt AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM more3c_post_surgery_crt_candidates
    WHERE row = 1
)
SELECT
    cmf.patient_id,
    cmf.encounter_id AS confirmed_mdt_first_encounter_id,
    cmf.patient_program_id AS confirmed_mdt_first_patient_program_id,
    ppdd.program_outcome AS confirmed_mdt_first_program_outcome,
    ic.initial_consultation_date AS "Date of Initial Consultation",
    (
        cmf.confirmed_mdt_date::date - ic.initial_consultation_date::date
    ) AS "Days between Initial Consultation and Confirmed First MDT",

    cmf.confirmed_mdt_date AS confirmed_mdt_first_date,
    cmf.confirmed_malignancy_source AS confirmed_mdt_first_type,
    cfmp.proposed_management_plan AS confirmed_mdt_first_proposed_management,
    tl.topography_of_the_tumour_list AS topography,
    cmf.vulva_figo AS vulva_figo,
    cmf.vagina_figo AS vagina_figo,
    cmf.cervix_figo AS cervical_figo_stage,
    cmf.uterus_figo AS uterus_figo,
    cmf.ovary_figo AS ovary_figo,

    us.date_upfront_surgery AS upfront_surgery,

    lnp.biopsy_encounter_id AS biopsy_encounter_id,
    lnp.biopsy_date AS biopsy_date,
    lnp.ln_pos AS "post_upfront_surgery_LN_pos",
    push.margins AS post_upfront_surgery_margins,
    push.parameters AS post_upfront_surgery_parameters,
    nfm.date_next_follow_up_mdt AS post_upfront_surgery_mdt_date,
    pum.proposed_management_plan AS post_upfront_surgery_proposed_management,
    puscrt.chemoradiotherapy_start_date AS post_upfront_surgery_crt_start_date,
    puscrt.radiotherapy_outcome AS post_upfront_surgery_crt_outcome,

    c3c.cycle_3_chemotherapy_date AS "3C_chemo_date",
    c3c.cycle_3_chemotherapy_type AS "3C_chemo_type",
    c3r.chemotherapy_response AS "3C_chemo_response",
    c3fum.cycle_3_follow_up_mdt_encounter_id AS "3C_follow_up_mdt_encounter_id",
    c3fum.cycle_3_follow_up_mdt_date AS "3C_follow_up_mdt_date",
    c3fmp.proposed_management_plan AS "3C_follow_up_mdt_proposed_management",
    CASE
        WHEN LOWER(c3fmp.proposed_management_plan) LIKE '%palliative care%' THEN 'Yes'
    END AS "3C_follow_up_mdt_proposed_management_palliative",
    CASE
        WHEN LOWER(c3fmp.proposed_management_plan) LIKE '%radiation therapy%' THEN 'Yes'
    END AS "3C_follow_up_mdt_proposed_management_CRT_referral",
    c3fcrt.chemoradiotherapy_start_date AS "3C_follow_up_mdt_proposed_management_CRT_date",
    c3fcrt.radiotherapy_outcome AS "3C_follow_up_mdt_proposed_management_CRT_outcome",

    c3s.date_cycle_3_surgery AS "3C_surgery",
    c3ln.ln_pos AS "3C_LN_pos",
    c3h.histology_margins AS "3C_histo_margins",
    c3h.histology_parameters AS "3C_histo_parameters",
    c3m.cycle_3_post_surgery_mdt_date AS "3C_after_surgery_mdt_date",
    c3pm.proposed_management_plan AS "3C_after_surgery_proposed_management",
    c3crt.chemoradiotherapy_start_date AS "3C_after_surgery_CRT_start_date",
    c3crt.radiotherapy_outcome AS "3C_after_surgery_CRT_outcome",
    c3pc.chemo_cycles_after_cycle_3_surgery AS "3C_surgery_post_chemo_cycles",
    c3pcr.chemotherapy_response AS "post_surgery_gt3_chemo_response",
    c3pcr.response_mdt_date AS "post_surgery_gt3_chemo_response_mdt_date",
    c3pmp.proposed_management_plan AS "post_surgery_gt3_chemo_response_mdt_proposed_management",
    CASE
        WHEN LOWER(c3pmp.proposed_management_plan) LIKE '%palliative care%' THEN 'Yes'
    END AS "post_surgery_gt3_chemo_response_mdt_proposed_management_palliative",
    CASE
        WHEN LOWER(c3pmp.proposed_management_plan) LIKE '%radiation therapy%' THEN 'Yes'
    END AS "post_surgery_gt3_chemo_response_mdt_proposed_management_CRT_referral",
    c3pcrt.chemoradiotherapy_start_date AS "post_surgery_gt3_chemo_response_mdt_proposed_management_CRT_date",
    c3pcrt.radiotherapy_outcome AS "post_surgery_gt3_chemo_response_mdt_proposed_management_CRT_outcome",

    m3s.date_surgery_after_more_than_3_cycles AS "more3C_surgery",
    m3ln.ln_pos AS "more3C_LN_pos",
    m3h.margins AS "more3C_margins",
    m3h.parameters AS "more3C_parameters",

    m3c.date_more_than_3_cycles AS "more3C_chemo_date",
    m3c.max_cycle_number AS "more3C_max_cycle_number",
    m3c.more_than_3_cycles_chemotherapy_type AS "more3C_chemo_type",
    m3r.chemotherapy_response AS "more3C_chemo_response",

    m3fum.more3c_follow_up_mdt_encounter_id AS "more3C_follow_up_mdt_encounter_id",
    m3fum.more3c_follow_up_mdt_date AS "more3C_follow_up_mdt_date",
    m3fmp.proposed_management_plan AS "more3C_follow_up_mdt_proposed_management",
    CASE
        WHEN LOWER(m3fmp.proposed_management_plan) LIKE '%palliative care%' THEN 'Yes'
    END AS "more3C_follow_up_mdt_proposed_management_palliative",
    CASE
        WHEN LOWER(m3fmp.proposed_management_plan) LIKE '%radiation therapy%' THEN 'Yes'
    END AS "more3C_follow_up_mdt_proposed_management_CRT_referral",
    CASE
        WHEN m3fcrt.chemoradiotherapy_start_date = m3pcrt.chemoradiotherapy_start_date
         AND m3fcrt.radiotherapy_outcome = m3pcrt.radiotherapy_outcome
        THEN NULL
        ELSE m3fcrt.chemoradiotherapy_start_date
    END AS "more3C_follow_up_mdt_proposed_management_CRT_date",
    CASE
        WHEN m3fcrt.chemoradiotherapy_start_date = m3pcrt.chemoradiotherapy_start_date
         AND m3fcrt.radiotherapy_outcome = m3pcrt.radiotherapy_outcome
        THEN NULL
        ELSE m3fcrt.radiotherapy_outcome
    END AS "more3C_follow_up_mdt_proposed_management_CRT_outcome",

    m3m.more3c_post_surgery_mdt_date AS "more3C_after_surgery_mdt_date",
    m3pm.proposed_management_plan AS "more3C_after_surgery_proposed_management",
    CASE
        WHEN m3pcrt.chemoradiotherapy_start_date = c3pcrt.chemoradiotherapy_start_date
         AND m3pcrt.radiotherapy_outcome = c3pcrt.radiotherapy_outcome
        THEN NULL
        ELSE m3pcrt.chemoradiotherapy_start_date
    END AS "more3C_after_surgery_CRT_start_date",
    CASE
        WHEN m3pcrt.chemoradiotherapy_start_date = c3pcrt.chemoradiotherapy_start_date
         AND m3pcrt.radiotherapy_outcome = c3pcrt.radiotherapy_outcome
        THEN NULL
        ELSE m3pcrt.radiotherapy_outcome
    END AS "more3C_after_surgery_CRT_outcome"
FROM confirmed_mdt_first cmf
LEFT JOIN patient_program_data_default ppdd
  ON ppdd.patient_program_id = cmf.patient_program_id
LEFT JOIN initial_consultation ic
  ON ic.patient_id = cmf.patient_id
 AND ic.patient_program_id = cmf.patient_program_id
LEFT JOIN proposed_management_by_form cfmp
  ON cfmp.encounter_id = cmf.encounter_id
 AND cfmp.reference_form_field_path = cmf.form_field_path
LEFT JOIN topography_list tl
  ON tl.encounter_id = cmf.encounter_id
LEFT JOIN upfront_surgery us
  ON us.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN next_follow_up_mdt nfm
  ON nfm.confirmed_mdt_encounter_id = cmf.encounter_id
 AND us.date_upfront_surgery IS NOT NULL
 AND nfm.date_next_follow_up_mdt > us.date_upfront_surgery
LEFT JOIN proposed_management_by_form pum
  ON pum.encounter_id = nfm.next_follow_up_mdt_encounter_id
 AND pum.reference_form_field_path = nfm.next_follow_up_mdt_form_field_path
LEFT JOIN post_upfront_surgery_crt puscrt
  ON puscrt.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_chemotherapy c3c
  ON c3c.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_surgery c3s
  ON c3s.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more_than_3_cycles_surgery m3s
  ON m3s.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more3c_ln_pos m3ln
  ON m3ln.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more3c_histology m3h
  ON m3h.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_post_surgery_chemo_cycles c3pc
  ON c3pc.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN post_gt3_cycle_chemo_response c3pcr
  ON c3pcr.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN proposed_management_by_form c3pmp
  ON c3pmp.encounter_id = c3pcr.response_mdt_encounter_id
 AND c3pmp.reference_form_field_path = c3pcr.response_mdt_form_field_path
LEFT JOIN post_gt3_cycle_response_mdt_crt c3pcrt
  ON c3pcrt.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_post_surgery_mdt c3m
  ON c3m.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN proposed_management_by_form c3pm
  ON c3pm.encounter_id = c3m.cycle_3_post_surgery_mdt_encounter_id
 AND c3pm.reference_form_field_path = c3m.cycle_3_post_surgery_mdt_form_field_path
LEFT JOIN cycle_3_post_surgery_crt c3crt
  ON c3crt.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_chemo_response c3r
  ON c3r.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_follow_up_mdt c3fum
  ON c3fum.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN proposed_management_by_form c3fmp
  ON c3fmp.encounter_id = c3fum.cycle_3_follow_up_mdt_encounter_id
 AND c3fmp.reference_form_field_path = c3fum.cycle_3_follow_up_mdt_form_field_path
LEFT JOIN cycle_3_follow_up_mdt_crt c3fcrt
  ON c3fcrt.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN ln_pos_first lnp
  ON lnp.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN upfront_surgery_histology push
  ON push.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_ln_pos c3ln
  ON c3ln.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN cycle_3_histology c3h
  ON c3h.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more_than_3_cycles m3c
  ON m3c.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more3c_chemo_response m3r
  ON m3r.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more3c_follow_up_mdt m3fum
  ON m3fum.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN proposed_management_by_form m3fmp
  ON m3fmp.encounter_id = m3fum.more3c_follow_up_mdt_encounter_id
 AND m3fmp.reference_form_field_path = m3fum.more3c_follow_up_mdt_form_field_path
LEFT JOIN more3c_follow_up_mdt_crt m3fcrt
  ON m3fcrt.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN more3c_post_surgery_mdt m3m
  ON m3m.confirmed_mdt_encounter_id = cmf.encounter_id
LEFT JOIN proposed_management_by_form m3pm
  ON m3pm.encounter_id = m3m.more3c_post_surgery_mdt_encounter_id
 AND m3pm.reference_form_field_path = m3m.more3c_post_surgery_mdt_form_field_path
LEFT JOIN more3c_post_surgery_crt m3pcrt
  ON m3pcrt.confirmed_mdt_encounter_id = cmf.encounter_id;