WITH cte_cohort AS (
	SELECT 
		ppdd.patient_program_id,
		ppdd.date_enrolled,
		ppdd.date_completed,
		abs(ppdd.date_completed::date - ppdd.date_enrolled::date) AS los_days
	FROM patient_program_data_default ppdd 
	WHERE ppdd.voided = 'false' AND ppdd.program_id = 2 AND ppdd.date_completed IS NOT NULL AND ppdd.program_outcome != 'Rejected')
SELECT 
	DATE_TRUNC('Month', cc.date_completed) AS record_month,
	percentile_cont(0.5) WITHIN GROUP (ORDER BY cc.los_days) AS alos
FROM cte_cohort cc
GROUP BY DATE_TRUNC('Month', cc.date_completed)