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
		CASE WHEN cdcm.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_confirmed_malignancy,
		CASE WHEN cdcm.clinical_diagnosis IS NOT NULL AND iccmd.topography_of_the_tumour_confirmed IS NOT NULL THEN 'Cervix' WHEN cdcm.clinical_diagnosis IS NOT NULL AND iccmd.topography_of_the_tumour_confirmed IS NULL THEN 'Other topograpy' ELSE NULL END AS initial_confirmed_malignancy_topo,
		CASE WHEN cdsm.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_suspected_malignancy,
		CASE WHEN cdsm.clinical_diagnosis IS NOT NULL AND icsmd.topography_of_the_tumour_suspected IS NOT NULL THEN 'Cervix' WHEN cdsm.clinical_diagnosis IS NOT NULL AND icsmd.topography_of_the_tumour_suspected IS NULL THEN 'Other topograpy' ELSE NULL END AS initial_suspected_malignancy_topo,  
		CASE WHEN cdpl.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_precancerous_lesions,
		CASE WHEN cdaf.clinical_diagnosis IS NOT NULL THEN 'Yes' ELSE NULL END AS initial_abnormal_findings
	FROM "05_initial_consultation" ic 
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Confirmed malignancy') cdcm
		ON cdcm.encounter_id = ic.encounter_id AND cdcm.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT * FROM "05_initial_consultation_confirmed_malignancy_details" WHERE topography_of_the_tumour_confirmed = 'Cervix Uteri') iccmd 
		ON ic.encounter_id = iccmd.encounter_id
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Suspected malignancy') cdsm
		ON cdsm.encounter_id = ic.encounter_id AND cdsm.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT * FROM "05_initial_consultation_suspected_malignancy_details" WHERE topography_of_the_tumour_suspected = 'Cervix Uteri') icsmd 
		ON ic.encounter_id = icsmd.encounter_id
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Precancerous lesions') cdpl
		ON cdpl.encounter_id = ic.encounter_id AND cdpl.reference_form_field_path = ic.form_field_path 
	LEFT JOIN (SELECT * FROM clinical_diagnosis WHERE clinical_diagnosis = 'Abnormal findings') cdaf
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
		ROW_NUMBER() OVER (PARTITION BY sa.patient_id ORDER BY sa.date_recorded ASC) AS row
	FROM "15_social_assessment" sa
	LEFT JOIN subsequent_consultation_disclosure scd ON sa.patient_id = scd.patient_id AND sa.date_recorded::date >= scd.disclosure_date::date
	WHERE scd.row = 1),
last_visit AS (
	SELECT
		patient_id,
		date_recorded AS last_visit_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row
	FROM (SELECT patient_id, date_recorded FROM "07_subsequent_consultation" UNION SELECT patient_id, date_recorded FROM "12_supportive_care_assessment" UNION SELECT patient_id, appointment_start_time::date AS date_recorded FROM patient_appointment_default WHERE (appointment_status = 'Completed' OR appointment_status = 'CheckedIn') AND appointment_service IN ('Initial gynaecology consultation','Subsequent gynaecology consultation','Palliative Care','Subsequent disclosure visit')) foo),
program AS (
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
	--add custom age groups <18; 18-24; 25-49; and >49 years
	pdd.age_group AS age_group_at_enrollment,
	LOWER(pad.address4) AS ta_town,
	LOWER(pad.address3) AS district, 
	LOWER(pad.address2) AS region, 
	LOWER(pad.address1) AS country,
	rd.date_created::date AS enrollment_date,
	AGE(CURRENT_DATE, rd.date_created::date) AS time_since_enrollment,
	(DATE_PART('year', AGE(CURRENT_DATE, rd.date_created::date)))*12+DATE_PART('Month', AGE(CURRENT_DATE, rd.date_created::date)) AS months_since_enrollment,
	DATE_PART('year', AGE(CURRENT_DATE, rd.date_created::date)) AS years_since_enrollment,
	ph.reason_for_referral,
	ph.referral_facility,
	ph.referral_facility_name,
	ph.pregnancies,
	hpv_status,
	ph.smoker,
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
	ptmdt.premdt_precancerous_lesions, 
	ptmdt.premdt_abnormal_findings,
	ptmdt.premdt_agreed_figo,
	ptmdt.premdt_conservative_surgery,
	ptmdt.premdt_surgical_procedure,
	ptmdt.premdt_radiation_therapy,
	ptmdt.premdt_chemotherapy,
	ptmdt.premdt_palliative_care,
	ptmdt.premdt_other_mgmt_plan,
	scd.disclosure_date AS first_disclosure_date,
	sapd.mh_assesssment_date AS first_mh_assessment_date,
	fumdt.fumdt_date,
	fumdt.fumdt_chemotherapy_response,
	fumdt.fumdt_conservative_surgery,
	fumdt.fumdt_surgical_procedure,
	fumdt.fumdt_radiation_therapy,
	fumdt.fumdt_chemotherapy,
	fumdt.fumdt_palliative_care,
	fumdt.fumdt_other_mgmt_plan,
	CASE WHEN p.patient_outcome != 'Death' OR p.patient_outcome IS NULL THEN scs.sub_consultation_date ELSE NULL END AS last_sub_consul_with_status,
	CASE WHEN p.patient_outcome != 'Death' OR p.patient_outcome IS NULL THEN scs.sub_consultation_cancer_status ELSE NULL END AS last_cancer_status,
	lv.last_visit_date,
	CASE WHEN p.date_completed IS NULL THEN AGE(CURRENT_DATE, lv.last_visit_date::date) ELSE NULL END AS time_since_last_visit,
	CASE WHEN p.date_completed IS NULL THEN (DATE_PART('year', AGE(CURRENT_DATE, lv.last_visit_date::date)))*12+DATE_PART('Month', AGE(CURRENT_DATE, lv.last_visit_date::date)) ELSE NULL END AS months_since_last_visit,
	CASE WHEN p.date_completed IS NULL THEN (CURRENT_DATE-lv.last_visit_date::date) ELSE NULL END AS days_since_last_visit,
	p.patient_outcome,
	p.date_completed,
	p.date_of_death,
	AGE(p.date_completed, rd.date_created::date) AS length_of_follow,
	(DATE_PART('year', AGE(p.date_completed, rd.date_created::date)))*12+DATE_PART('Month', AGE(p.date_completed, rd.date_created::date)) AS months_of_follow,
	DATE_PART('year', AGE(p.date_completed, rd.date_created::date)) AS years_of_follow
FROM pre_treatment_mdt ptmdt
JOIN patient_identifier ptid ON ptmdt.patient_id = ptid.patient_id
JOIN registration_date rd ON ptmdt.patient_id = rd.patient_id
JOIN person_details_default pdd ON ptmdt.patient_id = pdd.person_id
JOIN person_address_default pad ON ptid.patient_id = pad.person_id
LEFT JOIN initial_consultation ic ON ptmdt.patient_id = ic.patient_id 
LEFT JOIN follow_up_mdt fumdt ON ptmdt.patient_id = fumdt.patient_id 
LEFT JOIN subsequent_consultation_status scs ON ptmdt.patient_id = scs.patient_id 
LEFT JOIN subsequent_consultation_disclosure scd ON ptmdt.patient_id = scd.patient_id
LEFT JOIN patient_history ph ON ptmdt.patient_id = ph.patient_id 
LEFT JOIN hiv_result hr ON ptmdt.patient_id = hr.patient_id 
LEFT JOIN social_assessment_edu sae ON ptmdt.patient_id = sae.patient_id 
LEFT JOIN social_assessment_post_disclosure sapd ON ptmdt.patient_id = sapd.patient_id
LEFT JOIN last_visit lv ON ptmdt.patient_id = lv.patient_id
LEFT JOIN program p ON ptmdt.patient_id = p.patient_id 
WHERE ptmdt.row = 1 AND (ic.row = 1 OR ic.row IS NULL) AND (fumdt.row = 1 OR fumdt.row IS NULL) AND (scs.row = 1 OR scs.row IS NULL) AND (ph.row = 1 OR ph.row IS NULL) AND (hr.row = 1 OR hr.row IS NULL) AND (sae.row = 1 OR sae.row IS NULL) AND (p.row = 1 OR p.row IS NULL) AND (lv.row = 1 OR lv.row IS NULL) AND (scd.row = 1 OR scd.row IS NULL) AND (sapd.row = 1 OR sapd.row IS NULL);