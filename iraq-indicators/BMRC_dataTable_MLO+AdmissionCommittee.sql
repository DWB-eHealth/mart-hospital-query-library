/*ABOUT
* The MLO + Admission Committee data table connects information enter in the two forms.
* Each row represents a MLO encounter.
* If a patient has been assessed and reviewed by the admission committee more than once, there will be multiple lines for this patient.

* Variables: patient ID, sex, date of MLO assessment, type of MLO assessment, hospital of origin, date of injury, days between injury and MLO assessment, cause of injury, date of injury, date of last surgery, days between last surgery and MLO assessment, date of presentation to admission committee, outcome of admission committee, requested location of admission, reason for refusal
* Possible indicators: patients assessed by MLO by sex, average delay between injury and MLO assessment, average delay between last surgery and MLO assessment, Cases by hospital of origin and admission committee outcome
* Possible disaggregation: sex
* Customization: none
*/

WITH mlo_assessment AS (
	SELECT 
		mma.*,
		pedd.visit_id 
	FROM mlo_medical_assessment AS mma
	LEFT OUTER JOIN patient_encounter_details_default AS pedd
		ON mma.encounter_id = pedd.encounter_id),
adm_committee AS (
	SELECT 
		ac.*,
		pedd.visit_id 
	FROM admission_committee AS ac
	LEFT OUTER JOIN patient_encounter_details_default AS pedd 
		ON ac.encounter_id = pedd.encounter_id)
SELECT 
	mlo.patient_id,
	piv.gender AS sex,
	mlo.date_of_assessment,
	mlo.type_of_assessment,
	mlo.hospital_of_origin,
	mlo.date_of_injury,
	date_part('day', mlo.date_of_assessment::timestamp - mlo.date_of_injury::timestamp)::int AS day_diff_injury_assessment,
	mlo.cause_of_injury,
	mlo.date_of_last_surgery,
	date_part('day', mlo.date_of_assessment::timestamp - mlo.date_of_last_surgery::timestamp)::int AS day_diff_surgery_assessment,
	adm.date_of_presentation,
	adm.outcome_of_admission_committee, 
	adm.requested_admission, 
	adm.reason_for_refusal
FROM mlo_assessment AS mlo
LEFT OUTER JOIN patient_information_view AS piv 
	ON mlo.patient_id = piv.patient_id
LEFT OUTER JOIN adm_committee AS adm
	ON mlo.visit_id = adm.visit_id