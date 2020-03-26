## Summary of Data Tables for HT Bahmni-Mart
#### dataTable_urgences
This data table can be used to count emergency department visits and can be disaggregated by age, sex and patient origin.

#### dataTable_admissions
This data table can be used to count admissions and discharges to the entire hospital. It can also be used to calculate average length of stay. These indicators can be disaggregated by age, sex and patient origin. There are also columns for the location of admission and location of discharge to look at where patients first enter the hospital and where they exist the hospital from.

#### dataTable_admissionsParService
This data table can be used to calculate admissions to each service and the average length of stay within each service. These indicators can be disaggregated by sex and patient origin. When creating an indicator, filter by service name.

#### dataTable_TOL
This data table calculates bed occupancy rate for the entire hospital. It divides the sum of active patients per day for the reporting period by the sum of available beds per day for the reporting period. The sum of beds removes any beds that are marked as missing in the EMR ('hors service' tag). The reporting period is set to months. There are no disaggregations available within this data table.

#### dataTable_TOL_hospitalisation / dataTable_TOL_soinsIntensifs / dataTable_TOL_serviceBMR
This data table calculates bed occupancy rate for each service. It divides the sum of active patients in the service per day for the reporting period by the sum of available beds in the service per day for the reporting period. The sum of beds removes any beds that are marked as missing in the EMR ('hors service' tag). The reporting period is set to months. There are no disaggregations available within this data table.
