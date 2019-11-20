 /*ABOUT
* The bed occupancy rate data table calculates the percentage of beds occupied during the reporting period. Each row represents the reporting period defined in the query.
* Bed occupancy rate is based on the inpatient service days (sum of hospitalized patients per day during reporting period) and the bed count days (sum of beds per day of reporting period).
* Note that this query should only be used if the number of beds has changed overtime. Otherwise, the dynamic BOR query should be used. 

* Variables: reporting period, bed occupancy rate
* Possible indicators: Bed occupancy rate for the facility per reporting period
* Possible disaggregation: none (to disaggregate by service, the dataTable_BOR_byLocation.sql should be used)
* Customization: inpatient visit type name (row 20), missing bed tag name (row 32), static bed count and time frame (rows 81-82), reporting period unit (weeks, months, etc.) (row 96)*/

WITH active_patients AS (
	SELECT
		pvdd.visit_type_name AS visit_type_name, 
		pvdd.visit_start_date::date AS visit_start_date,
		CASE
			WHEN pvdd.visit_end_date NOTNULL THEN pvdd.visit_end_date::date
			ELSE CURRENT_DATE 
		END AS visit_end_date
	FROM patient_visit_details_default AS pvdd
/*The visit_type_name should be set to the visit type name used for inpatient visits with the EMR.*/
	WHERE pvdd.visit_type_name = 'Hospital'
	ORDER BY pvdd.visit_start_date),
exclude_beds AS (
	SELECT
		btd.date_created::date,
		CASE
			WHEN btd.date_stopped NOTNULL THEN btd.date_stopped::date
			ELSE current_date
		END AS date_stopped
	FROM bed_tags_default AS btd
/*The bed_tag_name should be set to bed tags of beds that should not be counted during the reporting period*/
	WHERE btd.bed_tag_name = 'Lost'
	ORDER BY btd.date_created),
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
	GROUP BY 1),
daily_excl_beds_start AS (
	SELECT 
		date_trunc('day',eb.date_created) AS day,
		count(*) AS started
	FROM exclude_beds AS eb
	GROUP BY 1),
daily_excl_beds_end AS (
	SELECT 
		date_trunc('day',eb.date_stopped) AS day,
		count(*) AS stopped
	FROM exclude_beds AS eb
	GROUP BY 1),
inpatient_survice_days AS (
	SELECT 
		day_range.day as reporting_day,
		sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row) AS cumulative_admissions,
		CASE
		    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN 0
		    ELSE sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) 
		END AS cumulative_exits, 
		CASE
		    WHEN sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_admissions.patients) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_exits.patients) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS active_patients,
/*If the number of beds that have been set up within the EMR have changed over time, the number during each period needs to be coded into the query. The timeframe and number of beds can be added below.*/
		CASE
			WHEN day_range.day BETWEEN '2019-11-01' AND CURRENT_date THEN 53
			WHEN day_range.day BETWEEN '2019-01-01' AND '2019-10-31' THEN 55
			ELSE null
		END AS bed_count,
		CASE
		    WHEN sum(daily_excl_beds_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN sum(daily_excl_beds_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_excl_beds_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_excl_beds_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS missing_beds		
	FROM day_range
	LEFT OUTER JOIN daily_admissions ON day_range.day = daily_admissions.day
	LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.day
	LEFT OUTER JOIN daily_excl_beds_start ON day_range.day = daily_excl_beds_start.day
	LEFT OUTER JOIN daily_excl_beds_end ON day_range.day = daily_excl_beds_end.day)
SELECT
/*To change the reporting period, 'month' can be changed to another reporting period (e.g. week, quarter, year)*/
	date_trunc('month', reporting_day) AS reporting_period,
/*The two rows below contain the components of the BOR calculation and can be used to check the calcualtion if needed
	sum(active_patients) AS inpatient_service_days,
	sum(bed_count) AS bed_count_days,*/
	(sum(active_patients)/sum(bed_count-missing_beds))*100 AS bed_occupancy_rate
FROM inpatient_survice_days
GROUP BY reporting_period
ORDER BY reporting_period