/*ABOUT
 * The data verification for the visits data table should be used to verify data entered in the EMR with data entered in the hospital registers. 
 * This query has been customized to only count 'Urgences' visit types.
 * Each row of the query represents an urgences visit.
 
 * Variables: EMR id, patient id, visit type, visit start date, visit end date, length of stay (days), age at visit, sex, address fields
 * Customization: date range (row 36)*/
 
SELECT
	pi."Patient_Identifier" AS "EMR id",
	pvdd.patient_id AS "patient id",
	pvdd.visit_type_name AS "visit type", 
	pvdd.visit_start_date AS "visit start date",
	pvdd.visit_end_date AS "visit end date",
/*Length of stay in days calculates the number of days between admission and discharge. Admission and discharge on the same day is counted as 1 day.*/
	CASE
		WHEN pvdd.visit_end_date::date - pvdd.visit_start_date::date = 0 THEN 1
		ELSE pvdd.visit_end_date::date - pvdd.visit_start_date::date
	END AS "length of stay (days)",
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the start date of the visit.*/
	CASE
		WHEN pdd.birthyear IS NOT NULL THEN (date_part('year', age(pvdd.visit_start_date, to_date((concat(pdd.birthyear,'-01-01')), 'YYYY-MM-DD'))))::int
		ELSE NULL 
	END AS "age at visit",
	piv.gender AS "sex",
	piv.address4 AS "department", 
	piv.address3 AS "commune"
FROM patient_visit_details_default AS pvdd
LEFT OUTER JOIN patient_information_view AS piv
	ON pvdd.patient_id = piv.patient_id
LEFT OUTER JOIN person_details_default AS pdd
	ON pvdd.patient_id = pdd.person_id 
LEFT OUTER JOIN patient_identifier AS pi
	ON pvdd.patient_id = pi.patient_id
/*The date range specified below can be changed depending on which reporting period needs to be verified.*/
WHERE pvdd.visit_type_name = 'Urgences' and pvdd.visit_start_date::date >= '2020-01-01' and pvdd.visit_start_date::date < '2020-02-01'
ORDER BY pvdd.patient_id, pvdd.visit_start_date
