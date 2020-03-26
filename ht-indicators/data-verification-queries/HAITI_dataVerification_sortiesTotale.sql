/*ABOUT
 * The data verification for total discharges should be used to verify data entered in the EMR with data entered in the hospital registers. 
 * Each row of the query represents the discharge of a patient from the facility. 
 * If a patient is admitted/discharged to/from multiple times to the facility, then there will be one row for each.
 
 * Variables: EMR id, patient id, visit_id, age at admission, sex, address fields, admission location and date, discharge location and date, length of stay (days)
 * Customization: date range (row 60)*/

WITH admission_date AS (
	SELECT
		DISTINCT ON (patient_id, visit_id) patient_id,
		visit_id,
		gender,
		age_at_bed_assignment,
		birth_year, 
		location, 
		bed_assigned_date AS admission_date
	FROM patient_bed_view
	WHERE location IS NOT NULL
	ORDER BY patient_id, visit_id, bed_assigned_date),
discharge_date AS (	
	SELECT
		DISTINCT ON (patient_id, visit_id) patient_id,
		visit_id,
		location, 
		bed_discharged_date AS discharge_date
	FROM patient_bed_view
	WHERE location IS NOT NULL
	ORDER BY patient_id, visit_id, discharge_date DESC)
SELECT
	pi."Patient_Identifier" AS "EMR id",
	ad.patient_id,
	ad.visit_id,
	ad.gender,
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the date of first bed assignment.*/
	CASE 
		WHEN ad.birth_year IS NOT NULL THEN ad.age_at_bed_assignment 
		ELSE NULL 
	END AS age_at_admission,
	piv.address4 AS "department", 
	piv.address3 AS "commune",
	ad.location AS admission_location,
	ad.admission_date,
	dd.location AS discharge_location,
	dd.discharge_date,
/*Length of stay in days calculates the number of days between admission and discharge. Admission and discharge on the same day is counted as 1 day.*/
	CASE
		WHEN dd.discharge_date::date IS NULL THEN NULL 
		WHEN dd.discharge_date::date - ad.admission_date::date = 0 THEN 1
		ELSE dd.discharge_date::date - ad.admission_date::date
	END AS "length of stay (days)"
FROM admission_date AS ad 
LEFT OUTER JOIN discharge_date AS dd
	ON ad.patient_id = dd.patient_id AND ad.visit_id = dd.visit_id
LEFT OUTER JOIN patient_information_view AS piv
	ON ad.patient_id = piv.patient_id
LEFT OUTER JOIN patient_identifier AS pi
	ON ad.patient_id = pi.patient_id
/*The date range specified below can be changed depending on which reporting period needs to be verified.*/
WHERE dd.discharge_date::date >= '2020-01-01' and dd.discharge_date::date < '2020-02-01' AND dd.discharge_date IS NOT NULL
ORDER BY ad.patient_id, dd.discharge_date