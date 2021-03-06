/*ABOUT
* The MLO + Admission Committee data table connects information enter in the MLO Medical Assessment and the Admission Committee forms.
* This query assumes that matching MLO and admission committee forms are completed in the same visit.
* Each row represents a visit where the MLO Medical Assessment was completed. If the Admission Committee form was also completed in that visit, it is connected to the MLO form. 
* If a patient has been assessed by an MLO and/or reviewed by the admission committee more than once, there will be multiple lines for this patient.

* Variables: patient ID, sex, date of MLO assessment, type of MLO assessment, hospital of origin, date of injury, days between injury and MLO assessment, cause of injury, date of injury, date of last surgery, days between last surgery and MLO assessment, date of presentation to admission committee, outcome of admission committee, requested location of admission, reason for refusal
* Possible indicators: patients assessed by MLO by sex, average delay between injury and MLO assessment, average delay between last surgery and MLO assessment, cases by hospital of origin and admission committee outcome
* Possible disaggregation: sex
* Customization: none */

SELECT 
	mlo.patient_id,
	mlo.visit_id,
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
FROM mlo_medical_assessment AS mlo
LEFT OUTER JOIN patient_information_view AS piv 
	ON mlo.patient_id = piv.patient_id
LEFT OUTER JOIN admission_committee AS adm
	ON mlo.visit_id = adm.visit_id
ORDER BY mlo.date_of_assessment::timestamp