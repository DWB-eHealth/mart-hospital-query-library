/*ABOUT
* The active patients data table calculates the number of patients active within the facility during the reporting period. Each row represents a day and patient counts at the end of each day.

* Variables: reporting day, cumulative admissions, cumulative exits, active patients
* Possible indicators: Active patients for entier facility per day, average active patients per reporting period
* Possible disaggregation: none (need to use customized individual data tables to disaggregate)
* Customization: inpatient visit type name*/

WITH active_patients AS (
	SELECT
		pvdd.visit_type_name AS visit_type, 
		pvdd.visit_start_date::date AS visit_start_date,
		CASE
			WHEN pvdd.visit_end_date NOTNULL THEN pvdd.visit_end_date::date
			ELSE CURRENT_DATE 
		END AS visit_end_date
	FROM patient_visit_details_default AS pvdd
/*The visit_type_name should be set to the visit type name used for inpatient visits with the EMR.*/
	WHERE pvdd.visit_type_name = 'Hospital'
	ORDER BY pvdd.visit_start_date),
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
	day_range.day as reporting_day
	sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions,
	CASE
	    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL
	    THEN 0
	    ELSE sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
	END AS cumulative_exits, 
	CASE
	    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL 
		THEN sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
	    ELSE (sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
	END AS active_patients
FROM day_range
LEFT OUTER JOIN daily_admissions ON day_range.day = daily_admissions.day
LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.day
