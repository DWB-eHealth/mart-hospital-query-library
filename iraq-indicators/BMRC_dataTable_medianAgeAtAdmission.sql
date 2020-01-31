/*ABOUT
 * The median age data table calcualtes the median age of patients admitted during the reporting period. 
 * The reporting period is set to be monthly - to modify this query will need to be customized. 
 
 * Variables: visit period, median age
 * Possible indicators: Median age of admitted patients per reporting period
 * Possible disaggregation: none
 * Customization: none*/

SELECT
	visit_period,
	ROUND(AVG(age),2) AS median_age
FROM (SELECT
		DISTINCT ON (pvev.person_id, pvev.visit_id) date_trunc('Month', pvev.visit_start_date) AS visit_period,
		pvev.age_at_visit::int AS age,
		ROW_NUMBER() OVER (PARTITION BY (DATE_TRUNC('Month', pvev.visit_start_date)) ORDER BY pvev.age_at_visit, pvev.person_id) AS rows_ascending,
		ROW_NUMBER() OVER (PARTITION BY (DATE_TRUNC('Month', pvev.visit_start_date)) ORDER BY pvev.age_at_visit DESC, pvev.person_id DESC) AS rows_descending
	FROM patient_visits_encounters_view AS pvev
	WHERE pvev.visit_type = 'OPD') AS foo
WHERE rows_ascending BETWEEN rows_descending - 1 AND rows_descending + 1
GROUP BY visit_period
ORDER BY visit_period