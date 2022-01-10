SELECT 
	DISTINCT ON (ppdd.patient_id) ppdd.patient_id,
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
	ppdd.date_enrolled
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN person_details_default pdd 
	ON ppdd.patient_id = pdd.person_id
WHERE ppdd.voided = 'false'
ORDER BY patient_id, date_enrolled DESC 