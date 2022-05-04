with preop2_cte AS (
	select
	    patient_id, 
	    start_date AS pre_op_start_date, 
	    CONCAT(patient_id,ROW_NUMBER () OVER (PARTITION BY patient_id ORDER BY start_date)) AS po2_id,
	    1 AS one
	from patient_state_default
	where state = 11),
preop1_cte AS (
	select
	    patient_id, 
		pre_op_start_date,
	    po2_id::int+one AS po1_id
	from preop2_cte),
preop_nwfu_cte AS (
	SELECT
		po1.patient_id, 
		po1.pre_op_start_date, 
		CASE 
			WHEN po2.pre_op_start_date IS NOT NULL THEN nwfu.start_date
			WHEN po2.pre_op_start_date IS NULL THEN nwfu2.start_date
			ELSE null
		END AS nwfu_date
	FROM preop1_cte po1
	LEFT OUTER JOIN preop2_cte po2
		ON po1.po1_id = po2.po2_id::int
	LEFT OUTER JOIN (SELECT patient_id, start_date FROM patient_state_default WHERE state = 8) nwfu
		ON po1.patient_id = nwfu.patient_id 
		AND nwfu.start_date > po1.pre_op_start_date 
		AND nwfu.start_date < po2.pre_op_start_date
	LEFT OUTER JOIN (SELECT patient_id, start_date FROM patient_state_default WHERE state = 8) nwfu2
		ON po1.patient_id = nwfu2.patient_id 
		AND nwfu2.start_date > po1.pre_op_start_date 
		AND po2.pre_op_start_date IS null
	ORDER BY po1.patient_id, po2.pre_op_start_date)
SELECT 
	DISTINCT ON (ponw.patient_id, ponw.pre_op_start_date) 
	ponw.patient_id,
	ponw.pre_op_start_date,
	ponw.nwfu_date,
	DATE_PART('day',ponw.nwfu_date::timestamp-ponw.pre_op_start_date::timestamp)
FROM preop_nwfu_cte ponw
WHERE ponw.nwfu_date IS NOT NULL 
ORDER BY ponw.patient_id, ponw.pre_op_start_date, ponw.nwfu_date