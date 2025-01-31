/*==================================================================================================
-------------------------------------- FETCH CASE STUDY -----------------------------------------------

Created Date: 1/29/2024              Created By: Candice Filar
Last Updated:                        Updated By: 

Purpose:
    1)What are the top 5 brands by sales among users that have had their account for at least six months?
    2)Identify the top 5 brands by receipts scanned among users 21 and over
    3)What percent has Fetch grown year over year?

Steps/Tables Within: 
        TEMP TABLE | CLEAN BASE: RECEIPT_ID level of detail
            1 - cleans final sale + final quantity entries
                removing text & converting to float using regex,
                removes duplicate entries to only the highest FINAL_SALE for a given Receipt/Barcode
            2- Joins transaction data into products table to get a flat view of brands + quantity/price
            3- Joins User data & created 
        
        Calculation 1 | Top 5 brands by sales among users that have had their account for at least six months

            Use CLEAN BASE table, filtering for USERS with an account older than 6 months
            The final output provides the the top 5 brands ranked 1 time for highest dollar sales, missing data are
            number of imputed lines & total orders are number of lines
        
        Calculation 2 | Identify the top 5 brands by receipts scanned among users 21 and over 

            Using CLEAN BASE table, filtering for USERS with an age >= 21
            final output shows number of unique transactions 

        Calculation 3 | What percent has Fetch grown year over year

            We use Tableau & visual analytics to answer this question. To prep the data we pull our CLEAN BASE & 
            calculate YoY growth at the Year/State level, calculating number of users 

            The data is shaped once in a wide format and a second in long format, this is necessary for the variety
            of Tableau Views created in the dashboard
                            
Assumptions:
    1) We assume that Receipt ID + Barcode makes a row unique in Transaction table, we find the highest price for a given row
    2) We define Final Sale as Unit Price * Final Quantity
    4) We assume Calculation 2 will look at the unqiue number of receipts versus the total number (i.e. receipt/barcode)
    5) The latest date in the dataset is 2024-06-12, we assume this is 'Today'

Notes: We do not have many matches between our Transaction Table & our User ID table for Users with demographic info (Gender/State), final analysis as < 100 entries

Enhancements: We see a decline in Users YoY, better analysis would include total purchases to see if the quality of 
User has increased over time
====================================================================================================*/

BEGIN

-- TEMP TABLE | CLEAN BASE: RECEIPT_ID/BARCODE level of detail
CREATE TEMP TABLE CLEAN_BASE AS
(
SELECT  P.CATEGORY_1 AS CATEGORY
    ,P.BRAND
    ,T.*
    ,G.LAT
    ,G.LON
    --ACCT + AGE FILTER FOR Q1 + Q2
    ,IF(DATE_DIFF(MAX_DATE,CAST(U.CREATED_DATE AS DATE),DAY) >= 60,1,0) AS ACCT_FILTER
    --ASSUMING MAX DATE IN DATASET IS 'TODAY'
    ,IF(ROUND(SAFE_DIVIDE(DATE_DIFF(MAX_DATE,CAST(U.BIRTH_DATE AS DATE),DAY),365),2) >= 21,1,0) AS AGE_FILTER
  FROM `couch2coding.FETCH_CASESTUDY.PRODUCTS_TAKEHOME` AS P --BIGGEST TABLE FOR OPTIMAL JOIN
  --PREPPING TRANSACTION DATA
  INNER JOIN 
    (
      SELECT RECEIPT_ID
        ,USER_ID
        ,PURCHASE_DATE
        ,BARCODE
        ,MAX(PURCHASE_DATE) AS MAX_DATE
            --DATA IS NUMERICAL BUT THERE ARE CHARACTERS IN COLUMN TURNING IT TO STRING, 
            --REMOVING CHARACTERS THEN CONVERTING TO NUMBER
            --ANY BLANKS WILL BE REPLACED WITH A NULL VALUE, WE WILL IMPUTE BASED ON HISTORY
        ,MAX(SAFE_CAST(REGEXP_REPLACE(T.FINAL_QUANTITY,r'[^0-9.]', '') AS FLOAT64)) AS FINAL_QUANTITY
        ,MAX(SAFE_CAST(REGEXP_REPLACE(T.FINAL_SALE,r'[^0-9.]', '') AS FLOAT64)) AS FINAL_SALE
      FROM `couch2coding.FETCH_CASESTUDY.TRANSACTION_TAKEHOME` AS T
      GROUP BY ALL
    ) AS T
    ON P.BARCODE = T.BARCODE
  --GATHERING USER DATA
  LEFT JOIN `couch2coding.FETCH_CASESTUDY.USER_TAKEHOME` AS U
    ON t.USER_ID = U.ID
  --USING BQ PUBLIC DATA TO GATHER A LAT/LON FOR TABLEAU VIEW
  LEFT JOIN
      (
        SELECT STATE_NAME 
          ,STATE_CODE 
          ,MAX(internal_point_lat) AS LAT
          ,MAX(internal_point_lon) AS LON
        FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
        GROUP BY ALL
      ) AS G
    ON UPPER(U.STATE) = UPPER(G.STATE_CODE)
);


-- Calculation 1 | Top 5 brands by sales among users that have had their account for at least six months
-- the final output provides the the top 5 brands ranked 1 time for highest dollar sales, missing data are number of barcodes
(

    SELECT *
    ,RANK() OVER(ORDER BY TOT_SALES DESC) AS SALES_RANK
    FROM  
    (
        SELECT BRAND
        ,COUNT(*) AS TOT_ORDS
        ,ROUND(SUM(FINAL_SALE),2) AS TOT_SALES
        FROM CLEAN_BASE --Use CLEAN_BASE table, filtering for USERS with an account older than 6 months
        WHERE ACCT_FILTER = 1 
        GROUP BY ALL
    )
    QUALIFY SALES_RANK <= 5
    ORDER BY SALES_RANK
);
-- Calculation 2 | Identify the top 5 brands by receipts scanned among users 21 and over 
-- final output shows number of UNIQUE transactions by brand
(
    SELECT *
        ,RANK() OVER(ORDER BY N_RECEIPTS DESC) AS RECEIPT_RANK
    FROM
        (
            SELECT BRAND
                ,COUNT(DISTINCT RECEIPT_ID) AS N_RECEIPTS
            FROM CLEAN_BASE
            WHERE AGE_FILTER = 1 --filtering for USERS with an age >= 21
            GROUP BY ALL
        )
    QUALIFY RECEIPT_RANK <= 5
    ORDER BY RECEIPT_RANK
);

/*
========================Q3 DATA SETS=================================
TABLEAU PUBLIC DOES NOT ALLOW LINK TO GBQ (ONLY TABLEAU DESKTOP), WILL
MANUALLY EXPORT INTO CSV FILES TO UPLOAD TO TABLEAU
*/

-------PULLING YOY DATA WIDE VIEW
CREATE TEMP TABLE DATA_WIDE AS
(
  WITH BASE AS 
    (
      SELECT EXTRACT(YEAR FROM CREATED_DATE) AS YEAR
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 1 YEAR)) AS LY
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 2 YEAR)) AS LLY
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 3 YEAR)) AS LLLY
        ,LAT
        ,LON
        ,IF(STATE IS NULL,'MISSING',STATE) AS STATE_ADJ
        ,COUNT(ID) AS N_USERS
        ,AVG(DATE_DIFF(CURRENT_DATE(),DATE(BIRTH_DATE), YEAR)) AS AGE
        
      FROM `couch2coding.FETCH_CASESTUDY.USER_TAKEHOME` AS U
          LEFT JOIN
        (
          SELECT STATE_NAME 
            ,STATE_CODE 
            ,MAX(internal_point_lat) AS LAT
            ,MAX(internal_point_lon) AS LON
          FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
          GROUP BY ALL
        ) AS G
        ON UPPER(U.STATE) = UPPER(G.STATE_CODE)
      GROUP BY ALL
    )
  SELECT CY.*
    ,LY.N_USERS AS LY_USERS
    ,LY.AGE AS LY_AGE
    ,LLY.N_USERS AS LLY_USERS
    ,LLY.AGE AS LLY_AGE
    ,LLLY.N_USERS AS LLLY_USERS
    ,LLLY.AGE AS LLLY_AGE
  FROM BASE AS CY
  LEFT JOIN BASE AS LY
    ON CY.LY = LY.YEAR
    AND CY.STATE_ADJ = LY.STATE_ADJ
    AND CY.LON = LY.LON
    AND CY.LAT = LY.LAT
  LEFT JOIN BASE AS LLY
    ON CY.LLY = LLY.YEAR
    AND CY.STATE_ADJ = LLY.STATE_ADJ
    AND CY.LON = LLY.LON
    AND CY.LAT = LLY.LAT
  LEFT JOIN BASE AS LLLY
    ON CY.LLLY = LLLY.YEAR
    AND CY.STATE_ADJ = LLLY.STATE_ADJ
    AND CY.LON = LLLY.LON
    AND CY.LAT = LLLY.LAT
);

------PULLING YOY DATA LONG VIEW
CREATE TEMP TABLE DATA_LONG AS
(
  WITH BASE AS 
    (
      SELECT EXTRACT(YEAR FROM CREATED_DATE) AS YEAR
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 1 YEAR)) AS LY
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 2 YEAR)) AS LLY
        ,EXTRACT(YEAR FROM DATE_SUB(CAST(CREATED_DATE AS DATE),INTERVAL 3 YEAR)) AS LLLY
        ,LAT
        ,LON
        ,IF(STATE IS NULL,'MISSING',STATE) AS STATE_ADJ
        ,COUNT(ID) AS N_USERS
        ,AVG(DATE_DIFF(CURRENT_DATE(),DATE(BIRTH_DATE), YEAR)) AS AGE
      FROM `couch2coding.FETCH_CASESTUDY.USER_TAKEHOME` AS U
          LEFT JOIN
        (
          SELECT STATE_NAME 
            ,STATE_CODE 
            ,MAX(internal_point_lat) AS LAT
            ,MAX(internal_point_lon) AS LON
          FROM `bigquery-public-data.geo_us_boundaries.zip_codes`
          GROUP BY ALL
        ) AS G
        ON UPPER(U.STATE) = UPPER(G.STATE_CODE)
      GROUP BY ALL
    )

  SELECT 'CURRENT YEAR' AS TYPE 
    ,BASE.YEAR
    ,BASE.LAT
    ,BASE.LON
    ,BASE.STATE_ADJ
    ,BASE.N_USERS
    ,BASE.AGE
  FROM BASE

  UNION ALL

  SELECT 'LY' AS TYPE 
    ,LY.YEAR
    ,LY.LAT
    ,LY.LON
    ,LY.STATE_ADJ
    ,LY.N_USERS
    ,LY.AGE
  FROM BASE AS CY
  LEFT JOIN BASE AS LY
    ON CY.LY = LY.YEAR
    AND CY.STATE_ADJ = LY.STATE_ADJ
    AND CY.LON = LY.LON
    AND CY.LAT = LY.LAT

  UNION ALL

  SELECT 'LLY' AS TYPE 
    ,LY.YEAR
    ,LY.LAT
    ,LY.LON
    ,LY.STATE_ADJ
    ,LY.N_USERS
    ,LY.AGE
  FROM BASE AS CY
  LEFT JOIN BASE AS LY
    ON CY.LLY = LY.YEAR
    AND CY.STATE_ADJ = LY.STATE_ADJ
    AND CY.LON = LY.LON
    AND CY.LAT = LY.LAT

  UNION ALL

  SELECT 'LLLY' AS TYPE 
    ,LY.YEAR
    ,LY.LAT
    ,LY.LON
    ,LY.STATE_ADJ
    ,LY.N_USERS
    ,LY.AGE
  FROM BASE AS CY
  LEFT JOIN BASE AS LY
    ON CY.LLLY = LY.YEAR
    AND CY.STATE_ADJ = LY.STATE_ADJ
    AND CY.LON = LY.LON
    AND CY.LAT = LY.LAT
);
END;


