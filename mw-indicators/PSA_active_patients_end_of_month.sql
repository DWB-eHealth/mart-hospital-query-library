WITH intake AS (
	SELECT 
		patient_id, date_recorded AS date_enrolled, DENSE_RANK () OVER (PARTITION BY patient_id ORDER BY date_recorded) AS initial_enrollment_order, LEAD (date_recorded) OVER (PARTITION BY patient_id ORDER BY date_recorded) AS next_enrollment_date
	FROM "16_counsellor_assessment"),
active_patients AS (
	SELECT
		i.date_enrolled, coalesce(date_discharge, CURRENT_DATE) AS date_discharged
	FROM intake i 
	FULL OUTER JOIN (SELECT patient_id, date_of_discharge AS date_discharge FROM "18_counsellor_discharge") d
		ON i.patient_id = d.patient_id AND d.date_discharge >= i.date_enrolled AND (d.date_discharge < i.next_enrollment_date OR i.next_enrollment_date IS NULL)),
range_values AS (
	SELECT 
		date_trunc('day', min(ap.date_enrolled::date)) AS minval,
		date_trunc('day', max(ap.date_discharged::date)) AS maxval
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
		date_trunc('day', ap.date_discharged) AS day,
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
	LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.day)
SELECT 
	dap.reporting_day,
	dap.active_patients
FROM daily_active_patients dap
WHERE dap.last_day_of_month = 1 
GROUP BY dap.reporting_day, dap.active_patients