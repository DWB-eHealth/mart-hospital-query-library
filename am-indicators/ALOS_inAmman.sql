With preopCTE AS (
  SELECT 
    "public"."patient_state_default"."patient_id", 
    "public"."patient_state_default"."start_date" 
  from 
    "public"."patient_state_default" 
  where 
    "public"."patient_state_default"."state_name" = 'Pre-Operative' 
  Order by 
    "public"."patient_state_default"."patient_id", 
    "public"."patient_state_default"."start_date" desc
), 
hospitalCTE AS (
  SELECT 
    "public"."patient_visit_details_default"."patient_id", 
    "public"."patient_visit_details_default"."visit_start_date" 
  from 
    "public"."patient_visit_details_default" 
  where 
    "public"."patient_visit_details_default"."visit_type_name" = 'Hospital' 
    /*hospital visits opened by mistake*/
    and visit_id <> 14347 
    and visit_id <> 14301 
    and visit_id <> 14515 
    and visit_id <> 3206 
    and visit_id <> 14517 
    and visit_id <> 14516 
    and visit_id <> 14514 
    and visit_id <> 14518 
    and visit_id <> 13184 
    and visit_id <> 14301 
    and visit_id <> 14515 
    and visit_id <> 14517 
    and visit_id <> 14516 
    and visit_id <> 1451 
    and visit_id <> 14598 
    and visit_id <> 14599 
    and visit_id <> 14634 
    and visit_id <> 14635 
    and visit_id <> 14598 
    and visit_id <> 14599 
    and visit_id <> 14634 
    and visit_id <> 14635 
  Order by 
    "public"."patient_visit_details_default"."patient_id", 
    "public"."patient_visit_details_default"."visit_start_date" desc
), 
nw_fupCTE AS (
  SELECT 
    "public"."patient_state_default"."patient_id", 
    "public"."patient_state_default"."start_date" 
  from 
    "public"."patient_state_default" 
  where 
    "public"."patient_state_default"."state_name" = 'Network Follow-up' 
  Order by 
    "public"."patient_state_default"."patient_id", 
    "public"."patient_state_default"."start_date" desc
), 
first_stageCTE AS (
  SELECT 
    "public"."patient_visit_details_default"."patient_id", 
    "public"."patient_visit_details_default"."visit_start_date" 
  from 
    "public"."patient_visit_details_default" 
  where 
    "public"."patient_visit_details_default"."visit_type_name" = 'First Stage Validation' 
  Order by 
    "public"."patient_visit_details_default"."patient_id", 
    "public"."patient_visit_details_default"."visit_start_date" desc
), 
fstg_name_s_of_surgeonCTE AS (
  SELECT 
    DISTINCT on (
      "public"."first_stage_validation"."patient_id"
    ) "public"."first_stage_validation"."patient_id", 
    case when "public"."first_stage_validation"."fstg_name_s_of_surgeon_1" = 'Dr. Muckhaled Naseef' then 'Dr. Muckhaled Naseef' else "public"."first_stage_validation"."fstg_name_s_of_surgeon_1" end as "fstg_name_s_of_surgeon_1" 
  from 
    "public"."first_stage_validation" 
  where 
    "public"."first_stage_validation"."fstg_name_s_of_surgeon_1" is not null 
    /*and "public"."first_stage_validation"."fstg_name_s_of_surgeon_1" <> 'Dr. Sofian Al-Qassab'*/
  Order by 
    "public"."first_stage_validation"."patient_id", 
    "public"."first_stage_validation"."obs_datetime" desc
), 
fv_name_s_of_surgeonCTE AS (
  SELECT 
    DISTINCT on (
      "public"."fv_final_validation"."patient_id"
    ) "public"."fv_final_validation"."patient_id", 
    case when "public"."fv_final_validation"."fv_name_s_of_surgeon_1" = 'Dr. Muckhaled Naseef' then 'Dr. Muckhaled Naseef' else "public"."fv_final_validation"."fv_name_s_of_surgeon_1" end as "fv_name_s_of_surgeon_1" 
  from 
    "public"."fv_final_validation" 
  where 
    "public"."fv_final_validation"."fv_name_s_of_surgeon_1" is not null 
    /*and "public"."fv_final_validation"."fv_name_s_of_surgeon_1" <> 'Dr. Sofian Al-Qassab'*/
  Order by 
    "public"."fv_final_validation"."patient_id", 
    "public"."fv_final_validation"."obs_datetime" desc
), 
fup_name_s_of_surgeonCTE AS (
  SELECT 
    DISTINCT on (
      "public"."follow_up_validation"."patient_id"
    ) "public"."follow_up_validation"."patient_id", 
    case when "public"."follow_up_validation"."fup_name_s_of_surgeon_1" = 'Dr. Muckhaled Naseef' then 'Dr. Muckhaled Naseef' else "public"."follow_up_validation"."fup_name_s_of_surgeon_1" end as "fup_name_s_of_surgeon_1" 
  from 
    "public"."follow_up_validation" 
  where 
    "public"."follow_up_validation"."fup_name_s_of_surgeon_1" is not null 
    /*and "public"."follow_up_validation"."fup_name_s_of_surgeon_1" <> 'Dr. Sofian Al-Qassab'*/
  Order by 
    "public"."follow_up_validation"."patient_id", 
    "public"."follow_up_validation"."obs_datetime" desc
), 
ProgramwithhospitalphaseCTE AS (
  SELECT 
    DISTINCT on (
      "public"."patient_state_default"."patient_id"
    ) "public"."patient_state_default"."patient_id", 
    "public"."patient_state_default"."patient_program_id", 
    min(
      "public"."patient_state_default"."start_date"
    ) as "start_date" 
  from 
    "public"."patient_state_default" 
  where 
    "public"."patient_state_default"."state" = 10 
    or "public"."patient_state_default"."state" = 9 
    or "public"."patient_state_default"."state" = 11 
  group by 
    "public"."patient_state_default"."patient_program_id", 
    "public"."patient_state_default"."patient_id" 
  Order by 
    "public"."patient_state_default"."patient_id"
) 
SELECT 
  Case when fup_name_s_of_surgeonCTE.fup_name_s_of_surgeon_1 is not null then fup_name_s_of_surgeonCTE.fup_name_s_of_surgeon_1 when fup_name_s_of_surgeonCTE.fup_name_s_of_surgeon_1 is null 
  and fv_name_s_of_surgeonCTE.fv_name_s_of_surgeon_1 is not null then fv_name_s_of_surgeonCTE.fv_name_s_of_surgeon_1 when fup_name_s_of_surgeonCTE.fup_name_s_of_surgeon_1 is null 
  and fv_name_s_of_surgeonCTE.fv_name_s_of_surgeon_1 is null 
  and fstg_name_s_of_surgeonCTE.fstg_name_s_of_surgeon_1 is not null then fstg_name_s_of_surgeonCTE.fstg_name_s_of_surgeon_1 else null end as "Name_of_Surgeon", 
  "public"."patient_state_default"."patient_id" AS "patient_id", 
  "public"."patient_state_default"."start_date" as "TRM date", 
  case when max(preopCTE.start_date) < "public"."patient_state_default"."start_date" then round(
    "public"."patient_state_default"."start_date" - max(preopCTE.start_date)
  ) when max(preopCTE.start_date) > "public"."patient_state_default"."start_date" then round(
    "public"."patient_state_default"."start_date" - min(preopCTE.start_date)
  ) else null end as "LOS" 
  /* , ProgramwithhospitalphaseCTE."patient_program_id"*/
  , 
  "public"."patient_information_view"."gender" AS "Gender" 
FROM 
  "public"."patient_state_default" 
  left outer join hospitalCTE on hospitalCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join preopCTE on preopCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join nw_fupCTE on nw_fupCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join first_stageCTE on first_stageCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join fstg_name_s_of_surgeonCTE on fstg_name_s_of_surgeonCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join fv_name_s_of_surgeonCTE on fv_name_s_of_surgeonCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join fup_name_s_of_surgeonCTE on fup_name_s_of_surgeonCTE.patient_id = "public"."patient_state_default"."patient_id" 
  left outer join ProgramwithhospitalphaseCTE on ProgramwithhospitalphaseCTE."patient_program_id" = "public"."patient_state_default"."patient_program_id" 
  left outer join "public"."patient_information_view" on "public"."patient_information_view"."patient_id" = "public"."patient_state_default"."patient_id" 
WHERE 
  (
    "public"."patient_state_default"."state_name" = 'Network Follow-up'
  ) 
  AND (
    hospitalCTE.visit_start_date < nw_fupCTE.start_date
  ) 
  and ProgramwithhospitalphaseCTE."patient_program_id" is not null 
  and "public"."patient_state_default"."start_date" > ProgramwithhospitalphaseCTE.start_date 
  /* and EXTRACT(month from "public"."patient_state_default"."start_date"::date) <> EXTRACT(month from NOW()) */
group by 
  "public"."patient_information_view"."gender", 
  ProgramwithhospitalphaseCTE."patient_program_id", 
  "public"."patient_state_default"."patient_id", 
  "public"."patient_state_default"."start_date", 
  fup_name_s_of_surgeonCTE.fup_name_s_of_surgeon_1, 
  fv_name_s_of_surgeonCTE.fv_name_s_of_surgeon_1, 
  fstg_name_s_of_surgeonCTE.fstg_name_s_of_surgeon_1 
ORDER BY 
  "public"."patient_state_default"."patient_id" asc
