SELECT 
	DISTINCT ON (bmv.patient_id, bmv.date_started, bmv.location) bmv.patient_id AS "patient id",
	pi."Patient_Identifier",
	bmv.location AS "service",
	bmv.date_started::date AS "service admission date",
	bmv.date_stopped::date AS "service discharge date",
	CASE
		WHEN bmv.date_stopped::date - bmv.date_started::date = 0 THEN 1
		ELSE bmv.date_stopped::date - bmv.date_started::date
	END AS "length of stay (days)",
	piv.gender AS "sex",
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM bed_management_view AS bmv
LEFT OUTER JOIN patient_information_view AS piv
    ON bmv.patient_id = piv.patient_id
LEFT OUTER JOIN patient_identifier AS pi
    on bmv.patient_id = pi.patient_id
WHERE bmv.date_started::date >= '2019-12-01' and bmv.date_started::date < '2020-01-01'
ORDER BY bmv.patient_id, bmv.date_started
