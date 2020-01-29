/*ABOUT
 * The admissions per service data table is for counting the number of admissions to and discharges from each inpatient department or service. 
 * Each row of the query represents the admission of a patient to a particular department or service. 
 * If a patient is admitted to multiple services  during the visit, then there will be one row for each admission.
 
 * Variables: patient id, service, service admission date, service discharge date, length of stay (days), age at admission, sex, address fields
 * Possible indicators: count of admissions by service, count of exits by service, average length of stay by service
 * Possible disaggregation: age, sex, address fields
 * Customization: address variables and address column names (rows 25 & 26)*/

SELECT 
	DISTINCT ON (bmlv.patient_id, bmlv.start_date, bmlv.location) bmlv.patient_id AS "patient id",
	bmlv.location AS "service",
	bmlv.start_date::date AS "service admission date",
	CASE 
		WHEN bmlv.discharge_date = CURRENT_DATE THEN NULL 
		ELSE bmlv.discharge_date::date 
	END AS "service discharge date",
/*Length of stay in days calculates the number of days between admission and discharge. Admission and discharge on the same day is counted as 1 day.*/
	CASE
		WHEN bmlv.discharge_date = CURRENT_DATE THEN NULL
		ELSE (CASE 
			WHEN bmlv.discharge_date::date - bmlv.start_date::date = 0 THEN 1
			ELSE bmlv.discharge_date::date - bmlv.start_date::date
		END)
	END AS "length of stay (days)",
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
ORDER BY bmlv.patient_id, bmlv.start_date