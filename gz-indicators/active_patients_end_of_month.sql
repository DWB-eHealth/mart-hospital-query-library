WITH active_patients AS (
	SELECT
		ppdd.date_enrolled::date,
		CASE
			WHEN ppdd.date_completed IS NOT NULL THEN ppdd.date_completed::date
			ELSE CURRENT_DATE 
		END AS date_completed 
	FROM patient_program_data_default ppdd
	WHERE ppdd.voided = 'false'
	ORDER BY ppdd.date_enrolled),
active_patients_trauma AS (
	SELECT
		ppdd.date_enrolled::date,
		CASE
			WHEN ppdd.date_completed IS NOT NULL THEN ppdd.date_completed::date
			ELSE CURRENT_DATE 
		END AS date_completed 
	FROM patient_program_data_default ppdd
	WHERE ppdd.voided = 'false' AND ppdd.program_id = 1
	ORDER BY ppdd.date_enrolled),
active_patients_burn AS (
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
daily_enrollments_trauma AS (
	SELECT 
		date_trunc('day', apt.date_enrolled) AS day,
		count(*) AS patients
	FROM active_patients_trauma AS apt
	GROUP BY 1),
daily_enrollments_burn AS (
	SELECT 
		date_trunc('day', apb.date_enrolled) AS day,
		count(*) AS patients
	FROM active_patients_burn AS apb
	GROUP BY 1),
daily_exits_trauma AS (
	SELECT
		date_trunc('day', apt.date_completed) AS day,
		count(*) AS patients
	FROM active_patients_trauma AS apt
	GROUP BY 1),
daily_exits_burn AS (
	SELECT
		date_trunc('day', apb.date_completed) AS day,
		count(*) AS patients
	FROM active_patients_burn AS apb
	GROUP BY 1),
daily_active_patients AS (
	SELECT 
		day_range.day as reporting_day,
		sum(daily_enrollments_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions_trauma,
		CASE
		    WHEN sum(daily_exits_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL
		    THEN 0
		    ELSE sum(daily_exits_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
		END AS cumulative_exits_trauma, 
		CASE
		    WHEN sum(daily_exits_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL 
			THEN sum(daily_enrollments_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_enrollments_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-
				sum(daily_exits_trauma.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS active_patients_trauma,
		sum(daily_enrollments_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions_burn,
		CASE
		    WHEN sum(daily_exits_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL
		    THEN 0
		    ELSE sum(daily_exits_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
		END AS cumulative_exits_burn,
		CASE
		    WHEN sum(daily_exits_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL 
			THEN sum(daily_enrollments_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_enrollments_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-
				sum(daily_exits_burn.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS active_patients_burn,
		CASE 
			WHEN date(day_range.day)::date = (date_trunc('MONTH', day_range.day) + INTERVAL '1 MONTH - 1 day')::date THEN 1
		END AS last_day_of_month
	FROM day_range
	LEFT OUTER JOIN daily_enrollments_trauma ON day_range.day = daily_enrollments_trauma.day
	LEFT OUTER JOIN daily_exits_trauma ON day_range.day = daily_exits_trauma.day
	LEFT OUTER JOIN daily_enrollments_burn ON day_range.day = daily_enrollments_burn.day
	LEFT OUTER JOIN daily_exits_burn ON day_range.day = daily_exits_burn.day)
SELECT 
	dap.reporting_day,
	dap.active_patients_burn,
	dap.active_patients_trauma,
	sum(dap.active_patients_trauma+dap.active_patients_burn) AS active_patients_total
FROM daily_active_patients dap
WHERE dap.last_day_of_month = 1 and dap.reporting_day > date_trunc('MONTH', CURRENT_DATE) - INTERVAL '1 year'
GROUP BY dap.reporting_day, dap.active_patients_trauma, dap.active_patients_burn