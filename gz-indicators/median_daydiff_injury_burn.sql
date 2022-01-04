WITH cte_initial_medical_assessment AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		date_of_injury
	FROM initial_medical_assessment
	ORDER BY patient_program_id, date_created DESC),
cte_cohort AS (
	SELECT 
		ppdd.patient_program_id,
		ppdd.date_enrolled,
		cima.date_of_injury, 
		abs(ppdd.date_enrolled::date - cima.date_of_injury::date) AS day_diff_injury_admission
	FROM patient_program_data_default ppdd 
	LEFT OUTER JOIN cte_initial_medical_assessment cima 
		ON ppdd.patient_program_id = cima.patient_program_id
	WHERE ppdd.voided = 'false' AND ppdd.program_id = 2)
SELECT 
	DATE_TRUNC('Month', cc.date_enrolled) AS record_month,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY cc.day_diff_injury_admission) AS daydiff_injury_admission
FROM cte_cohort cc
GROUP BY DATE_TRUNC('Month', cc.date_enrolled)