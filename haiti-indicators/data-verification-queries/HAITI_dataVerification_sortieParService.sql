/*ABOUT
 * The data verification for discharges per service should be used to verify data entered in the EMR with data entered in the hospital registers. 
 * Each row of the query represents the admission of a patient to a particular department or service. 
 * If a patient is admitted to multiple services during the visit, then there will be one row for each admission.
 
 * Variables: patient id, service, service admission date, service discharge date, length of stay (days), age at admission, sex, address fields
 * Customization: date range (row 31)*/

SELECT 
	DISTINCT ON (bmlv.patient_id, bmlv.discharge_date, bmlv.location) bmlv.patient_id AS "patient id",
	pi."Patient_Identifier" AS "EMR id",
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
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM bed_management_locations_view AS bmlv
LEFT OUTER JOIN patient_information_view AS piv
    ON bmlv.patient_id = piv.patient_id
LEFT OUTER JOIN person_details_default AS pdd 
	ON bmlv.patient_id = pdd.person_id 
LEFT OUTER JOIN patient_identifier AS pi
    on bmlv.patient_id = pi.patient_id
/*The date range specified below can be changed depending on which reporting period needs to be verified.*/	
WHERE bmlv.discharge_date::date >= '2020-01-01' and bmlv.discharge_date::date < '2020-02-01' and bmlv.discharge_date != CURRENT_DATE
ORDER BY bmlv.discharge_date, bmlv.patient_id