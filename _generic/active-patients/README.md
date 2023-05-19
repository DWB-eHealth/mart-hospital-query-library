<h2>Active Patient Queries</h2>

The number of active patients (sometimes referred to as the active cohort) is a core hospital indicator for inpatient services. This indicator is used to provide information on the utilization of resources within the facility.

The active patient query works by taking the difference between the cumulative sum of admissions and the cumulative sum of exits. The calculation provides daily data but can be averaged to a wider reporting period using the analytics tool.

<h4>List of Possible Active Patient Queries</h4>
  <h5>dataTable_activePatients.sql</h5>
  <ul>
  <li>count of active patients per day</li>
  <li>average number of active patients during reporting period</li>
  </ul>

  <h5>dataTable_activePatients_withFilter.sql</h5>
  <ul>
  <li>count of active patients per day by age group, sex, patient origin, etc.</li>
  <li>average number of active patients during reporting period by age group, sex, patient origin</li>
  </ul>

  <h5>dataTable_activePatients_byLocation.sql</h5>
  <ul>
  <li>count of active patients per day by service</li>
  <li>average number of active patients during reporting period by service</li>
  </ul>
