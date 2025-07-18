# View: `cohort_register_view`

## 🧾 Description
This view consolidates oncology patient information, including demographics, consultations, diagnoses, treatments, and outcomes. It supports longitudinal tracking of cancer care across multiple stages: initial and subsequent consultations, pre-treatment MDT, follow-up MDT, mental health assessment, and surgical interventions. The view contains one row per patient registered, regardless of number of programs the patient was enrolled it.

---

## 📦 Column Reference

The following tables contain a description of all variables avaliable in the `cohort_register_view`. Variables are organized by content groups. For the full codebook and to make requests for additional columns or other modifications, reach out to the eHealth team. 

### 👩 Patient demographics

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `Patient_Identifier` | unique identifier for the patient, used to identify patient records in Bahmni | text | N/A | Registration | Patient Identifier | [Patient_Identifier](#patient-identifier) |
| `patient_id` | unique identifier for the patient, used to make patient-level connections between Analytics tables and views | text | N/A | Registration | patient_id | [Patient_Identifier](#patient-identifier) |
| `age_at_enrollment` | patient's age in years at registration in Bahmni | int | N/A | Registration | Age | [person_details_default](#person_details_default) |
| `age_group_at_enrollment` | patient's age in years at registration in Bahmni, categorized by age group | text | 0-17; 18-24; 25-49; 50+ | Registration | Age | [person_details_default](#person_details_default) |
| `ta_town` | patient's traditional authority or town of residence | text | N/A | Registration | Traditional Authority/Town | [person_address_default](#person_address_default) |
| `district` | patient's district of residence | text | N/A | Registration | District | [person_address_default](#person_address_default) |
| `region` | patient's region of residence | text | N/A | Registration | Region | [person_address_default](#person_address_default) |
| `country` | patient's country of residence | text | N/A | Registration | Country | [person_address_default](#person_address_default) |
| `patient_education_level` | highest education level attained as reported in the Social Assessment form - data is from the most recent form | text | None; Illiterate; Primary school; High school; College/University | Clinical - Social Assessment form | Patient education level | [social_assessment_edu](https://github.com/DWB-eHealth/mart-hospital-query-library/blob/bd04f6f6b36346da4481a656765d4741150a9364/mw-indicators/cohort_registry_view_docs.md#L179) |

---

### 🧾 Cohort enrollment

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `registration_date` | date the patient was registered in Bahmni | date | N/A | Registration | Registration date | N/A |
| `enrollment_date` | date the patient was first enrolled in either oncogynae or palliative care program | date | N/A | Programs | Start Date | program_first |
| `program_name` | The program the patient is enrolled in (oncogynae/palliative care) | text | Oncogynae; Palliative Care | Programs | Program | program_open; program_exit |
| `time_since_enrollment` | days between first program enrollment date and todays date | int | N/A | Programs | Start Date | program_first |
| `months_since_enrollment` | months between first program enrollment date and todays date | int | N/A | Programs | Start Date | program_first |
| `years_since_enrollment` | years between first program enrollment date and todays date | int | N/A | Programs | Start Date | program_first |
| `reason_for_referral` | reason the patient was referred as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | Positive VIA results; Cancer treatment; Supportive services; Cancer suspect; Cancer follow-up, Other | Clinical - Patient History form | Reason for referral | patient_history |
| `referral_facility` | type of facility the patient was referred from as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | MSF VIA centre; NGO's VIA centre; Other health facility | Clinical - Patient History form | Referral facility | patient_history |
| `referral_facility_name` | name of facility the patient was referred from as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | N/A | Clinical - Patient History form | MSF VIA centre name; NGO's VIA centre name; MOH health facility name | patient_history |

---

### 🔬 Last health status

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `pregnancies` | number of pregnancies as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | int | N/A | Clinical - Patient History form | Number of previous pregnancies including current if applicable | patient_history |
| `hpv_status` | HPV status as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | Not Done; Negative; Positive; Unknown | Clinical - Patient History form | HPV status | patient_history |
| `smoker` | if patient smokes as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | Yes; No | Clinical - Patient History form | Smoker | patient_history |
| `bmi` | BMI of patient reported in the Vital Signs form - if multiple Vital Signs forms are completed, the data from the most recent form is used | number | N/A | Clinical - Vital Signs form | BMI | vital_signs |
| `hiv_test` | HIV test result as reported in the Patient History or Laboratory forms - data is from the most recent form | text | Positive; Negative; Unknown | Clinical - Patient History form; Laboratory form | Result of HIV test; HIV test | hiv_result |
| `on_antiretroviral_therapy` | ART status as reported in the Patient History form - if multiple Patient History forms are completed, the data from the most recent form is used | text | Yes; No | Clinical - Patient History form | On antiretroviral therapy | hiv_result |
| `cd4_count` | CD4 count as reported in the Patient History or Laboratory forms - data is from the most recent form | int | N/A | Clinical - Patient History form; Laboratory form | Last CD4 count; CD4 count | hiv_result |

---

### 🩺 Initial consultation

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `initial_consultation_date` | date of initial consultation from Initial Consultation form - if multiple Initial Consultation forms are completed, the date from the first form is used | date | N/A | Clinical - Initial Consultation form | Date recorded | initial_consultation |
| `initial_ecog_performance_status` | ECOG performance status reported in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | int | 0-5 | Clinical - Initial Consultation form | ECOG performance status | initial_consultation |
| `initial_confirmed_malignancy` | if confirm malignancy is diagnosed reported in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Yes; null | Clinical - Initial Consultation form | Diagnosis | initial_consultation |
| `initial_confirmed_malignancy_topo` | topography if confirm malignancy is diagnosed in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Cervix; other topography | Clinical - Initial Consultation form | Topography of the tumour (confirmed) | initial_consultation |
| `initial_suspected_malignancy` | if suspected malignancy is diagnosed reported in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Yes; null | Clinical - Initial Consultation form | Diagnosis | initial_consultation |
| `initial_suspected_malignancy_topo` | topography if suspected malignancy is diagnosed in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Cervix; other topography | Clinical - Initial Consultation form | Topography of the tumour (suspected) | initial_consultation |
| `initial_precancerous_lesions` | if precancerous lesions are diagnosed reported in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Yes; null | Clinical - Initial Consultation form | Diagnosis | initial_consultation |
| `initial_abnormal_findings` | if there are abnormal findings reported in the Initial Consultation form - if multiple Initial Consultation forms are completed, the data from the first form is used | text | Yes; null | Clinical - Initial Consultation form | Diagnosis | initial_consultation |

---

### 👩‍⚕️ Pre-treatment MDT

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `premdt_date` | date of pre-treatment MDT from the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | date | N/A | Clinical - Pre Treatment MDT | Date recorded | pre_treatment_mdt |
| `premdt_confirmed_malignancy` | if confirmed malignancy was recorded in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Clinical diagnosis | pre_treatment_mdt |
| `premdt_confirmed_malignancy_topo` | topography of confirmed malignancy recorded in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Cervix; other topography | Clinical - Pre Treatment MDT | Topography of the tumour | pre_treatment_mdt |
| `premdt_agreed_figo` | agreed FIGO staging recorded in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | IA1; IA2; IB1; IB2; IB3; IIA1; IIA2; IIB; IIIA; IIIB; IIIC1; IIIC2; IVA; IVB | Clinical - Pre Treatment MDT | Agreed FIGO staging for cancer of the cervix | pre_treatment_mdt |
| `premdt_precancerous_lesions` | if precancerous lesions was recorded in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Clinical diagnosis | pre_treatment_mdt |
| `premdt_abnormal_findings` | if abnormal findings was recorded in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Clinical diagnosis | pre_treatment_mdt |
| `premdt_conservative_surgery` | If plan for conservative surgery was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Proposed management plan | pre_treatment_mdt |
| `premdt_surgical_procedure` | if surgical procedure was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Proposed management plan | pre_treatment_mdt |
| `premdt_radiation_therapy` | if radiation therapy was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Proposed management plan | pre_treatment_mdt |
| `premdt_chemotherapy` | if chemotherapy was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Proposed management plan | pre_treatment_mdt |
| `premdt_palliative_care` | if palliative care was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used] | text | Yes; null | Clinical - Pre Treatment MDT | Proposed management plan | pre_treatment_mdt |
| `premdt_other_mgmt_plan` | if other was recorded as the proposed management plan in the Pre Treatment MDT form - if multiple Pre Treatment MDT forms are completed, data from the first form is used | text | Yes; null | Clinical - Pre Treatment MDT | Other proposed management plan | pre_treatment_mdt |

---

### 🔄 Follow-up MDT

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `fumdt_date` | date of follow-up MDT from the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | date | N/A | Clinical - Follow-up MDT | Date recorded | follow_up_mdt |
| `fumdt_chemotherapy_response` | chemotherapy response recorded in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Complete response; >= 30 percentage partial response; <= 30 percentage partial response; Stable disease; Progressive disease | Clinical - Follow-up MDT | Chemotherapy response | follow_up_mdt |
| `fumdt_conservative_surgery` | If plan for conservative surgery was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Yes; null | Clinical - Follow-up MDT | Proposed management plan | follow_up_mdt |
| `fumdt_surgical_procedure` | if surgical procedure was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Yes; null | Clinical - Follow-up MDT | Proposed management plan | follow_up_mdt |
| `fumdt_radiation_therapy` | if radiation therapy was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Yes; null | Clinical - Follow-up MDT | Proposed management plan | follow_up_mdt |
| `fumdt_chemotherapy` | if chemotherapy was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Yes; null | Clinical - Follow-up MDT | Proposed management plan | follow_up_mdt |
| `fumdt_palliative_care` | if palliative care was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used] | text | Yes; null | Clinical - Follow-up MDT | Proposed management plan | follow_up_mdt |
| `fumdt_other_mgmt_plan` | if other was recorded as the proposed management plan in the Follow-up MDT form - if multiple Follow-up MDT forms are completed, data from the most recent form is used | text | Yes; null | Clinical - Follow-up MDT | Other proposed management plan | follow_up_mdt |

---

### 🧬 Cancer status

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `first_disclosure_date` | date of the first diagnosis disclosure recorded in the Subsequent Consultation form, only Subsequent Consultation forms where reason for visit is recorded as "Diagnosis disclosure" and the date recorded in the form is after the date on or after the date of the first Pre Treatment MDT - if there are multiple forms fitting this criteria, data from the first form is used | date | N/A | Clinical - Subsequent Consultation form; Pre Treatment MDT form | Date recorded | subsequent_consultation_disclosure |
| `first_mh_assessment_date` | date of the first post-disclosure mental health assessment from the Social Assessment form, only Social Assessment forms dated after the first disclosure date are used - if there are multiple forms fitting this criteria, data from the first form is used | date | N/A | Clinical - Social Assessment form; Subsequent Consultation form; Pre Treatment MDT form | Date recorded | social_assessment_post_disclosure |
| `date_cancer_status` | date of Subsequent Consultation form where cancer disease status was given, except in the case when the patient has a program outcome - if multiple Subsequent Consultation forms are completed, data from the most recent form is used | date | N/A | Clinical - Subsequent Consultation form | Date recorded | subsequent_consultation_status; program_exit |
| `last_cancer_status` | cancer status recorded on the Subsequent Consultation form, except in the case when the patient has a program outcome - if multiple Subsequent Consultation forms are completed, data from the most recent form is used | text | No recurrence; Worsening; Improving; In remission; Metastatically recurrent tumour; Locally recurrent tumour; Stable but not improving | Clinical - Subsequent Consultation form | Cancer disease status | subsequent_consultation_status; program_exit |

---

### 📅 Appointments

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `last_visit_date` | date of patients most recent visit recorded in the Initial Consultation form, Subsequent Consultations form, Pre Treatment MDT form, Follow-up MDT form, Supportive Care Assessment form, or the Appointment Scheduling module (only checked in or completed appointments for Initial gynaecology consultation, Subsequent gynaecology consultation, Palliative Care, Subsequent disclosure visit services are included) | date | N/A | Appointment Scheduling; Clinical - Initial Consultation form; Subsequent Consultations form; Pre Treatment MDT form; Follow-up MDT form; Supportive Care Assessment form | Appointment start time; Date recorded | last_visit, program_exit |
| `time_since_last_visit` | years, months, and  days between the last visit date and the current date | int | N/A | Appointment Scheduling; Clinical - Initial Consultation form; Subsequent Consultations form; Pre Treatment MDT form; Follow-up MDT form; Supportive Care Assessment form | Appointment start time; Date recorded | last_visit, program_exit |
| `days_since_last_visit` | days between the last visit date and the current date | int | N/A | Appointment Scheduling; Clinical - Initial Consultation form; Subsequent Consultations form; Pre Treatment MDT form; Follow-up MDT form; Supportive Care Assessment form | Appointment start time; Date recorded | last_visit, program_exit |
| `months_since_last_visit` | months between the last visit date and the current date | int | N/A | Appointment Scheduling; Clinical - Initial Consultation form; Subsequent Consultations form; Pre Treatment MDT form; Follow-up MDT form; Supportive Care Assessment form | Appointment start time; Date recorded | last_visit, program_exit |
| `lost_to_follow_up` | identifies patients who's last appointment was marked as 'Missed' if the appointment occurred after the last visit date recorded in the Initial Consultation form, Subsequent Consultations form, Pre Treatment MDT form, Follow-up MDT form, or Supportive Care Assessment form | date | N/A | Appointment Scheduling | Appointment start time | last_appt_missed_clean, last_visit, program_exit |
| `next_scheduled_appointment` | identifies the next scheduled appointment in the Appointment Scheduling module, taking place after the current date | date | N/A | Appointment Scheduling | Appointment start time | next_appointment, program_exit |

---

### 🏥 Surgery & procedures

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `first_surgery_date` | data of first reported surgery from the Cervical Surgical Report form, Ovary Surgical Report form, Vulva Surgical Report form, or LEEP and Conization form - if multiple forms are completed, data from the first form is used | date | N/A | Clinical - Cervical Surgical Report form; Ovary Surgical Report form; Vulva Surgical Report form; LEEP and Conization form | Date of surgery; Date recorded | first_surgery |
| `radical_abdominal_hysterectomy` | if radical abdominal hysterectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | radical_abdominal_hysterectomy |
| `total_abdominal_hysterectomy` | if total abdominal hysterectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | total_abdominal_hysterectomy |
| `radical_vaginal_hysterectomy` | if radical vaginal hysterectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | radical_vaginal_hysterectomy |
| `total_vaginal_hysterectomy` | if total vaginal hysterectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | total_vaginal_hysterectomy |
| `bilateral_salpingectomy` | if bilateral salpingectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | bilateral_salpingectomy |
| `bilateral_oophorectomy` | if bilateral oophorectomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | bilateral_oophorectomy |
| `exploratory_laparotomy` | if exploratory laparotomy procedure was performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | exploratory_laparotomy |
| `other_cervical_surgical_procedures` | if any other cervical procedures were performed at any time as recorded in the Cervial Surgical Report form | text | Yes; null | Clinical - Cervical Surgical Report form | Procedure performed | other_cervical_surgical_procedures |
| `ovary_surgical_report` | if an Ovary Surgical Report form was completed at any time | text | Yes; null | Clinical - Ovary Surgical Report form | N/A | ovary_surgical_report |
| `vulva_surgical_report` | if an Vulva Surgical Report form was completed at any time | text | Yes; null | Clinical - Vulva Surgical Report form | N/A | vulva_surgical_report |
| `leep` | if a LEEP procedure was performed at any time as recorded in the LEEP and Conization form | text | Yes; null | Clinical - LEEP and Conization form | LEEP Indication | leep_binary |
| `biopsy` | if a biopsy was taken at any time as reported in the Initial Consultation form, Subsequent Consultation form, Colposcopy Report form, or retired Colposcopy form | text | Yes; null | Clinical - Initial Consultation form; Subsequent Consultation form; Colposcopy Report form; Colposcopy (retired) form | Procedure performed, Gynaecological Exam; Biopsies, Number of specimen(s) collected; Colposcopic management | biopsy_taken |

---

### 🏠 Patient outcome

| Column | Description | Data value type | Value options | Source module/form | Source field/concept | Source |
|:-------|:------------|:----------------|:--------------|:-------------------|:---------------------|:-------------------|
| `patient_outcome` | outcome recorded in the last program enrollment - if patient is enrolled in multiple programs, outcome is only recorded if all programs are closed & if there are multiple closed programs, the outcome from the last closed program is used | text | Non-cancer diagnosis; QECH Cancer referral; Transferred out; Lost to follow up; Refused care; End of Follow Up; Beyond Curative (Palliative); Death | Programs | Program Outcome | program_exit |
| `date_completed` | outcome date recorded in the last program enrollment - if patient is enrolled in multiple programs, outcome is only recorded if all programs are closed & if there are multiple closed programs, the outcome from the last closed program is used | date | N/A | Programs | Completed date | program_exit |
| `date_of_death` | date of death recorded in the Bereavement form or the program outcome - if recorded in multiple locations, the date recorded in the Bereavement form is used | date | N/A | Programs; Clinical - Bereavement form | Date of death; Completed date | program_exit |
| `length_of_follow` | years, months, and days between enrollment and exit | int | N/A | Programs | Completed date; Registration date | program_exit |
| `months_of_follow` | months between enrollment and exit | int | N/A | Programs | Completed date; Registration date | program_exit |
| `years_of_follow` | years between enrollment and exit | int | N/A | Programs | Completed date; Registration date | program_exit |

---

## 🔁 Sub-queries: common table expression (CTE)

Summary of common table expression (CTE) within the `cohort_register_view`. CTEs allow for discreate sub-tables to be created and used in the main query. The purpose of CTE is to create more human readable code, reduce code complexity, support troubleshooting of issues, and improve performance. CTEs contiain the code logic for the specific manipulations required to produce the view. 

| CTE name | Description | Used in main query |
|:---------|:------------|:-------------------|
| `pre_treatment_mdt` | extracts and pivots initial diagnosis information (diagnosis, tumour topography, FIGO staging, and management plan) from the first Pre-treatment MDT form completed for each patient | Yes |
| `initial_consultation` | extracts and pivots initial consultation information (consultation date, ECOG performance, diagnosis) from the first Initial Consultation form completed for each patient | Yes |
| `follow_up_mdt` | extracts and pivots follow-up MDT information (date, management plan) from the most recent follow-up MDT form completed for each patient | Yes |
| `subsequent_consultation_status` | extracts last cancer status from the most recent Subsequent Consultation form completed for each patient | Yes |
| `subsequent_consultation_disclosure`| extracts the first disclosure date from the first Subsequent Consultation form completed for each patient | Yes |
| `patient_history` | extracts referral, pregnancies, and smoking status from the most recent Patient History form completed for each patient | Yes |
| `vital_signs` | extracts last BMI reading from the most recent Vital Signs form completed for each patient | Yes |
| `hiv_test` | combines HIV test results from both the Patient History and Laboratory forms | No |
| `hiv_result` | extracts the last HIV test result or status, ART, and CD4 count from the most recent Patient History or Laboratory forms for each patient | Yes |
| `social_assessment_edu` | extracts the last reported education level from the most recent Social Assessmnet form for each patient | Yes |
| `social_assessment_post_disclosure` | extracts the first mental health assessment date taking place after diagnosis disclosure from the Social Assessment form for each patient | Yes |
| `last_visit` | extracts the last visit date from the Initial Consultation form, Subsequent Consultation form, Pre-Treatment MDT form, Follow-up MDT form, Supportive Care Assessment form, and appointments marked as Completed or Checked in in the Appointment Scheduling module. Only the most recent date from these sources is used | Yes |
| `last_appt_missed` | creates a list of patients who missed their last appointment recorded in the Appointment Scheduling Module | No |
| `last_appt_missed_clean` | extracts true missed appointments from the `last_appt_missed` CTE by checking if the patient has a form recorded after the last missed appointment date | Yes |
| `next_appointment` | extracts the next appointment from the Appointment Scheduling module for each patient | Yes |
| `first_surgery` | extracts the first reported surgery date from the Cervical Surgical Report, Ovary Surgical Report, Vulva Surgical Report, and Leep and Conization forms for each patient | Yes |
| `leep_binary` | extracts a list of patients where LEEP was indicated from the LEEP and Conization form | Yes |
| `radical_abdominal_hysterectomy` | extracts if a radical abdominal hysterectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `total_abdominal_hysterectomy` | extracts if a total abdominal hysterectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `radical_vaginal_hysterectomy` | extracts if a radical vaginal hysterectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `total_vaginal_hysterectomy` | extracts if a total vaginal hysterectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `bilateral_salpingectomy` | extracts if a bilateral salpingectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `bilateral_oophorectomy` | extracts if a bilateral oophorectomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `exploratory_laparotomy` | extracts if a exploratory laparotomy was completed from the Cervical Surgical Report form for each patient | Yes |
| `other_cervical_surgical_procedures`| extracts if other procedures (not otherwise listed) were completed from the Cervical Surgical Report form for each patient | Yes |
| `ovary_surgical_report` | extracts if any procedure was completed from the Ovary Surgical Report form for each patient | Yes |
| `vulva_surgical_report` | extracts if any procedure was completed from the Vulva Surgical Report form for each patient | Yes |
| `biopsy_taken` | consolidates and extracts if a biopsy was reported in Initial Consultation, Subsequent Consultation, _retired_ colposcopy, and colposcopy report forms for each patient | Yes |
| `program_first` | extracts the first reported program from the Programs module for each patient | Yes |
| `program_open` | extracts the program currently open from the Programs module for each patient. If multiple programs are open, Oncogynae wiil be reported over Palliative Care | Yes |
| `program_exit` | extracts the exit date and outcome from the Programs module for all patients without an open program | Yes |

---

## 🗂️ Source Tables
The following source tables from the analytics database are referenced in the `cohort_register_view`:

| Table name | Description | Use |
|:-----------|:------------|:----|
| <a name="patient-identifier"></a>`Patient_Identifier` | used to define the patient population present in the `cohort_register_view` and provide the unique identifier created in the Bahmni registration module | Main query |
| <a name="registration_date"></a>`registration_date` | provides date patient was created in the Bahmni registration module | Main query |
| <a name="person_details_default"></a>`person_details_default` | provides the current age of the patient recorded in the Bahmni registration module, calculated using the date of birth and the current date | Main query |
| <a name="person_address_default"></a>`person_address_default` | provides the traditional authority/town, district, region, and country of patient recorded in the Bahmni registration module | Main query |
| `patient_program_data_default` | provides the first, current, and final program enrollment information (enrollment date, current program, program exit date, patient outcome, date of death) for each patient | CTE [`program_first`; `program_open`; `program_exit`] |
| `patient_appointment_default` | provides last completed, last missed appointment, and next appointment for each patient as captured in the appointment scheduling module | CTE [`last_visit`; `last_appt_missed`; `next_appointment`] |
| `01_patient_history` | table containing information recorded in the patient history form | CTE [`patient_history`; `hiv_test`] |
| `02_vital_signs` | table containing information recorded in the vital signs form | CTE [`vital_signs`] |
| `03_laboratory` | table containing information recorded in the laboratory form | CTE [`hiv_test`] |
| `05_initial_consultation` | table containing information recorded in the initial consultation form | CTE [`initial_consultation`; `last_visit`; `last_appt_missed_clean`; `biopsy_taken`] |
| `05_initial_consultation_confirmed_malignancy_details` | table containing information recorded in the initial consultation form under confirmed malignancy details | CTE [`initial_consultation`] |
| `05_initial_consultation_suspected_malignancy_details` | table containing information recorded in the initial consultation form under suspected malignancy details | CTE [`initial_consultation`] |
| `07_subsequent_consultation` | table containing information recorded in the subsequent consultation form | CTE [`subsequent_consultation_status`; `subsequent_consultation_disclosure`; `last_visit`; `last_appt_missed_clean`; `biopsy_taken`] |
| `reason_for_visit` | table containing information recorded in the subsequent consultation form under the reason for visit | CTE [`subsequent_consultation_disclosure`] |
| `diagnosis` | table containing diagnosis information recorded in the initial or subsequent consultation forms | CTE [`initial_consultation`] |
| `08_colposcopy_report` | table containing information recorded in the colposcopy report form | CTE [`biopsy_taken`] |
| `colposcopic_management` | table containing colposcopy management information recorded in the colposcopy report form | CTE [`biopsy_taken`] |
| `09_leep_and_conization` | table containing information recorded in the LEEP and conization form | CTE [`first_surgery`; `leep_binary`] |
| `10_pre_treatment_mdt` | table containing information recorded in the pre-treatment MDT form | CTE [`pre_treatment_mdt`; `last_visit`; `last_appt_missed_clean`] |
| `clinical_diagnosis` | table containing diagnosis information recorded in the pre-treatment MDT form | CTE [`pre_treatment_mdt`; `initial_consultation`] |
| `topography_of_the_tumour` | table containing topography of tumour information recorded in the pre-treatment MDT form | CTE [`pre_treatment_mdt`] |
| `11_follow_up_mdt` | table containing information recorded in the follow-up MDT form | CTE [`last_visit`; `last_appt_missed_clean`; `follow_up_mdt`] |
| `proposed_management_plan` | table containing proposed management plan information recorded in the pre-treatment and follow-up MDT forms | CTE [`pre_treatment_mdt`; `follow_up_mdt`] |
| `12_supportive_care_assessment` | table containing information recorded in the supportive care assessment form | CTE [`last_visit`; `last_appt_missed_clean`] |
| `14_bereavement_form` | table containing information recorded in the bereavement form | CTE [`program_exit`] |
| `15_social_assessment` | table containing information recorded in the social assessment form | CTE [`social_assessment_edu`; `social_assessment_post_disclosure`] |
| `19_cervical_surgical_report` | table containing information recorded in the cervical surgical report form | CTE [`first_surgery`; `radical_abdominal_hysterectomy`; `total_abdominal_hysterectomy`; `radical_vaginal_hysterectomy`; `total_vaginal_hysterectomy`; `bilateral_salpingectomy`; `bilateral_oophorectomy`; `exploratory_laparotomy`; `other_cervical_surgical_procedures`] |
| `20_ovary_surgical_report` | table containing information recorded in the ovary surgical report form | CTE [`first_surgery`; `ovary_surgical_report`] |
| `21_vulva_surgical_report` | table containing information recorded in the vulva surgical report form | CTE [`first_surgery`; `vulva_surgical_report`] |
| `procedure_performed_gynaecological_exam` | table containing procedure information recorded in the initial and subsequent consultation forms | CTE [`biopsy_taken`] |
| `33_old_colposcopy` | table containing information recorded in the _retired_ colposcopy form | CTE [`biopsy_taken`] |
| `procedure_performed` | table containing procedure information recorded in the initial consultation, cervical surgical report, ovary surgical report, vulva surgical report, and old colposcopy form | CTE [`radical_abdominal_hysterectomy`; `total_abdominal_hysterectomy`; `radical_vaginal_hysterectomy`; `total_vaginal_hysterectomy`; `bilateral_salpingectomy`; `bilateral_oophorectomy`; `exploratory_laparotomy`; `other_cervical_surgical_procedures`; `biopsy_taken`] |

---

## 🧭 Audit Info

- **Created:** 2024-05-28 
- **Last Updated:** 2025-07-02 
- **SQL File:** [`cohort_registry_view.sql`](https://github.com/DWB-eHealth/mart-hospital-query-library/blob/master/mw-indicators/cohort_registry_view.sql) 
- **Codebook (excel format):** reach out to the eHealth team

---

## ⚠️ Known Issues & Notes

- Need to review and clarify the source of HPV test results. Laboratoy information may be missing

