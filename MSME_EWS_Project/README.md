# MSME Loan Portfolio Early Warning System

A Data Engineering project that builds an Early Warning System (EWS) for an MSME lending portfolio. The system ingests customer data, loan data, repayment data, banking behaviour data and bureau data; transforms them into a dimensional warehouse, generates customer-level risk features, applies configurable risk rules, and produces explainable alerts for deteriorating credit behaviour.


## Business Problem -

    - MSME borrowers can show signs of financial stress before default.
    - Warning signals may exist across repayment behaviour, banking activity and credit-bureau data.
    - The objective is to bring these signals together at a customer × month level.
    - The system produces risk indicators and descriptive alerts that could be used by a credit-risk/portfolio-monitoring team.


## Project Objectives -

    - Build an end-to-end data engineering pipeline using Python and DuckDB
    - Ingest raw MSME lending data from CSV files
    - Validate and clean source data
    - Build staging tables
    - Build a dimensional data warehouse
    - Create customer-month EWS features
    - Identify deterioration in repayment, banking and bureau behaviour
    - Apply configurable risk rules
    - Generate explainable customer-level alerts
    - Prepare the resulting data for reporting


## Architecture -

    CSV source files (customers.csv, loans.csv, repayment_transactions.csv, banking_behaviour.csv, bureau_snapshots.csv) -> Python ingestion -> Raw Tables -> SQL Cleaning -> Staging Tables -> Data Warehouse (dim_customers, dim_loans, fact_repayment_transactions, fact_customer_monthly_snapshot, fact_monthly_bureau_snapshot) -> EWS Feature Layer (ews_repayment_features, ews_banking_features, ews_bureau_features, ews_trend_features) -> EWS Risk Logic -> EWS Alerts


## Technology Stack -

    - Python — ingestion and pipeline orchestration
    - DuckDB — analytical database/warehouse
    - SQL — transformation, modelling and EWS logic
    - Git/GitHub — version control
    - VS Code/GitHub Codespaces — development environment


## Source Data -

    | Source File | Purpose |
    | customers.csv | Customer/Business information |
    | loans.csv | Loan level information |
    | repayment_transactions.csv | Repayment and delinquency information |
    | banking_behaviour.csv | Customer-wise Monthly banking behaviour |
    | bureau_snapshots.csv | Customer_wise Monthly Credit Bureau information |

    > The project uses purpose-built synthetic Indian MSME lending data. Public credit-risk datasets were used only as references for understanding data structures and risk variables.


## Data Pipeline -

    Python is primarily responsible for ingestion.

    The ingestion pipeline:
    1. Validates source files
    2. Establishes the DuckDB connection
    3. Creates required schemas
    4. Loads CSV files into raw tables
    5. Verifies loaded row counts
    6. Logs pipeline execution and failures

    SQL is used for downstream data cleaning, staging, warehouse modelling and EWS feature generation.


## Data Model -

    The Data Warehouse is created in a Star Schema formation, with two dimension tables (dim_customers and dim_loans) and three fact tables (fact_repayment_transactions, fact_customer_monthly_snapshot and fact_month_bureau_snapshot).


### Dimensions -

        #### dw.dim_customers

            Grain - One row per customer.

            Fields -
            - customer_key (PK)
            - customer_id
            - business_name
            - owner_name
            - owner_age
            - owner_gender
            - msme_segment
            - industry_sector
            - state
            - city
            - business_vintage_years
            - annual_turnover_inr
            - gst_registered
            - udyam_registered
            - banking_relationship_years
            - onboarding_date
        
        #### dw.dim_loans

            Grain - One row per loan.

            Fields -
            - loan_key (PK)
            - loan_id
            - customer_key (FK)
            - loan_type
            - loan_purpose
            - collateral_type
            - sanctioned_amount_inr
            - disbursed_amount_inr
            - disbursement_date
            - tenure_months
            - interest_rate_pct
            - emi_amount_inr
            - current_dpd
            - max_dpd_last_12m
            - loan_status

            Relationships - dim_customers -> (customer_key) -> dim_loans

    ### Facts -

        #### dw.fact_repayment_transactions

            Grain - One row per repayment transaction.

            Fields -
            - repayment_key (PK)
            - loan_key (FK)
            - customer_key (FK)
            - due_date
            - due_amount_inr
            - paid_date
            - paid_amount_inr
            - days_past_due
            - payment_status

            Relationships -
            1. dim_customers -> (customer_id) -> fact_repayment_transactions
            2. dim_loans -> (loan_key) -> fact_repayment_transactions

        #### dw.fact_customer_monthly_snapshot

            Grain - One row for One Customer X One Month

            Fields -
            - snapshot_key (PK)
            - customer_key (FK)
            - month
            - avg_monthly_balance_inr
            - total_credits_inr
            - total_debits_inr
            - cheque_ach_bounce_count
            - cash_deposit_ratio

            Relationships - dim_customers -> (customer_key) -> fact_customer_monthly_snapshot

        #### dw.fact_monthly_bureau_snapshot

            Grain - One row for One Customer X One Month

            Fields -
            - bureau_key (PK)
            - customer_key (FK)
            - snapshot_date
            - bureau_score
            - total_outstanding_inr
            - num_active_loans_all_lenders
            - num_enquiries_last_6m
            - write_off_flag

            Relationships - dim_customers -> (customer_key) -> fact_monthly_bureau_snapshot


## EWS Feature engineering -

    > All EWS feature tables use a common logical grain of one customer × one month.

    ### dw.ews_repayment_features

        Fields -
        - repayment_feature_key (PK)
        - customer_key (FK)
        - month
        - repayment_count
        - total_due_amount_inr
        - total_paid_amount_inr
        - late_payment_count
        - total_days_past_due
        - max_days_past_due

        Relationships - 
        1. dim_customers -> (customer_key) -> ews_repayment_features
        2. data lineage relationship with fact_repayment_transactions

        > ews_repayment_features calculates the following data for each customer -
        > 1. number of repayments per month
        > 2. total due amount per month
        > 3. total amount paid per month
        > 4. total DPD and maximum DPD per month

    ### dw.ews_banking_features

        Fields -
        - banking_feature_key (PK)
        - customer_key (FK)
        - month
        - avg_monthly_balance_inr
        - total_credits_inr
        - total_debits_inr
        - cheque_ach_bounce_count
        - cash_deposit_ratio

        Relationships -
        1. dim_customers -> (customer_key) -> ews_banking_features
        2. data lineage relationship with fact_customer_monthly_snapshot

        > ews_banking_features captures the monthly customer-wise data from the fact_customer_monthly_snapshot table

    ### dw.ews_bureau_features

        Fields -
        - bureau_feature_key (PK)
        - customer_key (FK)
        - month
        - bureau_score
        - total_outstanding_inr
        - num_active_loans_all_lenders
        - num_enquiries_last_6m
        - write_off_flag

        Relationships -
        1. dim_customers -> (customer_key) -> ews_bureau_features
        2. data lineage relationship with fact_monthly_bureau_snapshot

        > ews_bureau_features captures the monthly customer-wise data from the fact_monthly_bureau_snapshot table

    ### dw.ews_trend_features

        Fields -
        - trend_feature_key (PK)
        - customer_key (FK)
        - month
        - dpd_change
        - repayment_amount_change_inr
        - balance_change_inr
        - credit_inflow_change_inr
        - debit_outflow_change_inr
        - bureau_score_change
        - outstanding_change_inr

        Relationships -
        1. dim_customers -> (customer_key) -> ews_trend_features
        2. data lineage relationship with ews_repayment_features, ews_banking_features and ews_bureau_features

        > ews_trend_features uses LAG() function to calculate month over month changes such as -
        > - DPD change
        > - repayment amount change
        > - balance change
        > - credit inflow change
        > - debit outflow change
        > - bureau score change
        > - outstanding change


## Risk Logic -

    The EWS uses **configurable rule-based** indicators to identify potentially deteriorating customer behaviour such as -
    - Multiple late payments
    - High or rapidly increasing DPD
    - Increased cheque/ACH bounces
    - Declining balance combined with declining credit inflows
    - Low or deteriorating bureau score
    - Increased recent credit enquiries
    - High number of active loans
    - Historical write-off indicator

    The ews_risk_logic table stores the risk_flags and risk_levels for the customers, with a **grain of one row per customer x month**.

    There are 8 risk flags corresponding to the aforementioned customer behaviours, which are calculated as follows -

    ``` -- Case of late payment
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
        END AS write_off_risk_flag```

    The individual risk flags are assigned values of either 1 or 0 based on the logic incorporated in the code above, which are then added together to arrive at the risk_flag_count with the maximum possible risk_flag_count being 8.

    The risk_level is then assigned as follows -

    ```SET risk_level =
        CASE
            WHEN write_off_risk_flag = 1 THEN 'HIGH'
            -- Any write-off translates to an immediate HIGH risk level
            WHEN risk_flag_count >= 4 THEN 'HIGH'
            -- HIGH risk level has been asssigned in case of risk flag count of 50% or more of max count
            WHEN risk_flag_count >= 2 THEN 'MEDIUM'
            -- MEDIUM risk level for cases with risk flag count of 25% or above of max count
            ELSE 'LOW'
            -- LOW risk level for risk flag count under 25% of max count
        END;```

    The risk level is assigned based on the risk_flag_count arrived at for each customer X month, with HIGH level assigned to records with risk_flag_count of 4 and above, MEDIUM for records with risk_flag_count of 2 and above and LOW for records with risk_flag_count under 2. Any instance of a write off is immediately marked off as HIGH risk. 

    > Note: The thresholds are configurable project rules/illustrative thresholds and would require calibration against historical portfolio performance in a real production system.


## Alerts -

    As multiple alerts can exist for the same customer and month because a customer may exhibit multiple independent warning signals, an alerts table is desgined to provide EWS information to the stakeholders.

    The ews_alerts contains one row per customer × month × alert type.

    The table is structured as follows -

    |   Field   |   Purpose |
    |   alert_key   |   unique alert identifier |
    |   customer_key    |   for referencing customer records    |
    |   customer_id |   as the raw data is arranged by customer_ids, the output presents the data as per the customer_id    |
    |   month   |   month in which the alert was detected   |
    |   alert_type  |   type of warning |
    |   severity    |   severity of the **individual** alert    |
    |   alert_value |   metric that triggered the alert |
    |   alert_description   |   human-readable explanation for the alert    |
    |   overall_risk_level  |   overall risk level for the customer |

    The alerts.sql can be configured and executed to display information as per the business requirements.


## Data Quality/Validation -

    Validation checks include -
    - Source file existence validation
    - Row-count validation after ingestion
    - Customer-to-loan referential integrity
    - Loan-to-repayment referential integrity
    - Orphan customer checks
    - Customer/loan relationship consistency
    - Duplicate customer-month checks
    - EWS feature table grain validation
    - Risk-level distribution checks
    - Risk flag counts
    - Alert uniqueness checks

    At the intial ingestion stage, the Python script (ingest.py) -
        1. Checks whether the csv files are present at the given location
        2. Checks if the files are empty
        3. Loads files onto raw tables and performs a row count validation to ensure entire data is loaded onto the tables

    Subsequently, the check_raw_tables.sql files runs the validation on the raw tables -
        1. Checks for NULL entries
        2. Checks for duplicates
        3. Checks the anomalies in the data, such as invalid owner names, owner ages, disbursed amount exceeding sanctioned amount etc.

    After the cleaning, the row count validation is performed again.

    The data warehouse model is verified for the customer to loan and loan to repayment referential integrity; orphaned customer, loan entries; consistency of customer/loan relationship; table grains; etc.

    The EWS feature tables are then checked for risk_levels (any anomalies, whether correctly applied), table grains (duplicate customer-months) and the risk flags.


## Repository Structure -

    MSME_EWS_Project/
    │
    ├── data/
    │   └── raw/
    │       ├── customers.csv
    │       ├── loans.csv
    │       ├── repayment_transactions.csv
    │       ├── banking_behaviour.csv
    │       └── bureau_snapshots.csv
    │
    ├── logs/
    │
    │── ingest.py
    │
    │── check_raw_tables.sql
    │
    │── create_staging_tables.sql
    │
    │── create_dw.sql
    │
    │── create_EWS_layer.sql
    │
    │── alerts.sql
    │
    ├── README.md
    └── .gitignore


# MSME Loan Portfolio Early Warning System

A Data Engineering project that builds an Early Warning System (EWS) for an MSME lending portfolio. The system ingests customer data, loan data, repayment data, banking behaviour data and bureau data; transforms them into a dimensional warehouse, generates customer-level risk features, applies configurable risk rules, and produces explainable alerts for deteriorating credit behaviour.


## Business Problem -

    - MSME borrowers can show signs of financial stress before default.
    - Warning signals may exist across repayment behaviour, banking activity and credit-bureau data.
    - The objective is to bring these signals together at a customer × month level.
    - The system produces risk indicators and descriptive alerts that could be used by a credit-risk/portfolio-monitoring team.


## Project Objectives -

    - Build an end-to-end data engineering pipeline using Python and DuckDB
    - Ingest raw MSME lending data from CSV files
    - Validate and clean source data
    - Build staging tables
    - Build a dimensional data warehouse
    - Create customer-month EWS features
    - Identify deterioration in repayment, banking and bureau behaviour
    - Apply configurable risk rules
    - Generate explainable customer-level alerts
    - Prepare the resulting data for reporting


## Architecture -

    CSV source files (customers.csv, loans.csv, repayment_transactions.csv, banking_behaviour.csv, bureau_snapshots.csv) -> Python ingestion -> Raw Tables -> SQL Cleaning -> Staging Tables -> Data Warehouse (dim_customers, dim_loans, fact_repayment_transactions, fact_customer_monthly_snapshot, fact_monthly_bureau_snapshot) -> EWS Feature Layer (ews_repayment_features, ews_banking_features, ews_bureau_features, ews_trend_features) -> EWS Risk Logic -> EWS Alerts


## Technology Stack -

    - Python — ingestion and pipeline orchestration
    - DuckDB — analytical database/warehouse
    - SQL — transformation, modelling and EWS logic
    - Git/GitHub — version control
    - VS Code/GitHub Codespaces — development environment


## Source Data -

    | Source File | Purpose |
    | customers.csv | Customer/Business information |
    | loans.csv | Loan level information |
    | repayment_transactions.csv | Repayment and delinquency information |
    | banking_behaviour.csv | Customer-wise Monthly banking behaviour |
    | bureau_snapshots.csv | Customer_wise Monthly Credit Bureau information |

    > The project uses purpose-built synthetic Indian MSME lending data. Public credit-risk datasets were used only as references for understanding data structures and risk variables.


## Data Pipeline -

    Python is primarily responsible for ingestion.

    The ingestion pipeline:
    1. Validates source files
    2. Establishes the DuckDB connection
    3. Creates required schemas
    4. Loads CSV files into raw tables
    5. Verifies loaded row counts
    6. Logs pipeline execution and failures

    SQL is used for downstream data cleaning, staging, warehouse modelling and EWS feature generation.


## Data Model -

    The Data Warehouse is created in a Star Schema formation, with two dimension tables (dim_customers and dim_loans) and three fact tables (fact_repayment_transactions, fact_customer_monthly_snapshot and fact_month_bureau_snapshot).


    ### Dimensions -

        #### dw.dim_customers

            Grain - One row per customer.

            Fields -
            - customer_key (PK)
            - customer_id
            - business_name
            - owner_name
            - owner_age
            - owner_gender
            - msme_segment
            - industry_sector
            - state
            - city
            - business_vintage_years
            - annual_turnover_inr
            - gst_registered
            - udyam_registered
            - banking_relationship_years
            - onboarding_date
        
        #### dw.dim_loans

            Grain - One row per loan.

            Fields -
            - loan_key (PK)
            - loan_id
            - customer_key (FK)
            - loan_type
            - loan_purpose
            - collateral_type
            - sanctioned_amount_inr
            - disbursed_amount_inr
            - disbursement_date
            - tenure_months
            - interest_rate_pct
            - emi_amount_inr
            - current_dpd
            - max_dpd_last_12m
            - loan_status

            Relationships - dim_customers -> (customer_key) -> dim_loans

    ### Facts -

        #### dw.fact_repayment_transactions

            Grain - One row per repayment transaction.

            Fields -
            - repayment_key (PK)
            - loan_key (FK)
            - customer_key (FK)
            - due_date
            - due_amount_inr
            - paid_date
            - paid_amount_inr
            - days_past_due
            - payment_status

            Relationships -
            1. dim_customers -> (customer_id) -> fact_repayment_transactions
            2. dim_loans -> (loan_key) -> fact_repayment_transactions

        #### dw.fact_customer_monthly_snapshot

            Grain - One row for One Customer X One Month

            Fields -
            - snapshot_key (PK)
            - customer_key (FK)
            - month
            - avg_monthly_balance_inr
            - total_credits_inr
            - total_debits_inr
            - cheque_ach_bounce_count
            - cash_deposit_ratio

            Relationships - dim_customers -> (customer_key) -> fact_customer_monthly_snapshot

        #### dw.fact_monthly_bureau_snapshot

            Grain - One row for One Customer X One Month

            Fields -
            - bureau_key (PK)
            - customer_key (FK)
            - snapshot_date
            - bureau_score
            - total_outstanding_inr
            - num_active_loans_all_lenders
            - num_enquiries_last_6m
            - write_off_flag

            Relationships - dim_customers -> (customer_key) -> fact_monthly_bureau_snapshot


## EWS Feature engineering -

    > All EWS feature tables use a common logical grain of one customer × one month.

    ### dw.ews_repayment_features

        Fields -
        - repayment_feature_key (PK)
        - customer_key (FK)
        - month
        - repayment_count
        - total_due_amount_inr
        - total_paid_amount_inr
        - late_payment_count
        - total_days_past_due
        - max_days_past_due

        Relationships - 
        1. dim_customers -> (customer_key) -> ews_repayment_features
        2. data lineage relationship with fact_repayment_transactions

        > ews_repayment_features calculates the following data for each customer -
        > 1. number of repayments per month
        > 2. total due amount per month
        > 3. total amount paid per month
        > 4. total DPD and maximum DPD per month

    ### dw.ews_banking_features

        Fields -
        - banking_feature_key (PK)
        - customer_key (FK)
        - month
        - avg_monthly_balance_inr
        - total_credits_inr
        - total_debits_inr
        - cheque_ach_bounce_count
        - cash_deposit_ratio

        Relationships -
        1. dim_customers -> (customer_key) -> ews_banking_features
        2. data lineage relationship with fact_customer_monthly_snapshot

        > ews_banking_features captures the monthly customer-wise data from the fact_customer_monthly_snapshot table

    ### dw.ews_bureau_features

        Fields -
        - bureau_feature_key (PK)
        - customer_key (FK)
        - month
        - bureau_score
        - total_outstanding_inr
        - num_active_loans_all_lenders
        - num_enquiries_last_6m
        - write_off_flag

        Relationships -
        1. dim_customers -> (customer_key) -> ews_bureau_features
        2. data lineage relationship with fact_monthly_bureau_snapshot

        > ews_bureau_features captures the monthly customer-wise data from the fact_monthly_bureau_snapshot table

    ### dw.ews_trend_features

        Fields -
        - trend_feature_key (PK)
        - customer_key (FK)
        - month
        - dpd_change
        - repayment_amount_change_inr
        - balance_change_inr
        - credit_inflow_change_inr
        - debit_outflow_change_inr
        - bureau_score_change
        - outstanding_change_inr

        Relationships -
        1. dim_customers -> (customer_key) -> ews_trend_features
        2. data lineage relationship with ews_repayment_features, ews_banking_features and ews_bureau_features

        > ews_trend_features uses LAG() function to calculate month over month changes such as -
        > - DPD change
        > - repayment amount change
        > - balance change
        > - credit inflow change
        > - debit outflow change
        > - bureau score change
        > - outstanding change


## Risk Logic -

    The EWS uses **configurable rule-based** indicators to identify potentially deteriorating customer behaviour such as -
    - Multiple late payments
    - High or rapidly increasing DPD
    - Increased cheque/ACH bounces
    - Declining balance combined with declining credit inflows
    - Low or deteriorating bureau score
    - Increased recent credit enquiries
    - High number of active loans
    - Historical write-off indicator

    The ews_risk_logic table stores the risk_flags and risk_levels for the customers, with a **grain of one row per customer x month**.

    There are 8 risk flags corresponding to the aforementioned customer behaviours, which are calculated as follows -

    ``` -- Case of late payment
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
        END AS write_off_risk_flag```

    The individual risk flags are assigned values of either 1 or 0 based on the logic incorporated in the code above, which are then added together to arrive at the risk_flag_count with the maximum possible risk_flag_count being 8.

    The risk_level is then assigned as follows -

    ```SET risk_level =
        CASE
            WHEN write_off_risk_flag = 1 THEN 'HIGH'
            -- Any write-off translates to an immediate HIGH risk level
            WHEN risk_flag_count >= 4 THEN 'HIGH'
            -- HIGH risk level has been asssigned in case of risk flag count of 50% or more of max count
            WHEN risk_flag_count >= 2 THEN 'MEDIUM'
            -- MEDIUM risk level for cases with risk flag count of 25% or above of max count
            ELSE 'LOW'
            -- LOW risk level for risk flag count under 25% of max count
        END;```

    The risk level is assigned based on the risk_flag_count arrived at for each customer X month, with HIGH level assigned to records with risk_flag_count of 4 and above, MEDIUM for records with risk_flag_count of 2 and above and LOW for records with risk_flag_count under 2. Any instance of a write off is immediately marked off as HIGH risk. 

    > Note: The thresholds are configurable project rules/illustrative thresholds and would require calibration against historical portfolio performance in a real production system.


## Alerts -

    As multiple alerts can exist for the same customer and month because a customer may exhibit multiple independent warning signals, an alerts table is desgined to provide EWS information to the stakeholders.

    The ews_alerts contains one row per customer × month × alert type.

    The table is structured as follows -

    |   Field   |   Purpose |
    |   alert_key   |   unique alert identifier |
    |   customer_key    |   for referencing customer records    |
    |   customer_id |   as the raw data is arranged by customer_ids, the output presents the data as per the customer_id    |
    |   month   |   month in which the alert was detected   |
    |   alert_type  |   type of warning |
    |   severity    |   severity of the **individual** alert    |
    |   alert_value |   metric that triggered the alert |
    |   alert_description   |   human-readable explanation for the alert    |
    |   overall_risk_level  |   overall risk level for the customer |

    The alerts.sql can be configured and executed to display information as per the business requirements.


## Data Quality/Validation -

    Validation checks include -
    - Source file existence validation
    - Row-count validation after ingestion
    - Customer-to-loan referential integrity
    - Loan-to-repayment referential integrity
    - Orphan customer checks
    - Customer/loan relationship consistency
    - Duplicate customer-month checks
    - EWS feature table grain validation
    - Risk-level distribution checks
    - Risk flag counts
    - Alert uniqueness checks

    At the intial ingestion stage, the Python script (ingest.py) -
        1. Checks whether the csv files are present at the given location
        2. Checks if the files are empty
        3. Loads files onto raw tables and performs a row count validation to ensure entire data is loaded onto the tables

    Subsequently, the check_raw_tables.sql files runs the validation on the raw tables -
        1. Checks for NULL entries
        2. Checks for duplicates
        3. Checks the anomalies in the data, such as invalid owner names, owner ages, disbursed amount exceeding sanctioned amount etc.

    After the cleaning, the row count validation is performed again.

    The data warehouse model is verified for the customer to loan and loan to repayment referential integrity; orphaned customer, loan entries; consistency of customer/loan relationship; table grains; etc.

    The EWS feature tables are then checked for risk_levels (any anomalies, whether correctly applied), table grains (duplicate customer-months) and the risk flags.


## Repository Structure -

    MSME_EWS_Project/
    │
    ├── data/
    │   └── raw/
    │       ├── customers.csv
    │       ├── loans.csv
    │       ├── repayment_transactions.csv
    │       ├── banking_behaviour.csv
    │       └── bureau_snapshots.csv
    │
    ├── logs/
    │
    │── ingest.py
    │
    │── check_raw_tables.sql
    │
    │── create_staging_tables.sql
    │
    │── create_dw.sql
    │
    │── create_EWS_layer.sql
    │
    │── alerts.sql
    │
    ├── README.md
    └── .gitignore
