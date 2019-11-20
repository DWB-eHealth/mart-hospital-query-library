/*ABOUT
* The active patients data table calculates the number of patients active within a service during the reporting period. Each row represents a day and patient counts at the end of each day.

* Variables: reporting day, cumulative admissions, cumulative exits, active patients
* Possible indicators: Active patients within a service per day, average active patients within a service per reporting period
* Possible disaggregation: none
* Customization: inpatient location name*/

WITH active_patients AS (
	SELECT
		bmlv.location AS service, 
		bmlv.start_date::date AS service_admission_date, 
		CASE
			WHEN bmlv.discharge_date NOTNULL THEN bmlv.discharge_date::date
			ELSE CURRENT_DATE 
		END AS service_discharge_date
	FROM bed_management_locations_view AS bmlv
/*The location should be set to the inpatient location the active patient query should calculate.*/
	WHERE bmlv.location = 'Ward'
	ORDER BY bmlv.start_date),
range_values AS (
	SELECT 
		date_trunc('day', min(ap.service_admission_date)) AS minval,
		date_trunc('day', max(ap.service_discharge_date)) AS maxval
	FROM active_patients AS ap),
day_range AS (
	SELECT 
		generate_series(minval,maxval,'1 day'::interval) as day
	FROM range_values),   
daily_admissions AS (
	SELECT 
		date_trunc('day', ap.service_admission_date) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1),
daily_exits AS (
	SELECT
		date_trunc('day',ap.service_discharge_date) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1)
SELECT 
	day_range.day as reporting_period,
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
