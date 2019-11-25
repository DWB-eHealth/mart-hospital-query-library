/*ABOUT
 * The admissions per service data table is for counting the number of admissions to and discharges from each inpatient department or service. 
 * Each row of the query represents the admission of a patient to a particular department or service. 
 * If a patient is admitted to multiple services during the visit, then there will be one row for each admission.
 
 * Variables: patient id, service, service admission date, service discharge date, length of stay (days), sex, address fields, age (not yet available)
 * Possible indicators: count of admissions by service, count of exits by service, average length of stay by service
 * Possible disaggregation: sex, address fields, age (not yet available)
 * Customization: address variables and address coulmn names (rows 25 & 26)*/

SELECT 
	DISTINCT ON (bmv.patient_id, bmv.date_started, bmv.location) bmv.patient_id AS "patient id",
	bmv.location AS "service",
	bmv.date_started::date AS "service admission date",
	bmv.date_stopped::date AS "service discharge date",
/*Length of stay in days calculates the number of days between admission and discharge. Admission and discharge on the same day is counted as 1 day.*/
	CASE
		WHEN bmv.date_stopped::date - bmv.date_started::date = 0 THEN 1
		ELSE bmv.date_stopped::date - bmv.date_started::date
	END AS "length of stay (days)",
/*Age calcuated in Metabase is an estimate using January 1st of the birthyear and the start date of the visit.*/
    /*(date_part('year', age(bmv.date_started, to_date((concat(piv.birthyear,'-01-01')), 'YYYY-MM-DD'))))::int AS "age at admission",*/
	piv.gender AS "sex",
/*The address variables (address1, address2, etc.) and address column names (region, commune, etc.) should be customized according to the address hierarchy used.*/
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM bed_management_view AS bmv
LEFT OUTER JOIN patient_information_view AS piv
    ON bmv.patient_id = piv.patient_id
ORDER BY bmv.patient_id, bmv.date_started