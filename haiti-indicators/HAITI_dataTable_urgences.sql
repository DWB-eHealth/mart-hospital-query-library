/*ABOUT
 * The visits data table is for counting the number of visits recorded in the EMR.
 * This query has been customized to only count 'Urgences' visit types.
 * Each row of the query represents a visit.
 
 * Variables: patient id, visit type, visit start date, visit end date, length of stay (days), age at visit (not yet available), sex, address fields
 * Possible indicators: count of visits (admissions or exits) by type, average length of stay
 * Possible disaggregation: age (not yet available), sex, address fields
 * Customization: address variables and address coulmn names (rows 24 & 25), visit type name (row 30)*/
 
SELECT
    pvdd.patient_id AS "patient id",
    pvdd.visit_type_name AS "visit type", 
    pvdd.visit_start_date AS "visit start date",
	pvdd.visit_end_date AS "visit end date",
/*Length of stay in days calculates the number of days between admission and discharge. Admission and discharge on the same day is counted as 1 day*/
	CASE
		WHEN pvdd.visit_end_date::date - pvdd.visit_start_date::date = 0 THEN 1
		ELSE pvdd.visit_end_date::date - pvdd.visit_start_date::date
	END AS "length of stay (days)",
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the start date of the visit*/
    /*(date_part('year', age(pvdd.visit_start_date, to_date((concat(piv.birthyear,'-01-01')), 'YYYY-MM-DD'))))::int AS "age at visit",*/
    piv.gender AS "sex",
/*The address variables (address1, address2, etc.) and address column names (region, commune, etc.) should be customized according to the address hierarchy used.*/
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM patient_visit_details_default AS pvdd
LEFT OUTER JOIN patient_information_view AS piv
    ON pvdd.patient_id = piv.patient_id
/*The visit_type_name can be specified to display only specified visit types.*/
WHERE pvdd.visit_type_name = 'Urgences'
ORDER BY pvdd.patient_id, pvdd.visit_start_date