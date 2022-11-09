WITH last_subsequent_consultation AS (
	SELECT
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded
	FROM "7_subsequent_consultation" 
	ORDER BY patient_program_id, date_recorded DESC 
),
last_initial_consultation AS (
	SELECT
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded
	FROM "5_initial_consultation" 
	ORDER BY patient_program_id, date_recorded DESC 
),
last_pre_treatment_mdt AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded
	FROM "10_pre_treatment_mdt"
	ORDER BY patient_program_id, date_recorded DESC 
),
last_follow_up_mdt AS (
	SELECT 
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded
	FROM "11_follow_up_mdt" fum 
	ORDER BY patient_program_id, date_recorded DESC  
),
last_treatment_phase AS (
	SELECT
		DISTINCT ON (patient_program_id) patient_program_id,
		treatment_phase, 
		/*treatment_phase_other,*/
		date_recorded
	FROM "7_subsequent_consultation" 
	WHERE treatment_phase IS NOT NULL
	ORDER BY patient_program_id, date_recorded DESC  
),
last_ecog_sc AS (
	SELECT
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded,
		ecog_performance_status
	FROM "7_subsequent_consultation"
	WHERE ecog_performance_status IS NOT NULL 
	ORDER BY patient_program_id, date_recorded DESC
),
last_ecog_ic AS (
	SELECT
		DISTINCT ON (patient_program_id) patient_program_id,
		date_recorded,
		ecog_performance_status
	FROM "5_initial_consultation" 
	WHERE ecog_performance_status IS NOT NULL 
	ORDER BY patient_program_id, date_recorded DESC
),
last_abnormal_findings AS (
	SELECT 
		DISTINCT ON (cd.patient_program_id) cd.patient_program_id,
		cd.obs_datetime,
		CASE 
			WHEN ic.abnormal_findings IS NOT NULL AND ic.abnormal_findings != 'Other' THEN ic.abnormal_findings
			/*WHEN ic.abnormal_findings IS NOT NULL AND ic.abnormal_findings = 'Other' THEN ic.abnormal_findings_other*/
			WHEN sc.abnormal_findings IS NOT NULL AND sc.abnormal_findings != 'Other' THEN sc.abnormal_findings
			/*WHEN sc.abnormal_findings IS NOT NULL AND sc.abnormal_findings = 'Other' THEN sc.abnormal_findings_other*/
			WHEN af.abnormal_findings::text IS NOT NULL THEN af.abnormal_findings::text
			ELSE 'Not recorded'
		END abnormal_findings,
		CASE 
			WHEN ic.abnormal_findings IS NOT NULL THEN ic.date_recorded
			WHEN sc.abnormal_findings IS NOT NULL THEN sc.date_recorded
			WHEN af.abnormal_findings IS NOT NULL THEN ptm.date_recorded
			ELSE NULL
		END abnormal_findings_date
	FROM clinical_diagnosis cd 
	LEFT OUTER JOIN "5_initial_consultation" ic 
		ON cd.encounter_id = ic.encounter_id 
	LEFT OUTER JOIN "7_subsequent_consultation" sc 
		ON cd.encounter_id = sc.encounter_id 
	LEFT OUTER JOIN "10_pre_treatment_mdt" ptm 
		ON cd.encounter_id = ptm.encounter_id 
	LEFT OUTER JOIN (
			SELECT 
				encounter_id,
				ARRAY_AGG(abnormal_findings) as abnormal_findings
			FROM abnormal_findings
			GROUP BY encounter_id) af
		ON cd.encounter_id = af.encounter_id 
	WHERE clinical_diagnosis = 'Abnormal findings'
	ORDER BY cd.patient_program_id, cd.obs_datetime DESC
),
last_precancerous_lesion AS (
	SELECT 
		DISTINCT ON (cd.patient_program_id) cd.patient_program_id,
		cd.obs_datetime,
		CASE 
			WHEN ic.precancerous_lesions IS NOT NULL AND ic.precancerous_lesions != 'Other' THEN ic.precancerous_lesions
			WHEN ic.precancerous_lesions IS NOT NULL AND ic.precancerous_lesions = 'Other' THEN ic.precancerous_lesions_other
			WHEN sc.precancerous_lesions IS NOT NULL AND sc.precancerous_lesions != 'Other' THEN sc.precancerous_lesions
			WHEN sc.precancerous_lesions IS NOT NULL AND sc.precancerous_lesions = 'Other' THEN sc.precancerous_lesions_other
			WHEN pl.precancerous_lesions::text IS NOT NULL THEN pl.precancerous_lesions::text
			ELSE 'Not recorded'
		END precancerous_lesions,
		CASE 
			WHEN ic.precancerous_lesions IS NOT NULL THEN ic.date_recorded
			WHEN sc.precancerous_lesions IS NOT NULL THEN sc.date_recorded
			WHEN pl.precancerous_lesions IS NOT NULL THEN ptm.date_recorded
			ELSE NULL
		END precancerous_lesions_date
	FROM clinical_diagnosis cd 
	LEFT OUTER JOIN "5_initial_consultation" ic 
		ON cd.encounter_id = ic.encounter_id 
	LEFT OUTER JOIN "7_subsequent_consultation" sc 
		ON cd.encounter_id = sc.encounter_id 
	LEFT OUTER JOIN "10_pre_treatment_mdt" ptm 
		ON cd.encounter_id = ptm.encounter_id 
	LEFT OUTER JOIN (
			SELECT 
				encounter_id,
				ARRAY_AGG(precancerous_lesions) as precancerous_lesions
			FROM precancerous_lesions
			GROUP BY encounter_id) pl 
		ON cd.encounter_id = pl.encounter_id 
	WHERE cd.clinical_diagnosis = 'Precancerous lesions'
	ORDER BY cd.patient_program_id, cd.obs_datetime DESC
),
last_confirmed_malignancy AS (
	SELECT 
		DISTINCT ON (cd.patient_program_id) cd.patient_program_id,
		cd.obs_datetime,
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.clinical_figo_staging_for_cancer_of_the_vulva 
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.clinical_figo_staging_for_cancer_of_the_vulva 
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.agreed_figo_staging_for_cancer_of_the_vulva 
			ELSE NULL
		END AS confirmed_malignancy_vulva_figo,
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.clinical_figo_staging_for_cancer_of_the_vagina  
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.clinical_figo_staging_for_cancer_of_the_vagina 
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.agreed_figo_staging_for_cancer_of_the_vagina 
			ELSE NULL
		END AS confirmed_malignancy_vagina_figo,
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.clinical_figo_staging_for_cancer_of_the_cervix 
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.clinical_figo_staging_for_cancer_of_the_cervix  
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.agreed_figo_staging_for_cancer_of_the_cervix 
			ELSE NULL
		END AS confirmed_malignancy_cervix_uteri_figo,
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.clinical_figo_staging_for_cancer_of_the_uterus 
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.clinical_figo_staging_for_cancer_of_the_uterus 
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.agreed_figo_staging_for_cancer_of_the_uterus 
			ELSE NULL
		END AS confirmed_malignancy_corpus_uteri_figo,
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.clinical_figo_staging_for_cancer_of_the_ovary 
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.clinical_figo_staging_for_cancer_of_the_ovary 
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.agreed_figo_staging_for_cancer_of_the_ovary 
			ELSE NULL
		END AS confirmed_malignancy_ovary_figo,
		/*CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN iccmd.topography_of_tumour_confirmed_other_female_genital_organs 
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sccmd.topography_of_tumour_confirmed_other_female_genital_organs 
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN 'Confirm malignancy of other female genital organs'
			ELSE NULL
		END AS confirmed_malignancy_other_organ,*/
		CASE 
			WHEN cd.reference_form_field_path = '05 Initial Consultation' THEN ic.date_recorded
			WHEN cd.reference_form_field_path = '07 Subsequent Consultation' THEN sc.date_recorded
			WHEN cd.reference_form_field_path = '10 Pre Treatment MDT' THEN ptm.date_recorded
			ELSE NULL
		END confirmed_malignancy_date
	FROM clinical_diagnosis cd 
	LEFT OUTER JOIN "5_initial_consultation_confirmed_malignancy_details" iccmd 
		ON cd.encounter_id = iccmd.encounter_id 
	LEFT OUTER JOIN "7_subsequent_consultation_confirmed_malignancy_details" sccmd 
		ON cd.encounter_id = sccmd.encounter_id 
	LEFT OUTER JOIN "10_pre_treatment_mdt" ptm 
		ON cd.encounter_id = ptm.encounter_id 
	LEFT OUTER JOIN "5_initial_consultation" ic 
		ON cd.encounter_id = ic.encounter_id 
	LEFT OUTER JOIN "7_subsequent_consultation" sc 
		ON cd.encounter_id = sc.encounter_id 
	WHERE cd.clinical_diagnosis = 'Confirmed malignancy'
	ORDER BY cd.patient_program_id, cd.obs_datetime DESC
)
SELECT 
	pi."Patient_Identifier",
	ppdd.patient_program_id,
	ppdd.patient_id,
	ppdd.program_outcome,
	ph.referral_facility,
	CASE 
		WHEN ph.referral_facility = 'MSF VIA centre' AND ph.msf_via_centre_name IS NOT NULL THEN ph.msf_via_centre_name 
		WHEN ph.referral_facility = 'MSF VIA centre' AND ph.msf_via_centre_name IS NULL THEN 'MSF VIA centre name not recorded'
		WHEN ph.referral_facility = 'NGO%s VIA centre' AND ph.ngo_s_via_centre_name IS NOT NULL AND ph.ngo_s_via_centre_name != 'Other' THEN ph.ngo_s_via_centre_name 
		WHEN ph.referral_facility = 'NGO%s VIA centre' AND ph.ngo_s_via_centre_name = 'Other' AND ph.ngo_s_via_centre_name_other IS NOT NULL THEN ph.ngo_s_via_centre_name_other
		WHEN ph.referral_facility = 'NGO%s VIA centre' AND ph.ngo_s_via_centre_name = 'Other' AND ph.ngo_s_via_centre_name_other IS NULL THEN 'Other NGO VIA centre'
		WHEN ph.referral_facility = 'NGO%s VIA centre' AND ph.ngo_s_via_centre_name IS NULL THEN 'NGO VIA centre not recorded'
		WHEN ph.referral_facility = 'Other health facility' AND ph.moh_health_facility_name IS NOT NULL AND ph.moh_health_facility_name != 'Other' THEN ph.moh_health_facility_name 
		/*WHEN ph.referral_facility = 'Other health facility' AND ph.moh_health_facility_name = 'Other' AND ph.moh_health_facility_name is not null THEN ph.moh_health_facility_name_other
		WHEN ph.referral_facility = 'Other health facility' AND ph.moh_health_facility_name = 'Other' AND ph.moh_health_facility_name_other IS NULL THEN 'Other MOH VIA centre'*/
		WHEN ph.referral_facility = 'Other health facility' AND ph.moh_health_facility_name IS NULL THEN 'MOH VIA centre name not recorded'
		ELSE null
	END AS referral_facility_name,
	ph.reason_for_referral,
	ph.result_of_hiv_test,
	CASE 
		WHEN lsc.date_recorded IS NOT NULL THEN lsc.date_recorded
		WHEN lsc.date_recorded IS NULL THEN lic.date_recorded
		ELSE NULL
	END as last_consultation_date,
	CASE 
		WHEN lfum.date_recorded IS NOT NULL THEN lfum.date_recorded
		WHEN lfum.date_recorded IS NULL THEN lptm.date_recorded
		ELSE NULL
	END as last_mdt_date,
	CASE 
		WHEN DATE_PART('year', lsc.date_recorded) = DATE_PART('year', CURRENT_DATE) AND DATE_PART('month', lsc.date_recorded) = DATE_PART('month', CURRENT_DATE - INTERVAL '1 month') THEN 'Yes'
		WHEN DATE_PART('year', lic.date_recorded) = DATE_PART('year', CURRENT_DATE) AND DATE_PART('month', lic.date_recorded) = DATE_PART('month', CURRENT_DATE - INTERVAL '1 month') THEN 'Yes'
		WHEN DATE_PART('year', lfum.date_recorded) = DATE_PART('year', CURRENT_DATE) AND DATE_PART('month', lfum.date_recorded) = DATE_PART('month', CURRENT_DATE - INTERVAL '1 month') THEN 'Yes'
		WHEN DATE_PART('year', lptm.date_recorded) = DATE_PART('year', CURRENT_DATE) AND DATE_PART('month', lptm.date_recorded) = DATE_PART('month', CURRENT_DATE - INTERVAL '1 month') THEN 'Yes'
		ELSE NULL
	END AS seen_last_month,
	CASE 
		WHEN ltp.treatment_phase IS NOT NULL AND ltp.treatment_phase != 'Other' THEN ltp.treatment_phase
		/*WHEN ltp.treatment_phase IS NOT NULL AND ltp.treatment_phase = 'Other' THEN ltp.treatment_phase_other*/
		ELSE 'Not recorded'
	END AS treatment_phase,
	CASE 
		WHEN les.ecog_performance_status IS NOT NULL THEN les.date_recorded
		WHEN les.ecog_performance_status IS NULL AND lei.ecog_performance_status IS NOT NULL THEN lei.date_recorded
		ELSE NULL
	END as last_ecog_date,
	CASE 
		WHEN les.ecog_performance_status IS NOT NULL THEN les.ecog_performance_status
		WHEN les.ecog_performance_status IS NULL AND lei.ecog_performance_status IS NOT NULL THEN lei.ecog_performance_status
		ELSE NULL 
	END AS last_ecog,
	laf.abnormal_findings_date,
	laf.abnormal_findings,
	lpl.precancerous_lesions_date,
	lpl.precancerous_lesions,
	lcm.confirmed_malignancy_date,
	lcm.confirmed_malignancy_vulva_figo,
	lcm.confirmed_malignancy_vagina_figo,
	lcm.confirmed_malignancy_cervix_uteri_figo,
	lcm.confirmed_malignancy_corpus_uteri_figo,
	lcm.confirmed_malignancy_ovary_figo/*,
	lcm.confirmed_malignancy_other_organ*/
FROM patient_program_data_default ppdd 
LEFT OUTER JOIN patient_identifier pi
	ON ppdd.patient_id = pi.patient_id
LEFT OUTER JOIN "1_patient_history" ph 
	ON ppdd.patient_program_id = ph.patient_program_id 
LEFT OUTER JOIN last_subsequent_consultation lsc
	ON ppdd.patient_program_id = lsc.patient_program_id
LEFT OUTER JOIN last_initial_consultation lic 
	ON ppdd.patient_program_id = lic.patient_program_id
LEFT OUTER JOIN last_pre_treatment_mdt lptm
	ON ppdd.patient_program_id = lptm.patient_program_id
LEFT OUTER JOIN last_follow_up_mdt lfum
	ON ppdd.patient_program_id = lfum.patient_program_id
LEFT OUTER JOIN last_treatment_phase ltp 
	ON ppdd.patient_program_id = ltp.patient_program_id
LEFT OUTER JOIN last_ecog_sc les 
	ON ppdd.patient_program_id = les.patient_program_id
LEFT OUTER JOIN last_ecog_ic lei
	ON ppdd.patient_program_id = lei.patient_program_id
LEFT OUTER JOIN last_abnormal_findings laf
	ON ppdd.patient_program_id = laf.patient_program_id
LEFT OUTER JOIN last_precancerous_lesion lpl 
	ON ppdd.patient_program_id = lpl.patient_program_id
LEFT OUTER JOIN last_confirmed_malignancy lcm 
	ON ppdd.patient_program_id = lcm.patient_program_id
WHERE ppdd.program_id = 1 AND ppdd.voided = 'false'
ORDER BY ppdd.patient_program_id