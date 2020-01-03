WITH admission_date AS (
	SELECT
		DISTINCT ON (patient_id, visit_id) patient_id,
		visit_id,
		gender,
		age_at_bed_assignment,
		location, 
		bed_assigned_date AS admission_date
	FROM patient_bed_view
	WHERE location IS NOT NULL
	ORDER BY patient_id, visit_id, bed_assigned_date),
discharge_date AS (	
	SELECT
		DISTINCT ON (patient_id, visit_id) patient_id,
		visit_id,
		location, 
		bed_discharged_date AS discharge_date
	FROM patient_bed_view
	WHERE location IS NOT NULL
	ORDER BY patient_id, visit_id, discharge_date DESC)
SELECT
	ad.patient_id,
	pi."Patient_Identifier",
	ad.location	AS admission_location,
	ad.admission_date,
	ad.gender,
	ad.age_at_bed_assignment AS age_at_admission,
	piv.address4 AS "department", 
    piv.address3 AS "commune"
FROM admission_date AS ad 
LEFT OUTER JOIN patient_information_view AS piv
    ON ad.patient_id = piv.patient_id
LEFT OUTER JOIN patient_identifier AS pi
    on ad.patient_id = pi.patient_id
WHERE ad.admission_date::date >= '2019-12-01' and ad.admission_date::date < '2020-01-01'
ORDER BY ad.patient_id, ad.admission_date
