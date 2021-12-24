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
	CASE 
		WHEN pdd.gender = 'M' THEN 'Male'
		WHEN pdd.gender = 'F' THEN 'Female'
		ELSE NULL 
	END AS sex,
	CASE 
		WHEN ppdd.program_id = 1 THEN 'Trauma'
		WHEN ppdd.program_id = 2 THEN 'Burn'
	END AS program_name,
	ppdd.date_enrolled,
	ppdd.date_completed,
	ppdd.program_outcome,
	abs(ppdd.date_completed::date - ppdd.date_enrolled::date) AS los_days,
	cfc.location_name,
	cfc.source_of_initial_patient_referral,
	cfc.type_of_injury AS type_of_injury_fc,
	cfc.admission_status,
	cfc.reason_of_rejection,
	cfc.out_of_criteria,
	cfc.patient_sent_to_another_actor,
	cfc.referral_location,
	cima.type_of_injury AS type_of_injury_ima,
	cima.date_of_injury, 
	abs(ppdd.date_enrolled::date - cima.date_of_injury::date) AS day_diff_injury_admission,
	cima.cause_of_injury, 
	cima.cause_of_burn, 
	cima.location_of_first_treatment, 
	cima.total_tbsa, 
	CASE 
		WHEN cima.total_tbsa <10 THEN '0.1-9.9%'
		WHEN cima.total_tbsa >=10 AND cima.total_tbsa <20 THEN '10-19.9%'
		WHEN cima.total_tbsa >=20 AND cima.total_tbsa <30 THEN '20-29.9%'
		WHEN cima.total_tbsa >=30 AND cima.total_tbsa <40 THEN '30-39.9%'
		WHEN cima.total_tbsa >=40 AND cima.total_tbsa <50 THEN '40-49.9%'
		WHEN cima.total_tbsa >=50 AND cima.total_tbsa <60 THEN '50-59.9%'
		WHEN cima.total_tbsa >=60 AND cima.total_tbsa <70 THEN '60-69.9%'
		WHEN cima.total_tbsa >=70 AND cima.total_tbsa <80 THEN '70-79.9%'
		WHEN cima.total_tbsa >=80 AND cima.total_tbsa <90 THEN '80-89.9%'
		WHEN cima.total_tbsa >89.9 THEN '>=90%'
		ELSE NULL 
	END AS tbsa_categories
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN person_details_default pdd 
	ON ppdd.patient_id = pdd.person_id
LEFT OUTER JOIN cte_first_consultation cfc 
	ON ppdd.patient_program_id = cfc.patient_program_id
LEFT OUTER JOIN cte_initial_medical_assessment cima 
	ON ppdd.patient_program_id = cima.patient_program_id
WHERE ppdd.voided = 'false'