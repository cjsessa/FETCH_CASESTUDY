

<img align="left" src="Images/FETCH_LOGO.png" width="150">

# Fetch Case Study
*Prepared by Candice Sessa-Filar*

Purpose:
- Identify top 5 brands by sales among users that have had their account for at least six months
- Identify the top 5 brands by receipts scanned among users 21 and over
- What percent has Fetch grown year over year?



## Project Components
### Data Prep

The data is prepared using [Google Bigquery SQL server](https://console.cloud.google.com/bigquery?_gl=1*jn7tsk*_up*MQ..&gclid=Cj0KCQiA4-y8BhC3ARIsAHmjC_EE14TGQbo-E56maD4ynLhGnPWKppRGaeeMUQg4dJahCBG7n2z2NG4aAqMDEALw_wcB&gclsrc=aw.ds&project=zeta-matrix-337222) (GBQ.)

The repo is broken up into 3 folders:
* Code
  * SQL code used for data preparation (code file is heavily annotated with assumptions + process)
* Images
  * Fetch Logo used for Readme + Tableau
* Data
  * 3 sources provided from Fetch
  * 2 exports used for Tableau Public
  * 1 source is provided in GBQ server (State Codes>Lat/Lon)

Note: we found very few matches between Transaction data & User data resulting in small sample sets for Questions 1 + 2, analysis would benefit from having additional data points

### Data Viz

[Visualizations prepared using Tableau Public](https://public.tableau.com/views/FetchUserCaseStudy/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link). Typically, we would link GBQ directly to Tableau but this feature is only available in Tableau Desktop, so we export the two data tables from GBQ then manually upload to Tableau



![Tableau Dashboard](Images/TableauViz.png)
 


