WITH last_visit AS (
	SELECT
		patient_id,
		date_recorded AS last_visit_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY date_recorded DESC) AS row
	FROM (SELECT patient_id, date_recorded FROM "07_subsequent_consultation" UNION SELECT patient_id, date_recorded FROM "12_palliative_care_assessment" UNION SELECT patient_id, appointment_start_time::date AS date_recorded FROM patient_appointment_default WHERE appointment_status = 'Completed' OR appointment_status = 'CheckedIn') foo),
next_visit AS (
    SELECT
        patient_id,
		appointment_start_time::date AS next_visit_date,
		ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY appointment_start_time ASC) AS row
    FROM patient_appointment_default
    WHERE appointment_start_time > CURRENT_DATE),
program AS (
	SELECT 
		ppdd.patient_id, 
		ppdd.date_enrolled::date, 
		CASE WHEN ppdd.program_id = 1 THEN 'Oncogynae' WHEN ppdd.program_id = 2 THEN 'Palliative Care' ELSE NULL END AS program_name,
		ROW_NUMBER() OVER (PARTITION BY ppdd.patient_id ORDER BY ppdd.patient_program_id DESC) AS row
	FROM patient_program_data_default ppdd
	WHERE ppdd.date_completed IS NULL AND voided = 'false')
-- MAIN QUERY
SELECT 
	ptid."Patient_Identifier",
	p.*,
	lv.last_visit_date,
	nv.next_visit_date
FROM program p
JOIN patient_identifier ptid ON p.patient_id = ptid.patient_id
LEFT JOIN last_visit lv ON p.patient_id = lv.patient_id
LEFT JOIN next_visit nv ON p.patient_id = nv.patient_id
WHERE p.row = 1 AND (lv.row = 1 OR lv.row IS NULL) AND (nv.row = 1 OR nv.row IS NULL);