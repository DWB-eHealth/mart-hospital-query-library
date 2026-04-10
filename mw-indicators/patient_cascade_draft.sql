WITH premdt_confirmed AS ( 
    SELECT
        ptm.patient_id,
        ptm.encounter_id,
        ptm.patient_program_id,
        ptm.date_recorded AS premdt_date,
        ROW_NUMBER() OVER (
            PARTITION BY ptm.patient_id
            ORDER BY ptm.date_recorded
        ) AS row,
        'Yes' AS premdt_confirmed_malignancy,
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
          AND cdcm.clinical_diagnosis = 'Confirmed malignancy')),
premdt_first AS (
    SELECT *
    FROM premdt_confirmed
    WHERE row = 1),
topography_dedup AS (
    SELECT DISTINCT
        encounter_id,
        topography_of_the_tumour
    FROM topography_of_the_tumour
    WHERE topography_of_the_tumour IN (
        'Cervix Uteri',
        'Corpus Uteri',
        'Ovary',
        'Vulva',
        'Vagina',
        'Other female genital organs')),
topography_list AS (
    SELECT
        encounter_id,
        STRING_AGG(
            topography_of_the_tumour,
            ', '
            ORDER BY topography_of_the_tumour
        ) AS topography_of_the_tumour_list
    FROM topography_dedup
    GROUP BY encounter_id),
surgical_procedure_flag AS (
    SELECT
        encounter_id,
        'Yes' AS surgical_procedure_proposed
    FROM proposed_management_plan
    WHERE proposed_management_plan = 'Surgical procedure'
    GROUP BY encounter_id),
radiation_therapy_flag AS (
    SELECT
        encounter_id,
        'Yes' AS radiation_therapy_proposed_post_upfront_surgery
    FROM proposed_management_plan
    WHERE proposed_management_plan = 'Radiation therapy'
    GROUP BY encounter_id),
next_fumdt_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        fumdt.encounter_id AS fumdt_encounter_id,
        fumdt.date_recorded AS date_next_fumdt,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY fumdt.date_recorded, fumdt.encounter_id
        ) AS rn
    FROM premdt_first pc
    JOIN "11_follow_up_mdt" fumdt
      ON fumdt.patient_id = pc.patient_id
     AND fumdt.date_recorded > pc.premdt_date),
next_fumdt AS (
    SELECT
        premdt_encounter_id,
        fumdt_encounter_id,
        date_next_fumdt
    FROM next_fumdt_candidates
    WHERE rn = 1),
upfront_surgery_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        csr.date_of_surgery AS date_upfront_cervical_surgery,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY csr.date_of_surgery
        ) AS rn
    FROM premdt_first pc
    JOIN "19_cervical_surgical_report" csr
      ON csr.patient_id = pc.patient_id
     AND csr.date_of_surgery > pc.premdt_date),
upfront_surgery AS (
    SELECT
        premdt_encounter_id,
        date_upfront_cervical_surgery
    FROM upfront_surgery_candidates
    WHERE rn = 1),
fumdt_post_surgery_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        fumdt.encounter_id AS post_surgery_fumdt_encounter_id,
        fumdt.date_recorded AS date_fumdt_post_upfront_surgery,
        fumdt.treatment_type,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY fumdt.date_recorded, fumdt.encounter_id
        ) AS rn
    FROM premdt_first pc
    JOIN upfront_surgery us
      ON us.premdt_encounter_id = pc.encounter_id
    JOIN "11_follow_up_mdt" fumdt
      ON fumdt.patient_id = pc.patient_id
     AND fumdt.date_recorded > us.date_upfront_cervical_surgery),
fumdt_post_surgery AS (
    SELECT
        premdt_encounter_id,
        post_surgery_fumdt_encounter_id,
        date_fumdt_post_upfront_surgery,
        treatment_type
    FROM fumdt_post_surgery_candidates
    WHERE rn = 1),
chemoradiation_post_surgery_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        cr.chemoradiotherapy_start_date,
        cr.radiotherapy_outcome,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY cr.chemoradiotherapy_start_date
        ) AS rn
    FROM premdt_first pc
    JOIN upfront_surgery us
      ON us.premdt_encounter_id = pc.encounter_id
    JOIN "31_chemoradiation" cr
      ON cr.patient_id = pc.patient_id
     AND cr.chemoradiotherapy_start_date > us.date_upfront_cervical_surgery
     AND cr.radiotherapy_outcome IN (
         'Completed without delay',
         'Completed with delay')),
chemoradiation_post_surgery AS (
    SELECT
        premdt_encounter_id,
        chemoradiotherapy_start_date,
        radiotherapy_outcome
    FROM chemoradiation_post_surgery_candidates
    WHERE rn = 1),
nac_3_cycles_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        chemo.date_recorded AS date_NAC_3_cycles,
        chemo.cycle_number,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY chemo.date_recorded, chemo.cycle_number
        ) AS rn
    FROM premdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.premdt_date
     AND chemo.type_of_chemotherapy = 'Neoadjuvant Chemotherapy (NAC)'
     AND chemo.cycle_number >= 3),
nac_3_cycles AS (
    SELECT
        premdt_encounter_id,
        date_NAC_3_cycles,
        cycle_number
    FROM nac_3_cycles_candidates
    WHERE rn = 1),
nact_response_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        fumdt.date_recorded AS date_NACT_response,
        fumdt.chemotherapy_response,
        fumdt.encounter_id AS source_encounter_id,
        1 AS source_priority
    FROM premdt_first pc
    JOIN nac_3_cycles nac
      ON nac.premdt_encounter_id = pc.encounter_id
    JOIN "11_follow_up_mdt" fumdt
      ON fumdt.patient_id = pc.patient_id
     AND fumdt.date_recorded > nac.date_NAC_3_cycles
     AND fumdt.treatment_type = 'Chemotherapy follow up'
    UNION ALL
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        sc.date_recorded AS date_NACT_response,
        sc.chemotherapy_response,
        sc.encounter_id AS source_encounter_id,
        2 AS source_priority
    FROM premdt_first pc
    JOIN nac_3_cycles nac
      ON nac.premdt_encounter_id = pc.encounter_id
    JOIN "07_subsequent_consultation" sc
      ON sc.patient_id = pc.patient_id
     AND sc.date_recorded > nac.date_NAC_3_cycles
     AND sc.chemotherapy_response = 'Completed'),
nact_response_ranked AS (
    SELECT
        premdt_encounter_id,
        date_NACT_response,
        chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY premdt_encounter_id
            ORDER BY date_NACT_response, source_priority, source_encounter_id
        ) AS rn
    FROM nact_response_candidates),
nact_response AS (
    SELECT
        premdt_encounter_id,
        date_NACT_response,
        chemotherapy_response
    FROM nact_response_ranked
    WHERE rn = 1)

/*Main query*/
SELECT
    pc.patient_id,
    pc.encounter_id,
    pc.patient_program_id,
    pc.premdt_date AS date_premdt_confirmed_malignancy,
    pc.premdt_confirmed_malignancy,
    tl.topography_of_the_tumour_list AS topography,
    pc.vulva_figo,
    pc.vagina_figo,
    pc.cervix_figo,
    pc.uterus_figo,
    pc.ovary_figo,
    spf.surgical_procedure_proposed,
    nf.date_next_fumdt,
    us.date_upfront_cervical_surgery,
    CASE
        WHEN us.date_upfront_cervical_surgery IS NOT NULL
         AND nf.date_next_fumdt IS NOT NULL
         AND us.date_upfront_cervical_surgery < nf.date_next_fumdt
        THEN 'Yes'
        ELSE NULL
    END AS surgery_before_next_fumdt,
    fps.date_fumdt_post_upfront_surgery,
    fps.treatment_type,
    rtf.radiation_therapy_proposed_post_upfront_surgery,
    crps.chemoradiotherapy_start_date,
    crps.radiotherapy_outcome,
    nac.date_NAC_3_cycles,
    nac.cycle_number,
    nr.date_NACT_response,
    nr.chemotherapy_response
FROM premdt_first pc
LEFT JOIN topography_list tl
    ON tl.encounter_id = pc.encounter_id
LEFT JOIN surgical_procedure_flag spf
    ON spf.encounter_id = pc.encounter_id
LEFT JOIN next_fumdt nf
    ON nf.premdt_encounter_id = pc.encounter_id
LEFT JOIN upfront_surgery us
    ON us.premdt_encounter_id = pc.encounter_id
LEFT JOIN fumdt_post_surgery fps
    ON fps.premdt_encounter_id = pc.encounter_id
LEFT JOIN radiation_therapy_flag rtf
    ON rtf.encounter_id = fps.post_surgery_fumdt_encounter_id
LEFT JOIN chemoradiation_post_surgery crps
    ON crps.premdt_encounter_id = pc.encounter_id
LEFT JOIN nac_3_cycles nac
    ON nac.premdt_encounter_id = pc.encounter_id
LEFT JOIN nact_response nr
    ON nr.premdt_encounter_id = pc.encounter_id;