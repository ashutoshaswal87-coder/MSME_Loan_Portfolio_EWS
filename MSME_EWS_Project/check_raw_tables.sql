-- Checking the raw tables for duplicates, NULL entries etc.

-- raw_customers,
-- raw_loans,
-- raw_repayment_transactions,
-- raw_loan_monthly_snapshot,
-- raw_monthly_bureau_snapshot


-- Checking table schemas

SELECT '============ CHECKING TABLE SCHEMAS ======================';

SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='raw_customers';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='raw_loans';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='raw_repayment_transactions';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='raw_loan_monthly_snapshot';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='raw_monthly_bureau_snapshot';


-- Checking for NULL entries

SELECT '============ CHECKING FOR NULL ENTRIES ======================';

SELECT
COUNT(*) AS total_rows,
COUNT(customer_id) AS customer_id_present,
COUNT(*) - COUNT(customer_id) AS customer_id_null
FROM raw.raw_customers;

SELECT
COUNT(*) AS total_rows,
COUNT(owner_name) AS owner_name_present,
COUNT(*) - COUNT(owner_name) AS owner_name_null
FROM raw.raw_customers;

SELECT
COUNT(*) AS total_rows,
COUNT(business_name) AS business_name_present,
COUNT(*) - COUNT(business_name) AS business_name_null
FROM raw.raw_customers;

SELECT
COUNT(*) AS total_rows,
COUNT(loan_id) AS loan_id_present,
COUNT(*) - COUNT(loan_id) AS loan_id_null
FROM raw.raw_loans;


-- Checking for DUPLICATES

SELECT '============ CHECKING FOR DUPLICATES ======================';

SELECT
customer_id AS duplicate_customers,
COUNT(*) AS cnt
FROM raw.raw_customers
GROUP BY customer_id
HAVING COUNT(*)>1;

SELECT
loan_id AS duplicate_loans,
COUNT(*) AS cnt
FROM raw.raw_loans
GROUP BY loan_id
HAVING COUNT(*)>1;


-- Checking for DISTINCT entries

SELECT '============ CHECKING FOR DISTINCT ENTRIES ======================';

SELECT DISTINCT
owner_gender AS distinct_owner_genders
FROM raw.raw_customers;

SELECT DISTINCT
msme_segment AS distinct_msme_segments
FROM raw.raw_customers;

SELECT DISTINCT
industry_sector AS distinct_industry_sectors
FROM raw.raw_customers;

SELECT DISTINCT
state AS distinct_loan_states
FROM raw.raw_customers;


SELECT DISTINCT
loan_type AS distinct_loan_types
FROM raw.raw_loans;

SELECT DISTINCT
collateral_type AS distinct_collateral_types
FROM raw.raw_loans;

SELECT DISTINCT
loan_status AS distinct_loan_statuses
FROM raw.raw_loans;

SELECT DISTINCT
payment_status AS distinct_payment_statuses
FROM raw.raw_repayment_transactions;

SELECT DISTINCT
write_off_flag AS distinct_write_off_flags
FROM raw.raw_monthly_bureau_snapshot;


-- Checking for anomalies

SELECT '============ CHECKING FOR ANOMALIES ======================';

SELECT 
owner_name AS invalid_owner_names
FROM raw.raw_customers
WHERE NOT regexp_matches (owner_name, '^[A-Za-z '']');

SELECT
MIN(owner_age),
MAX(owner_age),
MIN(annual_turnover_inr),
MAX(annual_turnover_inr),
MAX(banking_relationship_years)
FROM raw.raw_customers;

SELECT
MIN(sanctioned_amount_inr),
MAX(sanctioned_amount_inr),
MIN(tenure_months),
MAX(tenure_months),
MIN(interest_rate_pct),
MAX(interest_rate_pct)
FROM raw.raw_loans;

SELECT
loan_id AS loan_with_disb_amt_exceeding_sanct_amt
FROM raw.raw_loans
WHERE disbursed_amount_inr > sanctioned_amount_inr;

SELECT
customer_id AS cust_with_avg_monthly_balance_negative
FROM raw.raw_loan_monthly_snapshot
WHERE avg_monthly_balance_inr < 0;

SELECT
MIN(bureau_score),
MAX(bureau_score)
FROM raw.raw_monthly_bureau_snapshot;