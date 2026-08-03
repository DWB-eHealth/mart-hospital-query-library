/* =====================================================================
   PATIENT CASCADE BY FIGO STAGE
   One row = one patient, anchored on their FIRST Pre-MDT with a
   confirmed malignancy. Every downstream column is an event found on
   that patient's timeline AFTER the relevant anchor date.

   Cascade counts (indicators 1.x / 2.x / 3.x) are obtained by FILTERING
   this row-level output 

      ===================================================================== */

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
     AND csr.date_of_surgery > pc.premdt_date
    /* Optional refinement to make this TRULY "upfront" (no chemo first),
       per spec note "No chemotherapy form is completed before surgery":
     AND NOT EXISTS (
         SELECT 1 FROM "27_chemotherapy_clinical_assessment_and_treatment" ch
         WHERE ch.patient_id = pc.patient_id
           AND ch.date_recorded > pc.premdt_date
           AND ch.date_recorded < csr.date_of_surgery)                     */
    ),
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

/*
 * nact_response_candidates
 * Priority 1 : Follow Up MDT after cycle 3 with treatment_type = 'Chemotherapy follow up'
 *              AND a chemo response value filled in
 * Priority 2 : Subsequent Consultation after cycle 3 with a chemo response value filled in
 * Tie-breaking rules:
 *   - Earlier date wins
 *   - Same date -> source priority 1 (Follow Up MDT) wins over 2 (Subsequent Consultation)
 *   - Same date + same source -> LATEST encounter_id wins (most recent record of that day)
 */
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
     AND fumdt.chemotherapy_response IN (
         'Complete response',
         '>= 30 percentage partial response',
         '<= 30 percentage partial response',
         'Stable disease',
         'Progressive disease')
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
     AND sc.chemotherapy_response IN (
         'Complete response',
         '>= 30 percentage partial response',
         '<= 30 percentage partial response',
         'Stable disease',
         'Progressive disease')),
nact_response_ranked AS (
    SELECT
        premdt_encounter_id,
        date_NACT_response,
        chemotherapy_response,
        ROW_NUMBER() OVER (
            PARTITION BY premdt_encounter_id
            ORDER BY
                date_NACT_response,       -- earliest date first
                source_priority,          -- Follow Up MDT before Subsequent Consultation
                source_encounter_id DESC  -- same date + same source -> latest encounter wins
        ) AS rn
    FROM nact_response_candidates),
nact_response AS (
    SELECT
        premdt_encounter_id,
        date_NACT_response,
        chemotherapy_response
    FROM nact_response_ranked
    WHERE rn = 1),

palliative_after_nac3_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        fum.encounter_id AS palliative_encounter_id,
        fum.date_recorded AS date_palliative_referred,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY fum.date_recorded, fum.encounter_id
        ) AS rn
    FROM premdt_first pc
    JOIN nac_3_cycles nac
      ON nac.premdt_encounter_id = pc.encounter_id
    JOIN "11_follow_up_mdt" fum
      ON fum.patient_id = pc.patient_id
     AND fum.date_recorded > nac.date_NAC_3_cycles
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id = fum.encounter_id
     AND pmp.reference_form_field_path = fum.form_field_path
     AND pmp.proposed_management_plan = 'Palliative Care'),
palliative_after_nac3 AS (
    SELECT
        premdt_encounter_id,
        palliative_encounter_id,
        date_palliative_referred
    FROM palliative_after_nac3_candidates
    WHERE rn = 1),

/* =====================================================================
   ================  NEW ADDITIONS : indicators 2.x & 3.x  =============
   =====================================================================
   Everything below reuses four "event source" CTEs so the same logic
   isn't rewritten a dozen times, then a set of small "first event after
   anchor X" pickers. Each picker returns at most one row per patient.
   ===================================================================== */

/* ---- Shared event sources ------------------------------------------ */

/* Any chemotherapy-response assessment, from Follow-up MDT (priority 1)
   or Subsequent Consultation (priority 2). Same value list & tie-break
   philosophy as the existing nact_response logic above.                */
chemo_response_events AS (
    SELECT
        fumdt.patient_id,
        fumdt.date_recorded  AS response_date,
        fumdt.chemotherapy_response,
        fumdt.encounter_id   AS source_encounter_id,
        1                    AS source_priority
    FROM "11_follow_up_mdt" fumdt
    WHERE fumdt.treatment_type = 'Chemotherapy follow up'
      AND fumdt.chemotherapy_response IN (
          'Complete response',
          '>= 30 percentage partial response',
          '<= 30 percentage partial response',
          'Stable disease',
          'Progressive disease')
    UNION ALL
    SELECT
        sc.patient_id,
        sc.date_recorded     AS response_date,
        sc.chemotherapy_response,
        sc.encounter_id      AS source_encounter_id,
        2                    AS source_priority
    FROM "07_subsequent_consultation" sc
    WHERE sc.chemotherapy_response IN (
          'Complete response',
          '>= 30 percentage partial response',
          '<= 30 percentage partial response',
          'Stable disease',
          'Progressive disease')),

/* Follow-up MDT proposed-management events (used for palliative and
   CCRT/radiation referrals).                                           */
fumdt_mgmt_events AS (
    SELECT
        fum.patient_id,
        fum.date_recorded  AS event_date,
        fum.encounter_id   AS source_encounter_id,
        pmp.proposed_management_plan
    FROM "11_follow_up_mdt" fum
    JOIN proposed_management_plan pmp
      ON pmp.encounter_id             = fum.encounter_id
     AND pmp.reference_form_field_path = fum.form_field_path),

/* All cervical surgeries.                                              */
surgery_events AS (
    SELECT patient_id, date_of_surgery
    FROM "19_cervical_surgical_report"),

/* Chemoradiation actually delivered (completed with or without delay). */
chemoradiation_done_events AS (
    SELECT patient_id, chemoradiotherapy_start_date, radiotherapy_outcome
    FROM "31_chemoradiation"
    WHERE radiotherapy_outcome IN ('Completed without delay', 'Completed with delay')),

/* ---- Chemotherapy cycle anchors ------------------------------------ */

/* 2.6 : last NAC record with cycle_number > 3 (the "last cycle").      */
nac_more_than_3_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        chemo.date_recorded AS date_nac_last_cycle,
        chemo.cycle_number  AS nac_last_cycle_number,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY chemo.cycle_number DESC, chemo.date_recorded DESC
        ) AS rn
    FROM premdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.premdt_date
     AND chemo.type_of_chemotherapy = 'Neoadjuvant Chemotherapy (NAC)'
     AND chemo.cycle_number > 3),
nac_more_than_3 AS (
    SELECT premdt_encounter_id, date_nac_last_cycle, nac_last_cycle_number
    FROM nac_more_than_3_candidates WHERE rn = 1),

/* 3.1 : first Induction-chemo record reaching cycle_number >= 3.       */
ic_3_cycles_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        chemo.date_recorded AS date_ic_3_cycles,
        chemo.cycle_number  AS ic_cycle_number,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY chemo.date_recorded, chemo.cycle_number
        ) AS rn
    FROM premdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.premdt_date
     AND chemo.type_of_chemotherapy = 'Induction Chemotherapy'  -- <<< VERIFY exact concept string
     AND chemo.cycle_number >= 3),
ic_3_cycles AS (
    SELECT premdt_encounter_id, date_ic_3_cycles, ic_cycle_number
    FROM ic_3_cycles_candidates WHERE rn = 1),

/* 3.7 : last Induction-chemo record with cycle_number > 3.            */
ic_more_than_3_candidates AS (
    SELECT
        pc.encounter_id AS premdt_encounter_id,
        chemo.date_recorded AS date_ic_last_cycle,
        chemo.cycle_number  AS ic_last_cycle_number,
        ROW_NUMBER() OVER (
            PARTITION BY pc.encounter_id
            ORDER BY chemo.cycle_number DESC, chemo.date_recorded DESC
        ) AS rn
    FROM premdt_first pc
    JOIN "27_chemotherapy_clinical_assessment_and_treatment" chemo
      ON chemo.patient_id = pc.patient_id
     AND chemo.date_recorded > pc.premdt_date
     AND chemo.type_of_chemotherapy = 'Induction Chemotherapy'  -- <<< VERIFY exact concept string
     AND chemo.cycle_number > 3),
ic_more_than_3 AS (
    SELECT premdt_encounter_id, date_ic_last_cycle, ic_last_cycle_number
    FROM ic_more_than_3_candidates WHERE rn = 1),

/* ---- GROUP 2 pickers (Ib3 / IIa2 / IIb : NACT pathway) ------------- */

/* 2.3 : surgery after the 3rd NAC cycle.                               */
surgery_post_nac3 AS (
    SELECT premdt_encounter_id, date_of_surgery AS date_surgery_post_nac3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, s.date_of_surgery,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY s.date_of_surgery) AS rn
        FROM premdt_first pc
        JOIN nac_3_cycles a ON a.premdt_encounter_id = pc.encounter_id
        JOIN surgery_events s
          ON s.patient_id = pc.patient_id
         AND s.date_of_surgery > a.date_NAC_3_cycles
    ) t WHERE rn = 1),

/* 2.7 & 2.9 : first response after the last (>3) NAC cycle.            */
nac_gt3_response AS (
    SELECT premdt_encounter_id,
           response_date AS date_nact_response_after_gt3,
           chemotherapy_response
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               e.response_date, e.chemotherapy_response,
               ROW_NUMBER() OVER (
                   PARTITION BY pc.encounter_id
                   ORDER BY e.response_date, e.source_priority,
                            e.source_encounter_id DESC) AS rn
        FROM premdt_first pc
        JOIN nac_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemo_response_events e
          ON e.patient_id = pc.patient_id
         AND e.response_date > a.date_nac_last_cycle
    ) t WHERE rn = 1),

/* 2.8 : surgery after the last (>3) NAC cycle.                         */
surgery_post_nac_gt3 AS (
    SELECT premdt_encounter_id, date_of_surgery AS date_surgery_post_nac_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, s.date_of_surgery,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY s.date_of_surgery) AS rn
        FROM premdt_first pc
        JOIN nac_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN surgery_events s
          ON s.patient_id = pc.patient_id
         AND s.date_of_surgery > a.date_nac_last_cycle
    ) t WHERE rn = 1),

/* 2.10 : palliative referral after the last (>3) NAC cycle.           */
palliative_post_nac_gt3 AS (
    SELECT premdt_encounter_id, event_date AS date_palliative_post_nac_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN nac_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Palliative Care'
         AND m.event_date > a.date_nac_last_cycle
    ) t WHERE rn = 1),

/* 2.11 : CCRT (radiation) referral after the last (>3) NAC cycle.     */
ccrt_ref_post_nac_gt3 AS (
    SELECT premdt_encounter_id, event_date AS date_ccrt_referred_post_nac_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN nac_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Radiation therapy'
         AND m.event_date > a.date_nac_last_cycle
    ) t WHERE rn = 1),

/* 2.12 : CCRT delivered after the last (>3) NAC cycle.                */
ccrt_done_post_nac_gt3 AS (
    SELECT premdt_encounter_id,
           chemoradiotherapy_start_date AS date_ccrt_done_post_nac_gt3,
           radiotherapy_outcome         AS ccrt_outcome_post_nac_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               c.chemoradiotherapy_start_date, c.radiotherapy_outcome,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY c.chemoradiotherapy_start_date) AS rn
        FROM premdt_first pc
        JOIN nac_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemoradiation_done_events c
          ON c.patient_id = pc.patient_id
         AND c.chemoradiotherapy_start_date > a.date_nac_last_cycle
    ) t WHERE rn = 1),

/* ---- GROUP 3 pickers (IIIa / IIIb / IIIc : Induction pathway) ------ */

/* 3.2 & 3.5 : first response after the 3rd IC cycle.                   */
ic3_response AS (
    SELECT premdt_encounter_id,
           response_date AS date_ic_response,
           chemotherapy_response
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               e.response_date, e.chemotherapy_response,
               ROW_NUMBER() OVER (
                   PARTITION BY pc.encounter_id
                   ORDER BY e.response_date, e.source_priority,
                            e.source_encounter_id DESC) AS rn
        FROM premdt_first pc
        JOIN ic_3_cycles a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemo_response_events e
          ON e.patient_id = pc.patient_id
         AND e.response_date > a.date_ic_3_cycles
    ) t WHERE rn = 1),

/* 3.3 : CCRT referral after 3 IC.                                     */
ccrt_ref_post_ic3 AS (
    SELECT premdt_encounter_id, event_date AS date_ccrt_referred_post_ic3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN ic_3_cycles a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Radiation therapy'
         AND m.event_date > a.date_ic_3_cycles
    ) t WHERE rn = 1),

/* 3.4 : CCRT delivered after 3 IC.                                    */
ccrt_done_post_ic3 AS (
    SELECT premdt_encounter_id,
           chemoradiotherapy_start_date AS date_ccrt_done_post_ic3,
           radiotherapy_outcome         AS ccrt_outcome_post_ic3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               c.chemoradiotherapy_start_date, c.radiotherapy_outcome,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY c.chemoradiotherapy_start_date) AS rn
        FROM premdt_first pc
        JOIN ic_3_cycles a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemoradiation_done_events c
          ON c.patient_id = pc.patient_id
         AND c.chemoradiotherapy_start_date > a.date_ic_3_cycles
    ) t WHERE rn = 1),

/* 3.6 : palliative referral after 3 IC.                              */
palliative_post_ic3 AS (
    SELECT premdt_encounter_id, event_date AS date_palliative_post_ic3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN ic_3_cycles a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Palliative Care'
         AND m.event_date > a.date_ic_3_cycles
    ) t WHERE rn = 1),

/* 3.8 & 3.11 : first response after the last (>3) IC cycle.           */
ic_gt3_response AS (
    SELECT premdt_encounter_id,
           response_date AS date_ic_response_after_gt3,
           chemotherapy_response
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               e.response_date, e.chemotherapy_response,
               ROW_NUMBER() OVER (
                   PARTITION BY pc.encounter_id
                   ORDER BY e.response_date, e.source_priority,
                            e.source_encounter_id DESC) AS rn
        FROM premdt_first pc
        JOIN ic_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemo_response_events e
          ON e.patient_id = pc.patient_id
         AND e.response_date > a.date_ic_last_cycle
    ) t WHERE rn = 1),

/* 3.9 : CCRT referral after >3 IC.                                   */
ccrt_ref_post_ic_gt3 AS (
    SELECT premdt_encounter_id, event_date AS date_ccrt_referred_post_ic_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN ic_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Radiation therapy'
         AND m.event_date > a.date_ic_last_cycle
    ) t WHERE rn = 1),

/* 3.10 : CCRT delivered after >3 IC.                                 */
ccrt_done_post_ic_gt3 AS (
    SELECT premdt_encounter_id,
           chemoradiotherapy_start_date AS date_ccrt_done_post_ic_gt3,
           radiotherapy_outcome         AS ccrt_outcome_post_ic_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id,
               c.chemoradiotherapy_start_date, c.radiotherapy_outcome,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY c.chemoradiotherapy_start_date) AS rn
        FROM premdt_first pc
        JOIN ic_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN chemoradiation_done_events c
          ON c.patient_id = pc.patient_id
         AND c.chemoradiotherapy_start_date > a.date_ic_last_cycle
    ) t WHERE rn = 1),

/* 3.12 : palliative referral after >3 IC.                            */
palliative_post_ic_gt3 AS (
    SELECT premdt_encounter_id, event_date AS date_palliative_post_ic_gt3
    FROM (
        SELECT pc.encounter_id AS premdt_encounter_id, m.event_date,
               ROW_NUMBER() OVER (PARTITION BY pc.encounter_id
                                  ORDER BY m.event_date, m.source_encounter_id) AS rn
        FROM premdt_first pc
        JOIN ic_more_than_3 a ON a.premdt_encounter_id = pc.encounter_id
        JOIN fumdt_mgmt_events m
          ON m.patient_id = pc.patient_id
         AND m.proposed_management_plan = 'Palliative Care'
         AND m.event_date > a.date_ic_last_cycle
    ) t WHERE rn = 1)

/* =====================================================================
   MAIN QUERY  (one row per patient)
   ===================================================================== */
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

    /* FIGO grouping helper for the cervix cascade (verify stored strings) */
    CASE
        WHEN pc.cervix_figo IN ('IB1','IB2','IIA1')            THEN 'Group 1 (IB1/IB2/IIA1)'
        WHEN pc.cervix_figo IN ('IB3','IIA2','IIB')            THEN 'Group 2 (IB3/IIA2/IIB)'
        WHEN pc.cervix_figo IN ('IIIA','IIIB','IIIC1','IIIC2') THEN 'Group 3 (IIIA/IIIB/IIIC)'
        ELSE NULL
    END AS figo_group_cervix,  -- <<< VERIFY exact FIGO stage strings

    /* ---------- GROUP 1 : Ib1 / Ib2 / IIa1 (upfront surgery) --------- */
    spf.surgical_procedure_proposed,                        -- Pre-MDT proposed surgery
    nf.date_next_fumdt,
    us.date_upfront_cervical_surgery,                       -- 1.1
    CASE
        WHEN us.date_upfront_cervical_surgery IS NOT NULL
         AND nf.date_next_fumdt IS NOT NULL
         AND us.date_upfront_cervical_surgery < nf.date_next_fumdt
        THEN 'Yes' ELSE NULL
    END AS surgery_before_next_fumdt,
    fps.date_fumdt_post_upfront_surgery,
    fps.treatment_type,
    rtf.radiation_therapy_proposed_post_upfront_surgery,    -- 1.2
    crps.chemoradiotherapy_start_date,                      -- 1.3
    crps.radiotherapy_outcome,

    /* ---------- GROUP 2 : Ib3 / IIa2 / IIb (NACT) ------------------- */
    nac.date_NAC_3_cycles,                                  -- 2.1
    nac.cycle_number,
    nr.date_NACT_response,                                  -- 2.2 / 2.4 (date)
    nr.chemotherapy_response,                               -- 2.2 / 2.4 (value)
    CASE WHEN nr.chemotherapy_response IN
             ('Complete response','>= 30 percentage partial response','<= 30 percentage partial response')
         THEN 'Yes' END AS nac3_responded,                 -- 2.2
    CASE WHEN nr.chemotherapy_response IN
             ('Stable disease','Progressive disease')
         THEN 'Yes' END AS nac3_stable_or_progressed,      -- 2.4

    spn3.date_surgery_post_nac3,                            -- 2.3 (date)
    CASE WHEN spn3.date_surgery_post_nac3 IS NOT NULL THEN 'Yes' END
        AS surgery_done_post_nac3,                          -- 2.3

    pan.date_palliative_referred AS date_palliative_referred_after_NAC3,   -- 2.5 (date)
    CASE WHEN pan.date_palliative_referred IS NOT NULL THEN 'Yes' ELSE NULL END
        AS referred_to_palliative_after_NAC3,              -- 2.5
    CASE WHEN pan.date_palliative_referred IS NOT NULL THEN 1 ELSE 0 END
        AS palliative_referred_after_NAC3_count,

    nm3.date_nac_last_cycle,                                -- 2.6 (date)
    nm3.nac_last_cycle_number,                              -- 2.6 (last cycle number)
    CASE WHEN nm3.date_nac_last_cycle IS NOT NULL THEN 'Yes' END
        AS received_more_than_3_nac_cycles,                -- 2.6

    ngr.date_nact_response_after_gt3,                       -- 2.7 / 2.9 (date)
    ngr.chemotherapy_response AS chemotherapy_response_after_gt3_nac, -- 2.7 / 2.9 (value)
    CASE WHEN ngr.chemotherapy_response IN
             ('Complete response','>= 30 percentage partial response','<= 30 percentage partial response')
         THEN 'Yes' END AS nac_gt3_responded,              -- 2.7
    CASE WHEN ngr.chemotherapy_response IN
             ('Stable disease','Progressive disease')
         THEN 'Yes' END AS nac_gt3_stable_or_progressed,   -- 2.9

    spng.date_surgery_post_nac_gt3,                         -- 2.8 (date)
    CASE WHEN spng.date_surgery_post_nac_gt3 IS NOT NULL THEN 'Yes' END
        AS surgery_done_post_nac_gt3,                       -- 2.8

    ppng.date_palliative_post_nac_gt3,                      -- 2.10 (date)
    CASE WHEN ppng.date_palliative_post_nac_gt3 IS NOT NULL THEN 'Yes' END
        AS referred_to_palliative_after_nac_gt3,           -- 2.10

    crng.date_ccrt_referred_post_nac_gt3,                   -- 2.11 (date)
    CASE WHEN crng.date_ccrt_referred_post_nac_gt3 IS NOT NULL THEN 'Yes' END
        AS ccrt_referred_after_nac_gt3,                     -- 2.11

    cdng.date_ccrt_done_post_nac_gt3,                       -- 2.12 (date)
    cdng.ccrt_outcome_post_nac_gt3,                         -- 2.12 (outcome)
    CASE WHEN cdng.date_ccrt_done_post_nac_gt3 IS NOT NULL THEN 'Yes' END
        AS ccrt_done_after_nac_gt3,                         -- 2.12

    /* ---------- GROUP 3 : IIIa / IIIb / IIIc (Induction chemo) ------ */
    ic3.date_ic_3_cycles,                                   -- 3.1 (date)
    ic3.ic_cycle_number,                                    -- 3.1 (cycle number)
    CASE WHEN ic3.date_ic_3_cycles IS NOT NULL THEN 'Yes' END
        AS received_3_ic_cycles,                            -- 3.1

    ic3r.date_ic_response,                                  -- 3.2 / 3.5 (date)
    ic3r.chemotherapy_response AS chemotherapy_response_ic3, -- 3.2 / 3.5 (value)
    CASE WHEN ic3r.chemotherapy_response IN
             ('Complete response','>= 30 percentage partial response','<= 30 percentage partial response')
         THEN 'Yes' END AS ic3_responded,                  -- 3.2
    CASE WHEN ic3r.chemotherapy_response IN
             ('Stable disease','Progressive disease')
         THEN 'Yes' END AS ic3_stable_or_progressed,       -- 3.5

    cri3.date_ccrt_referred_post_ic3,                       -- 3.3 (date)
    CASE WHEN cri3.date_ccrt_referred_post_ic3 IS NOT NULL THEN 'Yes' END
        AS ccrt_referred_after_ic3,                        -- 3.3

    cdi3.date_ccrt_done_post_ic3,                           -- 3.4 (date)
    cdi3.ccrt_outcome_post_ic3,                             -- 3.4 (outcome)
    CASE WHEN cdi3.date_ccrt_done_post_ic3 IS NOT NULL THEN 'Yes' END
        AS ccrt_done_after_ic3,                            -- 3.4

    ppi3.date_palliative_post_ic3,                          -- 3.6 (date)
    CASE WHEN ppi3.date_palliative_post_ic3 IS NOT NULL THEN 'Yes' END
        AS referred_to_palliative_after_ic3,               -- 3.6

    im3.date_ic_last_cycle,                                 -- 3.7 (date)
    im3.ic_last_cycle_number,                               -- 3.7 (last cycle number)
    CASE WHEN im3.date_ic_last_cycle IS NOT NULL THEN 'Yes' END
        AS received_more_than_3_ic_cycles,                 -- 3.7

    igr.date_ic_response_after_gt3,                         -- 3.8 / 3.11 (date)
    igr.chemotherapy_response AS chemotherapy_response_after_gt3_ic, -- 3.8 / 3.11 (value)
    CASE WHEN igr.chemotherapy_response IN
             ('Complete response','>= 30 percentage partial response','<= 30 percentage partial response')
         THEN 'Yes' END AS ic_gt3_responded,               -- 3.8
    CASE WHEN igr.chemotherapy_response IN
             ('Stable disease','Progressive disease')
         THEN 'Yes' END AS ic_gt3_stable_or_progressed,    -- 3.11

    crig.date_ccrt_referred_post_ic_gt3,                    -- 3.9 (date)
    CASE WHEN crig.date_ccrt_referred_post_ic_gt3 IS NOT NULL THEN 'Yes' END
        AS ccrt_referred_after_ic_gt3,                     -- 3.9

    cdig.date_ccrt_done_post_ic_gt3,                        -- 3.10 (date)
    cdig.ccrt_outcome_post_ic_gt3,                          -- 3.10 (outcome)
    CASE WHEN cdig.date_ccrt_done_post_ic_gt3 IS NOT NULL THEN 'Yes' END
        AS ccrt_done_after_ic_gt3,                         -- 3.10

    ppig.date_palliative_post_ic_gt3,                       -- 3.12 (date)
    CASE WHEN ppig.date_palliative_post_ic_gt3 IS NOT NULL THEN 'Yes' END
        AS referred_to_palliative_after_ic_gt3             -- 3.12

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
    ON nr.premdt_encounter_id = pc.encounter_id
LEFT JOIN palliative_after_nac3 pan
    ON pan.premdt_encounter_id = pc.encounter_id
/* --- new joins --- */
LEFT JOIN surgery_post_nac3        spn3 ON spn3.premdt_encounter_id = pc.encounter_id
LEFT JOIN nac_more_than_3          nm3  ON nm3.premdt_encounter_id  = pc.encounter_id
LEFT JOIN nac_gt3_response         ngr  ON ngr.premdt_encounter_id  = pc.encounter_id
LEFT JOIN surgery_post_nac_gt3     spng ON spng.premdt_encounter_id = pc.encounter_id
LEFT JOIN palliative_post_nac_gt3  ppng ON ppng.premdt_encounter_id = pc.encounter_id
LEFT JOIN ccrt_ref_post_nac_gt3    crng ON crng.premdt_encounter_id = pc.encounter_id
LEFT JOIN ccrt_done_post_nac_gt3   cdng ON cdng.premdt_encounter_id = pc.encounter_id
LEFT JOIN ic_3_cycles              ic3  ON ic3.premdt_encounter_id  = pc.encounter_id
LEFT JOIN ic3_response             ic3r ON ic3r.premdt_encounter_id = pc.encounter_id
LEFT JOIN ccrt_ref_post_ic3        cri3 ON cri3.premdt_encounter_id = pc.encounter_id
LEFT JOIN ccrt_done_post_ic3       cdi3 ON cdi3.premdt_encounter_id = pc.encounter_id
LEFT JOIN palliative_post_ic3      ppi3 ON ppi3.premdt_encounter_id = pc.encounter_id
LEFT JOIN ic_more_than_3           im3  ON im3.premdt_encounter_id  = pc.encounter_id
LEFT JOIN ic_gt3_response          igr  ON igr.premdt_encounter_id  = pc.encounter_id
LEFT JOIN ccrt_ref_post_ic_gt3     crig ON crig.premdt_encounter_id = pc.encounter_id
LEFT JOIN ccrt_done_post_ic_gt3    cdig ON cdig.premdt_encounter_id = pc.encounter_id
LEFT JOIN palliative_post_ic_gt3   ppig ON ppig.premdt_encounter_id = pc.encounter_id;