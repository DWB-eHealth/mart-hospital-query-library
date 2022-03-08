WITH cte_next_appointment AS (
	SELECT
		DISTINCT ON (patient_id, appointment_service) patient_id,
		appointment_service, 
		appointment_start_time 
	FROM patient_appointment_default pad2 
	WHERE appointment_start_time > current_date 
	ORDER BY patient_id, appointment_service, appointment_start_time 
)
SELECT
	ppdd.patient_id,
	ppdd.patient_program_id,
	ppdd.program_id,
	ppdd.date_enrolled,
	CASE 
		WHEN cna.appointment_service = 'Physiotherapy' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_physiotherapy_appt,
	CASE 
		WHEN cna.appointment_service = 'OCT' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_oct_appt,
	CASE 
		WHEN cna.appointment_service = '3D' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_3D_appt,
	CASE 
		WHEN cna.appointment_service = 'Dressing' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_dressing_appt,
	CASE 
		WHEN cna.appointment_service = 'Counselling' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_counselling_appt,
	CASE 
		WHEN cna.appointment_service = 'Social Work' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_social_work_appt,
	CASE 
		WHEN cna.appointment_service = 'HP' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_hp_appt,
	CASE 
		WHEN cna.appointment_service = 'psychology' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_psychology_appt,
	CASE 
		WHEN cna.appointment_service = 'Medical' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_medical_appt,
	CASE 
		WHEN cna.appointment_service = 'Physio + Dressing' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_physio_dressing_appt,
	CASE 
		WHEN cna.appointment_service = 'Ortho consultation' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_ortho_appt,
	CASE 
		WHEN cna.appointment_service = 'ATB	Gaza Clinic' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_atb_appt,
	CASE 
		WHEN cna.appointment_service = 'OM consultation' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_om_appt,
	CASE 
		WHEN cna.appointment_service = 'Pain management' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_pain_mgmt_appt,
	CASE 
		WHEN cna.appointment_service = 'Plastic consultation' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_plastic_appt,
	CASE 
		WHEN cna.appointment_service = 'PHYSIO G' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_physio_g_appt,
	CASE 
		WHEN cna.appointment_service = 'Session under sedation' THEN cna.appointment_start_time 
		ELSE NULL
	END AS next_under_sedation_appt
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN cte_next_appointment cna 
	ON ppdd.patient_id = cna.patient_id 
WHERE ppdd.voided = 'false' AND ppdd.date_completed IS NULL