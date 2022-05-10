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
	ORDER BY po1.patient_id, po2.pre_op_start_date),
fsv_surgeon_cte AS (
  SELECT 
    DISTINCT on (fsv.patient_id) fsv.patient_id, 
    fsv.fstg_name_s_of_surgeon_1 
  FROM first_stage_validation fsv
  WHERE fsv.fstg_name_s_of_surgeon_1  IS NOT NULL  
  ORDER BY fsv.patient_id, fsv.obs_datetime DESC),
fv_surgeon_cte AS (
  SELECT 
    DISTINCT on (fv.patient_id) fv.patient_id, 
    fv.fv_name_s_of_surgeon_1 
  FROM fv_final_validation fv
  WHERE fv.fv_name_s_of_surgeon_1  IS NOT NULL  
  ORDER BY fv.patient_id, fv.obs_datetime DESC),
fuv_surgeon_cte AS (
  SELECT 
    DISTINCT on (fuv.patient_id) fuv.patient_id, 
    fuv.fup_name_s_of_surgeon_1 
  FROM follow_up_validation fuv 
  WHERE fuv.fup_name_s_of_surgeon_1  IS NOT NULL  
  ORDER BY fuv.patient_id, fuv.obs_datetime DESC)
SELECT 
	DISTINCT ON (ponw.patient_id, ponw.pre_op_start_date) 
	ponw.patient_id,
	CASE
		WHEN fuv.fup_name_s_of_surgeon_1 IS NOT NULL THEN fuv.fup_name_s_of_surgeon_1 
		WHEN fuv.fup_name_s_of_surgeon_1 IS NULL AND fv.fv_name_s_of_surgeon_1 IS NOT NULL THEN fv.fv_name_s_of_surgeon_1 
		WHEN fuv.fup_name_s_of_surgeon_1 IS NULL AND fv.fv_name_s_of_surgeon_1 IS NULL AND fsv.fstg_name_s_of_surgeon_1 IS NOT NULL THEN fsv.fstg_name_s_of_surgeon_1
		ELSE NULL 
	END AS name_of_surgeon,
	pdd.gender,
	ponw.pre_op_start_date,
	ponw.nwfu_date,
	DATE_PART('day',ponw.nwfu_date::timestamp-ponw.pre_op_start_date::timestamp) AS  los_days
FROM preop_nwfu_cte ponw
LEFT OUTER JOIN fsv_surgeon_cte fsv
	ON ponw.patient_id = fsv.patient_id 
LEFT OUTER JOIN fv_surgeon_cte fv
	ON ponw.patient_id = fv.patient_id
LEFT OUTER JOIN fuv_surgeon_cte fuv
	ON ponw.patient_id = fuv.patient_id
LEFT OUTER JOIN person_details_default pdd 
	ON ponw.patient_id = pdd.person_id 
WHERE ponw.nwfu_date IS NOT NULL 
ORDER BY ponw.patient_id, ponw.pre_op_start_date, ponw.nwfu_date