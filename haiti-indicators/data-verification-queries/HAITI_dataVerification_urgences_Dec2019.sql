SELECT
    pi."Patient_Identifier",
	pvdd.patient_id AS "patient id",
    pvdd.visit_type_name AS "visit type", 
    pvdd.visit_start_date AS "visit start date",
	pvdd.visit_end_date AS "visit end date",
	CASE
		WHEN pvdd.visit_end_date::date - pvdd.visit_start_date::date = 0 THEN 1
		ELSE pvdd.visit_end_date::date - pvdd.visit_start_date::date
	END AS "length of stay (days)",
    piv.gender AS "sex",
    piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM patient_visit_details_default AS pvdd
LEFT OUTER JOIN patient_information_view AS piv
    ON pvdd.patient_id = piv.patient_id
LEFT OUTER JOIN patient_identifier AS pi
    on pvdd.patient_id = pi.patient_id
WHERE pvdd.visit_type_name = 'Urgences' and pvdd.visit_start_date::date >= '2019-12-01' and pvdd.visit_start_date::date < '2020-01-01'
ORDER BY pvdd.patient_id, pvdd.visit_start_date