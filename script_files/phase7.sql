-- ============================================================
-- INVESTMENT DOMAIN - ALERTS
-- ============================================================
-- Phase 07: Automated Alerts
-- Script: 07_alerts.sql
-- Version: 1.0.0
--
-- Description:
--   Automated Snowflake ALERT objects for proactive monitoring
--   of Investment Analysis Platform. Alerts query Phase 05/06
--   monitoring views and send notifications.
--
-- Alerts Created: 5
--   1. ALERT_RESOURCE_MONITOR_CRITICAL - Monitor >= 90%
--   2. ALERT_LONG_RUNNING_QUERY        - Queries > 5 minutes
--   3. ALERT_FAILED_QUERY_SPIKE        - Failed query threshold
--   4. ALERT_HIGH_WAREHOUSE_QUEUE      - Queue overload
--   5. ALERT_MONTHLY_COST_SPIKE        - Month-over-month spike
--
-- Initial State: All alerts created SUSPENDED
--
-- Dependencies:
--   - Phase 05/06 monitoring views exist
--   - INV_ANALYTICS_WH exists
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE INV_GOVERNANCE_DB;
USE SCHEMA MONITORING;


-- ============================================================
-- SECTION 1: RESOURCE MONITOR ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 1: Resource Monitor Critical (>= 90%)
-- Schedule: Every 30 minutes
-- Severity: CRITICAL
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT INV_GOVERNANCE_DB.MONITORING.ALERT_RESOURCE_MONITOR_CRITICAL
    WAREHOUSE = INV_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,30 * * * * UTC'
    COMMENT = 'CRITICAL: Resource monitors at or above 90% consumption. Immediate attention required.'
    IF (EXISTS (
        SELECT 1
        FROM INV_GOVERNANCE_DB.MONITORING.VW_RESOURCE_MONITOR_STATUS
        WHERE usage_percent >= 90
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'investment-alerts@company.com',
            'CRITICAL: Investment Platform - Resource Monitor Near Limit',
            'One or more resource monitors have reached 90% or higher credit consumption. Review immediately to prevent warehouse suspension.'
        );


-- ============================================================
-- SECTION 2: QUERY ALERTS
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 2: Long Running Queries (> 5 minutes)
-- Schedule: Every 15 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT INV_GOVERNANCE_DB.MONITORING.ALERT_LONG_RUNNING_QUERY
    WAREHOUSE = INV_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,15,30,45 * * * * UTC'
    COMMENT = 'WARNING: Queries exceeding 5 minutes in last 15 minutes.'
    IF (EXISTS (
        SELECT 1
        FROM INV_GOVERNANCE_DB.MONITORING.VW_LONG_RUNNING_QUERIES
        WHERE start_time >= DATEADD(MINUTE, -15, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'investment-alerts@company.com',
            'WARNING: Investment Platform - Long Running Queries Detected',
            'Long-running queries (>5 min) detected in the last 15 minutes. Review query patterns for optimization.'
        );


-- ------------------------------------------------------------
-- ALERT 3: Failed Query Spike (> 10 failures)
-- Schedule: Every 15 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT INV_GOVERNANCE_DB.MONITORING.ALERT_FAILED_QUERY_SPIKE
    WAREHOUSE = INV_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,15,30,45 * * * * UTC'
    COMMENT = 'WARNING: More than 10 failed queries in last 15 minutes.'
    IF (EXISTS (
        SELECT 1
        FROM (
            SELECT COUNT(*) AS failed_count
            FROM INV_GOVERNANCE_DB.MONITORING.VW_FAILED_QUERIES
            WHERE start_time >= DATEADD(MINUTE, -15, CURRENT_TIMESTAMP())
        )
        WHERE failed_count > 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'investment-alerts@company.com',
            'WARNING: Investment Platform - Failed Query Spike',
            'More than 10 failed queries detected in the last 15 minutes. Investigate error patterns.'
        );


-- ============================================================
-- SECTION 3: WAREHOUSE CAPACITY ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 4: High Warehouse Queue (> 5 queued)
-- Schedule: Every 30 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT INV_GOVERNANCE_DB.MONITORING.ALERT_HIGH_WAREHOUSE_QUEUE
    WAREHOUSE = INV_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,30 * * * * UTC'
    COMMENT = 'WARNING: Warehouse queue exceeding 5 queries.'
    IF (EXISTS (
        SELECT 1
        FROM INV_GOVERNANCE_DB.MONITORING.VW_ACTIVE_WAREHOUSE_LOAD
        WHERE avg_queries_queued > 5
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'investment-alerts@company.com',
            'WARNING: Investment Platform - High Warehouse Queue',
            'One or more warehouses have high query queue load. Consider scaling warehouse size.'
        );


-- ============================================================
-- SECTION 4: COST GOVERNANCE ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 5: Monthly Cost Spike (> 120% of previous month)
-- Schedule: Daily at 08:00 UTC
-- Severity: CRITICAL
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT INV_GOVERNANCE_DB.MONITORING.ALERT_MONTHLY_COST_SPIKE
    WAREHOUSE = INV_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 8 * * * UTC'
    COMMENT = 'CRITICAL: Current month credits exceed 120% of previous month.'
    IF (EXISTS (
        SELECT 1
        FROM (
            SELECT
                SUM(CASE WHEN usage_month = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN total_credits ELSE 0 END) AS current_credits,
                SUM(CASE WHEN usage_month = DATE_TRUNC('MONTH', DATEADD(MONTH, -1, CURRENT_DATE())) THEN total_credits ELSE 0 END) AS previous_credits
            FROM INV_GOVERNANCE_DB.MONITORING.VW_COST_BY_MONTH
        )
        WHERE current_credits > previous_credits * 1.2
          AND previous_credits > 0
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'investment-alerts@company.com',
            'CRITICAL: Investment Platform - Monthly Cost Spike',
            'Current month credit consumption exceeds 120% of previous month. Review cost drivers immediately.'
        );


-- ============================================================
-- SECTION 5: ENABLE ALERTS (Initially Suspended)
-- ============================================================
-- Uncomment to enable production alerting

-- ALTER ALERT ALERT_RESOURCE_MONITOR_CRITICAL RESUME;
-- ALTER ALERT ALERT_LONG_RUNNING_QUERY RESUME;
-- ALTER ALERT ALERT_FAILED_QUERY_SPIKE RESUME;
-- ALTER ALERT ALERT_HIGH_WAREHOUSE_QUEUE RESUME;
-- ALTER ALERT ALERT_MONTHLY_COST_SPIKE RESUME;


-- ============================================================
-- SECTION 6: GRANT OPERATE TO DATA_ADMIN
-- ============================================================

GRANT OPERATE ON ALERT ALERT_RESOURCE_MONITOR_CRITICAL TO ROLE INV_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_LONG_RUNNING_QUERY TO ROLE INV_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_FAILED_QUERY_SPIKE TO ROLE INV_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_HIGH_WAREHOUSE_QUEUE TO ROLE INV_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_MONTHLY_COST_SPIKE TO ROLE INV_DATA_ADMIN;


-- ============================================================
-- SECTION 7: VERIFICATION
-- ============================================================

SHOW ALERTS IN SCHEMA INV_GOVERNANCE_DB.MONITORING;


-- ============================================================
-- SECTION 8: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 07: ALERTS - SUMMARY
================================================================================

ALERTS CREATED: 5
┌────────────────────────────────────┬────────────────────┬──────────────────────┐
│ Alert                              │ Schedule           │ Condition            │
├────────────────────────────────────┼────────────────────┼──────────────────────┤
│ ALERT_RESOURCE_MONITOR_CRITICAL    │ Every 30 min       │ Monitor >= 90%       │
│ ALERT_LONG_RUNNING_QUERY           │ Every 15 min       │ Query > 5 minutes    │
│ ALERT_FAILED_QUERY_SPIKE           │ Every 15 min       │ > 10 failures        │
│ ALERT_HIGH_WAREHOUSE_QUEUE         │ Every 30 min       │ Queue > 5 queries    │
│ ALERT_MONTHLY_COST_SPIKE           │ Daily 08:00 UTC    │ > 120% of prev month │
└────────────────────────────────────┴────────────────────┴──────────────────────┘

SEVERITY LEVELS:
  - CRITICAL: ALERT_RESOURCE_MONITOR_CRITICAL, ALERT_MONTHLY_COST_SPIKE
  - WARNING:  ALERT_LONG_RUNNING_QUERY, ALERT_FAILED_QUERY_SPIKE, ALERT_HIGH_WAREHOUSE_QUEUE

INITIAL STATE: All alerts SUSPENDED (enable in production)

NOTIFICATION: investment-alerts@company.com (update as needed)

WAREHOUSE: INV_ANALYTICS_WH (used for all alerts)

GRANTS: OPERATE privilege to INV_DATA_ADMIN

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 07: ALERTS COMPLETE'
UNION ALL
SELECT '  5 Alerts Created (Suspended)'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 07: ALERTS
-- ============================================================
/*ALTER ALERT ALERT_RESOURCE_MONITOR_CRITICAL RESUME;
ALTER ALERT ALERT_LONG_RUNNING_QUERY RESUME;
ALTER ALERT ALERT_FAILED_QUERY_SPIKE RESUME;
ALTER ALERT ALERT_HIGH_WAREHOUSE_QUEUE RESUME;
ALTER ALERT ALERT_MONTHLY_COST_SPIKE RESUME;
*/ -- to Enable Alerts

