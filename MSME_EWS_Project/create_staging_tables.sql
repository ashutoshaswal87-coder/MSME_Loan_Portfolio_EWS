-- Creating Staging schema and tables

-- stg_customers,
-- stg_loans,
-- stg_repayment_transactions,
-- stg_loan_monthly_snapshot,
-- stg_monthly_bureau_snapshot

DROP SCHEMA stg CASCADE;

SELECT 'Creating Staging Schema...';

CREATE SCHEMA IF NOT EXISTS stg;


SELECT 'Creating Staging Tables...';

CREATE OR REPLACE TABLE stg.stg_customers AS
SELECT
CASE
    WHEN TRIM(customer_id) IS NULL
        THEN 'INVALID CUSTOMER ID'
    ELSE
        TRIM(customer_id)
END AS customer_id,
CASE
    WHEN TRIM(business_name) IS NULL
        THEN 'INVALID BUSINESS NAME'
    ELSE
        TRIM(business_name)
END AS business_name,
CASE
    WHEN TRIM(owner_name) IS NULL
        THEN 'INVALID OWNER NAME'
    ELSE
        TRIM(owner_name)
END AS owner_name,
CASE
    WHEN owner_age <18
        THEN NULL
    ELSE
        owner_age
END AS owner_age,
-- owner age should be minimum 18 years as per Indian law
CASE
    WHEN UPPER(TRIM(owner_gender)) IS NULL
        THEN 'INVALID OWNER GENDER'
    WHEN UPPER(TRIM(owner_gender)) NOT IN ('MALE', 'FEMALE', 'OTHERS')
        THEN 'INVALID OWNER GENDER'
    ELSE
        UPPER(TRIM(owner_gender))
END AS owner_gender,
CASE
    WHEN UPPER(TRIM(msme_segment)) IS NULL
        THEN 'INVALID MSME SEGMENT'
    WHEN UPPER(TRIM(msme_segment)) NOT IN ('MEDIUM', 'SMALL', 'MICRO')
        THEN 'INVALID MSME SEGMENT'
    ELSE
        UPPER(TRIM(msme_segment))
END AS msme_segment,
UPPER(TRIM(industry_sector)) AS industry_sector,
CASE
    WHEN UPPER(TRIM(state)) NOT IN ('ANDHRA PRADESH', 'ARUNACHAL PRADESH', 'ASSAM', 'BIHAR', 'CHHATTISGARH', 'GOA', 'GUJARAT', 'HARYANA', 'HIMACHAL PRADESH', 'JHARKAHND', 'KARNATAKA', 'KERALA', 'MADHYA PRADESH', 'MAHARASHTRA', 'MANIPUR', 'MEGHALAYA', 'MIZORAM', 'NAGALAND', 'ODISHA', 'PUNJAB', 'RAJASTHAN', 'SIKKIM', 'TAMIL NADU', 'TELANGANA', 'TRIPURA', 'UTTAR PRADESH', 'UTTARAKHAND', 'WEST BENGAL', 'ANDAMAN AND NICOBAR ISLANDS', 'CHANDIGARH', 'DADRA AND NAGAR HAVELI', 'DAMAN AND DIU', 'DELHI', 'JAMMU AND KASHMIR', 'LADAKH', 'LAKSHADWEEP', 'PUDUCHERRY')
        THEN 'INVALID STATE'
    ELSE
        UPPER(TRIM(state))
END AS state,
UPPER(TRIM(city)) AS city,
CASE
    WHEN business_vintage_years < 0
        THEN NULL
    ELSE
        business_vintage_years
END AS business_vintage_years,
TRY_CAST(annual_turnover_inr AS DOUBLE) AS annual_turnover_inr,
gst_registered,
udyam_registered,
CASE
    WHEN banking_relationship_years < 0
        THEN NULL
    ELSE
        banking_relationship_years
END AS banking_relationship_years,
TRY_CAST(onboarding_date AS DATE) AS onboarding_date
FROM raw.raw_customers;


CREATE OR REPLACE TABLE stg.stg_loans AS
SELECT
CASE
    WHEN TRIM(loan_id) IS NULL
        THEN 'INVALID LOAN ID'
    ELSE
        TRIM(loan_id)
END AS loan_id,
CASE
    WHEN TRIM(customer_id) IS NULL
        THEN 'INVALID CUSTOMER ID'
    ELSE
        TRIM(customer_id)
END AS customer_id,
CASE
    WHEN UPPER(TRIM(loan_type)) IS NULL
        THEN 'INVALID LOAN TYPE'
    ELSE
        UPPER(TRIM(loan_type))
END AS loan_type,
CASE
    WHEN UPPER(TRIM(loan_purpose)) IS NULL
        THEN 'INVALID LOAN PURPOSE'
    ELSE
        UPPER(TRIM(loan_purpose))
END AS loan_purpose,
CASE
    WHEN UPPER(TRIM(collateral_type)) IS NULL
        THEN 'INVALID COLLATERAL TYPE'
    ELSE
        UPPER(TRIM(collateral_type))
END AS collateral_type,
CASE
    WHEN sanctioned_amount_inr < 0
        THEN NULL    
    ELSE
        TRY_CAST(sanctioned_amount_inr AS DOUBLE)
END AS sanctioned_amount_inr,
CASE
    WHEN disbursed_amount_inr < 0
        THEN NULL
    ELSE
        TRY_CAST(disbursed_amount_inr AS DOUBLE)
END AS disbursed_amount_inr,
TRY_CAST(disbursement_date AS DATE) AS disbursement_date,
CASE
    WHEN tenure_months < 0
        THEN NULL
    ELSE
        tenure_months
END AS tenure_months,
CASE
    WHEN interest_rate_pct < 0 OR interest_rate_pct > 99
        THEN NULL 
    ELSE
        TRY_CAST(interest_rate_pct AS DOUBLE)
END AS interest_rate_pct,
CASE
    WHEN emi_amount_inr < 0
        THEN NULL
    ELSE
        TRY_CAST(emi_amount_inr AS DOUBLE)
END AS emi_amount_inr,
CASE
    WHEN current_dpd < 0
        THEN NULL
    ELSE
        current_dpd
END AS current_dpd,
CASE
    WHEN max_dpd_last_12m < 0
        THEN NULL
    ELSE
        max_dpd_last_12m
END AS max_dpd_last_12m,
TRIM(loan_status) AS loan_status
FROM raw.raw_loans;


CREATE OR REPLACE TABLE stg.stg_repayment_transactions AS
SELECT
CASE
    WHEN TRIM(loan_id) IS NULL
        THEN 'INVALID LOAN ID'
    ELSE
        TRIM(loan_id)
END AS loan_id,
CASE
    WHEN TRIM(customer_id) IS NULL
        THEN 'INVALID CUSTOMER ID'
    ELSE
        TRIM(customer_id)
END AS customer_id,
TRY_CAST(due_date AS DATE) AS due_date,
TRY_CAST(due_amount_inr AS DOUBLE) AS due_amount_inr,
TRY_CAST(paid_date AS DATE) AS paid_date,
TRY_CAST(paid_amount_inr AS DOUBLE) AS paid_amount_inr,
CASE
    WHEN days_past_due < 0
        THEN NULL
    ELSE
        days_past_due
END AS days_past_due,
TRIM(payment_status) AS payment_status
FROM raw.raw_repayment_transactions;


CREATE OR REPLACE TABLE stg.stg_loan_monthly_snapshot AS
SELECT
CASE
    WHEN TRIM(customer_id) IS NULL
        THEN 'INVALID CUSTOMER ID'
    ELSE
        TRIM(customer_id)
END AS customer_id,
month,
TRY_CAST(avg_monthly_balance_inr AS DOUBLE) AS avg_monthly_balance_inr,
TRY_CAST(total_credits_inr AS DOUBLE) AS total_credits_inr,
TRY_CAST(total_debits_inr AS DOUBLE) AS total_debits_inr,
CASE
    WHEN cheque_ach_bounce_count < 0
        THEN NULL
    ELSE
        cheque_ach_bounce_count
END AS cheque_ach_bounce_count,
cash_deposit_ratio
FROM raw.raw_loan_monthly_snapshot;


CREATE OR REPLACE TABLE stg.stg_monthly_bureau_snapshot AS
SELECT
CASE
    WHEN TRIM(customer_id) IS NULL
        THEN 'INVALID CUSTOMER ID'
    ELSE
        TRIM(customer_id)
END AS customer_id,
TRY_CAST(snapshot_date AS DATE) AS snapshot_date,
CASE
    WHEN bureau_score < 0 OR bureau_score > 900
        THEN NULL
    ELSE
        bureau_score
END AS bureau_score,
TRY_CAST(total_outstanding_inr AS DOUBLE) AS total_outstanding_inr,
num_active_loans_all_lenders,
num_enquiries_last_6m,
write_off_flag
FROM raw.raw_monthly_bureau_snapshot;


SELECT '================ STAGING CUSTOMERS TABLE =================';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='stg_customers';

SELECT '================ STAGING LOANS TABLE =================';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='stg_loans';

SELECT '================ STAGING REPAYMENT TRANSACTIONS TABLE =================';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='stg_repayment_transactions';

SELECT '================ STAGING LOAN MONTHLY SNAPSHOT TABLE =================';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='stg_loan_monthly_snapshot';

SELECT '================ STAGING MONTHLY BUREAU SNAPSHOT TABLE =================';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='stg_monthly_bureau_snapshot';

SELECT
COUNT(*) AS total_rows_customers_table
FROM stg.stg_customers;

SELECT
COUNT(*) AS total_rows_loans_table
FROM stg.stg_loans;

SELECT
COUNT(*) AS total_rows_repayment_transactions_table
FROM stg.stg_repayment_transactions;

SELECT
COUNT(*) AS total_rows_loan_monthly_snapshot_table
FROM stg.stg_loan_monthly_snapshot;

SELECT
COUNT(*) AS total_rows_monthly_bureau_snapshot_table
FROM stg.stg_monthly_bureau_snapshot;

