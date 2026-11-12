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
        ptm.agreed_figo_staging_for_cancer_of_the_cervix AS cervix_figo
    FROM "10_pre_treatment_mdt" ptm
    WHERE EXISTS (
        SELECT 1
        FROM clinical_diagnosis cdcm
        WHERE cdcm.encounter_id = ptm.encounter_id
          AND cdcm.reference_form_field_path = ptm.form_field_path
          AND cdcm.clinical_diagnosis = 'Confirmed malignancy'
    )
    OR EXISTS (
        SELECT 1
        FROM diagnosis d
        WHERE d.encounter_id = ptm.encounter_id
          AND d.reference_form_field_path = ptm.form_field_path
          AND d.diagnosis = 'Confirmed malignancy'
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
        fum.post_operative_figo_staging_for_cancer_of_the_cervix AS cervix_figo
    FROM public."11_follow_up_mdt" fum
    WHERE EXISTS (
        SELECT 1
        FROM public.post_operative_diagnosis pod
        WHERE pod.encounter_id = fum.encounter_id
          AND pod.reference_form_field_path = fum.form_field_path
          AND NULLIF(BTRIM(pod.post_operative_diagnosis), '') IS NOT NULL
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
        pc.encounter_id AS confirmed_mdt_encounter_id,
        MIN(fum.date_recorded) AS date_next_follow_up_mdt
    FROM confirmed_mdt_first pc
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
     AND fum.date_recorded > pc.confirmed_mdt_date
    GROUP BY pc.encounter_id
),
upfront_surgery AS (
    SELECT
        pc.encounter_id AS confirmed_mdt_encounter_id,
        MIN(csr.date_of_surgery) AS date_upfront_surgery
    FROM confirmed_mdt_first pc
    LEFT JOIN next_follow_up_mdt nfm
      ON nfm.confirmed_mdt_encounter_id = pc.encounter_id
    JOIN "19_cervical_surgical_report" csr
      ON csr.patient_id = pc.patient_id
     AND csr.date_of_surgery > pc.confirmed_mdt_date
     AND (
         nfm.date_next_follow_up_mdt IS NULL
         OR csr.date_of_surgery < nfm.date_next_follow_up_mdt
     )
    WHERE EXISTS (
        SELECT 1
        FROM proposed_management_plan pmp
        WHERE pmp.encounter_id = pc.encounter_id
          AND pmp.reference_form_field_path = pc.form_field_path
          AND pmp.proposed_management_plan = 'Surgical procedure'
    )
    GROUP BY pc.encounter_id
),
post_upfront_surgery_mdt_candidates AS (
    SELECT
        us.confirmed_mdt_encounter_id,
        fum.encounter_id AS post_upfront_surgery_mdt_encounter_id,
        fum.form_field_path AS post_upfront_surgery_mdt_form_field_path,
        fum.date_recorded AS post_upfront_surgery_mdt_date,
        ROW_NUMBER() OVER (
            PARTITION BY us.confirmed_mdt_encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row
    FROM upfront_surgery us
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = us.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
     AND fum.date_recorded > us.date_upfront_surgery
),
post_upfront_surgery_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        post_upfront_surgery_mdt_encounter_id,
        post_upfront_surgery_mdt_form_field_path,
        post_upfront_surgery_mdt_date
    FROM post_upfront_surgery_mdt_candidates
    WHERE row = 1
),
post_upfront_surgery_crt_candidates AS (
    SELECT
        pusm.confirmed_mdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY pusm.confirmed_mdt_encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS row
    FROM post_upfront_surgery_mdt pusm
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = pusm.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = pusm.post_upfront_surgery_mdt_encounter_id
     AND pmp.reference_form_field_path = pusm.post_upfront_surgery_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
     AND cr.chemoradiotherapy_start_date > pusm.post_upfront_surgery_mdt_date
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
        pc.encounter_id AS confirmed_mdt_encounter_id,
        chemo.date_recorded AS cycle_3_chemotherapy_date,
        chemo.type_of_chemotherapy AS cycle_3_chemotherapy_type,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY chemo.date_recorded, chemo.encounter_id
        ) AS row
    FROM confirmed_mdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.confirmed_mdt_date
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3c.confirmed_mdt_encounter_id
    JOIN "19_cervical_surgical_report" csr
      ON csr.patient_id = pc.patient_id
     AND csr.date_of_surgery > c3c.cycle_3_chemotherapy_date
    GROUP BY c3c.confirmed_mdt_encounter_id
),
more_than_3_cycles_candidates AS (
    SELECT
       pc.encounter_id AS confirmed_mdt_encounter_id,
       chemo.date_recorded AS date_more_than_3_cycles,
       MAX(chemo.cycle_number) OVER (
           PARTITION BY pc.encounter_id
       ) AS max_cycle_number,
       ROW_NUMBER() OVER (
           PARTITION BY pc.encounter_id
           ORDER BY chemo.date_recorded DESC, chemo.encounter_id DESC
       ) AS row
    FROM confirmed_mdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
     ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.confirmed_mdt_date
     AND chemo.cycle_number > 3
),
more_than_3_cycles AS (
    SELECT
       confirmed_mdt_encounter_id,
       date_more_than_3_cycles,
       max_cycle_number
    FROM more_than_3_cycles_candidates
    WHERE row = 1
),
more_than_3_cycles_surgery AS (
    SELECT
       m3c.confirmed_mdt_encounter_id,
       MIN(csr.date_of_surgery) AS date_surgery_after_more_than_3_cycles
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first pc
     ON pc.encounter_id = m3c.confirmed_mdt_encounter_id
    JOIN "19_cervical_surgical_report" csr
     ON csr.patient_id = pc.patient_id
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
        JOIN confirmed_mdt_first pc
          ON pc.encounter_id = c3s.confirmed_mdt_encounter_id
        JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
          ON chemo.patient_id = pc.patient_id
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
post_gt3_cycle_follow_up_mdt_candidates AS (
    SELECT
        c3pc.confirmed_mdt_encounter_id,
        fum.encounter_id AS response_mdt_encounter_id,
        fum.form_field_path AS response_mdt_form_field_path,
        fum.date_recorded AS response_mdt_date,
        fum.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY c3pc.confirmed_mdt_encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS row
    FROM post_gt3_cycle_chemo c3pc
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3pc.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
     AND fum.date_recorded > c3pc.last_post_surgery_chemo_date
     AND fum.treatment_type = 'Chemotherapy follow up'
),
post_gt3_cycle_follow_up_mdt AS (
    SELECT
        confirmed_mdt_encounter_id,
        response_mdt_encounter_id,
        response_mdt_form_field_path,
        response_mdt_date,
        chemotherapy_response
    FROM post_gt3_cycle_follow_up_mdt_candidates
    WHERE row = 1
),
post_gt3_cycle_subsequent_consultation_candidates AS (
    SELECT
        c3pc.confirmed_mdt_encounter_id,
        sc.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY c3pc.confirmed_mdt_encounter_id
            ORDER BY sc.date_recorded, sc.encounter_id
        ) AS row
    FROM post_gt3_cycle_chemo c3pc
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3pc.confirmed_mdt_encounter_id
    JOIN "07_subsequent_consultation" sc
      ON sc.patient_id = pc.patient_id
     AND sc.date_recorded > c3pc.last_post_surgery_chemo_date
     AND NULLIF(BTRIM(sc.chemotherapy_response), '') IS NOT NULL
),
post_gt3_cycle_subsequent_consultation AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemotherapy_response
    FROM post_gt3_cycle_subsequent_consultation_candidates
    WHERE row = 1
),
post_gt3_cycle_chemo_response AS (
    SELECT
        c3pc.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(BTRIM(mdt.chemotherapy_response), ''),
            NULLIF(BTRIM(sc.chemotherapy_response), '')
        ) AS chemotherapy_response,
        CASE
            WHEN NULLIF(BTRIM(mdt.chemotherapy_response), '') IS NOT NULL
            THEN mdt.response_mdt_encounter_id
        END AS response_mdt_encounter_id,
        CASE
            WHEN NULLIF(BTRIM(mdt.chemotherapy_response), '') IS NOT NULL
            THEN mdt.response_mdt_form_field_path
        END AS response_mdt_form_field_path,
        CASE
            WHEN NULLIF(BTRIM(mdt.chemotherapy_response), '') IS NOT NULL
            THEN mdt.response_mdt_date
        END AS response_mdt_date
    FROM post_gt3_cycle_chemo c3pc
    LEFT JOIN post_gt3_cycle_follow_up_mdt mdt
      ON mdt.confirmed_mdt_encounter_id = c3pc.confirmed_mdt_encounter_id
    LEFT JOIN post_gt3_cycle_subsequent_consultation sc
      ON sc.confirmed_mdt_encounter_id = c3pc.confirmed_mdt_encounter_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3pcr.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
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
    JOIN confirmed_mdt_first pc
     ON pc.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
     ON fum.patient_id = pc.patient_id
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
    JOIN confirmed_mdt_first pc
     ON pc.encounter_id = c3m.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
     ON pmp.encounter_id = c3m.cycle_3_post_surgery_mdt_encounter_id
     AND pmp.reference_form_field_path = c3m.cycle_3_post_surgery_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
     ON cr.patient_id = pc.patient_id
     AND cr.chemoradiotherapy_start_date > c3m.cycle_3_post_surgery_mdt_date
     AND cr.radiotherapy_outcome IN (
        'Completed without delay',
        'Completed with delay'
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3c.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3fum.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
     AND cr.chemoradiotherapy_start_date > c3fum.cycle_3_follow_up_mdt_date
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay'
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
cycle_3_subsequent_consultation_candidates AS (
    SELECT
        c3c.confirmed_mdt_encounter_id,
        sc.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY c3c.confirmed_mdt_encounter_id
            ORDER BY sc.date_recorded, sc.encounter_id
        ) AS row
    FROM cycle_3_chemotherapy c3c
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3c.confirmed_mdt_encounter_id
    JOIN "07_subsequent_consultation" sc
      ON sc.patient_id = pc.patient_id
     AND sc.date_recorded > c3c.cycle_3_chemotherapy_date
     AND NULLIF(BTRIM(sc.chemotherapy_response), '') IS NOT NULL
),
cycle_3_subsequent_consultation AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemotherapy_response
    FROM cycle_3_subsequent_consultation_candidates
    WHERE row = 1
),
cycle_3_chemo_response AS (
    SELECT
        c3c.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(BTRIM(mdt.chemotherapy_response), ''),
            NULLIF(BTRIM(sc.chemotherapy_response), '')
        ) AS chemotherapy_response
    FROM cycle_3_chemotherapy c3c
    LEFT JOIN cycle_3_follow_up_mdt mdt
      ON mdt.confirmed_mdt_encounter_id = c3c.confirmed_mdt_encounter_id
    LEFT JOIN cycle_3_subsequent_consultation sc
      ON sc.confirmed_mdt_encounter_id = c3c.confirmed_mdt_encounter_id
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
        pc.encounter_id AS confirmed_mdt_encounter_id,
        lnr.encounter_id AS biopsy_encounter_id,
        lnr.microbiology_date_of_result AS biopsy_date,
        lnr.ln_pos,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY lnr.microbiology_date_of_result, lnr.encounter_id
        ) AS row
    FROM confirmed_mdt_first pc
    JOIN upfront_surgery us
      ON us.confirmed_mdt_encounter_id = pc.encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = pc.patient_id
     AND lnr.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = us.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = pc.patient_id
     AND bcs.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = pc.patient_id
     AND lnr.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = c3s.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = pc.patient_id
     AND bcs.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN lymph_node_results lnr
      ON lnr.patient_id = pc.patient_id
     AND lnr.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN bacteriology_concept_set bcs
      ON bcs.patient_id = pc.patient_id
     AND bcs.patient_program_id = pc.patient_program_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3c.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
     AND fum.date_recorded > m3c.date_more_than_3_cycles
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3fum.confirmed_mdt_encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
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
more3c_subsequent_consultation_candidates AS (
    SELECT
        m3c.confirmed_mdt_encounter_id,
        sc.chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY m3c.confirmed_mdt_encounter_id
            ORDER BY sc.date_recorded, sc.encounter_id
        ) AS row
    FROM more_than_3_cycles m3c
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3c.confirmed_mdt_encounter_id
    JOIN "07_subsequent_consultation" sc
      ON sc.patient_id = pc.patient_id
     AND sc.date_recorded > m3c.date_more_than_3_cycles
     AND NULLIF(BTRIM(sc.chemotherapy_response), '') IS NOT NULL
),
more3c_subsequent_consultation AS (
    SELECT
        confirmed_mdt_encounter_id,
        chemotherapy_response
    FROM more3c_subsequent_consultation_candidates
    WHERE row = 1
),
more3c_chemo_response AS (
    SELECT
        m3c.confirmed_mdt_encounter_id,
        COALESCE(
            NULLIF(BTRIM(mdt.chemotherapy_response), ''),
            NULLIF(BTRIM(sc.chemotherapy_response), '')
        ) AS chemotherapy_response
    FROM more_than_3_cycles m3c
    LEFT JOIN more3c_follow_up_mdt mdt
      ON mdt.confirmed_mdt_encounter_id = m3c.confirmed_mdt_encounter_id
    LEFT JOIN more3c_subsequent_consultation sc
      ON sc.confirmed_mdt_encounter_id = m3c.confirmed_mdt_encounter_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3s.confirmed_mdt_encounter_id
    JOIN public."11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
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
    JOIN confirmed_mdt_first pc
      ON pc.encounter_id = m3m.confirmed_mdt_encounter_id
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = m3m.more3c_post_surgery_mdt_encounter_id
     AND pmp.reference_form_field_path = m3m.more3c_post_surgery_mdt_form_field_path
     AND pmp.proposed_management_plan = 'Radiation therapy'
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
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
    pc.patient_id,
    pc.encounter_id,
    pc.patient_program_id AS confirmed_mdt_first_patient_program_id,
    ppdd.program_outcome AS confirmed_mdt_first_program_outcome,
    pc.confirmed_mdt_date AS confirmed_mdt_first_date,
    pc.confirmed_malignancy_source AS confirmed_mdt_first_type,
    pc.cervix_figo AS figo_stage,

    us.date_upfront_surgery AS upfront_surgery,

    lnp.biopsy_encounter_id AS biopsy_encounter_id,
    lnp.biopsy_date AS biopsy_date,
    lnp.ln_pos AS "post_upfront_surgery_LN_post",
    push.margins AS post_upfront_surgery_margins,
    push.parameters AS post_upfront_surgery_parameters,
    pusm.post_upfront_surgery_mdt_date,
    pum.proposed_management_plan AS post_upfront_surgery_proposed_management,
    puscrt.chemoradiotherapy_start_date AS post_upfront_surgery_crt_start_date,
    puscrt.radiotherapy_outcome AS post_upfront_surgery_crt_outcome,

    c3c.cycle_3_chemotherapy_date AS "3C_chemo_date",
    c3c.cycle_3_chemotherapy_type AS "3C_chemo_type",
    c3r.chemotherapy_response AS "3C_chemo_response",
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
    m3r.chemotherapy_response AS "more3C_chemo_response",

    m3fum.more3c_follow_up_mdt_date AS "more3C_follow_up_mdt_date",
    m3fmp.proposed_management_plan AS "more3C_follow_up_mdt_proposed_management",
    CASE
        WHEN LOWER(m3fmp.proposed_management_plan) LIKE '%palliative care%' THEN 'Yes'
    END AS "more3C_follow_up_mdt_proposed_management_palliative",
    CASE
        WHEN LOWER(m3fmp.proposed_management_plan) LIKE '%radiation therapy%' THEN 'Yes'
    END AS "more3C_follow_up_mdt_proposed_management_CRT_referral",
    m3fcrt.chemoradiotherapy_start_date AS "more3C_follow_up_mdt_proposed_management_CRT_date",
    m3fcrt.radiotherapy_outcome AS "more3C_follow_up_mdt_proposed_management_CRT_outcome",

    m3m.more3c_post_surgery_mdt_date AS "more3C_after_surgery_mdt_date",
    m3pm.proposed_management_plan AS "more3C_after_surgery_proposed_management",
    m3pcrt.chemoradiotherapy_start_date AS "more3C_after_surgery_CRT_start_date",
    m3pcrt.radiotherapy_outcome AS "more3C_after_surgery_CRT_outcome"
FROM confirmed_mdt_first pc
LEFT JOIN patient_program_data_default ppdd
  ON ppdd.patient_program_id = pc.patient_program_id
LEFT JOIN upfront_surgery us
  ON us.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN post_upfront_surgery_mdt pusm
  ON pusm.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form pum
  ON pum.encounter_id = pusm.post_upfront_surgery_mdt_encounter_id
 AND pum.reference_form_field_path = pusm.post_upfront_surgery_mdt_form_field_path
LEFT JOIN post_upfront_surgery_crt puscrt
  ON puscrt.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_chemotherapy c3c
  ON c3c.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_surgery c3s
  ON c3s.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more_than_3_cycles_surgery m3s
  ON m3s.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more3c_ln_pos m3ln
  ON m3ln.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more3c_histology m3h
  ON m3h.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_post_surgery_chemo_cycles c3pc
  ON c3pc.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN post_gt3_cycle_chemo_response c3pcr
  ON c3pcr.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form c3pmp
  ON c3pmp.encounter_id = c3pcr.response_mdt_encounter_id
 AND c3pmp.reference_form_field_path = c3pcr.response_mdt_form_field_path
LEFT JOIN post_gt3_cycle_response_mdt_crt c3pcrt
  ON c3pcrt.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_post_surgery_mdt c3m
  ON c3m.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form c3pm
  ON c3pm.encounter_id = c3m.cycle_3_post_surgery_mdt_encounter_id
 AND c3pm.reference_form_field_path = c3m.cycle_3_post_surgery_mdt_form_field_path
LEFT JOIN cycle_3_post_surgery_crt c3crt
  ON c3crt.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_chemo_response c3r
  ON c3r.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_follow_up_mdt c3fum
  ON c3fum.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form c3fmp
  ON c3fmp.encounter_id = c3fum.cycle_3_follow_up_mdt_encounter_id
 AND c3fmp.reference_form_field_path = c3fum.cycle_3_follow_up_mdt_form_field_path
LEFT JOIN cycle_3_follow_up_mdt_crt c3fcrt
  ON c3fcrt.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN ln_pos_first lnp
  ON lnp.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN upfront_surgery_histology push
  ON push.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_ln_pos c3ln
  ON c3ln.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN cycle_3_histology c3h
  ON c3h.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more_than_3_cycles m3c
  ON m3c.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more3c_chemo_response m3r
  ON m3r.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more3c_follow_up_mdt m3fum
  ON m3fum.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form m3fmp
  ON m3fmp.encounter_id = m3fum.more3c_follow_up_mdt_encounter_id
 AND m3fmp.reference_form_field_path = m3fum.more3c_follow_up_mdt_form_field_path
LEFT JOIN more3c_follow_up_mdt_crt m3fcrt
  ON m3fcrt.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN more3c_post_surgery_mdt m3m
  ON m3m.confirmed_mdt_encounter_id = pc.encounter_id
LEFT JOIN proposed_management_by_form m3pm
  ON m3pm.encounter_id = m3m.more3c_post_surgery_mdt_encounter_id
 AND m3pm.reference_form_field_path = m3m.more3c_post_surgery_mdt_form_field_path
LEFT JOIN more3c_post_surgery_crt m3pcrt
  ON m3pcrt.confirmed_mdt_encounter_id = pc.encounter_id;