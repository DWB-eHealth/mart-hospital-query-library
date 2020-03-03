<h2>Bed Occupancy Rate Queries</h2>

Bed Occupancy Rate (BOR) is a core hospital indicator for inpatient services. This indicator is used to provide information on the functional ability of the facility and efficient use of resources within the facility. 

Depending on the configuration of the Bed Management module within Bahmni and the use of this module overtime, there are a couple variations in BOR SQL queries that are possible. Below is a summary of these possible variations and when to use each. All queries use the same standard formula:

>{**inpatient service days**} * 100 / {**inpatient bed count days**}

>**inpatient service days**: sum of hospitalized patients per day during reporting period

>**inpatient bed count days**: sum of beds per day of reporting period

<h4>List of Possible BOR Queries</h4>
  <h5>dataTable_BOR_dynamic.sql / dataTable_BOR_static.sql</h5>
  <ul>
  <li>bed occupancy rate per reporting period for all inpatient services within a facility</li>
  <li>useful if you want to calculate BOR for all ward configured within the bed management module</li>
  <li>should not be used for facilities with buffer beds configured (since buffer beds should not be counted unless in use)</li>
  </ul>

  <h5>dataTable_BOR_byLocation_dynamic.sql / dataTable_BOR_byLocation_static.sql</h5>
  <ul>
  <li>bed occupancy rate per location and reporting period for specific wards within a facility </li>
  <li>useful if you want to calculate BOR for a specific ward or wards confirgured within the bed management module</li>
  <li>does not include buffer beds</li>
  </ul>

  <h5>dataTable_BOR_byLocation_+buffer_dynamic.sql / dataTable_BOR_byLocation_+buffer_static.sql</h5>
  <ul>
  <li>bed occupancy rate per location and reporting period for specific wards within a facility </li>
  <li>useful if you want to calculate BOR for a specific ward or wards confirgured within the bed management module</li>
  <li>does include buffer beds in calculation when buffer bed is in use</li>
  </ul>

<h4>Dynamic vs. Static</h4>
In most cases the *dynamic* query should be used. Only when the number of configured beds has changed for an implementation, should the *static* versions of the BOR queries be used.
