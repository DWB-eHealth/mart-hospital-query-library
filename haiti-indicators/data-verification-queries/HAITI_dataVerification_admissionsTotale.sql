/*ABOUT
 * The data verification for total admissions should be used to verify data entered in the EMR with data entered in the hospital registers. 
 * Each row of the query represents the admission of a patient to the facility. 
 * If a patient is admitted to multiple times to the facility, then there will be one row for each admission.
 
 * Variables: EMR id, patient id, visit_id, age at admission, sex, address fields, admission location and date
 * Customization: date range (row 41)*/

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
	ORDER BY patient_id, visit_id, bed_assigned_date)
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
	ad.location	AS admission_location,
	ad.admission_date
FROM admission_date AS ad 
LEFT OUTER JOIN patient_information_view AS piv
    ON ad.patient_id = piv.patient_id
LEFT OUTER JOIN patient_identifier AS pi
    on ad.patient_id = pi.patient_id
/*The date range specified below can be changed depending on which reporting period needs to be verified.*/
WHERE ad.admission_date::date >= '2020-01-01' and ad.admission_date::date < '2020-02-01'
ORDER BY ad.patient_id, ad.admission_date
