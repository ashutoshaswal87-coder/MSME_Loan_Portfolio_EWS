-- Check for alerts

SELECT
    customer_id,
    month,
    alert_type,
    severity,
    alert_value,
    alert_description,
    overall_risk_level
FROM dw.ews_alerts
LIMIT 20;