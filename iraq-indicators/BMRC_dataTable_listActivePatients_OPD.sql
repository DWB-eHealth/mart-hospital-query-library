/*ABOUT
 * The list of active patients data table lists the start and end date of each patient visit and the patient id.*/

	WITH opd_admission AS (
		SELECT
			ime.*,
			pedd.visit_id
		FROM initial_medical_examination AS ime
		LEFT OUTER JOIN patient_encounter_details_default AS pedd
			ON ime.encounter_id = pedd.encounter_id
		WHERE ime.date_of_admission IS NOT NULL AND ime.patient_admitted_to = 'OPD'),
	opd_discharge AS (
		SELECT
			opn.*,
			pedd.visit_id
		FROM opd_progress_note_md AS opn
		LEFT OUTER JOIN patient_encounter_details_default AS pedd
			ON opn.encounter_id = pedd.encounter_id
		WHERE opn.date_of_discharge IS NOT NULL)
	SELECT
		oa.patient_id,
		oa.date_of_admission::date AS visit_start_date,
		CASE
			WHEN od.date_of_discharge NOTNULL THEN od.date_of_discharge::date
			ELSE CURRENT_DATE
		END AS visit_end_date
	FROM opd_admission AS oa
	LEFT OUTER JOIN opd_discharge AS od
		ON oa.visit_id = od.visit_id
	ORDER BY oa.date_of_admission::timestamp