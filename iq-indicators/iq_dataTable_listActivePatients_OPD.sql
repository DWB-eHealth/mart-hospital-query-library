/*ABOUT
 * The list of active patients data table lists the start and end date of each patient visit and the patient id.*/

SELECT
	ime.patient_id,
	ime.date_of_admission::date AS visit_start_date,
	CASE
		WHEN opn.date_of_discharge NOTNULL THEN opn.date_of_discharge::date
		ELSE CURRENT_DATE
	END AS visit_end_date
FROM initial_medical_examination AS ime
LEFT OUTER JOIN opd_progress_note_md AS opn
	ON ime.visit_id = opn.visit_id
WHERE ime.date_of_admission IS NOT NULL AND ime.patient_admitted_to = 'OPD'
ORDER BY ime.date_of_admission::timestamp