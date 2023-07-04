SELECT 
	CAST(pa.start_date_time AS DATE) as start_date,
	reg.patient_identifier,
	reg.patient_name_arabic,
	reg.patient_phone_number_1,
	reg.patient_phone_number_2,
	pn.value_numeric AS passengers,
	min(CAST(pa.start_date_time AS TIME)) as start_time,
	CASE 
		WHEN 3ds.appointment_service = '3D' THEN 'Yes'
		ELSE NULL
	END AS '3D',
	CASE 
		WHEN 3ds.appointment_service = 'Session under sedation' THEN 'Yes'
		ELSE NULL
	END AS 'Sedation',
	appser.name AS `appointment_service`,
	reg.area,
	reg.address_text,
	l.name AS `appointment_location`
FROM patient_appointment pa
INNER JOIN appointment_service appser 
	ON appser.appointment_service_id = pa.appointment_service_id AND pa.voided = FALSE AND appser.voided = FALSE
LEFT OUTER JOIN location l 
	ON l.location_id = pa.location_id AND l.retired = FALSE
LEFT OUTER JOIN (SELECT 
		o.person_id,
		o.encounter_id,
		max(o.obs_datetime),
		CASE
			WHEN o.value_coded = 325 OR o.value_coded = 360 THEN 1
			ELSE NULL
		END as transport	
	FROM obs o 
	WHERE o.concept_id = 674 OR o.concept_id = 303
	GROUP BY o.person_id) le
	ON le.person_id = pa.patient_id
LEFT OUTER JOIN (SELECT 
		o2.person_id,
		o2.encounter_id,
		o2.value_numeric 
	FROM obs o2 
	WHERE o2.concept_id = 414 OR o2.concept_id = 691) pn
	ON le.encounter_id = pn.encounter_id
LEFT OUTER JOIN (SELECT 
		pa.patient_id,
		pa.patient_appointment_id,
		CAST(pa.start_date_time AS DATE) as start_date,
		appser.name AS `appointment_service`
	FROM patient_appointment pa
	INNER JOIN appointment_service appser 
		ON appser.appointment_service_id = pa.appointment_service_id AND pa.voided = FALSE AND appser.voided = FALSE
	WHERE pa.STATUS != 'Cancelled' AND (appser.name = '3D' OR appser.name = 'Session under sedation')) 3ds
	ON 3ds.patient_id = pa.patient_id AND 3ds.start_date = CAST(pa.start_date_time AS DATE)
LEFT OUTER JOIN (SELECT 
		DISTINCT id.identifier as patient_identifier,
		id.patient_id,
	    concat_ws(' ', ppa.first_name, ppa.middle_name, ppa.last_name) as patient_name_arabic,
	    ppa.patient_phone_number_1,
	    ppa.patient_phone_number_2,
	    ad.city_village as area,
	    ad.address1 as address_text
	FROM patient_identifier id
	JOIN person p 
		ON p.person_id = id.patient_id AND p.voided IS FALSE
	JOIN(SELECT 
			person_id,
			group_concat(first_name) as first_name,
			group_concat(middle_name) as middle_name,
			group_concat(last_name) as last_name,
			group_concat(patient_phone_number_1) as patient_phone_number_1,
			group_concat(patient_phone_number_2) as patient_phone_number_2
		FROM((SELECT 
				pat.person_id,
				pat.value,
				CASE WHEN att.name = 'givenNameLocal' THEN value END as first_name,
				CASE WHEN att.name = 'middleNameLocal' THEN value END as middle_name,
				CASE WHEN att.name = 'familyNameLocal' THEN value END as last_name,
				CASE WHEN att.name = 'phoneNumber 1' THEN value END as patient_phone_number_1,
				CASE WHEN att.name = 'phoneNumber 2' THEN value END as patient_phone_number_2
			FROM person_attribute pat
	        JOIN person_attribute_type att
				ON pat.person_attribute_type_id = att.person_attribute_type_id
			WHERE voided=0) as person_attributes_with_name)
		GROUP BY person_id) as ppa
		ON ppa.person_id = id.patient_id
	JOIN person_address ad 
		ON ad.person_id = id.patient_id AND ad.voided IS FALSE
	WHERE id.identifier_type = (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = 'Patient Identifier') and id.voided = 0) reg
	ON reg.patient_id = pa.patient_id
WHERE pa.STATUS != 'Cancelled' AND le.transport = 1
GROUP BY pa.patient_id, CAST(pa.start_date_time AS DATE)
ORDER BY CAST(pa.start_date_time AS DATE) DESC, CAST(pa.start_date_time AS TIME) asc, l.name