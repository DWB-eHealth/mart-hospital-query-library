 /*ABOUT
* The bed occupancy rate data table calculates the percentage of beds occupied during the reporting period. Each row represents the reporting period defined in the query.
* Bed occupancy rate is based on the inpatient service days (sum of hospitalized patients per day during reporting period) and the bed count days (sum of beds per day of reporting period).
* Bed count days is a sum of standard ward beds, plus any buffer beds currently in use, minus any out-of-service beds.
* Note that this query should only be used if the number of beds configured in the EMR has changed overtime. Otherwise, the dynamic BOR query should be used. 

* Variables: reporting period, bed occupancy rate
* Possible indicators: Bed occupancy rate for a location per reporting period
* Possible disaggregation: location
* Customization: inpatient location names (row 22), buffer bed location name (rew 34), out-of-service tag name (row 45), out-of-service bed locations (row 47), static bed count and time frame (rows 108), bed count locations (row 113), reporting period unit (weeks, months, etc.) (row 132)*/

WITH active_patients AS (
	SELECT
		bmlv.location AS service, 
		bmlv.start_date::date AS service_admission_date, 
		CASE
			WHEN bmlv.start_date NOTNULL THEN bmlv.discharge_date::date
			ELSE CURRENT_DATE 
		END AS service_discharge_date
	FROM bed_management_locations_view AS bmlv
/*The location should be set to the inpatient location the active patient query should calculate.*/
	WHERE bmlv.location = 'Kahramana(1st floor)' OR bmlv.location = 'Kahramana(2nd floor)' OR bmlv.location = 'Buffer Beds'
	ORDER BY bmlv.start_date),
active_buffer_beds AS (
	SELECT
		bmlv.location AS service, 
		bmlv.start_date::date AS service_admission_date, 
		CASE
			WHEN bmlv.start_date NOTNULL THEN bmlv.discharge_date::date
			ELSE CURRENT_DATE 
		END AS service_discharge_date
	FROM bed_management_locations_view AS bmlv
/*The location should be set to the buffer beds for the locations included in the query.*/
	WHERE bmlv.location = 'Buffer Beds'
	ORDER BY bmlv.start_date),
exclude_beds AS (
	SELECT
		btd.date_created::date,
		CASE
			WHEN btd.date_stopped NOTNULL THEN btd.date_stopped::date
			ELSE current_date
		END AS date_stopped
	FROM bed_tags_default AS btd
/*The bed_tag_name should be set to bed tags that should not be counted during the reporting period (e.g. beds that are out-of-service)*/
	WHERE btd.bed_tag_name = 'Lost'
/*The bed_location should match the inpatient location(s) set in line 22*/	
	AND (btd.bed_location = 'Kahramana(1st floor)' OR btd.bed_location = 'Kahramana(2nd floor)')
	ORDER BY btd.date_created),
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
daily_incl_buffer_start AS (
	SELECT 
		date_trunc('day', abb.service_admission_date) AS day,
		count(*) AS started
	FROM active_buffer_beds AS abb
	GROUP BY 1),
daily_incl_buffer_end AS (
	SELECT 
		date_trunc('day',abb.service_discharge_date) AS day,
		count(*) AS stopped
	FROM active_buffer_beds AS abb
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
/*If the number of beds configured within the EMR has changed over time, the number(s) prior to the last change need to be hard-coded. The timeframe and number of beds can be added below.*/
		CASE
			WHEN day_range.day <= '2019-11-01' THEN 53
			ELSE (SELECT
				COUNT (cbdd.bed_id)
			FROM current_bed_details_default AS cbdd
/*The location should be set to the inpatient location the active patient query should calculate. Same as row 22*/
			WHERE cbdd.bed_location = 'Kahramana(1st floor)' OR cbdd.bed_location = 'Kahramana(2nd floor)')
		END AS bed_count,
		CASE
		    WHEN sum(daily_excl_beds_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN sum(daily_excl_beds_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_excl_beds_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_excl_beds_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS missing_beds,
		CASE
		    WHEN sum(daily_incl_buffer_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row) IS NULL THEN sum(daily_incl_buffer_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)
		    ELSE (sum(daily_incl_buffer_start.started) over (order by day_range.day asc rows between unbounded preceding and current row)-sum(daily_incl_buffer_end.stopped) over (order by day_range.day asc rows between unbounded preceding and current row)) 
		END AS active_buffer_beds
	FROM day_range
	LEFT OUTER JOIN daily_admissions ON day_range.day = daily_admissions.day
	LEFT OUTER JOIN daily_exits ON day_range.day = daily_exits.day
	LEFT OUTER JOIN daily_excl_beds_start ON day_range.day = daily_excl_beds_start.day
	LEFT OUTER JOIN daily_excl_beds_end ON day_range.day = daily_excl_beds_end.DAY
	LEFT OUTER JOIN daily_incl_buffer_start ON day_range.day = daily_incl_buffer_start.day
	LEFT OUTER JOIN daily_incl_buffer_end ON day_range.day = daily_incl_buffer_end.day)
SELECT
/*To change the reporting period, 'month' can be changed to another reporting period (e.g. week, quarter, year).*/
	date_trunc('month', reporting_day) AS reporting_period,
/*The two rows below contain the components of the BOR calculation and can be used to check the calcualtion if needed.
	sum(active_patients) AS inpatient_service_days,
	Sum (bed_count) AS bed_count, 
	sum (missing_beds) AS missing_beds, 
	sum(active_buffer_beds) AS buffer,
	sum(bed_count - missing_beds + active_buffer_beds) AS bed_count_days,*/
	(sum(active_patients)/sum(bed_count - missing_beds + active_buffer_beds))*100 AS bed_occupancy_rate
FROM inpatient_survice_days
GROUP BY reporting_period
ORDER BY reporting_period