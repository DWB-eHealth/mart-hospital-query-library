WITH active_patients AS (
	SELECT
		ppdd.date_enrolled::date,
		CASE
			WHEN ppdd.date_completed IS NOT NULL THEN ppdd.date_completed::date
			ELSE CURRENT_DATE 
		END AS date_completed 
	FROM patient_program_data_default ppdd
	WHERE ppdd.voided = 'false' AND ppdd.program_id = 2
	ORDER BY ppdd.date_enrolled),
range_values AS (
	SELECT 
		date_trunc('day',min(ap.date_enrolled)) AS minval,
		date_trunc('day',max(ap.date_completed)) AS maxval
	FROM active_patients ap),
day_range AS (
	SELECT 
		generate_series(minval,maxval,'1 day'::interval) as day
	FROM range_values),   
daily_enrollments AS (
	SELECT 
		date_trunc('day', ap.date_enrolled) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1),
daily_exits AS (
	SELECT
		date_trunc('day', ap.date_completed) AS day,
		count(*) AS patients
	FROM active_patients AS ap
	GROUP BY 1),
daily_active_patients AS (
	SELECT 
		day_range.day as reporting_day,
		sum(daily_enrollments.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions,
		CASE
		    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL
		    THEN 0
		    ELSE sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
		END AS cumulative_exits, 
		CASE
		    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL 
			THEN sum(daily_enrollments.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_enrollments.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-
				sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS active_patients,
		CASE 
			WHEN date(day_range.day)::date = (date_trunc('MONTH', day_range.day) + INTERVAL '1 MONTH - 1 day')::date THEN 1
		END AS last_day_of_month
	FROM day_range
	LEFT OUTER JOIN daily_enrollments ON day_range.day = daily_enrollments.day
	LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.DAY)
SELECT 
	dap.reporting_day,
	dap.active_patients
FROM daily_active_patients dap
WHERE dap.last_day_of_month = 1