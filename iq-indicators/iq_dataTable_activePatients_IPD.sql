/*ABOUT
 * The active patients data table calculates the number of patients active within the facility during the reporting period. 
 * Each row represents a day and patient counts at the end of each day.
 
 * Variables: reporting day, active patients, cumulative admissions (commented out by default), cumulative exits (commented out by default)
 * Possible indicators: Active patients within facility per day, average active patients within facility per reporting period
 * Possible disaggregation: none (need to use a separate [taTable_activePatients_withFilter.sql] to apply any disaggregations)
 * Customization: none*/

WITH active_patients AS (
	SELECT 
		ime.patient_id,
		ime.date_of_admission::date AS visit_start_date,
		CASE
			WHEN ipn.date_of_discharge NOTNULL THEN ipn.date_of_discharge::date
			ELSE CURRENT_DATE 
		END AS visit_end_date
	FROM initial_medical_examination AS ime
	LEFT OUTER JOIN ipd_progress_note_md AS ipn
		ON ime.visit_id = ipn.visit_id
	WHERE ime.date_of_admission IS NOT NULL AND ime.patient_admitted_to = 'IPD'
	ORDER BY ime.date_of_admission::timestamp),
range_values AS (
	SELECT 
		date_trunc('day',min(ap.visit_start_date)) AS minval,
		date_trunc('day',max(ap.visit_end_date)) AS maxval
	FROM active_patients AS ap),
day_range AS (
	SELECT 
		generate_series(minval,maxval,'1 day'::interval) as day
	FROM range_values),   
daily_admissions AS (
	SELECT 
		date_trunc('day', ap.visit_start_date) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1),
daily_exits AS (
	SELECT
		date_trunc('day',ap.visit_end_date) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1)
SELECT 
	day_range.day as reporting_day,
	/*sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions,
	CASE
		WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN 0
		ELSE sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
	END AS cumulative_exits,*/ 
	CASE
		WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
		ELSE (sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
	END AS active_patients
FROM day_range
LEFT OUTER JOIN daily_admissions ON day_range.day = daily_admissions.day
LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.day
ORDER BY day_range.day DESC