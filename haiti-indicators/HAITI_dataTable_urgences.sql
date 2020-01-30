/*ABOUT
 * The visits data table is for counting the number of visits recorded in the EMR.
 * This query has been customized to only count 'Urgences' visit types.
 * Each row of the query represents an urgences visit.
 
 * Variables: patient id, visit type, visit start date, visit end date, age at visit, sex, address fields
 * Possible indicators: count of visits (admissions or exits) by type
 * Possible disaggregation: age, sex, address fields
 * Customization: address variables and address coulmn names (rows 24 & 25), visit type name (row 30)*/
 
SELECT
    pvdd.patient_id AS "patient id",
    pvdd.visit_type_name AS "visit type", 
    pvdd.visit_start_date AS "visit start date",
	pvdd.visit_end_date AS "visit end date",
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the start date of the visit.*/
	CASE
		WHEN pdd.birthyear IS NOT NULL THEN (date_part('year', age(pvdd.visit_start_date, to_date((concat(pdd.birthyear,'-01-01')), 'YYYY-MM-DD'))))::int
		ELSE NULL 
	END AS "age at visit",
    piv.gender AS "sex",
/*The address variables (address1, address2, etc.) and address column names (region, commune, etc.) should be customized according to the address hierarchy used.*/
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM patient_visit_details_default AS pvdd
LEFT OUTER JOIN patient_information_view AS piv
	ON pvdd.patient_id = piv.patient_id
LEFT OUTER JOIN person_details_default AS pdd
	ON pvdd.patient_id = pdd.person_id 
/*The visit_type_name can be specified to display only specified visit types.*/
WHERE pvdd.visit_type_name = 'Urgences'
ORDER BY pvdd.patient_id, pvdd.visit_start_date