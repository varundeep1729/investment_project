-- ============================================================
-- INVESTMENT DOMAIN - DATABASE STRUCTURE
-- ============================================================
-- Phase 04: Database Structure (Simplified)
-- Script: 04_database_structure.sql
-- Version: 1.0.0
--
-- Description:
--   Creates 5 databases with simple schema structure for
--   Investment Analysis Platform. No DEV/QA/PROD complexity.
--
-- Databases: 5 (Medallion Architecture)
--   1. INV_GOVERNANCE_DB - Security policies, monitoring
--   2. INV_RAW_DB        - Bronze (raw market/portfolio data)
--   3. INV_TRANSFORM_DB  - Silver (cleansed, validated)
--   4. INV_ANALYTICS_DB  - Gold (business-ready analytics)
--   5. INV_AI_READY_DB   - Platinum (ML features, models)
--
-- Dependencies:
--   - Phase 01 completed (INV_GOVERNANCE_DB.SECURITY exists)
--   - Phase 02 completed (7 roles exist)
--   - Phase 03 completed (4 warehouses exist)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: COMPLETE INV_GOVERNANCE_DB
-- ============================================================
-- Phase 01 created SECURITY schema. Add remaining schemas.

USE DATABASE INV_GOVERNANCE_DB;

CREATE SCHEMA IF NOT EXISTS MONITORING
    COMMENT = 'Cost monitoring, query performance, usage tracking';

CREATE SCHEMA IF NOT EXISTS POLICIES
    COMMENT = 'Data masking policies, row access policies';

CREATE SCHEMA IF NOT EXISTS TAGS
    COMMENT = 'Object tags for data classification';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE INV_GOVERNANCE_DB;


-- ============================================================
-- SECTION 2: INV_RAW_DB — BRONZE LAYER
-- ============================================================
-- Landing zone for raw data from market feeds, custodians,
-- portfolio systems. Data stored as-is, no transformations.

CREATE DATABASE IF NOT EXISTS INV_RAW_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Bronze Layer: Raw investment data from sources. Market feeds, portfolio imports, transaction files. 90-day retention.';

USE DATABASE INV_RAW_DB;

-- Market Data (prices, quotes, corporate actions)
CREATE SCHEMA IF NOT EXISTS MARKET_DATA
    COMMENT = 'Raw market data - daily prices, quotes, corporate actions from Bloomberg/Reuters';

-- Portfolio Data (holdings, NAV, positions)
CREATE SCHEMA IF NOT EXISTS PORTFOLIO_DATA
    COMMENT = 'Raw portfolio data - holdings, NAV, positions from custodians';

-- Reference Data (securities master, benchmarks)
CREATE SCHEMA IF NOT EXISTS REFERENCE_DATA
    COMMENT = 'Raw reference data - securities master, benchmarks, exchanges';

-- External Data (news, sentiment, economic)
CREATE SCHEMA IF NOT EXISTS EXTERNAL_DATA
    COMMENT = 'Raw external data - news feeds, sentiment, economic indicators';

-- Staging (temporary data loading)
CREATE TRANSIENT SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Temporary staging for data loading. Transient - no time travel.';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE INV_RAW_DB;


-- ============================================================
-- SECTION 3: INV_TRANSFORM_DB — SILVER LAYER
-- ============================================================
-- Cleansed, validated, standardized data with business rules.

CREATE DATABASE IF NOT EXISTS INV_TRANSFORM_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Silver Layer: Cleansed and validated investment data. Business rules applied. 30-day retention.';

USE DATABASE INV_TRANSFORM_DB;

-- Cleansed Facts (prices, holdings, transactions)
CREATE SCHEMA IF NOT EXISTS CLEANSED
    COMMENT = 'Cleansed fact tables - validated prices, holdings, transactions';

-- Master Data (dimensions with SCD Type 2)
CREATE SCHEMA IF NOT EXISTS MASTER
    COMMENT = 'Master data dimensions - securities, portfolios, clients (SCD Type 2)';

-- History (historical snapshots)
CREATE SCHEMA IF NOT EXISTS HISTORY
    COMMENT = 'Historical snapshots - point-in-time data for audit';

-- Intermediate (temp transformations)
CREATE TRANSIENT SCHEMA IF NOT EXISTS INTERMEDIATE
    COMMENT = 'Intermediate transformations. Transient - no time travel.';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE INV_TRANSFORM_DB;


-- ============================================================
-- SECTION 4: INV_ANALYTICS_DB — GOLD LAYER
-- ============================================================
-- Business-ready analytics optimized for BI and reporting.

CREATE DATABASE IF NOT EXISTS INV_ANALYTICS_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Gold Layer: Business-ready analytics for BI and reporting. 90-day retention for compliance.';

USE DATABASE INV_ANALYTICS_DB;

-- Core Facts & Dimensions
CREATE SCHEMA IF NOT EXISTS CORE
    COMMENT = 'Core star schema - fact and dimension tables';

-- Performance Analytics
CREATE SCHEMA IF NOT EXISTS PERFORMANCE
    COMMENT = 'Portfolio performance analytics - returns, attribution, benchmarks';

-- Risk Analytics
CREATE SCHEMA IF NOT EXISTS RISK
    COMMENT = 'Risk analytics - VaR, volatility, exposure, Greeks';

-- Reporting Views
CREATE SCHEMA IF NOT EXISTS REPORTING
    COMMENT = 'Pre-built reporting views for dashboards and Streamlit';

-- Compliance Reports
CREATE SCHEMA IF NOT EXISTS COMPLIANCE
    COMMENT = 'Regulatory compliance reports - SOX, SEC, FINRA';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE INV_ANALYTICS_DB;


-- ============================================================
-- SECTION 5: INV_AI_READY_DB — PLATINUM LAYER
-- ============================================================
-- ML-ready data for model training and predictions.

CREATE DATABASE IF NOT EXISTS INV_AI_READY_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Platinum Layer: ML-ready features, training data, model artifacts. 30-day retention.';

USE DATABASE INV_AI_READY_DB;

-- Feature Store
CREATE SCHEMA IF NOT EXISTS FEATURES
    COMMENT = 'Feature store - engineered features for ML models';

-- Training Datasets
CREATE SCHEMA IF NOT EXISTS TRAINING
    COMMENT = 'Training datasets - labeled data for model training';

-- Model Artifacts
CREATE SCHEMA IF NOT EXISTS MODELS
    COMMENT = 'Model artifacts - serialized models, metadata, registry';

-- Predictions
CREATE SCHEMA IF NOT EXISTS PREDICTIONS
    COMMENT = 'Prediction outputs - batch and real-time predictions';

-- Experiments
CREATE SCHEMA IF NOT EXISTS EXPERIMENTS
    COMMENT = 'ML experiments - A/B tests, model comparisons';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE INV_AI_READY_DB;


-- ============================================================
-- SECTION 6: DATABASE GRANTS TO 7 ROLES
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ------------------------------------------------------------
-- INV_GOVERNANCE_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE INV_GOVERNANCE_DB TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON DATABASE INV_GOVERNANCE_DB TO ROLE INV_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_GOVERNANCE_DB TO ROLE INV_DATA_ADMIN;
GRANT USAGE ON SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA INV_GOVERNANCE_DB.MONITORING TO ROLE INV_READONLY;

-- ------------------------------------------------------------
-- INV_RAW_DB GRANTS
-- ------------------------------------------------------------
-- DATA_ENGINEER: Full access
GRANT USAGE ON DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE STAGE ON ALL SCHEMAS IN DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE STAGES IN DATABASE INV_RAW_DB TO ROLE INV_DATA_ENGINEER;

-- DATA_ADMIN: Ownership
GRANT OWNERSHIP ON DATABASE INV_RAW_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- INV_TRANSFORM_DB GRANTS
-- ------------------------------------------------------------
-- DATA_ENGINEER: Full access
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ENGINEER;

-- ML_ENGINEER: Read access
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_TRANSFORM_DB TO ROLE INV_ML_ENGINEER;
GRANT SELECT ON ALL TABLES IN DATABASE INV_TRANSFORM_DB TO ROLE INV_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE INV_TRANSFORM_DB TO ROLE INV_ML_ENGINEER;

-- ANALYST: Read access
GRANT USAGE ON DATABASE INV_TRANSFORM_DB TO ROLE INV_ANALYST;
GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.CLEANSED TO ROLE INV_ANALYST;
GRANT USAGE ON SCHEMA INV_TRANSFORM_DB.MASTER TO ROLE INV_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANSED TO ROLE INV_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA INV_TRANSFORM_DB.MASTER TO ROLE INV_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANSED TO ROLE INV_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA INV_TRANSFORM_DB.MASTER TO ROLE INV_ANALYST;

-- DATA_ADMIN: Ownership
GRANT OWNERSHIP ON DATABASE INV_TRANSFORM_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- INV_ANALYTICS_DB GRANTS
-- ------------------------------------------------------------
-- READONLY: Select on all
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT SELECT ON ALL TABLES IN DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT SELECT ON ALL VIEWS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE TABLES IN DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;
GRANT SELECT ON FUTURE VIEWS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_READONLY;

-- ANALYST: Read + create in REPORTING
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_ANALYST;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_ANALYST;

-- DATA_ENGINEER: Write to CORE
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA INV_ANALYTICS_DB.PERFORMANCE TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA INV_ANALYTICS_DB.RISK TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA INV_ANALYTICS_DB.CORE TO ROLE INV_DATA_ENGINEER;

-- ML_ENGINEER: Read for analytics data
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_ML_ENGINEER;
GRANT SELECT ON ALL TABLES IN DATABASE INV_ANALYTICS_DB TO ROLE INV_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE INV_ANALYTICS_DB TO ROLE INV_ML_ENGINEER;

-- APP_ADMIN: Streamlit apps
GRANT USAGE ON DATABASE INV_ANALYTICS_DB TO ROLE INV_APP_ADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_APP_ADMIN;
GRANT CREATE STREAMLIT ON SCHEMA INV_ANALYTICS_DB.REPORTING TO ROLE INV_APP_ADMIN;
GRANT SELECT ON ALL TABLES IN DATABASE INV_ANALYTICS_DB TO ROLE INV_APP_ADMIN;
GRANT SELECT ON ALL VIEWS IN DATABASE INV_ANALYTICS_DB TO ROLE INV_APP_ADMIN;

-- DATA_ADMIN: Ownership
GRANT OWNERSHIP ON DATABASE INV_ANALYTICS_DB TO ROLE INV_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- INV_AI_READY_DB GRANTS
-- ------------------------------------------------------------
-- ML_ENGINEER: Full access
GRANT USAGE ON DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW ON ALL SCHEMAS IN DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE INV_AI_READY_DB TO ROLE INV_ML_ENGINEER;

-- DATA_ENGINEER: Read + write features
GRANT USAGE ON DATABASE INV_AI_READY_DB TO ROLE INV_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE INV_AI_READY_DB TO ROLE INV_DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN DATABASE INV_AI_READY_DB TO ROLE INV_DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE INV_AI_READY_DB TO ROLE INV_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA INV_AI_READY_DB.FEATURES TO ROLE INV_DATA_ENGINEER;

-- ML_ADMIN: Ownership
GRANT OWNERSHIP ON DATABASE INV_AI_READY_DB TO ROLE INV_ML_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 7: VERIFICATION
-- ============================================================

-- Verify all 5 databases
SHOW DATABASES LIKE 'INV_%';

-- Verify schema counts
SELECT 'INV_GOVERNANCE_DB' AS database_name, COUNT(*) AS schema_count
FROM INV_GOVERNANCE_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'INV_RAW_DB', COUNT(*)
FROM INV_RAW_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'INV_TRANSFORM_DB', COUNT(*)
FROM INV_TRANSFORM_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'INV_ANALYTICS_DB', COUNT(*)
FROM INV_ANALYTICS_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'INV_AI_READY_DB', COUNT(*)
FROM INV_AI_READY_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
ORDER BY database_name;

-- Verify grants
SHOW GRANTS ON DATABASE INV_RAW_DB;
SHOW GRANTS ON DATABASE INV_ANALYTICS_DB;
SHOW GRANTS ON DATABASE INV_AI_READY_DB;


-- ============================================================
-- SECTION 8: CREATE RAW LAYER TABLES
-- ============================================================
USE ROLE SYSADMIN;
USE DATABASE INV_RAW_DB;
USE SCHEMA MARKET_DATA;

CREATE TABLE IF NOT EXISTS RAW_DAILY_PRICES (
    record_id           NUMBER AUTOINCREMENT,
    security_id         VARCHAR(50),
    price_date          DATE,
    open_price          DECIMAL(18,6),
    high_price          DECIMAL(18,6),
    low_price           DECIMAL(18,6),
    close_price         DECIMAL(18,6),
    adjusted_close      DECIMAL(18,6),
    volume              NUMBER,
    currency            VARCHAR(3),
    source_system       VARCHAR(50),
    source_file         VARCHAR(500),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (record_id)
)
COMMENT = 'Raw daily price data from market data providers';

CREATE TABLE IF NOT EXISTS RAW_CORPORATE_ACTIONS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw corporate actions - dividends, splits, mergers';

USE SCHEMA PORTFOLIO_DATA;

CREATE TABLE IF NOT EXISTS RAW_HOLDINGS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    portfolio_code      VARCHAR(50),
    as_of_date          DATE,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw portfolio holdings from custodians';

CREATE TABLE IF NOT EXISTS RAW_TRANSACTIONS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw trade transactions';

USE SCHEMA REFERENCE_DATA;

CREATE TABLE IF NOT EXISTS RAW_SECURITIES_MASTER (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw securities master data';


-- ============================================================
-- SECTION 9: CREATE TRANSFORM LAYER TABLES
-- ============================================================
USE DATABASE INV_TRANSFORM_DB;
USE SCHEMA MASTER;

CREATE TABLE IF NOT EXISTS DIM_SECURITY (
    security_key        NUMBER AUTOINCREMENT,
    security_id         VARCHAR(50) NOT NULL,
    isin                VARCHAR(12),
    cusip               VARCHAR(9),
    sedol               VARCHAR(7),
    ticker              VARCHAR(20),
    security_name       VARCHAR(255),
    security_type       VARCHAR(50),
    asset_class         VARCHAR(50),
    sub_asset_class     VARCHAR(100),
    sector              VARCHAR(100),
    industry            VARCHAR(100),
    country             VARCHAR(3),
    currency            VARCHAR(3),
    exchange            VARCHAR(50),
    benchmark_index     VARCHAR(50),
    expense_ratio       DECIMAL(8,4),
    fund_manager        VARCHAR(100),
    inception_date      DATE,
    min_investment      DECIMAL(18,2),
    risk_rating         VARCHAR(20),
    is_active           BOOLEAN DEFAULT TRUE,
    effective_from      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    effective_to        TIMESTAMP_NTZ DEFAULT '9999-12-31 00:00:00'::TIMESTAMP_NTZ,
    is_current          BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (security_key)
)
COMMENT = 'Securities master dimension - SCD Type 2';

CREATE TABLE IF NOT EXISTS DIM_PORTFOLIO (
    portfolio_key       NUMBER AUTOINCREMENT,
    portfolio_id        VARCHAR(50) NOT NULL,
    portfolio_name      VARCHAR(255),
    portfolio_type      VARCHAR(50),
    strategy            VARCHAR(100),
    benchmark_id        VARCHAR(50),
    inception_date      DATE,
    base_currency       VARCHAR(3),
    fund_manager        VARCHAR(255),
    management_fee      DECIMAL(8,4),
    expense_ratio       DECIMAL(8,4),
    min_investment      DECIMAL(18,2),
    is_active           BOOLEAN DEFAULT TRUE,
    effective_from      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    effective_to        TIMESTAMP_NTZ DEFAULT '9999-12-31 00:00:00'::TIMESTAMP_NTZ,
    PRIMARY KEY (portfolio_key)
)
COMMENT = 'Portfolio/Fund master dimension';

CREATE TABLE IF NOT EXISTS DIM_DATE (
    date_key            NUMBER,
    calendar_date       DATE NOT NULL,
    year                NUMBER,
    quarter             NUMBER,
    month               NUMBER,
    month_name          VARCHAR(20),
    week_of_year        NUMBER,
    day_of_week         NUMBER,
    day_name            VARCHAR(20),
    is_weekend          BOOLEAN,
    is_us_trading_day   BOOLEAN,
    is_month_end        BOOLEAN,
    is_quarter_end      BOOLEAN,
    is_year_end         BOOLEAN,
    fiscal_year         NUMBER,
    fiscal_quarter      NUMBER,
    PRIMARY KEY (date_key)
)
COMMENT = 'Date dimension with trading day flags';

USE SCHEMA CLEANSED;

CREATE TABLE IF NOT EXISTS FACT_DAILY_PRICES (
    price_id            NUMBER AUTOINCREMENT,
    security_id         VARCHAR(50) NOT NULL,
    trade_date          DATE NOT NULL,
    open_price          DECIMAL(18,6),
    high_price          DECIMAL(18,6),
    low_price           DECIMAL(18,6),
    close_price         DECIMAL(18,6),
    adjusted_close      DECIMAL(18,6),
    volume              NUMBER,
    vwap                DECIMAL(18,6),
    currency            VARCHAR(3),
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (price_id),
    UNIQUE (security_id, trade_date)
)
COMMENT = 'Cleansed daily OHLCV price data';

CREATE TABLE IF NOT EXISTS FACT_HOLDINGS (
    holding_id          NUMBER AUTOINCREMENT,
    as_of_date          DATE NOT NULL,
    portfolio_id        VARCHAR(50) NOT NULL,
    security_id         VARCHAR(50) NOT NULL,
    quantity            DECIMAL(18,4),
    market_value        DECIMAL(18,2),
    cost_basis          DECIMAL(18,2),
    unrealized_pnl      DECIMAL(18,2),
    weight_pct          DECIMAL(8,6),
    currency            VARCHAR(3),
    benchmark_value     DECIMAL(18,2),
    gain_loss_pct       DECIMAL(10,4),
    annualized_return   DECIMAL(10,4),
    holding_period_days NUMBER,
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (holding_id)
)
COMMENT = 'Cleansed portfolio holdings';

CREATE TABLE IF NOT EXISTS FACT_TRANSACTIONS (
    transaction_id      VARCHAR(100) NOT NULL,
    trade_date          DATE NOT NULL,
    settlement_date     DATE,
    portfolio_id        VARCHAR(50) NOT NULL,
    security_id         VARCHAR(50) NOT NULL,
    transaction_type    VARCHAR(20),
    quantity            DECIMAL(18,4),
    price               DECIMAL(18,6),
    gross_amount        DECIMAL(18,2),
    commission          DECIMAL(18,2),
    fees                DECIMAL(18,2),
    net_amount          DECIMAL(18,2),
    currency            VARCHAR(3),
    broker              VARCHAR(100),
    status              VARCHAR(20),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (transaction_id)
)
COMMENT = 'Cleansed trade transactions';

CREATE TABLE IF NOT EXISTS FACT_NAV_HISTORY (
    nav_id              NUMBER AUTOINCREMENT,
    portfolio_id        VARCHAR(50) NOT NULL,
    as_of_date          DATE NOT NULL,
    nav_per_share       DECIMAL(18,6),
    total_nav           DECIMAL(18,2),
    shares_outstanding  DECIMAL(18,4),
    daily_return        DECIMAL(10,6),
    mtd_return          DECIMAL(10,6),
    qtd_return          DECIMAL(10,6),
    ytd_return          DECIMAL(10,6),
    benchmark_nav       DECIMAL(18,6),
    alpha               DECIMAL(10,6),
    beta                DECIMAL(10,6),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (nav_id),
    UNIQUE (portfolio_id, as_of_date)
)
COMMENT = 'NAV and returns history';


-- ============================================================
-- SECTION 10: CREATE ANALYTICS LAYER VIEWS
-- ============================================================
USE DATABASE INV_ANALYTICS_DB;
USE SCHEMA PERFORMANCE;

CREATE OR REPLACE VIEW VW_PORTFOLIO_PERFORMANCE AS
SELECT 
    p.portfolio_id,
    pm.portfolio_name,
    pm.portfolio_type,
    pm.strategy,
    n.as_of_date,
    n.nav_per_share,
    n.total_nav,
    n.daily_return,
    n.mtd_return,
    n.ytd_return,
    AVG(n.daily_return) OVER (
        PARTITION BY p.portfolio_id 
        ORDER BY n.as_of_date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) * 252 AS annualized_30d_return,
    STDDEV(n.daily_return) OVER (
        PARTITION BY p.portfolio_id 
        ORDER BY n.as_of_date 
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) * SQRT(252) AS annualized_30d_volatility
FROM INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY n
JOIN INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS p 
    ON n.portfolio_id = p.portfolio_id AND n.as_of_date = p.as_of_date
JOIN INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO pm 
    ON p.portfolio_id = pm.portfolio_id AND pm.is_active = TRUE;

USE SCHEMA RISK;

CREATE OR REPLACE VIEW VW_PORTFOLIO_RISK AS
WITH daily_returns AS (
    SELECT 
        portfolio_id,
        as_of_date,
        daily_return
    FROM INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY
    WHERE daily_return IS NOT NULL
      AND as_of_date >= DATEADD(YEAR, -1, CURRENT_DATE())
)
SELECT 
    portfolio_id,
    MAX(as_of_date) AS as_of_date,
    COUNT(*) AS trading_days,
    AVG(daily_return) * 252 AS annualized_return,
    STDDEV(daily_return) * SQRT(252) AS annualized_volatility,
    CASE 
        WHEN STDDEV(daily_return) > 0 
        THEN (AVG(daily_return) * 252) / (STDDEV(daily_return) * SQRT(252))
        ELSE NULL 
    END AS sharpe_ratio,
    PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY daily_return) AS var_95_daily,
    PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY daily_return) AS var_99_daily,
    MIN(daily_return) AS worst_daily_return,
    MAX(daily_return) AS best_daily_return
FROM daily_returns
GROUP BY portfolio_id;

USE SCHEMA REPORTING;

CREATE OR REPLACE VIEW VW_SECTOR_ALLOCATION AS
SELECT 
    h.as_of_date,
    h.portfolio_id,
    p.portfolio_name,
    s.sector,
    s.industry,
    s.country,
    COUNT(DISTINCT h.security_id) AS num_positions,
    SUM(h.market_value) AS total_market_value,
    SUM(h.weight_pct) AS total_weight_pct,
    SUM(h.unrealized_pnl) AS total_unrealized_pnl
FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS h
JOIN INV_TRANSFORM_DB.MASTER.DIM_SECURITY s 
    ON h.security_id = s.security_id AND s.is_current = TRUE
JOIN INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO p 
    ON h.portfolio_id = p.portfolio_id
GROUP BY 1, 2, 3, 4, 5, 6;

CREATE OR REPLACE VIEW VW_TOP_HOLDINGS AS
SELECT 
    h.as_of_date,
    h.portfolio_id,
    p.portfolio_name,
    h.security_id,
    s.ticker,
    s.security_name,
    s.security_type,
    s.sector,
    h.quantity,
    h.market_value,
    h.cost_basis,
    h.unrealized_pnl,
    h.weight_pct,
    ROW_NUMBER() OVER (
        PARTITION BY h.portfolio_id, h.as_of_date 
        ORDER BY h.market_value DESC
    ) AS holding_rank
FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS h
JOIN INV_TRANSFORM_DB.MASTER.DIM_SECURITY s 
    ON h.security_id = s.security_id AND s.is_current = TRUE
JOIN INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO p 
    ON h.portfolio_id = p.portfolio_id;


-- ============================================================
-- SECTION 11: CREATE AI_READY LAYER TABLES
-- ============================================================
USE DATABASE INV_AI_READY_DB;
USE SCHEMA FEATURES;

CREATE TABLE IF NOT EXISTS FACT_PRICE_FEATURES (
    feature_id          NUMBER AUTOINCREMENT,
    security_id         VARCHAR(50) NOT NULL,
    feature_date        DATE NOT NULL,
    close_price         DECIMAL(18,6),
    daily_return        DECIMAL(10,6),
    log_return          DECIMAL(10,6),
    sma_5               DECIMAL(18,6),
    sma_20              DECIMAL(18,6),
    sma_50              DECIMAL(18,6),
    sma_200             DECIMAL(18,6),
    ema_12              DECIMAL(18,6),
    ema_26              DECIMAL(18,6),
    volatility_20d      DECIMAL(10,6),
    volatility_60d      DECIMAL(10,6),
    rsi_14              DECIMAL(8,4),
    macd                DECIMAL(10,6),
    macd_signal         DECIMAL(10,6),
    volume_sma_20       DECIMAL(18,2),
    volume_ratio        DECIMAL(10,6),
    high_52w            DECIMAL(18,6),
    low_52w             DECIMAL(18,6),
    pct_from_high       DECIMAL(10,6),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feature_id),
    UNIQUE (security_id, feature_date)
)
COMMENT = 'Technical indicator features for ML models';

CREATE TABLE IF NOT EXISTS FACT_PORTFOLIO_FEATURES (
    feature_id          NUMBER AUTOINCREMENT,
    portfolio_id        VARCHAR(50) NOT NULL,
    feature_date        DATE NOT NULL,
    num_positions       NUMBER,
    concentration_top5  DECIMAL(8,6),
    concentration_top10 DECIMAL(8,6),
    sector_hhi          DECIMAL(10,6),
    return_1d           DECIMAL(10,6),
    return_5d           DECIMAL(10,6),
    return_20d          DECIMAL(10,6),
    return_60d          DECIMAL(10,6),
    volatility_20d      DECIMAL(10,6),
    volatility_60d      DECIMAL(10,6),
    sharpe_60d          DECIMAL(10,6),
    max_drawdown_60d    DECIMAL(10,6),
    beta_to_benchmark   DECIMAL(10,6),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feature_id)
)
COMMENT = 'Portfolio-level features for ML models';

USE SCHEMA TRAINING;

CREATE TABLE IF NOT EXISTS DS_RETURN_PREDICTION (
    record_id           NUMBER AUTOINCREMENT,
    security_id         VARCHAR(50),
    feature_date        DATE,
    return_1d           DECIMAL(10,6),
    return_5d           DECIMAL(10,6),
    return_20d          DECIMAL(10,6),
    volatility_20d      DECIMAL(10,6),
    rsi_14              DECIMAL(8,4),
    volume_ratio        DECIMAL(10,6),
    sma_cross           NUMBER,
    forward_return_5d   DECIMAL(10,6),
    forward_return_20d  DECIMAL(10,6),
    direction_5d        NUMBER,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (record_id)
)
COMMENT = 'Training dataset for return prediction models';

USE SCHEMA PREDICTIONS;

CREATE TABLE IF NOT EXISTS FACT_PREDICTIONS (
    prediction_id       NUMBER AUTOINCREMENT,
    model_name          VARCHAR(100),
    model_version       VARCHAR(50),
    prediction_date     DATE,
    security_id         VARCHAR(50),
    predicted_return    DECIMAL(10,6),
    predicted_direction NUMBER,
    confidence_score    DECIMAL(8,6),
    actual_return       DECIMAL(10,6),
    is_correct          BOOLEAN,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (prediction_id)
)
COMMENT = 'ML model predictions and actual outcomes';


-- ============================================================
-- SECTION 12: GENERATE SYNTHETIC DATA (~10,000 Records)
-- ============================================================
USE ROLE SYSADMIN;

CREATE OR REPLACE TEMPORARY TABLE TEMP_STOCK_NAMES AS
SELECT column1 AS company_name, column2 AS ticker, column3 AS sector, column4 AS industry
FROM VALUES
    ('Apple Inc', 'AAPL', 'Technology', 'Consumer Electronics'),
    ('Microsoft Corporation', 'MSFT', 'Technology', 'Software'),
    ('Amazon.com Inc', 'AMZN', 'Consumer Discretionary', 'E-Commerce'),
    ('Alphabet Inc', 'GOOGL', 'Technology', 'Internet Services'),
    ('Tesla Inc', 'TSLA', 'Consumer Discretionary', 'Automobiles'),
    ('NVIDIA Corporation', 'NVDA', 'Technology', 'Semiconductors'),
    ('Meta Platforms Inc', 'META', 'Technology', 'Social Media'),
    ('Berkshire Hathaway', 'BRK.B', 'Financials', 'Diversified Financials'),
    ('JPMorgan Chase & Co', 'JPM', 'Financials', 'Banking'),
    ('Johnson & Johnson', 'JNJ', 'Healthcare', 'Pharmaceuticals'),
    ('Visa Inc', 'V', 'Financials', 'Payment Processing'),
    ('UnitedHealth Group', 'UNH', 'Healthcare', 'Health Insurance'),
    ('Procter & Gamble', 'PG', 'Consumer Staples', 'Household Products'),
    ('Mastercard Inc', 'MA', 'Financials', 'Payment Processing'),
    ('Home Depot Inc', 'HD', 'Consumer Discretionary', 'Home Improvement'),
    ('Chevron Corporation', 'CVX', 'Energy', 'Oil & Gas'),
    ('Eli Lilly and Company', 'LLY', 'Healthcare', 'Pharmaceuticals'),
    ('AbbVie Inc', 'ABBV', 'Healthcare', 'Biotechnology'),
    ('Costco Wholesale', 'COST', 'Consumer Staples', 'Retail'),
    ('Coca-Cola Company', 'KO', 'Consumer Staples', 'Beverages'),
    ('PepsiCo Inc', 'PEP', 'Consumer Staples', 'Beverages'),
    ('Walmart Inc', 'WMT', 'Consumer Staples', 'Retail'),
    ('Exxon Mobil Corp', 'XOM', 'Energy', 'Oil & Gas'),
    ('Adobe Inc', 'ADBE', 'Technology', 'Software'),
    ('Salesforce Inc', 'CRM', 'Technology', 'Cloud Computing'),
    ('Netflix Inc', 'NFLX', 'Communication Services', 'Streaming'),
    ('Intel Corporation', 'INTC', 'Technology', 'Semiconductors'),
    ('Cisco Systems Inc', 'CSCO', 'Technology', 'Networking'),
    ('Oracle Corporation', 'ORCL', 'Technology', 'Enterprise Software'),
    ('Walt Disney Company', 'DIS', 'Communication Services', 'Entertainment'),
    ('PayPal Holdings', 'PYPL', 'Financials', 'Payment Processing'),
    ('Goldman Sachs Group', 'GS', 'Financials', 'Investment Banking'),
    ('Morgan Stanley', 'MS', 'Financials', 'Investment Banking'),
    ('Bank of America', 'BAC', 'Financials', 'Banking'),
    ('Wells Fargo & Co', 'WFC', 'Financials', 'Banking'),
    ('Caterpillar Inc', 'CAT', 'Industrials', 'Machinery'),
    ('Boeing Company', 'BA', 'Industrials', 'Aerospace'),
    ('3M Company', 'MMM', 'Industrials', 'Conglomerate'),
    ('General Electric', 'GE', 'Industrials', 'Conglomerate'),
    ('Lockheed Martin', 'LMT', 'Industrials', 'Defense'),
    ('Raytheon Technologies', 'RTX', 'Industrials', 'Defense'),
    ('American Express', 'AXP', 'Financials', 'Credit Services'),
    ('Target Corporation', 'TGT', 'Consumer Discretionary', 'Retail'),
    ('Starbucks Corporation', 'SBUX', 'Consumer Discretionary', 'Restaurants'),
    ('McDonalds Corporation', 'MCD', 'Consumer Discretionary', 'Restaurants'),
    ('Nike Inc', 'NKE', 'Consumer Discretionary', 'Apparel'),
    ('Qualcomm Inc', 'QCOM', 'Technology', 'Semiconductors'),
    ('Texas Instruments', 'TXN', 'Technology', 'Semiconductors'),
    ('Broadcom Inc', 'AVGO', 'Technology', 'Semiconductors'),
    ('Applied Materials', 'AMAT', 'Technology', 'Semiconductors')
AS t(column1, column2, column3, column4);

CREATE OR REPLACE TEMPORARY TABLE TEMP_FUND_NAMES AS
SELECT column1 AS fund_name, column2 AS ticker, column3 AS category, column4 AS strategy
FROM VALUES
    ('Vanguard 500 Index Fund', 'VFIAX', 'Large Cap Blend', 'Index'),
    ('Fidelity Contrafund', 'FCNTX', 'Large Cap Growth', 'Active'),
    ('Vanguard Total Stock Market', 'VTSAX', 'Total Market', 'Index'),
    ('T. Rowe Price Blue Chip Growth', 'TRBCX', 'Large Cap Growth', 'Active'),
    ('Fidelity Growth Company', 'FDGRX', 'Large Cap Growth', 'Active'),
    ('Vanguard Growth Index', 'VIGAX', 'Large Cap Growth', 'Index'),
    ('American Funds Growth Fund', 'AGTHX', 'Large Cap Growth', 'Active'),
    ('Vanguard Value Index', 'VVIAX', 'Large Cap Value', 'Index'),
    ('Dodge & Cox Stock Fund', 'DODGX', 'Large Cap Value', 'Active'),
    ('Fidelity Low-Priced Stock', 'FLPSX', 'Mid Cap Value', 'Active'),
    ('Vanguard Mid-Cap Index', 'VIMAX', 'Mid Cap Blend', 'Index'),
    ('T. Rowe Price Mid-Cap Growth', 'RPMGX', 'Mid Cap Growth', 'Active'),
    ('Vanguard Small Cap Index', 'VSMAX', 'Small Cap Blend', 'Index'),
    ('Fidelity Small Cap Discovery', 'FSCRX', 'Small Cap Growth', 'Active'),
    ('Vanguard International Growth', 'VWIGX', 'International Growth', 'Active'),
    ('Fidelity International Index', 'FSPSX', 'International Blend', 'Index'),
    ('American Funds EuroPacific', 'AEPGX', 'International Growth', 'Active'),
    ('Vanguard Emerging Markets', 'VEMAX', 'Emerging Markets', 'Index'),
    ('T. Rowe Price Emerging Markets', 'PRMSX', 'Emerging Markets', 'Active'),
    ('Vanguard Total Bond Market', 'VBTLX', 'Intermediate Bond', 'Index'),
    ('PIMCO Total Return', 'PTTRX', 'Intermediate Bond', 'Active'),
    ('Fidelity US Bond Index', 'FXNAX', 'Intermediate Bond', 'Index'),
    ('Vanguard High-Yield Corporate', 'VWEHX', 'High Yield Bond', 'Active'),
    ('BlackRock High Yield Bond', 'BHYAX', 'High Yield Bond', 'Active'),
    ('Vanguard Balanced Index', 'VBIAX', 'Balanced', 'Index'),
    ('Fidelity Balanced Fund', 'FBALX', 'Balanced', 'Active'),
    ('Vanguard Target Retirement 2030', 'VTHRX', 'Target Date', 'Index'),
    ('Fidelity Freedom 2035', 'FFTHX', 'Target Date', 'Active'),
    ('Vanguard REIT Index', 'VGSLX', 'Real Estate', 'Index'),
    ('Fidelity Real Estate Income', 'FRIFX', 'Real Estate', 'Active'),
    ('Vanguard Health Care Fund', 'VGHCX', 'Healthcare', 'Active'),
    ('Fidelity Select Technology', 'FSPTX', 'Technology', 'Active'),
    ('T. Rowe Price Science & Tech', 'PRSCX', 'Technology', 'Active'),
    ('Vanguard Energy Fund', 'VGENX', 'Energy', 'Active'),
    ('Fidelity Select Financial', 'FIDSX', 'Financials', 'Active'),
    ('Invesco QQQ Trust', 'QQQ', 'Large Cap Growth', 'Index'),
    ('SPDR S&P 500 ETF', 'SPY', 'Large Cap Blend', 'Index'),
    ('iShares Core S&P 500', 'IVV', 'Large Cap Blend', 'Index'),
    ('Vanguard S&P 500 ETF', 'VOO', 'Large Cap Blend', 'Index'),
    ('iShares Russell 2000', 'IWM', 'Small Cap Blend', 'Index')
AS t(column1, column2, column3, column4);


-- Generate Securities (500 Records: 200 Stocks + 200 Mutual Funds + 100 ETFs)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.MASTER.DIM_SECURITY;

INSERT INTO INV_TRANSFORM_DB.MASTER.DIM_SECURITY (
    security_id, isin, cusip, ticker, security_name, security_type, 
    asset_class, sub_asset_class, sector, industry, country, currency, 
    exchange, benchmark_index, expense_ratio, risk_rating, inception_date,
    is_active, effective_from, is_current
)
SELECT 
    'SEC-STK-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5, '0') AS security_id,
    'US' || LPAD(ABS(HASH(s.ticker || SEQ4())), 10, '0') AS isin,
    LPAD(ABS(HASH(s.ticker)), 9, '0') AS cusip,
    s.ticker || CASE WHEN SEQ4() > 0 THEN '-' || SEQ4() ELSE '' END AS ticker,
    s.company_name || CASE WHEN SEQ4() > 0 THEN ' Series ' || CHR(65 + MOD(SEQ4(), 26)) ELSE '' END AS security_name,
    'STOCK' AS security_type,
    'EQUITY' AS asset_class,
    CASE 
        WHEN s.sector = 'Technology' THEN 'LARGE_CAP_GROWTH'
        WHEN s.sector = 'Financials' THEN 'LARGE_CAP_VALUE'
        WHEN s.sector = 'Healthcare' THEN 'LARGE_CAP_BLEND'
        ELSE 'LARGE_CAP_BLEND'
    END AS sub_asset_class,
    s.sector,
    s.industry,
    'USA' AS country,
    'USD' AS currency,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'NYSE' WHEN 1 THEN 'NASDAQ' ELSE 'AMEX' END AS exchange,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'SPX' WHEN 1 THEN 'NDX' ELSE 'RUT' END AS benchmark_index,
    NULL AS expense_ratio,
    CASE MOD(SEQ4(), 5) 
        WHEN 0 THEN 'LOW'
        WHEN 1 THEN 'LOW-MEDIUM'
        WHEN 2 THEN 'MEDIUM'
        WHEN 3 THEN 'MEDIUM-HIGH'
        ELSE 'HIGH'
    END AS risk_rating,
    DATEADD(DAY, -UNIFORM(365, 10000, RANDOM()), CURRENT_DATE()) AS inception_date,
    TRUE,
    CURRENT_TIMESTAMP(),
    TRUE
FROM TEMP_STOCK_NAMES s,
     TABLE(GENERATOR(ROWCOUNT => 4)) g
LIMIT 200;

INSERT INTO INV_TRANSFORM_DB.MASTER.DIM_SECURITY (
    security_id, isin, cusip, ticker, security_name, security_type,
    asset_class, sub_asset_class, sector, industry, country, currency,
    exchange, benchmark_index, expense_ratio, fund_manager, risk_rating,
    min_investment, inception_date, is_active, effective_from, is_current
)
SELECT 
    'SEC-MF-' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 5, '0') AS security_id,
    'US' || LPAD(ABS(HASH(f.ticker || SEQ4())), 10, '0') AS isin,
    LPAD(ABS(HASH(f.ticker)), 9, '0') AS cusip,
    f.ticker || CASE WHEN SEQ4() > 0 THEN TO_VARCHAR(SEQ4()) ELSE '' END AS ticker,
    f.fund_name || CASE WHEN SEQ4() > 0 THEN ' Class ' || CHR(65 + MOD(SEQ4(), 5)) ELSE '' END AS security_name,
    'MUTUAL_FUND' AS security_type,
    CASE 
        WHEN f.category LIKE '%Bond%' THEN 'FIXED_INCOME'
        WHEN f.category LIKE '%International%' OR f.category LIKE '%Emerging%' THEN 'INTERNATIONAL_EQUITY'
        ELSE 'EQUITY'
    END AS asset_class,
    f.category AS sub_asset_class,
    COALESCE(NULLIF(f.category, ''), 'Diversified') AS sector,
    f.strategy AS industry,
    'USA' AS country,
    'USD' AS currency,
    'MUTUAL_FUND' AS exchange,
    CASE 
        WHEN f.category LIKE '%Growth%' THEN 'RLG'
        WHEN f.category LIKE '%Value%' THEN 'RLV'
        WHEN f.category LIKE '%Bond%' THEN 'LBUSTRUU'
        WHEN f.category LIKE '%International%' THEN 'MXWO'
        WHEN f.category LIKE '%Emerging%' THEN 'MXEF'
        ELSE 'SPX'
    END AS benchmark_index,
    ROUND(UNIFORM(0.03, 1.50, RANDOM()), 2) AS expense_ratio,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'John Smith'
        WHEN 1 THEN 'Sarah Johnson'
        WHEN 2 THEN 'Michael Chen'
        WHEN 3 THEN 'Emily Davis'
        WHEN 4 THEN 'Robert Wilson'
        WHEN 5 THEN 'Jennifer Lee'
        WHEN 6 THEN 'David Brown'
        ELSE 'Lisa Anderson'
    END AS fund_manager,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'LOW'
        WHEN 1 THEN 'LOW-MEDIUM'
        WHEN 2 THEN 'MEDIUM'
        WHEN 3 THEN 'MEDIUM-HIGH'
        ELSE 'HIGH'
    END AS risk_rating,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 1000
        WHEN 1 THEN 2500
        WHEN 2 THEN 3000
        ELSE 5000
    END AS min_investment,
    DATEADD(DAY, -UNIFORM(365, 15000, RANDOM()), CURRENT_DATE()) AS inception_date,
    TRUE,
    CURRENT_TIMESTAMP(),
    TRUE
FROM TEMP_FUND_NAMES f,
     TABLE(GENERATOR(ROWCOUNT => 5)) g
LIMIT 200;

INSERT INTO INV_TRANSFORM_DB.MASTER.DIM_SECURITY (
    security_id, isin, cusip, ticker, security_name, security_type,
    asset_class, sub_asset_class, sector, industry, country, currency,
    exchange, benchmark_index, expense_ratio, risk_rating, inception_date,
    is_active, effective_from, is_current
)
SELECT 
    'SEC-ETF-' || LPAD(SEQ4(), 5, '0') AS security_id,
    'US' || LPAD(ABS(HASH('ETF' || SEQ4())), 10, '0') AS isin,
    LPAD(ABS(HASH('ETF' || SEQ4())), 9, '0') AS cusip,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'SPY' WHEN 1 THEN 'QQQ' WHEN 2 THEN 'IWM' WHEN 3 THEN 'DIA'
        WHEN 4 THEN 'VTI' WHEN 5 THEN 'VOO' WHEN 6 THEN 'IVV' WHEN 7 THEN 'VEA'
        WHEN 8 THEN 'VWO' WHEN 9 THEN 'EFA' WHEN 10 THEN 'AGG' WHEN 11 THEN 'BND'
        WHEN 12 THEN 'LQD' WHEN 13 THEN 'HYG' WHEN 14 THEN 'TLT' WHEN 15 THEN 'GLD'
        WHEN 16 THEN 'SLV' WHEN 17 THEN 'XLF' WHEN 18 THEN 'XLK' ELSE 'XLE'
    END || '-' || LPAD(SEQ4(), 2, '0') AS ticker,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'SPDR S&P 500 ETF Trust'
        WHEN 1 THEN 'Invesco QQQ Trust'
        WHEN 2 THEN 'iShares Russell 2000 ETF'
        WHEN 3 THEN 'SPDR Dow Jones Industrial ETF'
        WHEN 4 THEN 'Vanguard Total Stock Market ETF'
        WHEN 5 THEN 'Vanguard S&P 500 ETF'
        WHEN 6 THEN 'iShares Core S&P 500 ETF'
        WHEN 7 THEN 'Vanguard FTSE Developed Markets ETF'
        WHEN 8 THEN 'Vanguard FTSE Emerging Markets ETF'
        WHEN 9 THEN 'iShares MSCI EAFE ETF'
        WHEN 10 THEN 'iShares Core US Aggregate Bond ETF'
        WHEN 11 THEN 'Vanguard Total Bond Market ETF'
        WHEN 12 THEN 'iShares iBoxx Investment Grade Bond ETF'
        WHEN 13 THEN 'iShares iBoxx High Yield Bond ETF'
        WHEN 14 THEN 'iShares 20+ Year Treasury Bond ETF'
        WHEN 15 THEN 'SPDR Gold Shares ETF'
        WHEN 16 THEN 'iShares Silver Trust ETF'
        WHEN 17 THEN 'Financial Select Sector SPDR ETF'
        WHEN 18 THEN 'Technology Select Sector SPDR ETF'
        ELSE 'Energy Select Sector SPDR ETF'
    END || ' Series ' || CHR(65 + MOD(SEQ4(), 5)) AS security_name,
    'ETF' AS security_type,
    CASE 
        WHEN MOD(SEQ4(), 20) BETWEEN 10 AND 14 THEN 'FIXED_INCOME'
        WHEN MOD(SEQ4(), 20) BETWEEN 15 AND 16 THEN 'COMMODITIES'
        WHEN MOD(SEQ4(), 20) BETWEEN 7 AND 9 THEN 'INTERNATIONAL_EQUITY'
        ELSE 'EQUITY'
    END AS asset_class,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'LARGE_CAP_BLEND'
        WHEN 1 THEN 'LARGE_CAP_GROWTH'
        WHEN 2 THEN 'SMALL_CAP_BLEND'
        WHEN 3 THEN 'INTERNATIONAL'
        ELSE 'FIXED_INCOME'
    END AS sub_asset_class,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Diversified' WHEN 1 THEN 'Technology' WHEN 2 THEN 'Financials'
        WHEN 3 THEN 'Healthcare' WHEN 4 THEN 'Energy' WHEN 5 THEN 'Consumer'
        WHEN 6 THEN 'International' WHEN 7 THEN 'Fixed Income' WHEN 8 THEN 'Commodities'
        ELSE 'Real Estate'
    END AS sector,
    'Passive' AS industry,
    'USA' AS country,
    'USD' AS currency,
    CASE MOD(SEQ4(), 2) WHEN 0 THEN 'NYSE_ARCA' ELSE 'NASDAQ' END AS exchange,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'SPX' WHEN 1 THEN 'NDX' WHEN 2 THEN 'RUT' ELSE 'MXWO' END AS benchmark_index,
    ROUND(UNIFORM(0.03, 0.50, RANDOM()), 2) AS expense_ratio,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'LOW'
        WHEN 1 THEN 'MEDIUM'
        WHEN 2 THEN 'MEDIUM-HIGH'
        ELSE 'HIGH'
    END AS risk_rating,
    DATEADD(DAY, -UNIFORM(365, 8000, RANDOM()), CURRENT_DATE()) AS inception_date,
    TRUE,
    CURRENT_TIMESTAMP(),
    TRUE
FROM TABLE(GENERATOR(ROWCOUNT => 100));


-- Generate Portfolios (50 Records)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO;

INSERT INTO INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO (
    portfolio_id, portfolio_name, portfolio_type, strategy, benchmark_id,
    inception_date, base_currency, fund_manager, management_fee, expense_ratio,
    min_investment, is_active, effective_from
)
SELECT 
    'PORT-' || LPAD(SEQ4(), 4, '0') AS portfolio_id,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Growth Equity Fund'
        WHEN 1 THEN 'Value Investment Portfolio'
        WHEN 2 THEN 'Balanced Growth Fund'
        WHEN 3 THEN 'Income & Growth Portfolio'
        WHEN 4 THEN 'Aggressive Growth Fund'
        WHEN 5 THEN 'Conservative Income Fund'
        WHEN 6 THEN 'Global Diversified Portfolio'
        WHEN 7 THEN 'Technology Leaders Fund'
        WHEN 8 THEN 'Dividend Income Portfolio'
        ELSE 'Total Return Fund'
    END || ' ' || CHR(65 + MOD(SEQ4(), 26)) AS portfolio_name,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'MUTUAL_FUND'
        WHEN 1 THEN 'HEDGE_FUND'
        WHEN 2 THEN 'SMA'
        WHEN 3 THEN 'ETF'
        ELSE 'PENSION'
    END AS portfolio_type,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'GROWTH'
        WHEN 1 THEN 'VALUE'
        WHEN 2 THEN 'BALANCED'
        WHEN 3 THEN 'INCOME'
        WHEN 4 THEN 'INDEX'
        WHEN 5 THEN 'MOMENTUM'
        WHEN 6 THEN 'DIVIDEND'
        ELSE 'MULTI_STRATEGY'
    END AS strategy,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'SPX'
        WHEN 1 THEN 'NDX'
        WHEN 2 THEN 'RUT'
        WHEN 3 THEN 'MXWO'
        ELSE 'LBUSTRUU'
    END AS benchmark_id,
    DATEADD(DAY, -UNIFORM(365, 5000, RANDOM()), CURRENT_DATE()) AS inception_date,
    'USD' AS base_currency,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'James Morrison'
        WHEN 1 THEN 'Patricia Clark'
        WHEN 2 THEN 'William Taylor'
        WHEN 3 THEN 'Elizabeth Martinez'
        WHEN 4 THEN 'Christopher Lee'
        WHEN 5 THEN 'Amanda White'
        WHEN 6 THEN 'Daniel Harris'
        WHEN 7 THEN 'Michelle Thompson'
        WHEN 8 THEN 'Andrew Garcia'
        ELSE 'Rebecca Robinson'
    END AS fund_manager,
    ROUND(UNIFORM(0.25, 2.00, RANDOM()), 2) AS management_fee,
    ROUND(UNIFORM(0.10, 1.50, RANDOM()), 2) AS expense_ratio,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 10000
        WHEN 1 THEN 25000
        WHEN 2 THEN 50000
        ELSE 100000
    END AS min_investment,
    TRUE,
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 50));


-- Generate Date Dimension (3+ Years)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.MASTER.DIM_DATE;

INSERT INTO INV_TRANSFORM_DB.MASTER.DIM_DATE (
    date_key, calendar_date, year, quarter, month, month_name,
    week_of_year, day_of_week, day_name, is_weekend, is_us_trading_day,
    is_month_end, is_quarter_end, is_year_end, fiscal_year, fiscal_quarter
)
SELECT 
    TO_NUMBER(TO_CHAR(DATEADD(DAY, SEQ4(), '2022-01-01'), 'YYYYMMDD')) AS date_key,
    DATEADD(DAY, SEQ4(), '2022-01-01') AS calendar_date,
    YEAR(DATEADD(DAY, SEQ4(), '2022-01-01')) AS year,
    QUARTER(DATEADD(DAY, SEQ4(), '2022-01-01')) AS quarter,
    MONTH(DATEADD(DAY, SEQ4(), '2022-01-01')) AS month,
    MONTHNAME(DATEADD(DAY, SEQ4(), '2022-01-01')) AS month_name,
    WEEKOFYEAR(DATEADD(DAY, SEQ4(), '2022-01-01')) AS week_of_year,
    DAYOFWEEK(DATEADD(DAY, SEQ4(), '2022-01-01')) AS day_of_week,
    DAYNAME(DATEADD(DAY, SEQ4(), '2022-01-01')) AS day_name,
    CASE WHEN DAYOFWEEK(DATEADD(DAY, SEQ4(), '2022-01-01')) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend,
    CASE WHEN DAYOFWEEK(DATEADD(DAY, SEQ4(), '2022-01-01')) NOT IN (0, 6) THEN TRUE ELSE FALSE END AS is_us_trading_day,
    CASE WHEN DATEADD(DAY, SEQ4(), '2022-01-01') = LAST_DAY(DATEADD(DAY, SEQ4(), '2022-01-01')) THEN TRUE ELSE FALSE END AS is_month_end,
    CASE WHEN MONTH(DATEADD(DAY, SEQ4(), '2022-01-01')) IN (3, 6, 9, 12) AND 
              DATEADD(DAY, SEQ4(), '2022-01-01') = LAST_DAY(DATEADD(DAY, SEQ4(), '2022-01-01')) THEN TRUE ELSE FALSE END AS is_quarter_end,
    CASE WHEN MONTH(DATEADD(DAY, SEQ4(), '2022-01-01')) = 12 AND 
              DAY(DATEADD(DAY, SEQ4(), '2022-01-01')) = 31 THEN TRUE ELSE FALSE END AS is_year_end,
    YEAR(DATEADD(DAY, SEQ4(), '2022-01-01')) AS fiscal_year,
    QUARTER(DATEADD(DAY, SEQ4(), '2022-01-01')) AS fiscal_quarter
FROM TABLE(GENERATOR(ROWCOUNT => 1461))
WHERE DATEADD(DAY, SEQ4(), '2022-01-01') <= CURRENT_DATE();


-- Generate Holdings (~5000 Records)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS;

INSERT INTO INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS (
    as_of_date, portfolio_id, security_id, quantity, market_value, cost_basis,
    unrealized_pnl, weight_pct, currency, benchmark_value, gain_loss_pct,
    annualized_return, holding_period_days, load_timestamp
)
WITH portfolios AS (
    SELECT portfolio_id FROM INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO
),
securities AS (
    SELECT security_id, security_type FROM INV_TRANSFORM_DB.MASTER.DIM_SECURITY WHERE is_current = TRUE
),
date_range AS (
    SELECT DISTINCT calendar_date 
    FROM INV_TRANSFORM_DB.MASTER.DIM_DATE 
    WHERE is_us_trading_day = TRUE 
      AND calendar_date >= DATEADD(MONTH, -6, CURRENT_DATE())
      AND calendar_date <= CURRENT_DATE()
    ORDER BY RANDOM()
    LIMIT 20
),
holding_base AS (
    SELECT 
        d.calendar_date AS as_of_date,
        p.portfolio_id,
        s.security_id,
        CASE 
            WHEN s.security_type = 'STOCK' THEN ROUND(UNIFORM(100, 10000, RANDOM()), 0)
            WHEN s.security_type = 'MUTUAL_FUND' THEN ROUND(UNIFORM(50, 5000, RANDOM()), 2)
            ELSE ROUND(UNIFORM(100, 5000, RANDOM()), 0)
        END AS quantity,
        ROUND(UNIFORM(10, 500, RANDOM()), 2) AS current_price,
        ROUND(UNIFORM(0.70, 1.30, RANDOM()), 4) AS cost_multiplier,
        UNIFORM(30, 1000, RANDOM()) AS holding_period_days
    FROM date_range d
    CROSS JOIN portfolios p
    CROSS JOIN securities s
    WHERE UNIFORM(0, 1, RANDOM()) < 0.10
)
SELECT 
    h.as_of_date,
    h.portfolio_id,
    h.security_id,
    h.quantity,
    ROUND(h.quantity * h.current_price, 2) AS market_value,
    ROUND(h.quantity * h.current_price * h.cost_multiplier, 2) AS cost_basis,
    ROUND(h.quantity * h.current_price - h.quantity * h.current_price * h.cost_multiplier, 2) AS unrealized_pnl,
    ROUND(UNIFORM(0.1, 15.0, RANDOM()), 4) AS weight_pct,
    'USD' AS currency,
    ROUND(h.quantity * h.current_price * UNIFORM(0.95, 1.05, RANDOM()), 2) AS benchmark_value,
    ROUND((1 - h.cost_multiplier) * 100, 4) AS gain_loss_pct,
    ROUND(((1 / h.cost_multiplier) - 1) * (365.0 / h.holding_period_days) * 100, 4) AS annualized_return,
    h.holding_period_days,
    CURRENT_TIMESTAMP() AS load_timestamp
FROM holding_base h
LIMIT 5000;


-- Generate Daily Prices (~3000 Records)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES;

INSERT INTO INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES (
    security_id, trade_date, open_price, high_price, low_price, close_price,
    adjusted_close, volume, vwap, currency, source_system, load_timestamp
)
WITH securities AS (
    SELECT security_id, security_type 
    FROM INV_TRANSFORM_DB.MASTER.DIM_SECURITY 
    WHERE is_current = TRUE
    ORDER BY RANDOM()
    LIMIT 100
),
trading_days AS (
    SELECT calendar_date
    FROM INV_TRANSFORM_DB.MASTER.DIM_DATE
    WHERE is_us_trading_day = TRUE
      AND calendar_date >= DATEADD(DAY, -30, CURRENT_DATE())
      AND calendar_date <= CURRENT_DATE()
)
SELECT 
    s.security_id,
    t.calendar_date AS trade_date,
    ROUND(UNIFORM(10, 500, RANDOM()), 2) AS base_price,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(1.02, 1.05, RANDOM()), 2) AS high_price,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(0.95, 0.98, RANDOM()), 2) AS low_price,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(0.97, 1.03, RANDOM()), 2) AS close_price,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(0.97, 1.03, RANDOM()), 2) AS adjusted_close,
    ROUND(UNIFORM(100000, 50000000, RANDOM()), 0) AS volume,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(0.98, 1.02, RANDOM()), 2) AS vwap,
    'USD' AS currency,
    CASE MOD(HASH(s.security_id), 3)
        WHEN 0 THEN 'BLOOMBERG'
        WHEN 1 THEN 'REUTERS'
        ELSE 'FACTSET'
    END AS source_system,
    CURRENT_TIMESTAMP() AS load_timestamp
FROM securities s
CROSS JOIN trading_days t
LIMIT 3000;


-- Generate NAV History (~2000 Records)
TRUNCATE TABLE IF EXISTS INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY;

INSERT INTO INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY (
    portfolio_id, as_of_date, nav_per_share, total_nav, shares_outstanding,
    daily_return, mtd_return, qtd_return, ytd_return, benchmark_nav, alpha, beta,
    load_timestamp
)
WITH portfolios AS (
    SELECT portfolio_id, benchmark_id FROM INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO
),
trading_days AS (
    SELECT calendar_date
    FROM INV_TRANSFORM_DB.MASTER.DIM_DATE
    WHERE is_us_trading_day = TRUE
      AND calendar_date >= DATEADD(MONTH, -3, CURRENT_DATE())
      AND calendar_date <= CURRENT_DATE()
)
SELECT 
    p.portfolio_id,
    t.calendar_date AS as_of_date,
    ROUND(UNIFORM(10, 500, RANDOM()), 4) AS nav_per_share,
    ROUND(UNIFORM(1000000, 500000000, RANDOM()), 2) AS total_nav,
    ROUND(UNIFORM(100000, 10000000, RANDOM()), 2) AS shares_outstanding,
    ROUND(UNIFORM(-0.05, 0.05, RANDOM()), 6) AS daily_return,
    ROUND(UNIFORM(-0.10, 0.15, RANDOM()), 6) AS mtd_return,
    ROUND(UNIFORM(-0.15, 0.20, RANDOM()), 6) AS qtd_return,
    ROUND(UNIFORM(-0.20, 0.30, RANDOM()), 6) AS ytd_return,
    ROUND(UNIFORM(10, 500, RANDOM()) * UNIFORM(0.95, 1.05, RANDOM()), 4) AS benchmark_nav,
    ROUND(UNIFORM(-0.02, 0.05, RANDOM()), 6) AS alpha,
    ROUND(UNIFORM(0.7, 1.3, RANDOM()), 4) AS beta,
    CURRENT_TIMESTAMP() AS load_timestamp
FROM portfolios p
CROSS JOIN trading_days t
LIMIT 2000;


-- Create Investment Summary View
CREATE OR REPLACE VIEW INV_ANALYTICS_DB.REPORTING.VW_INVESTMENT_SUMMARY AS
SELECT 
    h.as_of_date,
    h.portfolio_id,
    p.portfolio_name,
    p.portfolio_type,
    p.strategy AS portfolio_strategy,
    p.fund_manager AS portfolio_manager,
    h.security_id,
    s.security_name AS investment_name,
    s.ticker,
    s.security_type,
    s.asset_class,
    s.sector,
    s.industry,
    s.benchmark_index,
    s.expense_ratio AS fund_expense_ratio,
    s.risk_rating,
    h.quantity AS shares_units_held,
    h.cost_basis AS holding_cost,
    h.market_value AS current_value,
    h.unrealized_pnl AS gain_loss_amount,
    h.gain_loss_pct,
    h.benchmark_value,
    h.market_value - h.benchmark_value AS vs_benchmark,
    h.weight_pct AS portfolio_weight,
    h.holding_period_days,
    h.annualized_return,
    n.nav_per_share,
    n.total_nav AS portfolio_total_nav,
    n.daily_return AS portfolio_daily_return,
    n.ytd_return AS portfolio_ytd_return,
    n.benchmark_nav,
    n.alpha,
    n.beta
FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS h
JOIN INV_TRANSFORM_DB.MASTER.DIM_SECURITY s 
    ON h.security_id = s.security_id AND s.is_current = TRUE
JOIN INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO p 
    ON h.portfolio_id = p.portfolio_id
LEFT JOIN INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY n 
    ON h.portfolio_id = n.portfolio_id AND h.as_of_date = n.as_of_date;


-- ============================================================
-- SECTION 13: DATA VERIFICATION
-- ============================================================

SELECT 'DIM_SECURITY' AS table_name, COUNT(*) AS record_count FROM INV_TRANSFORM_DB.MASTER.DIM_SECURITY
UNION ALL
SELECT 'DIM_PORTFOLIO', COUNT(*) FROM INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO
UNION ALL
SELECT 'DIM_DATE', COUNT(*) FROM INV_TRANSFORM_DB.MASTER.DIM_DATE
UNION ALL
SELECT 'FACT_HOLDINGS', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS
UNION ALL
SELECT 'FACT_DAILY_PRICES', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES
UNION ALL
SELECT 'FACT_NAV_HISTORY', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY;

SELECT 
    investment_name,
    ticker,
    security_type,
    benchmark_index,
    holding_cost,
    current_value,
    gain_loss_amount,
    gain_loss_pct,
    benchmark_value,
    nav_per_share,
    annualized_return
FROM INV_ANALYTICS_DB.REPORTING.VW_INVESTMENT_SUMMARY
LIMIT 20;

SELECT 
    security_type,
    COUNT(*) AS num_holdings,
    ROUND(SUM(holding_cost), 2) AS total_cost,
    ROUND(SUM(current_value), 2) AS total_value,
    ROUND(SUM(gain_loss_amount), 2) AS total_gain_loss,
    ROUND(AVG(gain_loss_pct), 2) AS avg_return_pct
FROM INV_ANALYTICS_DB.REPORTING.VW_INVESTMENT_SUMMARY
GROUP BY security_type
ORDER BY total_value DESC;


-- ============================================================
-- SECTION 14: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 04: DATABASE STRUCTURE - SUMMARY
================================================================================

DATABASES CREATED: 5
┌────────────────────┬──────────────┬───────────────────────────────────────────┐
│ Database           │ Retention    │ Purpose                                   │
├────────────────────┼──────────────┼───────────────────────────────────────────┤
│ INV_GOVERNANCE_DB  │ (default)    │ Security, monitoring, policies            │
│ INV_RAW_DB         │ 90 days      │ Bronze: Raw market/portfolio data         │
│ INV_TRANSFORM_DB   │ 30 days      │ Silver: Cleansed, validated data          │
│ INV_ANALYTICS_DB   │ 90 days      │ Gold: Business-ready analytics            │
│ INV_AI_READY_DB    │ 30 days      │ Platinum: ML features, models             │
└────────────────────┴──────────────┴───────────────────────────────────────────┘

SCHEMAS CREATED: 22 Total
┌────────────────────┬─────────────────────────────────────────────────────────┐
│ Database           │ Schemas                                                 │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ INV_GOVERNANCE_DB  │ SECURITY, MONITORING, POLICIES, TAGS (4)               │
│ INV_RAW_DB         │ MARKET_DATA, PORTFOLIO_DATA, REFERENCE_DATA,           │
│                    │ EXTERNAL_DATA, STAGING (5)                              │
│ INV_TRANSFORM_DB   │ CLEANSED, MASTER, HISTORY, INTERMEDIATE (4)            │
│ INV_ANALYTICS_DB   │ CORE, PERFORMANCE, RISK, REPORTING, COMPLIANCE (5)     │
│ INV_AI_READY_DB    │ FEATURES, TRAINING, MODELS, PREDICTIONS, EXPERIMENTS(5)│
└────────────────────┴─────────────────────────────────────────────────────────┘

DATABASE OWNERSHIP:
┌────────────────────┬─────────────────────────────────────────────────────────┐
│ Database           │ Owner Role                                              │
├────────────────────┼─────────────────────────────────────────────────────────┤
│ INV_GOVERNANCE_DB  │ ACCOUNTADMIN                                            │
│ INV_RAW_DB         │ INV_DATA_ADMIN                                          │
│ INV_TRANSFORM_DB   │ INV_DATA_ADMIN                                          │
│ INV_ANALYTICS_DB   │ INV_DATA_ADMIN                                          │
│ INV_AI_READY_DB    │ INV_ML_ADMIN                                            │
└────────────────────┴─────────────────────────────────────────────────────────┘

NO DEV/QA/PROD COMPLEXITY - Simple, clean structure!
================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 04: DATABASE STRUCTURE COMPLETE'
UNION ALL
SELECT '  5 Databases, 22 Schemas'
UNION ALL
SELECT '  Investment Analysis Platform'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 04: DATABASE STRUCTURE
-- ============================================================
