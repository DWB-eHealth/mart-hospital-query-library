WITH cte_first_vs AS (
	SELECT
		DISTINCT ON (vs.patient_program_id) vs.patient_program_id ,
		vs.date_time_recorded::date AS first_vs_date,
		vs.bmi
	FROM '2_vital_signs' vs
	ORDER BY vs.patient_program_id, vs.date_time_recorded ASC),
	cte_latest_vs AS (
	SELECT
		DISTINCT ON (vs.patient_program_id) vs.patient_program_id ,
		vs.date_time_recorded::date AS first_vs_date,
		vs.bmi
	FROM '2_vital_signs' vs
	ORDER BY vs.patient_program_id, vs.date_time_recorded DESC)
SELECT 
	ppdd.patient_id,
	ppdd.age_during_enrollment,
	age_group(ppdd.date_enrolled, TO_DATE(CONCAT('01-01-', pdd.birthyear), 'dd-MM-yyyy')) AS age_group_during_enrollment,
	pad2.address1 AS country,
	pad2.address2 AS region,
	pad2.address3 AS district,
	ppdd.patient_program_id,
	CASE
		WHEN ppdd.program_id = 1 then 'Oncogynae'
		WHEN ppdd.program_id = 2 THEN 'Palliative Care'
		ELSE NULL
	END AS program_name,
	ppdd.date_enrolled,
	psd.state_name AS current_state,
	psd.start_date AS state_start_date,
	ph.referral_facility,
	CASE 
		WHEN ph.msf_via_centre_name IS NOT NULL THEN ph.msf_via_centre_name
		WHEN ph.ngo_s_via_centre_name IS NOT NULL THEN ph.ngo_s_via_centre_name
		WHEN ph.moh_health_facility_name IS NOT NULL THEN ph.moh_health_facility_name
		ELSE NULL
	END AS facility_name,
	ph.result_of_hiv_test,
	ph.on_antiretroviral_therapy,
	ph.current_antiretroviral_drugs_used,
	ph.last_cd4_count,
	CASE 
		WHEN ph.last_cd4_count < 200 THEN '<200'
		WHEN ph.last_cd4_count >= 200 THEN '>=200'
		ELSE NULL
	END AS cd4_categories,
	ph.last_viral_load,
	ph.hpv_status,
	ph.smoker,
	cfv.bmi AS first_bmi,
	CASE 
		WHEN cfv.bmi < 18.5 THEN '18.5 or less'
		WHEN cfv.bmi >= 18.5 AND cfv.bmi < 25 THEN '18.5-24.9'
		WHEN cfv.bmi >= 25 THEN '25 or more'
		ELSE NULL 
	END AS first_bmi_categories,
	clv.bmi AS latest_bmi,
	CASE 
		WHEN clv.bmi < 18.5 THEN '18.5 or less'
		WHEN clv.bmi >= 18.5 AND clv.bmi < 25 THEN '18.5-24.9'
		WHEN clv.bmi >= 25 THEN '25 or more'
		ELSE NULL
	END AS latest_bmi_categories,
	ppdd.date_completed,
	ppdd.program_outcome, 
	date_part('month', age(ppdd.date_completed::date,ppdd.date_enrolled::date)) AS length_of_follow_months
FROM patient_program_data_default ppdd
LEFT OUTER JOIN person_details_default pdd 
	ON ppdd.patient_id = pdd.person_id 
LEFT OUTER JOIN person_address_default pad2 
	ON ppdd.patient_id = pad2.person_id 
LEFT OUTER JOIN patient_state_default psd 
	ON ppdd.patient_program_id = psd.patient_program_id 
LEFT OUTER JOIN '1_patient_history' ph 
	ON ppdd.patient_program_id = ph.patient_program_id
LEFT OUTER JOIN cte_first_vs cfv 
	ON ppdd.patient_program_id = cfv.patient_program_id
LEFT OUTER JOIN cte_latest_vs clv
	ON ppdd.patient_program_id = clv.patient_program_id
WHERE ppdd.voided = 'false' AND psd.end_date IS NULL
