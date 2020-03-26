/*ABOUT
 * The data verification for admissions per service should be used to verify data entered in the EMR with data entered in the hospital registers. 
 * Each row of the query represents the admission of a patient to a particular department or service. 
 * If a patient is admitted to multiple services during the visit, then there will be one row for each admission.
 
 * Variables: EMR id, patient id, service, service admission date, age at admission, sex, address fields
 * Customization: date range (row 31)*/

SELECT 
	DISTINCT ON (bmlv.patient_id, bmlv.start_date, bmlv.location) bmlv.patient_id AS "patient id",
	pi."Patient_Identifier" AS "EMR id",
	bmlv.location AS "service",
	bmlv.start_date::date AS "service admission date",
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the start date of the visit.*/
	CASE
		WHEN pdd.birthyear IS NOT NULL THEN (date_part('year', age(bmlv.start_date, to_date((concat(pdd.birthyear,'-01-01')), 'YYYY-MM-DD'))))::int
		ELSE NULL
	END AS "age at admission",
	piv.gender AS "sex",
/*The address variables (address1, address2, etc.) and address column names (region, commune, etc.) should be customized according to the address hierarchy used.*/
	piv.address4 AS "department", 
	piv.address3 AS "commune"
FROM bed_management_locations_view AS bmlv
LEFT OUTER JOIN patient_information_view AS piv
	ON bmlv.patient_id = piv.patient_id
LEFT OUTER JOIN person_details_default AS pdd
	ON bmlv.patient_id = pdd.person_id 
LEFT OUTER JOIN patient_identifier AS pi
	ON bmlv.patient_id = pi.patient_id
/*The date range specified below can be changed depending on which reporting period needs to be verified.*/	
WHERE bmlv.start_date::date >= '2020-01-01' and bmlv.start_date::date < '2020-02-01'
ORDER BY bmlv.patient_id, bmlv.start_date