-- creating Data Warehouse

-- dim_customers
-- dim_loans

-- fact_repayment_transactions
-- fact_customer_monthly_snapshot
-- fact_monthly_bureau_snapshot


DROP SCHEMA dw CASCADE;

SELECT 'Creating DW Schema...';

CREATE SCHEMA IF NOT EXISTS dw;


-- CREATING DIM_CUSTOMERS TABLE

SELECT 'Creating dim_customers Table...';

CREATE OR REPLACE TABLE dw.dim_customers (
customer_key INTEGER PRIMARY KEY,
customer_id VARCHAR UNIQUE,
business_name VARCHAR,
owner_name VARCHAR,
owner_age BIGINT,
owner_gender VARCHAR,
msme_segment VARCHAR,
industry_sector VARCHAR,
state VARCHAR,
city VARCHAR,
business_vintage_years BIGINT,
annual_turnover_inr DOUBLE,
gst_registered BOOLEAN,
udyam_registered BOOLEAN,
banking_relationship_years BIGINT,
onboarding_date DATE 
);

INSERT INTO dw.dim_customers (
customer_key,
customer_id,
business_name,
owner_name,
owner_age,
owner_gender,
msme_segment,
industry_sector,
state,
city,
business_vintage_years,
annual_turnover_inr,
gst_registered,
udyam_registered,
banking_relationship_years,
onboarding_date
)
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    business_name,
    owner_name,
    owner_age,
    owner_gender,
    msme_segment,
    industry_sector,
    state,
    city,
    business_vintage_years,
    annual_turnover_inr,
    gst_registered,
    udyam_registered,
    banking_relationship_years,
    onboarding_date
FROM
    stg.stg_customers;


-- CREATING DIM_LOANS TABLE

SELECT 'Creating dim_loans Table...';

CREATE OR REPLACE TABLE dw.dim_loans (
    loan_key INTEGER PRIMARY KEY,
    loan_id VARCHAR UNIQUE,
    customer_key INTEGER,
    loan_type VARCHAR,
    loan_purpose VARCHAR,
    collateral_type VARCHAR,
    sanctioned_amount_inr DOUBLE,
    disbursed_amount_inr DOUBLE,
    disbursement_date DATE,
    tenure_months BIGINT,
    interest_rate_pct DOUBLE,
    emi_amount_inr DOUBLE,
    current_dpd BIGINT,
    max_dpd_last_12m BIGINT,
    loan_status VARCHAR,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key)
);

INSERT INTO dw.dim_loans (
    loan_key,
    loan_id,
    customer_key,
    loan_type,
    loan_purpose,
    collateral_type,
    sanctioned_amount_inr,
    disbursed_amount_inr,
    disbursement_date,
    tenure_months,
    interest_rate_pct,
    emi_amount_inr,
    current_dpd,
    max_dpd_last_12m,
    loan_status
)
SELECT
    ROW_NUMBER() OVER (ORDER BY l.loan_id) AS loan_key,
    l.loan_id,
    c.customer_key,
    l.loan_type,
    l.loan_purpose,
    l.collateral_type,
    l.sanctioned_amount_inr,
    l.disbursed_amount_inr,
    l.disbursement_date,
    l.tenure_months,
    l.interest_rate_pct,
    l.emi_amount_inr,
    l.current_dpd,
    l.max_dpd_last_12m,
    l.loan_status
FROM stg.stg_loans l
INNER JOIN dw.dim_customers c
    ON l.customer_id = c.customer_id;


-- CREATING FACT_REPAYMENT_TRANSACTIONS TABLE

SELECT 'Creating fact_repayment_transactions Table...';

CREATE OR REPLACE TABLE dw.fact_repayment_transactions (
    repayment_key INTEGER PRIMARY KEY,
    loan_key INTEGER,
    customer_key INTEGER,
    due_date DATE,
    due_amount_inr DOUBLE,
    paid_date DATE,
    paid_amount_inr DOUBLE,
    days_past_due BIGINT,
    payment_status VARCHAR,
    FOREIGN KEY (loan_key)
        REFERENCES dw.dim_loans(loan_key)
);

INSERT INTO dw.fact_repayment_transactions (
    repayment_key,
    loan_key,
    customer_key,
    due_date,
    due_amount_inr,
    paid_date,
    paid_amount_inr,
    days_past_due,
    payment_status
)
SELECT
    ROW_NUMBER() OVER(ORDER BY l.loan_key, r.paid_date) AS repayment_key,
    l.loan_key,
    c.customer_key,
    r.due_date,
    r.due_amount_inr,
    r.paid_date,
    r.paid_amount_inr,
    r.days_past_due,
    r.payment_status
FROM stg.stg_repayment_transactions r
INNER JOIN dw.dim_loans l
    ON r.loan_id = l.loan_id
INNER JOIN dw.dim_customers c
    ON l.customer_key = c.customer_key;


-- CREATING FACT_CUSTOMER_MONTHLY_SNAPSHOT TABLE

SELECT 'Creating fact_customer_monthly_snapshot Table...';
-- The staging table is named as per the raw data file, i.e. stg_loan_monthly_snapshot.
-- However, it is noted that the grain is one row = one customer per month.
-- i.e. the snapshot is of customer per month
-- Hence, the fact table is named as fact_customer_monthly_snapshot.

CREATE OR REPLACE TABLE dw.fact_customer_monthly_snapshot (
    snapshot_key INTEGER PRIMARY KEY,
    customer_key INTEGER,
    month DATE,
    avg_monthly_balance_inr DOUBLE,
    total_credits_inr DOUBLE,
    total_debits_inr DOUBLE,
    cheque_ach_bounce_count BIGINT,
    cash_deposit_ratio DOUBLE,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key)
);

INSERT INTO dw.fact_customer_monthly_snapshot (
    snapshot_key,
    customer_key,
    month,
    avg_monthly_balance_inr,
    total_credits_inr,
    total_debits_inr,
    cheque_ach_bounce_count,
    cash_deposit_ratio
)
SELECT
    ROW_NUMBER() OVER(ORDER BY c.customer_key, s.month) AS snapshot_key,
    c.customer_key,
    s.month,
    s.avg_monthly_balance_inr,
    s.total_credits_inr,
    s.total_debits_inr,
    s.cheque_ach_bounce_count,
    s.cash_deposit_ratio
FROM stg.stg_loan_monthly_snapshot s
INNER JOIN dw.dim_customers c
    ON s.customer_id = c.customer_id;


-- CREATING FACT_MONTHLY_BUREAU_SNAPSHOT TABLE

SELECT 'Creating fact_monthly_bureau_snapshot Table...';

CREATE OR REPLACE TABLE dw.fact_monthly_bureau_snapshot (
    bureau_key INTEGER PRIMARY KEY,
    customer_key INTEGER,
    snapshot_date DATE,
    bureau_score BIGINT,
    total_outstanding_inr DOUBLE,
    num_active_loans_all_lenders BIGINT,
    num_enquiries_last_6m BIGINT,
    write_off_flag BIGINT,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key)
);

INSERT INTO dw.fact_monthly_bureau_snapshot (
    bureau_key,
    customer_key,
    snapshot_date,
    bureau_score,
    total_outstanding_inr,
    num_active_loans_all_lenders,
    num_enquiries_last_6m,
    write_off_flag
)
SELECT
    ROW_NUMBER() OVER(ORDER BY c.customer_key, b.snapshot_date) AS bureau_key,
    c.customer_key,
    b.snapshot_date,
    b.bureau_score,
    b.total_outstanding_inr,
    b.num_active_loans_all_lenders,
    b.num_enquiries_last_6m,
    b.write_off_flag
FROM stg.stg_monthly_bureau_snapshot b
INNER JOIN dw.dim_customers c
    ON b.customer_id = c.customer_id;


-- Data Validation

-- Sample rows from the DW tables

SELECT * FROM dw.dim_customers LIMIT 10;
SELECT * FROM dw.dim_loans LIMIT 10;
SELECT * FROM dw.fact_repayment_transactions LIMIT 10;
SELECT * FROM dw.fact_customer_monthly_snapshot LIMIT 10;
SELECT * FROM dw.fact_monthly_bureau_snapshot LIMIT 10;

-- Verifying row count

SELECT 'No. of Rows in stg_customers...';
SELECT COUNT(*) FROM stg.stg_customers;

SELECT 'No. of Rows in dim_customers...';
SELECT COUNT(*) FROM dw.dim_customers;

SELECT 'No. of Rows in stg_loans...';
SELECT COUNT(*) FROM stg.stg_loans;

SELECT 'No. of Rows in dim_loans...';
SELECT COUNT(*) FROM dw.dim_loans;

SELECT 'No. of Rows in stg_repayment_transactions...';
SELECT COUNT(*) FROM stg.stg_repayment_transactions;

SELECT 'No. of Rows in fact_repayment_transactions...';
SELECT COUNT(*) FROM dw.fact_repayment_transactions;

SELECT 'No. of Rows in stg_loan_monthly_snapshot...';
SELECT COUNT(*) FROM stg.stg_loan_monthly_snapshot;

SELECT 'No. of Rows in fact_customer_monthly_snapshot...';
SELECT COUNT(*) FROM dw.fact_customer_monthly_snapshot;

SELECT 'No. of Rows in stg_monthly_bureau_snapshot...';
SELECT COUNT(*) FROM stg.stg_monthly_bureau_snapshot;

SELECT 'No. of Rows in fact_monthly_bureau_snapshot...';
SELECT COUNT(*) FROM dw.fact_monthly_bureau_snapshot;

-- Verifying uniqueness of surrogate keys

SELECT 'Verifying uniqueness of surrogate keys...';

SELECT
    customer_key,
    COUNT(*)
FROM dw.dim_customers
GROUP BY customer_key
HAVING COUNT(*) >1;

SELECT
    loan_key,
    COUNT(*)
FROM dw.dim_loans
GROUP BY loan_key
HAVING COUNT(*) >1;

SELECT
    repayment_key,
    COUNT(*)
FROM dw.fact_repayment_transactions
GROUP BY repayment_key
HAVING COUNT(*) >1;

SELECT
    snapshot_key,
    COUNT(*)
FROM dw.fact_customer_monthly_snapshot
GROUP BY snapshot_key
HAVING COUNT(*) >1;

SELECT
    bureau_key,
    COUNT(*)
FROM dw.fact_monthly_bureau_snapshot
GROUP BY bureau_key
HAVING COUNT(*) >1;

-- Verifying business keys - loan_id and customer_id

SELECT 'Verifying business keys - loan_id and customer_id...';

SELECT
    customer_id,
    COUNT(*)
FROM dw.dim_customers
GROUP BY customer_id
HAVING COUNT(*) >1;

SELECT
    loan_id,
    COUNT(*)
FROM dw.dim_loans
GROUP BY loan_id
HAVING COUNT(*) >1;

-- Verifying Foreign keys - orphaned loan, repayment, customer_snapshot and bureau_snapshot entries

SELECT 'Verifying Foreign keys - orphaned loan, repayment, customer_snapshot and bureau_snapshot entries...';

SELECT
    l.*
FROM dw.dim_loans l
LEFT JOIN dw.dim_customers c
    ON l.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT
    r.*
FROM dw.fact_repayment_transactions r
LEFT JOIN dw.dim_loans l
    ON r.loan_key = l.loan_key
WHERE l.loan_key IS NULL;

SELECT
    s.*
FROM dw.fact_customer_monthly_snapshot s
LEFT JOIN dw.dim_customers c
    ON s.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT
    b.*
FROM dw.fact_monthly_bureau_snapshot b
LEFT JOIN dw.dim_customers c
    ON b.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

-- Verifying grain

SELECT 'Verifying grain...';

SELECT
    loan_key,
    paid_date,
    paid_amount_inr,
    COUNT(*) AS no_of_transactions
FROM dw.fact_repayment_transactions
GROUP BY
    loan_key,
    paid_date,
    paid_amount_inr
HAVING
    COUNT(*)>1 AND paid_date IS NOT NULL;

SELECT
    customer_key,
    month,
    avg_monthly_balance_inr,
    COUNT(*) AS no_of_transactions
FROM dw.fact_customer_monthly_snapshot
GROUP BY
    customer_key,
    month,
    avg_monthly_balance_inr
HAVING
    COUNT(*)>1;

SELECT
    customer_key,
    snapshot_date,
    bureau_score,
    COUNT(*) AS no_of_transactions
FROM dw.fact_monthly_bureau_snapshot
GROUP BY
    customer_key,
    snapshot_date,
    bureau_score
HAVING
    COUNT(*)>1;

-- Verifying consistency of loan_id and customer_id relationship - loan ownership verification

SELECT 'Verifying consistency of loan_id and customer_id relationship...';

SELECT
    r.loan_id AS staging_loan_id,
    r.customer_id AS staging_customer_id,
    l.customer_key AS dw_customer_key,
    c.customer_id AS dw_customer_id
FROM stg.stg_repayment_transactions r
INNER JOIN dw.dim_loans l
    ON r.loan_id = l.loan_id
INNER JOIN dw.dim_customers c
    ON l.customer_key = c.customer_key
WHERE r.customer_id <> c.customer_id;

/*-- Checking repayment_snpashot table

SELECT
    *
FROM dw.fact_repayment_transactions r
WHERE loan_key = 5272;*/