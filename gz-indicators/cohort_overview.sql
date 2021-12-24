WITH cte_first_consultation AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		location_name,
		source_of_initial_patient_referral,
		type_of_injury,
		admission_status,
		reason_of_rejection,
		out_of_criteria,
		patient_sent_to_another_actor,
		referral_location 
	FROM first_consultation fc
	ORDER BY patient_program_id, date_created DESC),
cte_initial_medical_assessment AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		type_of_injury,
		date_of_injury, 
		cause_of_injury, 
		cause_of_burn, 
		location_of_first_treatment, 
		total_tbsa 
	FROM initial_medical_assessment
	ORDER BY patient_program_id, date_created DESC)
SELECT 
	ppdd.patient_id,
	ppdd.patient_program_id,
	ppdd.age_during_enrollment,
	CASE 
		WHEN ppdd.age_during_enrollment::int <5 THEN '<5'
		WHEN ppdd.age_during_enrollment::int >=5 AND ppdd.age_during_enrollment::int <15 THEN '5-15'
		WHEN ppdd.age_during_enrollment::int >=15 AND ppdd.age_during_enrollment::int <45 THEN '15-45'
		WHEN ppdd.age_during_enrollment::int >=45 THEN '>45'
		ELSE NULL 
	END AS age_group_during_enrollment,
	pdd.gender,
	CASE 
		WHEN ppdd.program_id = 1 THEN 'Trauma'
		WHEN ppdd.program_id = 2 THEN 'Burn'
	END AS program_name,
	ppdd.date_enrolled,
	ppdd.date_completed,
	ppdd.program_outcome
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN person_details_default pdd 
	ON ppdd.patient_id = pdd.person_id
LEFT OUTER JOIN cte_first_consultation cfc 
	ON ppdd.patient_program_id = cfc.patient_program_id
LEFT OUTER JOIN cte_initial_medical_assessment cima 
	ON ppdd.patient_program_id = cima.patient_program_id
WHERE ppdd.voided = 'false'