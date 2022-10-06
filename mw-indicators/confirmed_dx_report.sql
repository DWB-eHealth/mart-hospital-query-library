/*
 * filter: program = oncogyn, not voided, not completed
 * to add:
 * 		filter for only confirmed diagnosis?
 * 		columns:
 * 			abnormal findings
 * 			pre-cancerous lesions 
 * 			confirm malignancy >>> y/v
 * 				topo vulva + FIOG
 * 				topo vagina + figo
 * 				topo cervix uteri + FIGO
 * 				corpus uteri + FIGO
 * 				ovary + FIGO
 * 				other
 * */
WITH last_subsequent_consultation AS (
	SELECT
		patient_program_id,
		MAX(date_recorded) AS last_subsequent_consultation_date
	FROM "7_subsequent_consultation" sc 
	GROUP BY patient_program_id 
),
current_treatment_phase AS (
	SELECT
		patient_program_id,
		state_name AS current_treatment_phase
	FROM patient_state_default
	WHERE program_id = 1 AND end_date IS NULL
),
last_ecog_sc AS (
	select
		patient_program_id,
		MAX(date_recorded) AS last_subsequent_consultation_date,
		ecog_performance_status
	FROM "7_subsequent_consultation"
	WHERE ecog_performance_status IS NOT NULL 
	GROUP BY patient_program_id , ecog_performance_status),
last_ecog_ic AS (
	select
		patient_program_id,
		MAX(date_recorded) AS last_subsequent_consultation_date,
		ecog_performance_status
	FROM "5_initial_consultation" 
	WHERE ecog_performance_status IS NOT NULL 
	GROUP BY patient_program_id , ecog_performance_status)
SELECT 
	ppdd.patient_id,
	CASE 
		WHEN ph.msf_via_centre_name IS NOT NULL THEN ph.msf_via_centre_name 
		WHEN ph.ngo_s_via_centre_name IS NOT NULL AND ph.ngo_s_via_centre_name != 'Other' THEN ph.ngo_s_via_centre_name 
		WHEN ph.ngo_s_via_centre_name_other IS NOT NULL THEN ph.ngo_s_via_centre_name_other 
		WHEN ph.moh_health_facility_name IS NOT NULL THEN ph.moh_health_facility_name 
		ELSE null
	END AS referral_facility_name,
	ph.reason_for_referral,
	ph.result_of_hiv_test,
	lsc.last_subsequent_consultation_date,
	ctp.current_treatment_phase,
	CASE 
		WHEN les.ecog_performance_status IS NOT NULL THEN les.ecog_performance_status
		WHEN les.ecog_performance_status IS NULL AND lei.ecog_performance_status IS NOT NULL THEN lei.ecog_performance_status
		ELSE NULL 
	END AS last_ecog
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN "1_patient_history" ph 
	ON ppdd.patient_program_id = ph.patient_program_id 
LEFT OUTER JOIN last_subsequent_consultation lsc
	ON ppdd.patient_program_id = lsc.patient_program_id
LEFT OUTER JOIN current_treatment_phase ctp
	ON ppdd.patient_program_id = ctp.patient_program_id
LEFT OUTER JOIN last_ecog_sc les 
	ON ppdd.patient_program_id = les.patient_program_id
LEFT OUTER JOIN last_ecog_ic lei
	ON ppdd.patient_program_id = lei.patient_program_id
WHERE ppdd.program_id = 1 AND ppdd.voided = 'false' AND ppdd.date_completed IS NULL