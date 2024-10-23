WITH pre_treatment_mdt AS (
	SELECT
		ptm.patient_id,
		ptm.encounter_id,
		ptm.patient_program_id,
		ptm.date_recorded AS premdt_date,
		ROW_NUMBER() OVER (PARTITION BY ptm.patient_id ORDER BY ptm.date_recorded) AS row,
		CASE WHEN cdcm.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_confirmed_malignancy,
		CASE WHEN cdcm.clinical_diagnosis IS NOT NULL AND ptmtt.topography_of_the_tumour IS NOT NULL THEN 'Cervix' WHEN cdcm.clinical_diagnosis IS NOT NULL AND ptmtt.topography_of_the_tumour IS NULL THEN 'Other topograpy' ELSE NULL END AS premdt_confirmed_malignancy_topo,
		CASE WHEN cdpl.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_precancerous_lesions,
		CASE WHEN cdaf.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_abnormal_findings,
		CASE WHEN ptmtt.topography_of_the_tumour IS NOT NULL THEN ptm.agreed_figo_staging_for_cancer_of_the_cervix ELSE NULL END AS premdt_agreed_figo,
		CASE WHEN pmpcs.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_conservative_surgery,
		CASE WHEN pmpsp.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_surgical_procedure,
		CASE WHEN pmprt.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_radiation_therapy,
		CASE WHEN pmpc.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_chemotherapy,
		CASE WHEN pmppc.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS premdt_palliative_care,
		CASE WHEN ptm.other_proposed_management_plan IS NOT NULL THEN  ptm.other_proposed_management_plan ELSE NULL END AS premdt_other_mgmt_plan
	FROM "10_pre_treatment_mdt" ptm
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Confirmed malignancy') cdcm
		ON cdcm.encounter_id = ptm.encounter_id AND cdcm.reference_form_field_path = ptm.form_field_path 
	LEFT JOIN (SELECT * FROM topography_of_the_tumour WHERE topography_of_the_tumour = 'Cervix Uteri') ptmtt 
		ON ptm.encounter_id = ptmtt.encounter_id
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Precancerous lesions') cdpl
		ON cdpl.encounter_id = ptm.encounter_id AND cdpl.reference_form_field_path = ptm.form_field_path 
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Abnormal findings') cdaf
		ON cdaf.encounter_id = ptm.encounter_id AND cdaf.reference_form_field_path = ptm.form_field_path
	LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Conservative surgery') pmpcs
		ON pmpcs.encounter_id = ptm.encounter_id AND pmpcs.reference_form_field_path = ptm.form_field_path
	LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Surgical procedure') pmpsp
		ON pmpsp.encounter_id = ptm.encounter_id AND pmpsp.reference_form_field_path = ptm.form_field_path
	LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Radiation therapy') pmprt
		ON pmprt.encounter_id = ptm.encounter_id AND pmprt.reference_form_field_path = ptm.form_field_path
	LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Chemotherapy') pmpc
		ON pmpc.encounter_id = ptm.encounter_id AND pmpc.reference_form_field_path = ptm.form_field_path    
	LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Palliative Care') pmppc
		ON pmppc.encounter_id = ptm.encounter_id AND pmppc.reference_form_field_path = ptm.form_field_path),
initial_consultation AS (
	SELECT
		ic.patient_id,
		ic.encounter_id,
		ic.patient_program_id,
		ic.date_recorded AS initial_consultation_date,
		ROW_NUMBER() OVER (PARTITION BY ic.patient_id ORDER BY ic.date_recorded) AS row,
		ic.ecog_performance_status AS initial_ecog_performance_status,
		CASE WHEN cdcm.diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_confirmed_malignancy,
		CASE WHEN cdcm.diagnosis IS NOT NULL AND iccmd.topography_of_the_tumour_confirmed IS NOT NULL THEN 'Cervix' WHEN cdcm.diagnosis IS NOT NULL AND iccmd.topography_of_the_tumour_confirmed IS NULL THEN 'Other topograpy' ELSE NULL END AS initial_confirmed_malignancy_topo,
		CASE WHEN cdsm.diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_suspected_malignancy,
		CASE WHEN cdsm.diagnosis IS NOT NULL AND icsmd.topography_of_the_tumour_suspected IS NOT NULL THEN 'Cervix' WHEN cdsm.diagnosis IS NOT NULL AND icsmd.topography_of_the_tumour_suspected IS NULL THEN 'Other topograpy' ELSE NULL END AS initial_suspected_malignancy_topo,  
		CASE WHEN cdpl.diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_precancerous_lesions,
		CASE WHEN cdaf.diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_abnormal_findings
	FROM "05_initial_consultation" ic 
	LEFT JOIN (SELECT patient_id, encounter_id, clinical_diagnosis AS diagnosis, reference_form_field_path FROM clinical_diagnosis WHERE clinical_diagnosis = 'Confirmed malignancy' UNION SELECT patient_id, encounter_id, diagnosis, reference_form_field_path FROM diagnosis WHERE diagnosis = 'Confirmed malignancy') cdcm
		ON cdcm.encounter_id = ic.encounter_id AND cdcm.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT * FROM "05_initial_consultation_confirmed_malignancy_details" WHERE topography_of_the_tumour_confirmed = 'Cervix Uteri') iccmd 
		ON ic.encounter_id = iccmd.encounter_id
	LEFT JOIN (SELECT patient_id, encounter_id, clinical_diagnosis AS diagnosis, reference_form_field_path FROM clinical_diagnosis WHERE clinical_diagnosis = 'Suspected malignancy' UNION SELECT patient_id, encounter_id, diagnosis, reference_form_field_path FROM diagnosis WHERE diagnosis = 'Suspected malignancy') cdsm
		ON cdsm.encounter_id = ic.encounter_id AND cdsm.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT * FROM "05_initial_consultation_suspected_malignancy_details" WHERE topography_of_the_tumour_suspected = 'Cervix Uteri') icsmd 
		ON ic.encounter_id = icsmd.encounter_id
	LEFT JOIN (SELECT patient_id, encounter_id, clinical_diagnosis AS diagnosis, reference_form_field_path FROM clinical_diagnosis WHERE clinical_diagnosis = 'Precancerous lesions' UNION SELECT patient_id, encounter_id, diagnosis, reference_form_field_path FROM diagnosis WHERE diagnosis = 'Precancerous lesions') cdpl
		ON cdpl.encounter_id = ic.encounter_id AND cdpl.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT patient_id, encounter_id, clinical_diagnosis AS diagnosis, reference_form_field_path FROM clinical_diagnosis WHERE clinical_diagnosis = 'Abnormal findings' UNION SELECT patient_id, encounter_id, diagnosis AS diagnosis, reference_form_field_path FROM diagnosis WHERE diagnosis = 'Abnormal findings') cdaf
		ON cdaf.encounter_id = ic.encounter_id AND cdaf.reference_form_field_path = ic.form_field_path),
follow_up_mdt AS (
SELECT
	fum.patient_id,
	fum.encounter_id,
	fum.patient_program_id,
	fum.date_recorded AS fumdt_date,
	ROW_NUMBER() OVER (PARTITION BY fum.patient_id ORDER BY fum.date_recorded DESC) AS row,
	chemotherapy_response AS fumdt_chemotherapy_response,
	CASE WHEN pmpcs.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS fumdt_conservative_surgery,
	CASE WHEN pmpsp.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS fumdt_surgical_procedure,
	CASE WHEN pmprt.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS fumdt_radiation_therapy,
	CASE WHEN pmpc.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS fumdt_chemotherapy,
	CASE WHEN pmppc.proposed_management_plan IS NOT NULL THEN 'Yes' ELSE NULL END AS fumdt_palliative_care,
	CASE WHEN fum.other_proposed_management_plan IS NOT NULL THEN  fum.other_proposed_management_plan ELSE null END AS fumdt_other_mgmt_plan
FROM "11_follow_up_mdt" fum
LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Conservative surgery') pmpcs
    ON pmpcs.encounter_id = fum.encounter_id AND pmpcs.reference_form_field_path = fum.form_field_path
LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Surgical procedure') pmpsp
    ON pmpsp.encounter_id = fum.encounter_id AND pmpsp.reference_form_field_path = fum.form_field_path
LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Radiation therapy') pmprt
    ON pmprt.encounter_id = fum.encounter_id AND pmprt.reference_form_field_path = fum.form_field_path
LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Chemotherapy') pmpc
    ON pmpc.encounter_id = fum.encounter_id AND pmpc.reference_form_field_path = fum.form_field_path    
LEFT JOIN (SELECT * FROM proposed_management_plan WHERE proposed_management_plan = 'Palliative Care') pmppc
    ON pmppc.encounter_id = fum.encounter_id AND pmppc.reference_form_field_path = fum.form_field_path),
subsequent_consultation_status AS (
	SELECT
		patient_id,
		encounter_id,
		patient_program_id,
		date_recorded AS sub_consultation_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row,
		cancer_disease_status AS sub_consultation_cancer_status
	FROM "07_subsequent_consultation" WHERE cancer_disease_status IS NOT NULL),
subsequent_consultation_disclosure AS (
	SELECT
		sc.patient_id, 
		sc.encounter_id, 
		sc.patient_program_id,
		sc.date_recorded AS disclosure_date,
		ROW_NUMBER() OVER (PARTITION BY sc.patient_id ORDER BY sc.date_recorded ASC) AS row
	FROM "reason_for_visit" sct
	LEFT JOIN "07_subsequent_consultation" sc ON sct.encounter_id = sc.encounter_id
	LEFT JOIN pre_treatment_mdt ptm ON sc.patient_id = ptm.patient_id AND sc.date_recorded::date >= ptm.premdt_date::date
	WHERE sct.reason_for_visit = 'Diagnosis Disclosure' AND ptm.row = 1),
patient_history AS (
	SELECT
		patient_id,
		encounter_id,
		patient_program_id,
		date_recorded AS ph_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row,
		reason_for_referral,
		referral_facility, 
		CASE WHEN msf_via_centre_name IS NOT NULL THEN msf_via_centre_name WHEN ngo_s_via_centre_name IS NOT NULL AND ngo_s_via_centre_name != 'Other' THEN ngo_s_via_centre_name WHEN ngo_s_via_centre_name IS NOT NULL AND ngo_s_via_centre_name = 'Other' THEN ngo_s_via_centre_name_other WHEN moh_health_facility_name IS NOT NULL AND moh_health_facility_name != 'Other' THEN moh_health_facility_name WHEN moh_health_facility_name IS NOT NULL AND moh_health_facility_name = 'Other' THEN moh_health_facility_name_other ELSE NULL END AS referral_facility_name,
		number_of_previous_pregnancies_including_current_if_applica AS pregnancies,
		hpv_status,
		smoker
	FROM "01_patient_history"),
vital_signs AS (
	SELECT
		patient_id,
		encounter_id,
		patient_program_id,
		date_time_recorded AS date_last_vitals,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_time_recorded DESC) AS row,
		bmi
	FROM "02_vital_signs"),
hiv_test AS (
		SELECT patient_id, encounter_id, patient_program_id, date_recorded, result_of_hiv_test AS hiv_test, on_antiretroviral_therapy, last_cd4_count AS cd4_count FROM "01_patient_history" WHERE result_of_hiv_test IS NOT NULL UNION
		SELECT patient_id, encounter_id, patient_program_id, date_recorded, hiv_test, null AS on_antiretroviral_therapy, cd4_count FROM "03_laboratory" WHERE hiv_test IS NOT NULL),
hiv_result AS (
	SELECT
		patient_id,
		encounter_id,
		patient_program_id,
		date_recorded,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row,
		hiv_test,
		on_antiretroviral_therapy,
		cd4_count
	FROM hiv_test),
social_assessment_edu AS (
	SELECT
		patient_id,
		encounter_id,
		patient_program_id,
		date_recorded,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row,
		patient_education_level
	FROM "15_social_assessment"
	WHERE patient_education_level IS NOT NULL),
social_assessment_post_disclosure AS (
	SELECT
		sa.patient_id,
		sa.encounter_id,
		sa.patient_program_id,
		sa.date_recorded AS mh_assesssment_date,
		ROW_NUMBER() OVER (PARTITION BY sa.patient_id ORDER BY sa.date_recorded) AS row
	FROM "15_social_assessment" sa
	LEFT JOIN subsequent_consultation_disclosure scd ON sa.patient_id = scd.patient_id AND sa.date_recorded::date >= scd.disclosure_date::date
	WHERE scd.row = 1),
last_visit AS (
	SELECT
		patient_id,
		date_recorded AS last_visit_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row
	FROM (SELECT patient_id, date_recorded FROM "05_initial_consultation" UNION SELECT patient_id, date_recorded FROM "07_subsequent_consultation" UNION SELECT patient_id, date_recorded FROM "10_pre_treatment_mdt" UNION SELECT patient_id, date_recorded FROM "11_follow_up_mdt" UNION 	SELECT patient_id, date_recorded FROM "12_supportive_care_assessment" UNION SELECT patient_id, appointment_start_time::date AS date_recorded FROM patient_appointment_default WHERE (appointment_status = 'Completed' OR appointment_status = 'CheckedIn') AND appointment_service IN ('Initial gynaecology consultation','Subsequent gynaecology consultation','Palliative Care','Subsequent disclosure visit')) foo),
last_appt_missed AS (
	SELECT patient_id, appointment_start_time::date, appointment_status
	FROM (SELECT patient_id, appointment_start_time, appointment_status, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY appointment_start_time DESC) as row
		FROM patient_appointment_default
		WHERE appointment_start_time::date < CURRENT_DATE) foo
	WHERE row = 1 AND appointment_status = 'Missed'),
last_appt_missed_clean AS (
	SELECT 
		patient_id, appointment_start_time, appointment_status
	FROM last_appt_missed lam
	WHERE NOT EXISTS (
    SELECT 1
    FROM (SELECT patient_id, date_recorded FROM "05_initial_consultation" UNION SELECT patient_id, date_recorded FROM "07_subsequent_consultation" UNION SELECT patient_id, date_recorded FROM "10_pre_treatment_mdt" UNION SELECT patient_id, date_recorded FROM "11_follow_up_mdt" UNION 	SELECT patient_id, date_recorded FROM "12_supportive_care_assessment") foo
    WHERE foo.patient_id = lam.patient_id AND foo.date_recorded > lam.appointment_start_time)),
next_appointment AS (
	SELECT
		patient_id, appointment_start_time,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY appointment_start_time) AS row
	FROM patient_appointment_default
	WHERE appointment_status = 'Scheduled' AND appointment_start_time > CURRENT_DATE),
first_surgery AS (
	SELECT patient_id, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_of_surgery) AS ROW
	FROM (SELECT patient_id, date_of_surgery FROM "19_cervical_surgical_report" UNION SELECT patient_id, date_of_surgery FROM "20_ovary_surgical_report" UNION SELECT patient_id, date_of_surgery FROM "21_vulva_surgical_report" UNION SELECT patient_id, date_recorded AS date_of_surgery FROM "09_leep_and_conization" WHERE conization_indication IS NOT NULL) foo),
leep_binary AS (
	SELECT patient_id, 'Yes' AS leep, date_recorded, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded) AS ROW
	FROM "09_leep_and_conization" 
	WHERE leep_indication IS NOT NULL),
radical_abdominal_hysterectomy AS (
	SELECT
    	pp.patient_id, 'Yes' AS radical_abdominal_hysterectomy, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed = 'Radical abdominal hysterectomy'),
total_abdominal_hysterectomy AS (
	SELECT
    	pp.patient_id, 'Yes' AS total_abdominal_hysterectomy, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed = 'Total abdominal hysterectomy'),
radical_vaginal_hysterectomy AS (
	SELECT
    	pp.patient_id, 'Yes' AS radical_vaginal_hysterectomy, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed = 'Radical vaginal hysterectomy'),
total_vaginal_hysterectomy AS (
	SELECT
    	pp.patient_id, 'Yes' AS total_vaginal_hysterectomy, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed = 'Total vaginal hysterectomy'),
exploratory_laparotomy AS (
	SELECT
    	pp.patient_id, 'Yes' AS exploratory_laparotomy, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed = 'Exploratory laparotomy'),
other_cervical_surgical_procedures AS (
	SELECT
    	pp.patient_id, 'Yes' AS other_cervical_surgical_procedures, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY pp.patient_id ORDER BY csr.date_of_surgery) AS ROW
	FROM procedure_performed pp
	JOIN "19_cervical_surgical_report" csr USING(encounter_id)
	WHERE pp.procedure_performed IN ('Bilateral salpingectomy', 'Radical trachelectomy', 'Pelvic lymphadenectomy', 'Lomboaortic lymphadenectomy', 'Left oophorectomy', 'Right oophorectomy', 'Bilateral oophorectomy', 'Lateral parametrium excision', 'Ventral parametrium excision', 'Dorsal parametrium excision', 'Wound Debridement', 'Delayed suture of wound', 'Peritoneal washing', 'Pelvic examination under anesthesia', 'Dilation and curettage', 'Drainage of abscess', 'Cauterization of wart', 'Left salpingectomy', 'Right salpingectomy', 'Total colpectomy', 'Partial colpectomy', 'Other')),
ovary_surgical_report AS (
	SELECT
    	patient_id, 'Yes' AS ovary_surgical_report, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_of_surgery) AS ROW
	FROM "20_ovary_surgical_report"),
vulva_surgical_report AS (
	SELECT
    	patient_id, 'Yes' AS vulva_surgical_report, date_of_surgery, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_of_surgery) AS ROW
	FROM "21_vulva_surgical_report"),
biopsy_taken AS (
	SELECT patient_id, 'Yes' AS biopsy, date_recorded, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded) AS ROW
	FROM (
		SELECT ppge.patient_id, ic.date_recorded, 'Yes' AS biopsy 
		FROM procedure_performed_gynaecological_exam ppge
		LEFT JOIN "05_initial_consultation" ic USING(encounter_id)
		WHERE procedure_performed_gynaecological_exam IN ('Biopsy of cervix', 'Biopsy')
		UNION
		SELECT ppge.patient_id, sc.date_recorded, 'Yes' AS biopsy 
		FROM procedure_performed_gynaecological_exam ppge
		LEFT JOIN "07_subsequent_consultation" sc USING(encounter_id)
		WHERE procedure_performed_gynaecological_exam IN ('Biopsy of cervix', 'Biopsy')
		UNION
		SELECT patient_id, date_recorded, 'Yes' AS biopsy
		FROM "08_colposcopy"
		WHERE biopsies_number_of_specimen_s_collected IS NOT NULL OR biopsies_number_of_specimen_s_collected > 0) foo),
program_first AS (
	SELECT 
		patient_id,
		CASE WHEN program_id = 1 THEN 'Oncogynae' WHEN program_id = 2 THEN 'Palliative Care' ELSE NULL END AS program_name,
		date_enrolled::date, 
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY patient_program_id) AS row 
	FROM patient_program_data_default 
	WHERE voided = 'false'),
program_open AS (
	SELECT 
		patient_id,
		CASE WHEN program_id = 1 THEN 'Oncogynae' WHEN program_id = 2 THEN 'Palliative Care' ELSE NULL END AS program_name,
		date_enrolled::date, 
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY patient_program_id) AS row 
	FROM patient_program_data_default 
	WHERE voided = 'false' AND date_completed IS NULL),
program_exit AS (
	SELECT 
		ppdd.patient_id, 
		CASE WHEN ppdd.program_id = 1 THEN 'Oncogynae' WHEN ppdd.program_id = 2 THEN 'Palliative Care' ELSE NULL END AS program_name,
		ppdd.date_enrolled::date, 
		ppdd.date_completed::date,
		ppdd.program_outcome AS patient_outcome,
		CASE WHEN bf.date_of_death IS NOT NULL THEN bf.date_of_death::date WHEN bf.date_of_death IS NULL AND ppdd.program_outcome = 'Death' THEN ppdd.date_completed::date ELSE NULL END AS date_of_death,
		ROW_NUMBER() OVER (PARTITION BY ppdd.patient_id ORDER BY ppdd.patient_program_id DESC) AS row
	FROM patient_program_data_default ppdd
	LEFT JOIN "14_bereavement_form" bf USING (patient_program_id)
	WHERE ppdd.patient_id NOT IN (SELECT patient_id FROM patient_program_data_default WHERE voided = 'false' AND date_completed IS NULL) AND voided = 'false')
-- MAIN QUERY
SELECT 
	ptid."Patient_Identifier",
	ptid.patient_id,
	pdd.age AS age_at_enrollment,
	CASE 
		WHEN pdd.age::int < 18 THEN '0-17'
		WHEN pdd.age::int >= 18 AND pdd.age::int <= 24 THEN '18-24'
		WHEN pdd.age::int >= 25 AND pdd.age::int <= 49 THEN '25-49'
		WHEN pdd.age::int >= 50 THEN '50+'
		ELSE NULL
	END AS age_group_at_enrollment,
	LOWER(pad.address4) AS ta_town,
	LOWER(pad.address3) AS district, 
	LOWER(pad.address2) AS region, 
	LOWER(pad.address1) AS country,
	rd.date_created::date AS registration_date,
	pf.date_enrolled AS enrollment_date,
	AGE(CURRENT_DATE, pf.date_enrolled) AS time_since_enrollment,
	(DATE_PART('year', AGE(CURRENT_DATE, pf.date_enrolled)))*12+DATE_PART('Month', AGE(CURRENT_DATE, pf.date_enrolled)) AS months_since_enrollment,
	DATE_PART('year', AGE(CURRENT_DATE, pf.date_enrolled)) AS years_since_enrollment,
	ph.reason_for_referral,
	ph.referral_facility,
	ph.referral_facility_name,
	ph.pregnancies,
	hpv_status,
	ph.smoker,
	vs.bmi,
	hr.hiv_test,
	hr.on_antiretroviral_therapy,
	hr.cd4_count,
	sae.patient_education_level,
	ic.initial_consultation_date,
	ic.initial_ecog_performance_status,
	ic.initial_confirmed_malignancy,
	ic.initial_confirmed_malignancy_topo,
	ic.initial_suspected_malignancy,
	ic.initial_suspected_malignancy_topo,
	ic.initial_precancerous_lesions,
	ic.initial_abnormal_findings,
	ptmdt.premdt_date,
	ptmdt.premdt_confirmed_malignancy,
	ptmdt.premdt_confirmed_malignancy_topo,
	ptmdt.premdt_agreed_figo,
	ptmdt.premdt_precancerous_lesions, 
	ptmdt.premdt_abnormal_findings,
	ptmdt.premdt_conservative_surgery,
	ptmdt.premdt_surgical_procedure,
	ptmdt.premdt_radiation_therapy,
	ptmdt.premdt_chemotherapy,
	ptmdt.premdt_palliative_care,
	ptmdt.premdt_other_mgmt_plan,
	fumdt.fumdt_date,
	fumdt.fumdt_chemotherapy_response,
	fumdt.fumdt_conservative_surgery,
	fumdt.fumdt_surgical_procedure,
	fumdt.fumdt_radiation_therapy,
	fumdt.fumdt_chemotherapy,
	fumdt.fumdt_palliative_care,
	fumdt.fumdt_other_mgmt_plan,
	scd.disclosure_date AS first_disclosure_date,
	sapd.mh_assesssment_date AS first_mh_assessment_date,
	CASE WHEN pe.patient_outcome != 'Death' OR pe.patient_outcome IS NULL THEN scs.sub_consultation_date ELSE NULL END AS date_cancer_status,
	CASE WHEN pe.patient_outcome != 'Death' OR pe.patient_outcome IS NULL THEN scs.sub_consultation_cancer_status ELSE NULL END AS last_cancer_status,
	lv.last_visit_date,
	CASE WHEN pe.date_completed IS NULL THEN AGE(CURRENT_DATE, lv.last_visit_date::date) ELSE NULL END AS time_since_last_visit,
	CASE WHEN pe.date_completed IS NULL THEN (CURRENT_DATE-lv.last_visit_date::date) ELSE NULL END AS days_since_last_visit,
	CASE WHEN pe.date_completed IS NULL THEN (DATE_PART('year', AGE(CURRENT_DATE, lv.last_visit_date::date)))*12+DATE_PART('Month', AGE(CURRENT_DATE, lv.last_visit_date::date)) ELSE NULL END AS months_since_last_visit,
	CASE WHEN pe.date_completed IS NULL AND lam.appointment_start_time::date <> lv.last_visit_date THEN lam.appointment_start_time ELSE NULL END AS lost_to_follow_up,
	CASE WHEN pe.date_completed IS NULL THEN na.appointment_start_time ELSE NULL END AS next_scheduled_appointment,
	fs.date_of_surgery AS first_surgery_date,
	rah.radical_abdominal_hysterectomy,
	tah.total_abdominal_hysterectomy,
	rvh.radical_vaginal_hysterectomy,
	tvh.total_vaginal_hysterectomy,
	el.exploratory_laparotomy,
	op.other_cervical_surgical_procedures,
	osr.ovary_surgical_report,
	vsr.vulva_surgical_report,
	lb.leep,
	bt.biopsy,
	CASE WHEN pe.program_name IS NOT NULL THEN pe.program_name WHEN po.program_name IS NOT NULL THEN po.program_name ELSE NULL END AS program_name,
	pe.patient_outcome,
	pe.date_completed,
	pe.date_of_death,
	AGE(pe.date_completed, rd.date_created::date) AS length_of_follow,
	(DATE_PART('year', AGE(pe.date_completed, rd.date_created::date)))*12+DATE_PART('Month', AGE(pe.date_completed, rd.date_created::date)) AS months_of_follow,
	DATE_PART('year', AGE(pe.date_completed, rd.date_created::date)) AS years_of_follow
FROM patient_identifier ptid
LEFT JOIN pre_treatment_mdt ptmdt ON ptid.patient_id = ptmdt.patient_id
JOIN registration_date rd ON ptid.patient_id = rd.patient_id
JOIN person_details_default pdd ON ptid.patient_id = pdd.person_id
JOIN person_address_default pad ON ptid.patient_id = pad.person_id
LEFT JOIN initial_consultation ic ON ptid.patient_id = ic.patient_id 
LEFT JOIN follow_up_mdt fumdt ON ptid.patient_id = fumdt.patient_id 
LEFT JOIN subsequent_consultation_status scs ON ptid.patient_id = scs.patient_id 
LEFT JOIN subsequent_consultation_disclosure scd ON ptid.patient_id = scd.patient_id
LEFT JOIN patient_history ph ON ptid.patient_id = ph.patient_id 
LEFT JOIN vital_signs vs ON ptid.patient_id = vs.patient_id
LEFT JOIN hiv_result hr ON ptid.patient_id = hr.patient_id 
LEFT JOIN social_assessment_edu sae ON ptid.patient_id = sae.patient_id 
LEFT JOIN social_assessment_post_disclosure sapd ON ptid.patient_id = sapd.patient_id
LEFT JOIN last_visit lv ON ptid.patient_id = lv.patient_id
LEFT JOIN last_appt_missed_clean lam ON ptid.patient_id = lam.patient_id
LEFT JOIN next_appointment na ON ptid.patient_id = na.patient_id
LEFT JOIN first_surgery fs ON ptid.patient_id = fs.patient_id
LEFT JOIN leep_binary lb ON ptid.patient_id = lb.patient_id
LEFT JOIN radical_abdominal_hysterectomy rah ON ptid.patient_id = rah.patient_id
LEFT JOIN total_abdominal_hysterectomy tah ON ptid.patient_id = tah.patient_id
LEFT JOIN radical_vaginal_hysterectomy rvh ON ptid.patient_id = rvh.patient_id
LEFT JOIN total_vaginal_hysterectomy tvh ON ptid.patient_id = tvh.patient_id
LEFT JOIN exploratory_laparotomy el ON ptid.patient_id = el.patient_id
LEFT JOIN other_cervical_surgical_procedures op ON ptid.patient_id = op.patient_id
LEFT JOIN ovary_surgical_report osr ON ptid.patient_id = osr.patient_id
LEFT JOIN vulva_surgical_report vsr ON ptid.patient_id = vsr.patient_id
LEFT JOIN biopsy_taken bt ON ptid.patient_id = bt.patient_id
LEFT JOIN program_first pf ON ptid.patient_id = pf.patient_id
LEFT JOIN program_open po ON ptid.patient_id = po.patient_id
LEFT JOIN program_exit pe ON ptid.patient_id = pe.patient_id 
WHERE (ptmdt.row = 1 OR ptmdt.row IS NULL) AND 
	(ic.row = 1 OR ic.row IS NULL) AND 
	(fumdt.row = 1 OR fumdt.row IS NULL) AND 
	(scs.row = 1 OR scs.row IS NULL) AND 
	(ph.row = 1 OR ph.row IS NULL) AND 
	(vs.row = 1 OR vs.row IS NULL) AND 
	(hr.row = 1 OR hr.row IS NULL) AND 
	(sae.row = 1 OR sae.row IS NULL) AND 
	(pe.row = 1 OR pe.row IS NULL) AND 
	(lv.row = 1 OR lv.row IS NULL) AND 
	(scd.row = 1 OR scd.row IS NULL) AND 
	(sapd.row = 1 OR sapd.row IS NULL) AND 
	(na.row = 1 OR na.row IS NULL) AND 
	(fs.row = 1 OR fs.row IS NULL) AND 
	(lb.row = 1 OR lb.row IS NULL) AND 
	(rah.row = 1 OR rah.row IS NULL ) AND 
	(tah.row = 1 OR tah.row IS NULL) AND 
	(rvh.row = 1 OR rvh.row IS NULL) AND 
	(tvh.row = 1 OR tvh.row IS NULL) AND 
	(el.row = 1 OR el.row IS NULL) AND 
	(op.row = 1 OR op.row IS NULL) AND 
	(osr.row = 1 OR osr.row IS NULL) AND 
	(vsr.row = 1 OR vsr.row IS NULL) AND 
	(bt.row = 1 OR bt.row IS NULL) AND 
	(pf.row = 1 OR pf.row IS NULL) AND
	(po.row = 1 OR po.row IS NULL);