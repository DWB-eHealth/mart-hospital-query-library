/*ABOUT
 * Since it is not possible to calculate medians within Metabase - we have to use SQL to do so.
 * This query calculates a median based on numeric values found in a form table. 
 * The same syntax can be used for other tables or data tables as well.

 * Variables: period, median value
 * Possible indicators: Median value for reporting period
 * Possible disaggregation: none
 * Customization: table and variable names and references should be updated as needed, reporting period unit (weeks, months, etc.) (row 16)*/

SELECT
	record_month,
	ROUND(AVG(bmi), 2) AS median_bmi
FROM (SELECT
/*To change the reporting period, 'month' can be changed to another reporting period (e.g. week, quarter, year)*/
		DATE_TRUNC('Month', vs.vs_date_recorded) AS record_month,
		vs.bmi,
		ROW_NUMBER() OVER (PARTITION BY (DATE_TRUNC('Month', vs.vs_date_recorded)) ORDER BY vs.bmi, vs.patient_id) AS rows_ascending,
		ROW_NUMBER() OVER (PARTITION BY (DATE_TRUNC('Month', vs.vs_date_recorded)) ORDER BY vs.bmi DESC, vs.patient_id DESC) AS rows_descending
	FROM vital_signs AS vs) AS mm
WHERE rows_ascending BETWEEN rows_descending - 1 AND rows_descending + 1
GROUP BY record_month
ORDER BY record_month
