-- EWS layer

-- CREATING ews_repayment_features TABLE

SELECT 'Creating ews_repayment_features Table...';

CREATE OR REPLACE TABLE dw.ews_repayment_features (
    repayment_feature_key INTEGER PRIMARY KEY,
    customer_key INTEGER NOT NULL,
    month DATE NOT NULL,
    repayment_count BIGINT,
    total_due_amount_inr DOUBLE,
    total_paid_amount_inr DOUBLE,
    late_payment_count BIGINT,
    total_days_past_due BIGINT,
    max_days_past_due BIGINT,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key),
    UNIQUE (customer_key, month)
    -- Since grain is one customer one month, the combination of customer_key and month should be unique
);

INSERT INTO dw.ews_repayment_features (
    repayment_feature_key,
    customer_key,
    month,
    repayment_count,
    total_due_amount_inr,
    total_paid_amount_inr,
    late_payment_count,
    total_days_past_due,
    max_days_past_due
)
SELECT
    ROW_NUMBER() OVER(ORDER BY r.customer_key, DATE_TRUNC('month', r.due_date)) AS repayment_feature_key,
    -- Date_trunc as we are using one month per customer as grain
    -- but fact_repayment_transactions contains all repayment transactions customer and loan-wise
    r.customer_key,
    DATE_TRUNC('month', r.due_date) AS month,
    COUNT(*) AS repayment_count,
    SUM(r.due_amount_inr) AS total_due_amount_inr,
    -- As the grain is per customer and not per loan
    SUM(COALESCE(r.paid_amount_inr, 0)) AS total_paid_amount_inr,
    -- To replace NULL values if the paid amount is NULL
    SUM(
        CASE
            WHEN r.days_past_due > 0 THEN 1
            ELSE 0
        END
    ) AS late_payment_count,
    SUM(COALESCE(r.days_past_due, 0)) AS total_days_past_due,
    MAX(COALESCE(r.days_past_due, 0)) AS max_days_past_due
FROM dw.fact_repayment_transactions r
GROUP BY
    r.customer_key,
    DATE_TRUNC('month', r.due_date);


-- CREATING ews_banking_features TABLE

SELECT 'Creating ews_banking_features Table...';

CREATE OR REPLACE TABLE dw.ews_banking_features (
    banking_feature_key INTEGER PRIMARY KEY,
    customer_key INTEGER NOT NULL,
    month DATE NOT NULL,
    avg_monthly_balance_inr DOUBLE,
    total_credits_inr DOUBLE,
    total_debits_inr DOUBLE,
    cheque_ach_bounce_count BIGINT,
    cash_deposit_ratio DOUBLE,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key),
    UNIQUE (customer_key, month)
);

INSERT INTO dw.ews_banking_features (
    banking_feature_key,
    customer_key,
    month,
    avg_monthly_balance_inr,
    total_credits_inr,
    total_debits_inr,
    cheque_ach_bounce_count,
    cash_deposit_ratio
)
SELECT
    ROW_NUMBER() OVER(ORDER BY customer_key, month) AS banking_feature_key,
    customer_key,
    month,
    avg_monthly_balance_inr,
    total_credits_inr,
    total_debits_inr,
    cheque_ach_bounce_count,
    cash_deposit_ratio
FROM dw.fact_customer_monthly_snapshot;


-- CREATING ews_bureau_features TABLE

SELECT 'Creating ews_bureau_features Table...';

CREATE OR REPLACE TABLE dw.ews_bureau_features (
    bureau_feature_key INTEGER PRIMARY KEY,
    customer_key INTEGER NOT NULL,
    month DATE NOT NULL,
    bureau_score BIGINT,
    total_outstanding_inr DOUBLE,
    num_active_loans_all_lenders BIGINT,
    num_enquiries_last_6m BIGINT,
    write_off_flag BIGINT,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key),
    UNIQUE (customer_key, month)
);

INSERT INTO dw.ews_bureau_features (
    bureau_feature_key,
    customer_key,
    month,
    bureau_score,
    total_outstanding_inr,
    num_active_loans_all_lenders,
    num_enquiries_last_6m,
    write_off_flag
)
SELECT
    ROW_NUMBER() OVER(ORDER BY customer_key, snapshot_date) AS bureau_feature_key,
    customer_key,
    snapshot_date AS month,
    bureau_score,
    total_outstanding_inr,
    num_active_loans_all_lenders,
    num_enquiries_last_6m,
    write_off_flag
FROM dw.fact_monthly_bureau_snapshot;


-- Creating TREND feature Table to track the customer behaviour and trends

SELECT 'Creating ews_trend_features Table...';

CREATE OR REPLACE TABLE dw.ews_trend_features (
    trend_feature_key INTEGER PRIMARY KEY,
    customer_key INTEGER NOT NULL,
    month DATE NOT NULL,
    dpd_change BIGINT,
    repayment_amount_change_inr DOUBLE,
    balance_change_inr DOUBLE,
    credit_inflow_change_inr DOUBLE,
    debit_outflow_change_inr DOUBLE,
    bureau_score_change BIGINT,
    outstanding_change_inr DOUBLE,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key),
    UNIQUE (customer_key, month)
);

INSERT INTO dw.ews_trend_features (
    trend_feature_key,
    customer_key,
    month,
    dpd_change,
    repayment_amount_change_inr,
    balance_change_inr,
    credit_inflow_change_inr,
    debit_outflow_change_inr,
    bureau_score_change,
    outstanding_change_inr
)
WITH repayment_trends AS (
    SELECT
        customer_key,
        month,
        max_days_past_due - LAG(max_days_past_due) OVER(PARTITION BY customer_key ORDER BY month) AS dpd_change,
        -- tracking customer-wise changes in the dpd over the previous months
        total_paid_amount_inr - LAG(total_paid_amount_inr) OVER(PARTITION BY customer_key ORDER BY month) AS repayment_amount_change_inr
        -- tracking the customer-wise changes in the repayment amounts over the previous months
    FROM dw.ews_repayment_features
),
-- repayment_trends CTE with fields as -
-- customer_key, month, dpd_change, repayment_amount_change_inr
banking_trends AS (
    SELECT
        customer_key,
        month,
        avg_monthly_balance_inr - LAG(avg_monthly_balance_inr) OVER(PARTITION BY customer_key ORDER BY month) AS balance_change_inr,
        -- changes in average monthly balances
        total_credits_inr - LAG(total_credits_inr) OVER(PARTITION BY customer_key ORDER BY month) AS credit_inflow_change_inr,
        -- changes in total inflow
        total_debits_inr - LAG(total_debits_inr) OVER(PARTITION BY customer_key ORDER BY month) AS debit_outflow_change_inr
        -- changes in total outflow
    FROM dw.ews_banking_features
),
-- banking_trends CTE with fields as -
-- customer_key, month, balance_change_inr, credit_inflow_change_inr, debit_outflow_change_inr
bureau_trends AS (
    SELECT
        customer_key,
        month,
        bureau_score - LAG(bureau_score) OVER(PARTITION BY customer_key ORDER BY month) AS bureau_score_change,
        -- changes in bureau scores
        total_outstanding_inr - LAG(total_outstanding_inr) OVER(PARTITION BY customer_key ORDER BY month) AS outstanding_change_inr
        -- changes in total o/s as per bureau report
    FROM dw.ews_bureau_features
),
-- bureau_trends CTE with fields as -
-- customer_key, month, bureau_score_change, outstanding_change_inr
all_months AS (
    SELECT customer_key, month
    FROM dw.ews_repayment_features
    UNION
    SELECT customer_key, month
    FROM dw.ews_banking_features
    UNION
    SELECT customer_key, month
    FROM dw.ews_bureau_features
)
-- all_months CTE containing the entire time period relevant to the entries in all the feature tables
SELECT
    ROW_NUMBER() OVER(ORDER BY a.customer_key, a.month) AS trend_feature_key,
    -- grain of one customer one month
    a.customer_key,
    a.month,
    -- customer_key and month from the entire time period
    r.dpd_change,
    r.repayment_amount_change_inr,
    b.balance_change_inr,
    b.credit_inflow_change_inr,
    b.debit_outflow_change_inr,
    bu.bureau_score_change,
    bu.outstanding_change_inr
FROM all_months a
LEFT JOIN repayment_trends r
    ON a.customer_key = r.customer_key
    AND a.month = r.month
LEFT JOIN banking_trends b
    ON a.customer_key = b.customer_key
    AND a.month = b.month
LEFT JOIN bureau_trends bu
    ON a.customer_key = bu.customer_key
    AND a.month = bu.month;
    -- ensuring monthly data for the same combination of customer_key and month as per grain


-- Creating EWS Risk Logic Table

SELECT 'Creating ews_risk_logic Table...';

CREATE OR REPLACE TABLE dw.ews_risk_logic (
    risk_key INTEGER PRIMARY KEY,
    customer_key INTEGER NOT NULL,
    month DATE NOT NULL,
    -- Repayment risk
    late_payment_count BIGINT,
    max_days_past_due BIGINT,
    dpd_change BIGINT,
    -- Banking risk
    cheque_ach_bounce_count BIGINT,
    cash_deposit_ratio DOUBLE,
    balance_change_inr DOUBLE,
    credit_inflow_change_inr DOUBLE,
    -- Bureau risk
    bureau_score BIGINT,
    bureau_score_change BIGINT,
    num_enquiries_last_6m BIGINT,
    num_active_loans_all_lenders BIGINT,
    outstanding_change_inr DOUBLE,
    write_off_flag BIGINT,
    -- Risk indicators
    late_payment_risk_flag INTEGER,
    dpd_risk_flag INTEGER,
    bounce_risk_flag INTEGER,
    cash_flow_risk_flag INTEGER,
    bureau_score_risk_flag INTEGER,
    bureau_enquiry_risk_flag INTEGER,
    borrowings_risk_flag INTEGER,
    write_off_risk_flag INTEGER,
    -- Overall result
    risk_flag_count INTEGER,
    risk_level VARCHAR,
    FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customers(customer_key),
    UNIQUE (customer_key, month)
    -- grain, so composite UNIQUE
);

INSERT INTO dw.ews_risk_logic (
    risk_key,
    customer_key,
    month,
    late_payment_count,
    max_days_past_due,
    dpd_change,
    cheque_ach_bounce_count,
    cash_deposit_ratio,
    balance_change_inr,
    credit_inflow_change_inr,
    bureau_score,
    bureau_score_change,
    num_enquiries_last_6m,
    num_active_loans_all_lenders,
    outstanding_change_inr,
    write_off_flag,
    late_payment_risk_flag,
    dpd_risk_flag,
    bounce_risk_flag,
    cash_flow_risk_flag,
    bureau_score_risk_flag,
    bureau_enquiry_risk_flag,
    borrowings_risk_flag,
    write_off_risk_flag,
    risk_flag_count,
    risk_level
)
WITH features AS (
    SELECT
        r.customer_key,
        r.month,
        r.late_payment_count,
        r.max_days_past_due,
        r.total_paid_amount_inr,
        b.cheque_ach_bounce_count,
        b.cash_deposit_ratio,
        b.avg_monthly_balance_inr,
        b.total_credits_inr,
        bu.bureau_score,
        bu.num_enquiries_last_6m,
        bu.num_active_loans_all_lenders,
        bu.write_off_flag,
        t.dpd_change,
        t.balance_change_inr,
        t.credit_inflow_change_inr,
        t.bureau_score_change,
        t.outstanding_change_inr
    FROM dw.ews_repayment_features r
    LEFT JOIN dw.ews_banking_features b
        ON r.customer_key = b.customer_key
        AND r.month = b.month
    LEFT JOIN dw.ews_bureau_features bu
        ON r.customer_key = bu.customer_key
        AND r.month = bu.month
    LEFT JOIN dw.ews_trend_features t
        ON r.customer_key = t.customer_key
        AND r.month = t.month
)
SELECT
    ROW_NUMBER() OVER(ORDER BY customer_key, month) AS risk_key,
    -- grain one customer one month
    customer_key,
    month,
    late_payment_count,
    max_days_past_due,
    dpd_change,
    cheque_ach_bounce_count,
    cash_deposit_ratio,
    balance_change_inr,
    credit_inflow_change_inr,
    bureau_score,
    bureau_score_change,
    num_enquiries_last_6m,
    num_active_loans_all_lenders,
    outstanding_change_inr,
    write_off_flag,
    -- Case of late payment
    CASE
        WHEN late_payment_count >= 1 THEN 1
        ELSE 0
    END AS late_payment_risk_flag,
    -- Case of DPD deterioration
    CASE
        WHEN max_days_past_due >= 30 THEN 1
        WHEN dpd_change >= 5 THEN 1
        ELSE 0
    END AS dpd_risk_flag,
    -- Case of cheque bounce
    CASE
        WHEN cheque_ach_bounce_count >= 1 THEN 1
        ELSE 0
    END AS bounce_risk_flag,
    -- Case of deterioration in cash flow
    CASE
        WHEN balance_change_inr < 0 AND credit_inflow_change_inr < 0 THEN 1
        -- Only when both the cash inflow and the balance are negative, i.e. there is financial deterioration
        ELSE 0
    END AS cash_flow_risk_flag,
    -- Case of deterioration in bureau score
    CASE
        WHEN bureau_score < 650 THEN 1
        WHEN bureau_score_change <= -10 THEN 1
        ELSE 0
    END AS bureau_score_risk_flag,
    -- Case of frequent credit enquiries in bureau report
    CASE
        WHEN num_enquiries_last_6m >= 5 THEN 1
        ELSE 0
    END AS bureau_enquiry_risk_flag,
    -- Case of borrowing risk
    CASE
        WHEN num_active_loans_all_lenders >= 5 THEN 1
        ELSE 0
    END AS borrowings_risk_flag,
    -- Case of write-off in the bureau report
    CASE
        WHEN write_off_flag = 1 THEN 1
        ELSE 0
    END AS write_off_risk_flag,
    -- Summation of count triggered indicators
    (
        CASE WHEN late_payment_count >= 1 THEN 1 ELSE 0 END
        +
        CASE
            WHEN max_days_past_due >= 30
              OR dpd_change >= 5
            THEN 1 ELSE 0
        END
        +
        CASE WHEN cheque_ach_bounce_count >= 1 THEN 1 ELSE 0 END
        +
        CASE
            WHEN balance_change_inr < 0
             AND credit_inflow_change_inr < 0
            THEN 1 ELSE 0
        END
        +
        CASE
            WHEN bureau_score < 650
              OR bureau_score_change <= -10
            THEN 1 ELSE 0
        END
        +
        CASE WHEN num_enquiries_last_6m >= 5 THEN 1 ELSE 0 END
        +
        CASE WHEN num_active_loans_all_lenders >= 5 THEN 1 ELSE 0 END
        +
        CASE WHEN write_off_flag = 1 THEN 1 ELSE 0 END
    ) AS risk_flag_count,
    -- Total risk flag count is used to assess the risk level (max possible risk flags = 8)
    NULL AS risk_level
    -- Since the risk flags are calculated and assigned aliases in the same SELECT statement
    -- updated in the following code block
FROM features;

UPDATE dw.ews_risk_logic
SET risk_level =
    CASE
        WHEN write_off_risk_flag = 1 THEN 'HIGH'
        -- Any write-off translates to an immediate HIGH risk level
        WHEN risk_flag_count >= 4 THEN 'HIGH'
        -- HIGH risk level has been asssigned in case of risk flag count of 50% or more of max count
        WHEN risk_flag_count >= 2 THEN 'MEDIUM'
        -- MEDIUM risk level for cases with risk flag count of 25% or above of max count
        ELSE 'LOW'
        -- LOW risk level for risk flag count under 25% of max count
    END;
    -- uses the aliases created in the previous code block to update the risk_level field


-- Data Validation

-- Verifying risk levels

SELECT
    risk_level,
    COUNT(*)
FROM dw.ews_risk_logic
GROUP BY
    risk_level
ORDER BY
    risk_level;

-- Verifying if risk_levels correctly applied

SELECT
    risk_level,
    risk_flag_count,
    COUNT(*) AS no_of_entries
FROM dw.ews_risk_logic
GROUP BY
    risk_level,
    risk_flag_count
ORDER BY
    risk_flag_count;

-- Verifying the grain

SELECT
    customer_key,
    month,
    -- as the grain is one customer one month
    COUNT(*)
FROM dw.ews_risk_logic
GROUP BY
    customer_key,
    month
HAVING COUNT(*)>1;

-- Verifying all risk_flags

SELECT
    SUM(late_payment_risk_flag) AS total_late_payment_risk_flags,
    SUM(dpd_risk_flag) AS total_dpd_risk_flags,
    SUM(bounce_risk_flag) AS total_bounce_risk_flags,
    SUM(cash_flow_risk_flag) AS total_cash_flow_risk_flags
FROM dw.ews_risk_logic;

SELECT
    SUM(bureau_score_risk_flag) AS total_bureau_score_risk_flags,
    SUM(bureau_enquiry_risk_flag) AS total_bureau_enquiry_risk_flags,
    SUM(borrowings_risk_flag) AS total_borrowings_risk_flags,
    SUM(write_off_risk_flag) AS total_write_off_risk_flags
FROM dw.ews_risk_logic;

-- Verifying HIGH risk customers

SELECT
    customer_key,
    month,
    risk_flag_count,
    risk_level,
    -- possbile reasons why customer is classified as HIGH Risk
    -- late payments
    late_payment_count,
    -- dpd deterioration
    max_days_past_due,
    dpd_change,
    -- cheque bounce
    cheque_ach_bounce_count,
    -- deterioration in cash flow
    balance_change_inr,
    credit_inflow_change_inr,
    -- deterioration in bureau score
    bureau_score,
    bureau_score_change,
    -- frequent credit enquiries
    num_enquiries_last_6m,
    -- borrowing risk
    num_active_loans_all_lenders,
    -- write offs
    write_off_flag
FROM dw.ews_risk_logic
WHERE risk_level = 'HIGH'
ORDER BY
    customer_key,
    month;


-- Creating an ALERTS table to provide alert information to the business

SELECT 'Creating ews_alerts Table...';

CREATE OR REPLACE TABLE dw.ews_alerts (
    alert_key INTEGER PRIMARY KEY,
    customer_key INTEGER,
    customer_id VARCHAR,
    month DATE,
    alert_type VARCHAR,
    severity VARCHAR,
    alert_value DOUBLE,
    alert_description VARCHAR,
    overall_risk_level VARCHAR
);

INSERT INTO dw.ews_alerts (
    alert_key,
    -- customer_key, months and alert_type
    customer_key,
    customer_id,
    month,
    alert_type,
    severity,
    alert_value,
    alert_description,
    overall_risk_level
)
WITH alert_logic AS (
    -- Case of late payment
    SELECT
        customer_key,
        month,
        'Late Payment' AS alert_type,
        'HIGH' severity,
        late_payment_count AS alert_value,
        'Instance(s) of late payment(s)' AS alert_description
    FROM dw.ews_risk_logic
    WHERE late_payment_risk_flag = 1
    UNION ALL
    -- Case of DPD deterioration
    SELECT
        customer_key,
        month,
        'DPD deterioration' AS alert_type,
        CASE
            WHEN max_days_past_due>=30 THEN 'HIGH'
            WHEN dpd_change >=5 THEN 'MEDIUM'
        END AS severity,
        CASE
            WHEN max_days_past_due>=30 THEN max_days_past_due
            ELSE dpd_change
        END AS alert_value,       
        CASE
            WHEN max_days_past_due>=30 THEN 'Maximum DPD reached 30 days or more'
            WHEN dpd_change >=5 THEN 'DPD increased by more than 5 days over previous month'          
        END AS alert_description
    FROM dw.ews_risk_logic
    WHERE dpd_risk_flag = 1
    UNION ALL
    -- Case of cheque bounce
    SELECT
        customer_key,
        month,
        'Cheque Bounce' AS alert_type,
        'HIGH' severity,
        cheque_ach_bounce_count AS alert_value,
        'Instance(s) of cheque bounce(s) and/or failed NACH mandates' AS alert_description
    FROM dw.ews_risk_logic
    WHERE bounce_risk_flag = 1
    UNION ALL
    -- Case of deterioration in cash flow
    SELECT
        customer_key,
        month,
        'Deterioration of cash flow' AS alert_type,
        'HIGH' AS severity,
        credit_inflow_change_inr AS alert_value,
        'Account balance and credit inflows have declined over the past month' AS alert_description
    FROM dw.ews_risk_logic
    WHERE cash_flow_risk_flag = 1
    UNION ALL
    -- Case of deterioration in bureau score
    SELECT
        customer_key,
        month,
        'Deterioration of Bureau score' AS alert_type,
        CASE
            WHEN bureau_score <650 THEN 'HIGH'
            WHEN bureau_score_change <= -10. THEN 'MEDIUM'
        END AS severity,
        CASE
            WHEN bureau_score <650 THEN bureau_score
            WHEN bureau_score_change <= -10. THEN bureau_score_change
        END AS alert_value,
        CASE
            WHEN bureau_score < 650 THEN 'Bureau score is under 650'
            WHEN bureau_score_change <= -10 THEN 'Bureau score decreased by 10 or more over past month'
        END AS alert_description
    FROM dw.ews_risk_logic
    WHERE bureau_score_risk_flag = 1
    UNION ALL
    -- Case of frequent credit enquiries
    SELECT
        customer_key,
        month,
        'High number of credit enquiries' AS alert_type,
        'HIGH' AS severity,
        num_enquiries_last_6m AS alert_value,
        'High number of credit enquiries in the last 6 months' AS alert_description
    FROM dw.ews_risk_logic
    WHERE bureau_enquiry_risk_flag = 1
    UNION ALL
    -- Case of borrowing risk
    SELECT
        customer_key,
        month,
        'High number of loans' AS alert_type,
        'HIGH' AS severity,
        num_active_loans_all_lenders AS alert_value,
        'High amount of borrowing across all lenders' AS alert_description
    FROM dw.ews_risk_logic
    WHERE borrowings_risk_flag = 1
    UNION ALL
    -- Case of write-offs
    SELECT
        customer_key,
        month,
        'Write-offs' AS alert_type,
        'HIGH' AS severity,
        write_off_flag AS alert_value,
        'Write-off detected in Bureau report' AS alert_description
    FROM dw.ews_risk_logic
    WHERE write_off_risk_flag = 1
)
SELECT
    ROW_NUMBER() OVER(ORDER BY a.customer_key, a.month, a.alert_type) AS alert_key,
    a.customer_key,
    c.customer_id,
    -- Since this is a business front table for providing alerts, linked with customer_id
    a.month,
    a.alert_type,
    a.severity,
    a.alert_value,
    a.alert_description,
    rl.risk_level AS overall_risk_level
FROM alert_logic a
JOIN dw.ews_risk_logic rl
    ON a.customer_key = rl.customer_key
    AND a.month = rl.month
LEFT JOIN dw.dim_customers c
    ON rl.customer_key = c.customer_key
ORDER BY alert_key;