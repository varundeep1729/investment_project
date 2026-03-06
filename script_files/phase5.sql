-- ============================================================
-- INVESTMENT DOMAIN - RESOURCE MONITORS
-- ============================================================
-- Phase 05: Resource Monitors & Cost Governance
-- Script: 05_resource_monitors.sql
-- Version: 1.0.0
--
-- Description:
--   Implements cost governance for Investment Analysis Platform.
--   Creates account-level and warehouse-level resource monitors.
--
-- Why Cost Controls for Investment Platform:
--   1. Budget predictability for financial operations
--   2. Runaway queries can indicate unauthorized data access
--   3. Cost anomalies may signal security incidents
--   4. SOX compliance requires financial controls
--   5. Prevents unexpected billing impacting operations
--
-- Resource Monitors: 5
--   1. INV_ACCOUNT_MONITOR   - Account-level (5000 credits/month)
--   2. INV_INGEST_MONITOR    - Ingest warehouse (500 credits/month)
--   3. INV_TRANSFORM_MONITOR - Transform warehouse (1500 credits/month)
--   4. INV_ANALYTICS_MONITOR - Analytics warehouse (2000 credits/month)
--   5. INV_ML_MONITOR        - ML warehouse (1000 credits/month)
--
-- Dependencies:
--   - Phase 03 completed: 4 warehouses exist
--   - Phase 02 completed: 7 roles exist
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: ACCOUNT-LEVEL MONITOR
-- ============================================================
-- Hard cap on total credit consumption across ALL warehouses.
-- Financial safety net for entire platform.

CREATE OR REPLACE RESOURCE MONITOR INV_ACCOUNT_MONITOR
    WITH
        CREDIT_QUOTA = 5000
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- Apply to account
ALTER ACCOUNT SET RESOURCE_MONITOR = INV_ACCOUNT_MONITOR;


-- ============================================================
-- SECTION 2: WAREHOUSE-LEVEL MONITORS
-- ============================================================
-- Granular cost control per workload type.

-- ------------------------------------------------------------
-- INV_INGEST_MONITOR
-- Warehouse: INV_INGEST_WH
-- Quota: 500 credits/month
-- Purpose: Market data feeds, portfolio imports
-- ------------------------------------------------------------
CREATE OR REPLACE RESOURCE MONITOR INV_INGEST_MONITOR
    WITH
        CREDIT_QUOTA = 500
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

-- ------------------------------------------------------------
-- INV_TRANSFORM_MONITOR
-- Warehouse: INV_TRANSFORM_WH
-- Quota: 1500 credits/month
-- Purpose: ETL transformations, dbt, data pipelines
-- ------------------------------------------------------------
CREATE OR REPLACE RESOURCE MONITOR INV_TRANSFORM_MONITOR
    WITH
        CREDIT_QUOTA = 1500
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

-- ------------------------------------------------------------
-- INV_ANALYTICS_MONITOR
-- Warehouse: INV_ANALYTICS_WH
-- Quota: 2000 credits/month
-- Purpose: BI queries, dashboards, Streamlit apps
-- ------------------------------------------------------------
CREATE OR REPLACE RESOURCE MONITOR INV_ANALYTICS_MONITOR
    WITH
        CREDIT_QUOTA = 2000
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

-- ------------------------------------------------------------
-- INV_ML_MONITOR
-- Warehouse: INV_ML_WH
-- Quota: 1000 credits/month
-- Purpose: ML model training, feature engineering
-- ------------------------------------------------------------
CREATE OR REPLACE RESOURCE_MONITOR INV_ML_MONITOR
    WITH
        CREDIT_QUOTA = 1000
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;


-- ============================================================
-- SECTION 3: ASSIGN MONITORS TO WAREHOUSES
-- ============================================================

ALTER WAREHOUSE INV_INGEST_WH SET RESOURCE_MONITOR = INV_INGEST_MONITOR;
ALTER WAREHOUSE INV_TRANSFORM_WH SET RESOURCE_MONITOR = INV_TRANSFORM_MONITOR;
ALTER WAREHOUSE INV_ANALYTICS_WH SET RESOURCE_MONITOR = INV_ANALYTICS_MONITOR;
ALTER WAREHOUSE INV_ML_WH SET RESOURCE_MONITOR = INV_ML_MONITOR;


-- ============================================================
-- SECTION 4: MONITORING VIEWS
-- ============================================================
-- Create views in INV_GOVERNANCE_DB.MONITORING for cost tracking

USE DATABASE INV_GOVERNANCE_DB;
USE SCHEMA MONITORING;

-- ------------------------------------------------------------
-- VIEW 1: Daily Credit Consumption by Warehouse
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_DAILY_WAREHOUSE_CREDITS AS
SELECT 
    DATE_TRUNC('DAY', start_time) AS usage_date,
    warehouse_name,
    SUM(credits_used) AS total_credits,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_services_credits,
    COUNT(*) AS query_count,
    ROUND(SUM(credits_used) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
  AND warehouse_name LIKE 'INV_%'
GROUP BY 1, 2
ORDER BY usage_date DESC, total_credits DESC;

-- ------------------------------------------------------------
-- VIEW 2: Monthly Credit Summary
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_MONTHLY_CREDIT_SUMMARY AS
SELECT 
    DATE_TRUNC('MONTH', start_time) AS usage_month,
    warehouse_name,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(MONTH, -12, CURRENT_DATE())
  AND warehouse_name LIKE 'INV_%'
GROUP BY 1, 2
ORDER BY usage_month DESC, total_credits DESC;

-- ------------------------------------------------------------
-- VIEW 3: Credit Consumption by User
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_CREDITS_BY_USER AS
SELECT 
    user_name,
    COUNT(DISTINCT query_id) AS total_queries,
    SUM(credits_used_cloud_services) AS total_credits,
    ROUND(AVG(total_elapsed_time) / 1000, 2) AS avg_query_seconds,
    ROUND(SUM(credits_used_cloud_services) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
  AND warehouse_name LIKE 'INV_%'
GROUP BY user_name
ORDER BY total_credits DESC;

-- ------------------------------------------------------------
-- VIEW 4: Credit Consumption by Role
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_CREDITS_BY_ROLE AS
SELECT 
    role_name,
    COUNT(DISTINCT user_name) AS unique_users,
    COUNT(DISTINCT query_id) AS total_queries,
    SUM(credits_used_cloud_services) AS total_credits,
    ROUND(SUM(credits_used_cloud_services) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
  AND role_name LIKE 'INV_%'
GROUP BY role_name
ORDER BY total_credits DESC;

-- ------------------------------------------------------------
-- VIEW 5: Top Expensive Queries
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_TOP_EXPENSIVE_QUERIES AS
SELECT 
    query_id,
    SUBSTR(query_text, 1, 200) AS query_preview,
    user_name,
    role_name,
    warehouse_name,
    database_name,
    execution_status,
    start_time,
    total_elapsed_time / 1000 AS elapsed_seconds,
    bytes_scanned / POWER(1024, 3) AS gb_scanned,
    credits_used_cloud_services AS credits_used,
    ROUND(credits_used_cloud_services * 3, 4) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
  AND warehouse_name LIKE 'INV_%'
  AND credits_used_cloud_services > 0
ORDER BY credits_used_cloud_services DESC
LIMIT 100;

-- ------------------------------------------------------------
-- VIEW 6: Storage Consumption
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_STORAGE_CONSUMPTION AS
SELECT 
    usage_date,
    ROUND(average_database_bytes / POWER(1024, 4), 4) AS database_storage_tb,
    ROUND(average_stage_bytes / POWER(1024, 4), 4) AS stage_storage_tb,
    ROUND(average_failsafe_bytes / POWER(1024, 4), 4) AS failsafe_storage_tb,
    ROUND((average_database_bytes + average_stage_bytes + average_failsafe_bytes) / POWER(1024, 4), 4) AS total_storage_tb,
    ROUND(((average_database_bytes + average_stage_bytes + average_failsafe_bytes) / POWER(1024, 4)) * 23, 2) AS estimated_monthly_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
WHERE usage_date >= DATEADD(MONTH, -6, CURRENT_DATE())
ORDER BY usage_date DESC;

-- ------------------------------------------------------------
-- VIEW 7: Resource Monitor Status
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_RESOURCE_MONITOR_STATUS AS
SELECT 
    name AS monitor_name,
    credit_quota,
    used_credits,
    remaining_credits,
    ROUND(used_credits / NULLIF(credit_quota, 0) * 100, 2) AS usage_percent,
    frequency,
    start_time,
    end_time
FROM SNOWFLAKE.ACCOUNT_USAGE.RESOURCE_MONITORS
WHERE name LIKE 'INV_%';


-- ============================================================
-- SECTION 5: GRANT ACCESS TO MONITORING VIEWS
-- ============================================================

GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;


-- ============================================================
-- SECTION 6: VERIFICATION
-- ============================================================

-- Verify resource monitors
SHOW RESOURCE MONITORS LIKE 'INV_%';

-- Verify warehouse assignments
SELECT 
    warehouse_name,
    resource_monitor
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE warehouse_name LIKE 'INV_%';

-- Verify monitoring views
SHOW VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING;


-- ============================================================
-- SECTION 7: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 05: RESOURCE MONITORS - SUMMARY
================================================================================

RESOURCE MONITORS CREATED: 5
┌─────────────────────────┬───────────────────┬─────────────────────────────────┐
│ Monitor                 │ Credits/Month     │ Assigned To                     │
├─────────────────────────┼───────────────────┼─────────────────────────────────┤
│ INV_ACCOUNT_MONITOR     │ 5,000             │ Account (overall cap)           │
│ INV_INGEST_MONITOR      │ 500               │ INV_INGEST_WH                   │
│ INV_TRANSFORM_MONITOR   │ 1,500             │ INV_TRANSFORM_WH                │
│ INV_ANALYTICS_MONITOR   │ 2,000             │ INV_ANALYTICS_WH                │
│ INV_ML_MONITOR          │ 1,000             │ INV_ML_WH                       │
└─────────────────────────┴───────────────────┴─────────────────────────────────┘

TOTAL WAREHOUSE ALLOCATION: 5,000 credits/month
  - Ingest:    500 (10%)
  - Transform: 1,500 (30%)
  - Analytics: 2,000 (40%)
  - ML:        1,000 (20%)

MONITORING VIEWS CREATED: 7
  1. VW_DAILY_WAREHOUSE_CREDITS   - Daily credit tracking
  2. VW_MONTHLY_CREDIT_SUMMARY    - Monthly rollup
  3. VW_CREDITS_BY_USER           - Per-user consumption
  4. VW_CREDITS_BY_ROLE           - Per-role consumption
  5. VW_TOP_EXPENSIVE_QUERIES     - Top 100 costly queries
  6. VW_STORAGE_CONSUMPTION       - Storage trends
  7. VW_RESOURCE_MONITOR_STATUS   - Monitor utilization

ALERT THRESHOLDS:
  - 50%: Email notification (early warning)
  - 75%: Email notification (warning)
  - 90%: Email notification (critical)
  - 100%: Suspend warehouse (stop queries)

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 05: RESOURCE MONITORS COMPLETE'
UNION ALL
SELECT '  5 Monitors + 7 Monitoring Views'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 05: RESOURCE MONITORS
-- ============================================================
