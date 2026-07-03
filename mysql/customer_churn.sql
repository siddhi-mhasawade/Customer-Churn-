-- DATABASE: churn_prediction
-- TABLE: customers_train
-- PURPOSE: Exploration and Feature Engineering
-- ===============================================

-- 1 Use the database
USE churn_prediction;

-- 2 Preview the table
SHOW TABLES;
SELECT * FROM customers_train LIMIT 10;

-- 3 Data Exploration
-- Total customers
SELECT COUNT(*) AS total_customers
FROM customers_train;

-- Total churned customers
SELECT COUNT(*) AS churned_customers
FROM customers_train
WHERE Churn = 'Yes';

-- Churn rate percentage
SELECT ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS churn_rate_percent
FROM customers_train;

-- Table structure
DESCRIBE customers_train;

-- Count missing or null values
SELECT
    SUM(CASE WHEN CustomerID IS NULL OR CustomerID = '' THEN 1 ELSE 0 END) AS customerID_nulls,
    SUM(CASE WHEN Gender IS NULL OR Gender = '' THEN 1 ELSE 0 END) AS gender_nulls,
    SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS tenure_nulls,
    SUM(CASE WHEN MonthlyCharges IS NULL THEN 1 ELSE 0 END) AS monthlycharges_nulls,
    SUM(CASE WHEN Contract IS NULL OR Contract = '' THEN 1 ELSE 0 END) AS contract_nulls,
    SUM(CASE WHEN PaymentMethod IS NULL OR PaymentMethod = '' THEN 1 ELSE 0 END) AS paymentmethod_nulls,
    SUM(CASE WHEN TotalCharges IS NULL THEN 1 ELSE 0 END) AS totalcharges_nulls,
    SUM(CASE WHEN Churn IS NULL OR Churn = '' THEN 1 ELSE 0 END) AS churn_nulls
FROM customers_train;

-- 4 Demographic Analysis
-- Churn by Gender
SELECT Gender,
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
       ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS churn_rate_percent
FROM customers_train
GROUP BY Gender;


-- 5 Contract & Payment Analysis
-- Churn by Contract
SELECT Contract,
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
       ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS churn_rate_percent
FROM customers_train
GROUP BY Contract;

-- Churn by Payment Method
SELECT PaymentMethod,
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
       ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS churn_rate_percent
FROM customers_train
GROUP BY PaymentMethod;

-- 6 Billing Analysis
-- Average Monthly Charges
SELECT ROUND(AVG(MonthlyCharges),2) AS avg_monthly_charges
FROM customers_train;

-- Average Monthly Charges by Churn
SELECT Churn, ROUND(AVG(MonthlyCharges),2) AS avg_monthly_charges
FROM customers_train
GROUP BY Churn;

-- Average Total Charges by Churn
SELECT Churn, ROUND(AVG(TotalCharges),2) AS avg_total_charges
FROM customers_train
GROUP BY Churn;

-- 7 Tenure Analysis
-- Average Tenure
SELECT ROUND(AVG(Tenure),2) AS avg_tenure
FROM customers_train;

-- Average Tenure by Churn
SELECT Churn, ROUND(AVG(Tenure),2) AS avg_tenure
FROM customers_train
GROUP BY Churn;

-- Tenure buckets for feature engineering
SELECT 
    CASE 
        WHEN Tenure <= 12 THEN '0-12 months'
        WHEN Tenure <= 24 THEN '13-24 months'
        WHEN Tenure <= 48 THEN '25-48 months'
        WHEN Tenure <= 60 THEN '49-60 months'
        ELSE '61+ months'
    END AS tenure_group,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END) AS churned,
    ROUND(SUM(CASE WHEN Churn='Yes' THEN 1 ELSE 0 END)/COUNT(*)*100,2) AS churn_rate_percent
FROM customers_train
GROUP BY tenure_group
ORDER BY tenure_group;

-- 8 Feature Engineering
-- High Monthly Charges Flag
ALTER TABLE customers_train ADD COLUMN HighChargeFlag TINYINT(1) DEFAULT 0;

-- 1 Turn off safe update mode 
SET SQL_SAFE_UPDATES = 0; -- Temporarily disabling safe update mode to allow batch update for feature engineering

-- 2 Run the update
UPDATE customers_train
SET HighChargeFlag = 1
WHERE MonthlyCharges > 80;

-- 3 Turn safe update mode back on
SET SQL_SAFE_UPDATES = 1;

-- Combine Tenure and Contract
ALTER TABLE customers_train ADD COLUMN TenureContract VARCHAR(20);

UPDATE customers_train
SET TenureContract = CONCAT(
    CASE 
        WHEN Tenure <= 12 THEN '0-12'
        WHEN Tenure <= 24 THEN '13-24'
        WHEN Tenure <= 48 THEN '25-48'
        WHEN Tenure <= 60 THEN '49-60'
        ELSE '61+'
    END,
    '_',
    Contract
);

-- 9 Top / Outlier Analysis
-- Customers with highest monthly charges who churned
SELECT CustomerID, MonthlyCharges, Churn
FROM customers_train
WHERE Churn='Yes'
ORDER BY MonthlyCharges DESC
LIMIT 10;

-- Customers with short tenure who churned
SELECT CustomerID, Tenure, Churn
FROM customers_train
WHERE Churn='Yes' AND Tenure <= 6
ORDER BY Tenure ASC
LIMIT 10;

