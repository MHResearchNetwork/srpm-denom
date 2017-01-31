# Suicide Risk Prediction Model (SRPM)
## Denominator Programming

The [Mental Health Research Network (MHRN)](http://hcsrn.org/mhrn/en/) Suicide Risk Prediction Model (SRPM) encompasses the following major programming tasks:

1. **Identify denominator (SAS)**
    1. Recommended: Perform QA on PHQ item #9 data (SAS)
2. Create analytic data set (SAS)
3. Implement model (R)

In addition to this README, the srpm-denom repository contains the following materials that were used to perform task 1 within the MHRN.

* **SAS program:** SRPM_DENOM.sas
    * **Details:** Developed in SAS v9.4 for use in the [HCSRN VDW](http://www.hcsrn.org/en/Tools%20&%20Materials/VDW/) programming environment
    * **Purpose:** Identifies a VDW-based denominator of internal (i.e., [Epic](http://www.epic.com)-based) adult outpatient clinic visits that occurred between January 1, 2009 (or date of local Epic implementation, whichever happened more recently) and June 20, 2015 and were associated with one or more of the following: 1) mental health department, 2) mental health specialty provider, 3) psychotherapy procedures, or 4) selected mental health diagnoses. The program summarizes unique encounters by each of the four methods of inclusion (i.e., department, provider, procedure, or diagnosis) to facilitate review within and across participating sites.
    * **Input VDW data sets:** Demographic, Dx, Encounter, Provider Specialty, Px
    * **Dependencies:** StdVars.sas; local modifications to identify internal, Epic-based encounters
    * **Output files:**
        * /LOCAL/SRPM_DENOM_SITE.log – SAS log file (where SITE = local implementation of VDW StdVars &_siteabbr macro variable)
        * /LOCAL/SRPM_DENOM_SUM_SITE.pdf - Table for local review
        * /LOCAL/SRPM_DENOM_FULL_SITE.sas7bdat - Full utilization data set for use in subsequent SRPM tasks.
        * /RETURN/SRPM_DENOM_SUM_SITE.sas7bdat - Data set version of the PDF file above, originally intended for return to lead site. Small cell sizes suppressed per local implementation of VDW StdVars &lowest_count macro variable; totals not displayed.
* **Subdirectory /LOCAL:** Stores SAS log, PDF file, and full denominator data set for local use
* **Subdirectory /RETURN:** Stores summary SAS data set, which was originally intended for return to lead site

The basic procedure to generate the SRPM denominator is as follows:

1. Extract repository contents to local directory of choice
2. Open SRPM_DENOM.sas and:
    1. Complete initial %include and %let statements as directed in program header.
    2. Make necessary modifications in relevant sections to restrict to denominator to internal, Epic-based visits.
        * Tip: Ctrl+F "LOCAL CODE" to find relevant sections.
3. Submit modified program.
4. After program execution is complete, ensure that aforementioned log, PDF, and sas7bdat files have been output to the appropriate subdirectories.
5. Review /LOCAL/SRPM_DENOM_SITE.log for errors.
6. If log file is clean, review /LOCAL/SRPM_DENOM_SUM_SITE.pdf to understand the contents of your SRPM denominator.
    * E.g., what is the mix of mental health specialty vs. primary care (Dx only) visits?
