/*
================================================================================
PHASE 11: MEDALLION ARCHITECTURE - DETAILED EXPLANATION
================================================================================
Script: Phase11_Medallion_Architecture.sql
Version: 1.0.0
Purpose: Comprehensive documentation and explanation of the 4-layer 
         Medallion Architecture for Investment Domain Platform

MEDALLION LAYERS:
  🥉 BRONZE  - INV_RAW_DB        (Raw/Landing Zone)
  🥈 SILVER  - INV_TRANSFORM_DB  (Cleansed/Validated)
  🥇 GOLD    - INV_ANALYTICS_DB  (Business-Ready Analytics)
  💎 PLATINUM - INV_AI_READY_DB  (ML/AI Features & Models)

Author: Investment Platform Team
================================================================================
*/

-- ============================================================================
-- SECTION 1: MEDALLION ARCHITECTURE OVERVIEW
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MEDALLION ARCHITECTURE OVERVIEW                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DATA SOURCES                                                              │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│   │ Bloomberg   │  │ Custodians  │  │ Trading     │  │ Reference   │       │
│   │ Reuters     │  │ Prime Broker│  │ Systems     │  │ Data        │       │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │
│          │                │                │                │               │
│          └────────────────┴────────────────┴────────────────┘               │
│                                    │                                        │
│                                    ▼                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  🥉 BRONZE LAYER - INV_RAW_DB                                       │  │
│   │  ─────────────────────────────                                      │  │
│   │  • Raw data landing zone                                            │  │
│   │  • No transformations applied                                       │  │
│   │  • VARIANT storage for flexibility                                  │  │
│   │  • Full audit trail of source data                                  │  │
│   │  • 90-day retention                                                 │  │
│   └─────────────────────────────────┬───────────────────────────────────┘  │
│                                     │                                       │
│                                     ▼                                       │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  🥈 SILVER LAYER - INV_TRANSFORM_DB                                 │  │
│   │  ───────────────────────────────────                                │  │
│   │  • Cleansed and validated data                                      │  │
│   │  • Business rules applied                                           │  │
│   │  • SCD Type 2 for dimensions                                        │  │
│   │  • Standardized formats & currencies                                │  │
│   │  • 30-day retention                                                 │  │
│   └─────────────────────────────────┬───────────────────────────────────┘  │
│                                     │                                       │
│                          ┌──────────┴──────────┐                            │
│                          ▼                     ▼                            │
│   ┌──────────────────────────────┐  ┌──────────────────────────────────┐   │
│   │  🥇 GOLD LAYER               │  │  💎 PLATINUM LAYER               │   │
│   │  INV_ANALYTICS_DB            │  │  INV_AI_READY_DB                 │   │
│   │  ────────────────            │  │  ──────────────────              │   │
│   │  • Business-ready analytics  │  │  • ML feature store              │   │
│   │  • Star schema design        │  │  • Training datasets             │   │
│   │  • Pre-aggregated metrics    │  │  • Model artifacts               │   │
│   │  • Optimized for BI          │  │  • Predictions output            │   │
│   │  • 90-day retention          │  │  • 30-day retention              │   │
│   └──────────────────────────────┘  └──────────────────────────────────┘   │
│              │                                   │                          │
│              ▼                                   ▼                          │
│   ┌──────────────────────────────┐  ┌──────────────────────────────────┐   │
│   │  📊 BI & REPORTING           │  │  🤖 ML MODELS & PREDICTIONS      │   │
│   │  Streamlit Dashboards        │  │  Return Predictions              │   │
│   │  Tableau/PowerBI             │  │  Risk Models                     │   │
│   │  Executive Reports           │  │  Anomaly Detection               │   │
│   └──────────────────────────────┘  └──────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

WHY MEDALLION ARCHITECTURE?
════════════════════════════
1. DATA QUALITY PROGRESSION: Each layer improves data quality
2. SEPARATION OF CONCERNS: Different teams work on different layers
3. AUDITABILITY: Raw data preserved for compliance/debugging
4. FLEXIBILITY: Schema evolution without breaking downstream
5. PERFORMANCE: Optimized structures for each use case
6. GOVERNANCE: Clear ownership and access control per layer

*/


-- ============================================================================
-- SECTION 2: 🥉 BRONZE LAYER - INV_RAW_DB (Landing Zone)
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                     🥉 BRONZE LAYER: INV_RAW_DB                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PURPOSE:                                                                   │
│  ─────────                                                                  │
│  The Bronze layer is the RAW DATA LANDING ZONE. Data arrives here exactly  │
│  as it comes from source systems - no transformations, no cleaning, no     │
│  business logic. This preserves the original data for audit and debugging. │
│                                                                             │
│  KEY PRINCIPLES:                                                            │
│  ────────────────                                                           │
│  ✓ Store data "as-is" from source systems                                  │
│  ✓ Use VARIANT type for semi-structured data (JSON, XML)                   │
│  ✓ Append-only pattern (no updates/deletes)                                │
│  ✓ Capture source metadata (file name, load time, source system)           │
│  ✓ 90-day retention for compliance and debugging                           │
│                                                                             │
│  SCHEMAS:                                                                   │
│  ─────────                                                                  │
│  ┌───────────────────┬──────────────────────────────────────────────────┐  │
│  │ Schema            │ Description                                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ MARKET_DATA       │ Raw prices, quotes, corporate actions from       │  │
│  │                   │ Bloomberg, Reuters, FactSet                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ PORTFOLIO_DATA    │ Raw holdings, NAV, positions from custodians     │  │
│  │                   │ and prime brokers                                │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ REFERENCE_DATA    │ Raw securities master, benchmarks, exchange      │  │
│  │                   │ calendars from data vendors                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ EXTERNAL_DATA     │ Raw news feeds, sentiment scores, economic       │  │
│  │                   │ indicators from alternative data providers       │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ STAGING           │ Temporary landing for file processing            │  │
│  │ (TRANSIENT)       │ No time-travel to reduce storage costs           │  │
│  └───────────────────┴──────────────────────────────────────────────────┘  │
│                                                                             │
│  TABLES:                                                                    │
│  ────────                                                                   │
│                                                                             │
│  1. RAW_DAILY_PRICES (Structured)                                          │
│     ├── record_id (PK, AUTOINCREMENT)                                      │
│     ├── security_id                                                        │
│     ├── price_date                                                         │
│     ├── open_price, high_price, low_price, close_price                     │
│     ├── adjusted_close, volume                                             │
│     ├── source_system (BLOOMBERG/REUTERS/FACTSET)                          │
│     ├── source_file                                                        │
│     └── load_timestamp                                                     │
│                                                                             │
│  2. RAW_CORPORATE_ACTIONS (Semi-structured)                                │
│     ├── record_id (PK, AUTOINCREMENT)                                      │
│     ├── raw_data (VARIANT - stores JSON as-is)                             │
│     ├── source_system                                                      │
│     └── load_timestamp                                                     │
│                                                                             │
│  3. RAW_HOLDINGS (Semi-structured)                                         │
│     ├── record_id (PK, AUTOINCREMENT)                                      │
│     ├── raw_data (VARIANT)                                                 │
│     ├── portfolio_code                                                     │
│     ├── as_of_date                                                         │
│     ├── source_system (CUSTODIAN_A/CUSTODIAN_B)                            │
│     └── load_timestamp                                                     │
│                                                                             │
│  4. RAW_TRANSACTIONS (Semi-structured)                                     │
│     ├── record_id (PK, AUTOINCREMENT)                                      │
│     ├── raw_data (VARIANT)                                                 │
│     ├── source_system                                                      │
│     └── load_timestamp                                                     │
│                                                                             │
│  5. RAW_SECURITIES_MASTER (Semi-structured)                                │
│     ├── record_id (PK, AUTOINCREMENT)                                      │
│     ├── raw_data (VARIANT)                                                 │
│     ├── source_system                                                      │
│     └── load_timestamp                                                     │
│                                                                             │
│  DATA FLOW EXAMPLE:                                                        │
│  ──────────────────                                                        │
│                                                                             │
│    Bloomberg Feed                                                          │
│         │                                                                  │
│         ▼                                                                  │
│    ┌─────────────────────────────────────────────────────────────────┐    │
│    │ {                                                                │    │
│    │   "ticker": "AAPL",                                              │    │
│    │   "date": "2024-01-15",                                          │    │
│    │   "px_open": 185.23,                                             │    │
│    │   "px_high": 187.45,                                             │    │
│    │   "px_low": 184.89,                                              │    │
│    │   "px_last": 186.92,                                             │    │
│    │   "volume": 58234567                                             │    │
│    │ }                                                                │    │
│    └─────────────────────────────────────────────────────────────────┘    │
│         │                                                                  │
│         ▼                                                                  │
│    Stored in RAW_DAILY_PRICES with:                                        │
│    - source_system = 'BLOOMBERG'                                           │
│    - source_file = 's3://feeds/bloomberg/2024-01-15/prices.json'           │
│    - load_timestamp = CURRENT_TIMESTAMP()                                  │
│                                                                             │
│  ROLE ACCESS:                                                               │
│  ─────────────                                                              │
│  ✓ INV_DATA_ENGINEER: Full access (CRUD)                                   │
│  ✓ INV_DATA_ADMIN: Ownership                                               │
│  ✗ INV_ANALYST: No access (raw data not analyst-ready)                     │
│  ✗ INV_ML_ENGINEER: No direct access (use TRANSFORM_DB)                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

-- Bronze Layer Database Details
SELECT 'BRONZE LAYER DATABASE' AS layer;
SHOW SCHEMAS IN DATABASE INV_RAW_DB;

-- View Raw Tables
SHOW TABLES IN SCHEMA INV_RAW_DB.MARKET_DATA;
SHOW TABLES IN SCHEMA INV_RAW_DB.PORTFOLIO_DATA;


-- ============================================================================
-- SECTION 3: 🥈 SILVER LAYER - INV_TRANSFORM_DB (Cleansed/Validated)
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    🥈 SILVER LAYER: INV_TRANSFORM_DB                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PURPOSE:                                                                   │
│  ─────────                                                                  │
│  The Silver layer contains CLEANSED, VALIDATED, and STANDARDIZED data.     │
│  This is where business rules are applied, data quality checks run, and    │
│  master data is maintained with Slowly Changing Dimension (SCD) patterns.  │
│                                                                             │
│  TRANSFORMATIONS APPLIED:                                                   │
│  ─────────────────────────                                                  │
│  ✓ Data type standardization (dates, numbers, strings)                     │
│  ✓ NULL handling and default values                                        │
│  ✓ Currency conversion to base currency                                    │
│  ✓ Identifier mapping (ISIN ↔ CUSIP ↔ SEDOL ↔ Ticker)                      │
│  ✓ Duplicate detection and removal                                         │
│  ✓ Business rule validation                                                │
│  ✓ Calculated fields (unrealized P&L, return %)                            │
│                                                                             │
│  SCHEMAS:                                                                   │
│  ─────────                                                                  │
│  ┌───────────────────┬──────────────────────────────────────────────────┐  │
│  │ Schema            │ Description                                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ MASTER            │ Dimension tables with SCD Type 2                 │  │
│  │                   │ DIM_SECURITY, DIM_PORTFOLIO, DIM_DATE            │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ CLEANSED          │ Fact tables with validated/enriched data         │  │
│  │                   │ FACT_HOLDINGS, FACT_DAILY_PRICES, FACT_NAV       │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ HISTORY           │ Historical snapshots for point-in-time queries   │  │
│  │                   │ and regulatory reporting                         │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ INTERMEDIATE      │ Temporary transformation staging                 │  │
│  │ (TRANSIENT)       │ No time-travel, reduced storage costs            │  │
│  └───────────────────┴──────────────────────────────────────────────────┘  │
│                                                                             │
│  KEY TABLES - DIMENSIONS (MASTER Schema):                                   │
│  ─────────────────────────────────────────                                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ DIM_SECURITY - Securities Master (SCD Type 2)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Columns:                                                            │   │
│  │ ├── security_key (PK, surrogate)                                    │   │
│  │ ├── security_id (business key)                                      │   │
│  │ ├── isin, cusip, sedol, ticker (identifiers)                        │   │
│  │ ├── security_name, security_type                                    │   │
│  │ ├── asset_class, sub_asset_class                                    │   │
│  │ ├── sector, industry, country, currency                             │   │
│  │ ├── exchange, benchmark_index                                       │   │
│  │ ├── expense_ratio, fund_manager (for funds)                         │   │
│  │ ├── risk_rating, min_investment                                     │   │
│  │ ├── effective_from, effective_to (SCD Type 2)                       │   │
│  │ └── is_current (flag for current record)                            │   │
│  │                                                                     │   │
│  │ Security Types: STOCK, MUTUAL_FUND, ETF, BOND, OPTION               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ DIM_PORTFOLIO - Portfolio/Fund Master                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Columns:                                                            │   │
│  │ ├── portfolio_key (PK, surrogate)                                   │   │
│  │ ├── portfolio_id (business key)                                     │   │
│  │ ├── portfolio_name, portfolio_type                                  │   │
│  │ ├── strategy (GROWTH/VALUE/BALANCED/INDEX)                          │   │
│  │ ├── benchmark_id                                                    │   │
│  │ ├── inception_date, base_currency                                   │   │
│  │ ├── fund_manager                                                    │   │
│  │ ├── management_fee, expense_ratio                                   │   │
│  │ └── min_investment, is_active                                       │   │
│  │                                                                     │   │
│  │ Portfolio Types: MUTUAL_FUND, HEDGE_FUND, SMA, ETF, PENSION         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ DIM_DATE - Date Dimension                                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Columns:                                                            │   │
│  │ ├── date_key (PK, YYYYMMDD format)                                  │   │
│  │ ├── calendar_date                                                   │   │
│  │ ├── year, quarter, month, month_name                                │   │
│  │ ├── week_of_year, day_of_week, day_name                             │   │
│  │ ├── is_weekend                                                      │   │
│  │ ├── is_us_trading_day (market calendar)                             │   │
│  │ ├── is_month_end, is_quarter_end, is_year_end                       │   │
│  │ └── fiscal_year, fiscal_quarter                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  KEY TABLES - FACTS (CLEANSED Schema):                                      │
│  ──────────────────────────────────────                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_HOLDINGS - Portfolio Holdings (Core Investment Data)           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Investment Attributes:                                              │   │
│  │ ├── holding_id (PK)                                                 │   │
│  │ ├── as_of_date (FK to DIM_DATE)                                     │   │
│  │ ├── portfolio_id (FK to DIM_PORTFOLIO)                              │   │
│  │ ├── security_id (FK to DIM_SECURITY)                                │   │
│  │ ├── quantity (shares/units held)                                    │   │
│  │ ├── cost_basis (original purchase cost)          ◄── INVESTMENT    │   │
│  │ ├── market_value (current value)                 ◄── INVESTMENT    │   │
│  │ ├── unrealized_pnl (gain/loss = MV - Cost)       ◄── INVESTMENT    │   │
│  │ ├── benchmark_value (vs benchmark)               ◄── INVESTMENT    │   │
│  │ ├── gain_loss_pct (return %)                     ◄── INVESTMENT    │   │
│  │ ├── annualized_return                            ◄── INVESTMENT    │   │
│  │ ├── holding_period_days                          ◄── INVESTMENT    │   │
│  │ └── weight_pct (position weight)                                    │   │
│  │                                                                     │   │
│  │ Calculated Fields:                                                  │   │
│  │ • unrealized_pnl = market_value - cost_basis                        │   │
│  │ • gain_loss_pct = (market_value / cost_basis - 1) * 100             │   │
│  │ • annualized_return = gain_loss_pct * (365 / holding_period_days)   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_DAILY_PRICES - Security Prices (OHLCV)                         │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Columns:                                                            │   │
│  │ ├── price_id (PK)                                                   │   │
│  │ ├── security_id, trade_date                                         │   │
│  │ ├── open_price, high_price, low_price, close_price                  │   │
│  │ ├── adjusted_close (split/dividend adjusted)                        │   │
│  │ ├── volume                                                          │   │
│  │ └── vwap (volume-weighted average price)                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_NAV_HISTORY - Fund NAV & Performance                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Performance Metrics:                                                │   │
│  │ ├── nav_id (PK)                                                     │   │
│  │ ├── portfolio_id, as_of_date                                        │   │
│  │ ├── nav_per_share                                ◄── INVESTMENT    │   │
│  │ ├── total_nav                                    ◄── INVESTMENT    │   │
│  │ ├── shares_outstanding                                              │   │
│  │ ├── daily_return                                 ◄── PERFORMANCE   │   │
│  │ ├── mtd_return (month-to-date)                   ◄── PERFORMANCE   │   │
│  │ ├── qtd_return (quarter-to-date)                 ◄── PERFORMANCE   │   │
│  │ ├── ytd_return (year-to-date)                    ◄── PERFORMANCE   │   │
│  │ ├── benchmark_nav                                ◄── BENCHMARK     │   │
│  │ ├── alpha (excess return vs benchmark)           ◄── RISK          │   │
│  │ └── beta (systematic risk)                       ◄── RISK          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_TRANSACTIONS - Trade Transactions                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Columns:                                                            │   │
│  │ ├── transaction_id (PK)                                             │   │
│  │ ├── trade_date, settlement_date                                     │   │
│  │ ├── portfolio_id, security_id                                       │   │
│  │ ├── transaction_type (BUY/SELL/DIVIDEND/SPLIT)                      │   │
│  │ ├── quantity, price                                                 │   │
│  │ ├── gross_amount, commission, fees, net_amount                      │   │
│  │ └── broker, status                                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ROLE ACCESS:                                                               │
│  ─────────────                                                              │
│  ✓ INV_DATA_ENGINEER: Full access (CRUD)                                   │
│  ✓ INV_DATA_ADMIN: Ownership                                               │
│  ✓ INV_ANALYST: Read access (CLEANSED, MASTER schemas)                     │
│  ✓ INV_ML_ENGINEER: Read access (for feature engineering)                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

-- Silver Layer Database Details
SELECT 'SILVER LAYER DATABASE' AS layer;
SHOW SCHEMAS IN DATABASE INV_TRANSFORM_DB;

-- View Dimension Tables
SHOW TABLES IN SCHEMA INV_TRANSFORM_DB.MASTER;

-- View Fact Tables
SHOW TABLES IN SCHEMA INV_TRANSFORM_DB.CLEANSED;

-- Sample: DIM_SECURITY Structure
DESC TABLE INV_TRANSFORM_DB.MASTER.DIM_SECURITY;

-- Sample: Investment Holdings with Key Attributes
SELECT 
    'FACT_HOLDINGS Sample - Investment Attributes' AS description,
    security_id,
    cost_basis AS "Holding Cost",
    market_value AS "Current Value",
    unrealized_pnl AS "Gain/Loss $",
    gain_loss_pct AS "Return %",
    benchmark_value AS "Benchmark Value",
    annualized_return AS "Ann. Return %"
FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS
LIMIT 5;


-- ============================================================================
-- SECTION 4: 🥇 GOLD LAYER - INV_ANALYTICS_DB (Business Analytics)
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    🥇 GOLD LAYER: INV_ANALYTICS_DB                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PURPOSE:                                                                   │
│  ─────────                                                                  │
│  The Gold layer contains BUSINESS-READY ANALYTICS optimized for BI tools,  │
│  dashboards, and executive reporting. Data is pre-aggregated, denormalized,│
│  and structured for fast query performance.                                 │
│                                                                             │
│  DESIGN PRINCIPLES:                                                         │
│  ───────────────────                                                        │
│  ✓ Star schema design for fast joins                                       │
│  ✓ Pre-aggregated metrics (no heavy calculations at query time)            │
│  ✓ Denormalized views for self-service BI                                  │
│  ✓ Business-friendly column names                                          │
│  ✓ Optimized for Streamlit dashboards and BI tools                         │
│                                                                             │
│  SCHEMAS:                                                                   │
│  ─────────                                                                  │
│  ┌───────────────────┬──────────────────────────────────────────────────┐  │
│  │ Schema            │ Description                                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ CORE              │ Star schema fact and dimension tables for        │  │
│  │                   │ general analytics                                │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ PERFORMANCE       │ Portfolio performance analytics                  │  │
│  │                   │ Returns, attribution, benchmarking               │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ RISK              │ Risk analytics - VaR, volatility, exposure       │  │
│  │                   │ Greeks for derivatives                           │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ REPORTING         │ Pre-built views for dashboards and reports       │  │
│  │                   │ Streamlit apps consume from here                 │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ COMPLIANCE        │ Regulatory reports - SOX, SEC, FINRA             │  │
│  │                   │ Audit-ready data structures                      │  │
│  └───────────────────┴──────────────────────────────────────────────────┘  │
│                                                                             │
│  KEY VIEWS:                                                                 │
│  ───────────                                                                │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ VW_PORTFOLIO_PERFORMANCE (PERFORMANCE Schema)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Provides:                                                           │   │
│  │ • Portfolio identification and metadata                             │   │
│  │ • NAV per share and total NAV                                       │   │
│  │ • Daily, MTD, YTD returns                                           │   │
│  │ • 30-day annualized return (rolling window)                         │   │
│  │ • 30-day annualized volatility (rolling window)                     │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Performance dashboards                                            │   │
│  │ ✓ Manager leaderboards                                              │   │
│  │ ✓ Fund comparison reports                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ VW_PORTFOLIO_RISK (RISK Schema)                                     │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Provides:                                                           │   │
│  │ • Annualized return and volatility                                  │   │
│  │ • Sharpe ratio (risk-adjusted return)                               │   │
│  │ • Value-at-Risk (VaR) at 95% and 99%                                │   │
│  │ • Best and worst daily returns                                      │   │
│  │                                                                     │   │
│  │ Risk Metrics Explained:                                             │   │
│  │ ─────────────────────────                                           │   │
│  │ Sharpe Ratio = (Return - Risk-Free Rate) / Volatility               │   │
│  │ VaR 95% = 5th percentile of daily returns                           │   │
│  │ VaR 99% = 1st percentile of daily returns                           │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Risk monitoring dashboards                                        │   │
│  │ ✓ Portfolio risk reports                                            │   │
│  │ ✓ Compliance reporting                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ VW_SECTOR_ALLOCATION (REPORTING Schema)                             │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Provides:                                                           │   │
│  │ • Holdings grouped by sector/industry/country                       │   │
│  │ • Total market value per sector                                     │   │
│  │ • Number of positions per sector                                    │   │
│  │ • Weight percentage allocation                                      │   │
│  │ • Total unrealized P&L by sector                                    │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Sector allocation pie charts                                      │   │
│  │ ✓ Concentration analysis                                            │   │
│  │ ✓ Diversification reports                                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ VW_TOP_HOLDINGS (REPORTING Schema)                                  │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Provides:                                                           │   │
│  │ • Individual holdings with security details                         │   │
│  │ • Market value, cost basis, unrealized P&L                          │   │
│  │ • Position weight and rank within portfolio                         │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Top 10 holdings reports                                           │   │
│  │ ✓ Position detail drilldowns                                        │   │
│  │ ✓ Holdings comparison                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ VW_INVESTMENT_SUMMARY (REPORTING Schema) - MASTER VIEW              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Comprehensive denormalized view joining:                            │   │
│  │ • Holdings data (FACT_HOLDINGS)                                     │   │
│  │ • Security details (DIM_SECURITY)                                   │   │
│  │ • Portfolio metadata (DIM_PORTFOLIO)                                │   │
│  │ • NAV history (FACT_NAV_HISTORY)                                    │   │
│  │                                                                     │   │
│  │ Key Columns:                                                        │   │
│  │ ├── investment_name, ticker, security_type                          │   │
│  │ ├── portfolio_name, portfolio_strategy                              │   │
│  │ ├── holding_cost, current_value, gain_loss_amount                   │   │
│  │ ├── gain_loss_pct, benchmark_value, vs_benchmark                    │   │
│  │ ├── nav_per_share, portfolio_ytd_return                             │   │
│  │ └── alpha, beta                                                     │   │
│  │                                                                     │   │
│  │ This is the PRIMARY VIEW for Streamlit dashboards                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ROLE ACCESS:                                                               │
│  ─────────────                                                              │
│  ✓ INV_READONLY: Read access (all schemas)                                 │
│  ✓ INV_ANALYST: Read + Create views in REPORTING                           │
│  ✓ INV_DATA_ENGINEER: Write to CORE, PERFORMANCE, RISK                     │
│  ✓ INV_ML_ENGINEER: Read access                                            │
│  ✓ INV_APP_ADMIN: Read + CREATE STREAMLIT in REPORTING                     │
│  ✓ INV_DATA_ADMIN: Ownership                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

-- Gold Layer Database Details
SELECT 'GOLD LAYER DATABASE' AS layer;
SHOW SCHEMAS IN DATABASE INV_ANALYTICS_DB;

-- View Analytics Views
SHOW VIEWS IN SCHEMA INV_ANALYTICS_DB.PERFORMANCE;
SHOW VIEWS IN SCHEMA INV_ANALYTICS_DB.RISK;
SHOW VIEWS IN SCHEMA INV_ANALYTICS_DB.REPORTING;

-- Sample: Portfolio Performance View
SELECT 
    'VW_PORTFOLIO_PERFORMANCE Sample' AS description,
    portfolio_id,
    portfolio_name,
    nav_per_share,
    daily_return,
    ytd_return
FROM INV_ANALYTICS_DB.PERFORMANCE.VW_PORTFOLIO_PERFORMANCE
LIMIT 5;

-- Sample: Risk View
SELECT 
    'VW_PORTFOLIO_RISK Sample' AS description,
    portfolio_id,
    annualized_return,
    annualized_volatility,
    sharpe_ratio,
    var_95_daily
FROM INV_ANALYTICS_DB.RISK.VW_PORTFOLIO_RISK
LIMIT 5;


-- ============================================================================
-- SECTION 5: 💎 PLATINUM LAYER - INV_AI_READY_DB (ML/AI Features)
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                   💎 PLATINUM LAYER: INV_AI_READY_DB                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PURPOSE:                                                                   │
│  ─────────                                                                  │
│  The Platinum layer is the ML/AI FEATURE STORE containing engineered       │
│  features, training datasets, model artifacts, and prediction outputs.     │
│  This layer bridges the gap between data engineering and data science.     │
│                                                                             │
│  DESIGN PRINCIPLES:                                                         │
│  ───────────────────                                                        │
│  ✓ Feature versioning and lineage                                          │
│  ✓ Point-in-time correct features (avoid data leakage)                     │
│  ✓ Optimized for batch and real-time inference                             │
│  ✓ Reproducible training datasets                                          │
│  ✓ Model registry integration                                              │
│                                                                             │
│  SCHEMAS:                                                                   │
│  ─────────                                                                  │
│  ┌───────────────────┬──────────────────────────────────────────────────┐  │
│  │ Schema            │ Description                                      │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ FEATURES          │ Feature store - engineered features ready for    │  │
│  │                   │ model training and inference                     │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ TRAINING          │ Labeled training datasets for model development  │  │
│  │                   │ Includes train/validation/test splits            │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ MODELS            │ Snowflake Model Registry integration             │  │
│  │                   │ Serialized models and metadata                   │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ PREDICTIONS       │ Model prediction outputs                         │  │
│  │                   │ Batch predictions, real-time scoring             │  │
│  ├───────────────────┼──────────────────────────────────────────────────┤  │
│  │ EXPERIMENTS       │ ML experiments and A/B tests                     │  │
│  │                   │ Model comparison metrics                         │  │
│  └───────────────────┴──────────────────────────────────────────────────┘  │
│                                                                             │
│  KEY TABLES:                                                                │
│  ────────────                                                               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_PRICE_FEATURES (FEATURES Schema)                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Technical Indicator Features for ML:                                │   │
│  │                                                                     │   │
│  │ Price Features:                                                     │   │
│  │ ├── close_price (current price)                                     │   │
│  │ ├── daily_return (simple return)                                    │   │
│  │ └── log_return (logarithmic return)                                 │   │
│  │                                                                     │   │
│  │ Moving Averages:                                                    │   │
│  │ ├── sma_5, sma_20, sma_50, sma_200 (Simple MA)                      │   │
│  │ └── ema_12, ema_26 (Exponential MA)                                 │   │
│  │                                                                     │   │
│  │ Volatility:                                                         │   │
│  │ ├── volatility_20d (20-day rolling volatility)                      │   │
│  │ └── volatility_60d (60-day rolling volatility)                      │   │
│  │                                                                     │   │
│  │ Technical Indicators:                                               │   │
│  │ ├── rsi_14 (Relative Strength Index)                                │   │
│  │ ├── macd, macd_signal (MACD indicator)                              │   │
│  │ └── volume_sma_20, volume_ratio                                     │   │
│  │                                                                     │   │
│  │ Price Levels:                                                       │   │
│  │ ├── high_52w, low_52w (52-week high/low)                            │   │
│  │ └── pct_from_high (% below 52-week high)                            │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Return prediction models                                          │   │
│  │ ✓ Trend classification                                              │   │
│  │ ✓ Momentum strategies                                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_PORTFOLIO_FEATURES (FEATURES Schema)                           │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Portfolio-Level Features:                                           │   │
│  │                                                                     │   │
│  │ Composition:                                                        │   │
│  │ ├── num_positions (number of holdings)                              │   │
│  │ ├── concentration_top5, concentration_top10                         │   │
│  │ └── sector_hhi (Herfindahl-Hirschman Index)                         │   │
│  │                                                                     │   │
│  │ Returns:                                                            │   │
│  │ ├── return_1d, return_5d, return_20d, return_60d                    │   │
│  │                                                                     │   │
│  │ Risk:                                                               │   │
│  │ ├── volatility_20d, volatility_60d                                  │   │
│  │ ├── sharpe_60d                                                      │   │
│  │ ├── max_drawdown_60d                                                │   │
│  │ └── beta_to_benchmark                                               │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Portfolio optimization                                            │   │
│  │ ✓ Risk prediction                                                   │   │
│  │ ✓ Manager skill analysis                                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ DS_RETURN_PREDICTION (TRAINING Schema)                              │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Training Dataset for Return Prediction Model:                       │   │
│  │                                                                     │   │
│  │ Input Features:                                                     │   │
│  │ ├── return_1d, return_5d, return_20d                                │   │
│  │ ├── volatility_20d                                                  │   │
│  │ ├── rsi_14, volume_ratio                                            │   │
│  │ └── sma_cross (SMA crossover signal)                                │   │
│  │                                                                     │   │
│  │ Target Variables (Labels):                                          │   │
│  │ ├── forward_return_5d (5-day forward return)                        │   │
│  │ ├── forward_return_20d (20-day forward return)                      │   │
│  │ └── direction_5d (1 = up, 0 = down)                                 │   │
│  │                                                                     │   │
│  │ Note: Forward returns calculated AFTER feature date to avoid        │   │
│  │ data leakage (look-ahead bias)                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ FACT_PREDICTIONS (PREDICTIONS Schema)                               │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │ Model Prediction Outputs:                                           │   │
│  │                                                                     │   │
│  │ Prediction Metadata:                                                │   │
│  │ ├── model_name, model_version                                       │   │
│  │ ├── prediction_date                                                 │   │
│  │ └── security_id                                                     │   │
│  │                                                                     │   │
│  │ Predictions:                                                        │   │
│  │ ├── predicted_return                                                │   │
│  │ ├── predicted_direction (1 = buy, 0 = sell)                         │   │
│  │ └── confidence_score                                                │   │
│  │                                                                     │   │
│  │ Actuals (for backtesting):                                          │   │
│  │ ├── actual_return                                                   │   │
│  │ └── is_correct (prediction accuracy)                                │   │
│  │                                                                     │   │
│  │ Use Cases:                                                          │   │
│  │ ✓ Trading signals                                                   │   │
│  │ ✓ Model monitoring                                                  │   │
│  │ ✓ Backtesting analysis                                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ML WORKFLOW:                                                               │
│  ─────────────                                                              │
│                                                                             │
│    TRANSFORM_DB              AI_READY_DB                                   │
│    (Silver)                  (Platinum)                                    │
│        │                          │                                        │
│        │    Feature               │    Model Training                      │
│        │    Engineering           │                                        │
│        ▼                          ▼                                        │
│  ┌──────────┐              ┌──────────────┐                                │
│  │ FACT_    │  ─────────►  │ FACT_PRICE_  │                                │
│  │ DAILY_   │  Calculate   │ FEATURES     │                                │
│  │ PRICES   │  indicators  └──────────────┘                                │
│  └──────────┘                     │                                        │
│                                   ▼                                        │
│                            ┌──────────────┐    ┌──────────────┐            │
│                            │ DS_RETURN_   │───►│ Snowflake    │            │
│                            │ PREDICTION   │    │ ML Model     │            │
│                            └──────────────┘    │ Registry     │            │
│                                   │            └──────────────┘            │
│                                   ▼                    │                   │
│                            ┌──────────────┐            │                   │
│                            │ FACT_        │◄───────────┘                   │
│                            │ PREDICTIONS  │  Store predictions             │
│                            └──────────────┘                                │
│                                                                             │
│  ROLE ACCESS:                                                               │
│  ─────────────                                                              │
│  ✓ INV_ML_ENGINEER: Full access (CRUD on all schemas)                      │
│  ✓ INV_ML_ADMIN: Ownership                                                 │
│  ✓ INV_DATA_ENGINEER: Read + Write to FEATURES schema                      │
│  ✗ INV_ANALYST: No access (ML-specific data)                               │
│  ✗ INV_READONLY: No access                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/

-- Platinum Layer Database Details
SELECT 'PLATINUM LAYER DATABASE' AS layer;
SHOW SCHEMAS IN DATABASE INV_AI_READY_DB;

-- View ML Tables
SHOW TABLES IN SCHEMA INV_AI_READY_DB.FEATURES;
SHOW TABLES IN SCHEMA INV_AI_READY_DB.TRAINING;
SHOW TABLES IN SCHEMA INV_AI_READY_DB.PREDICTIONS;


-- ============================================================================
-- SECTION 6: DATA FLOW BETWEEN LAYERS
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DATA FLOW BETWEEN LAYERS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  FLOW 1: RAW → TRANSFORM (Bronze → Silver)                                  │
│  ──────────────────────────────────────────                                 │
│                                                                             │
│  INV_RAW_DB.MARKET_DATA.RAW_DAILY_PRICES                                    │
│       │                                                                     │
│       │  ETL Pipeline (Snowflake Tasks/Streams)                             │
│       │  ────────────────────────────────────                               │
│       │  1. Parse VARIANT JSON fields                                       │
│       │  2. Validate data types                                             │
│       │  3. Handle NULL values                                              │
│       │  4. Check for duplicates                                            │
│       │  5. Apply business rules                                            │
│       │  6. Calculate derived fields (VWAP)                                 │
│       │                                                                     │
│       ▼                                                                     │
│  INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES                                │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  FLOW 2: TRANSFORM → ANALYTICS (Silver → Gold)                              │
│  ─────────────────────────────────────────────                              │
│                                                                             │
│  INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS                                    │
│  + INV_TRANSFORM_DB.MASTER.DIM_SECURITY                                     │
│  + INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO                                    │
│       │                                                                     │
│       │  View Creation                                                      │
│       │  ─────────────                                                      │
│       │  1. Join facts with dimensions                                      │
│       │  2. Calculate aggregations                                          │
│       │  3. Apply window functions                                          │
│       │  4. Create business-friendly names                                  │
│       │                                                                     │
│       ▼                                                                     │
│  INV_ANALYTICS_DB.REPORTING.VW_INVESTMENT_SUMMARY                           │
│  INV_ANALYTICS_DB.REPORTING.VW_SECTOR_ALLOCATION                            │
│  INV_ANALYTICS_DB.PERFORMANCE.VW_PORTFOLIO_PERFORMANCE                      │
│  INV_ANALYTICS_DB.RISK.VW_PORTFOLIO_RISK                                    │
│                                                                             │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  FLOW 3: TRANSFORM → AI_READY (Silver → Platinum)                           │
│  ────────────────────────────────────────────────                           │
│                                                                             │
│  INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES                                │
│       │                                                                     │
│       │  Feature Engineering Pipeline                                       │
│       │  ─────────────────────────────                                      │
│       │  1. Calculate technical indicators (SMA, EMA, RSI)                  │
│       │  2. Compute rolling statistics (volatility)                         │
│       │  3. Generate lagged features                                        │
│       │  4. Create forward-looking labels                                   │
│       │  5. Handle missing data                                             │
│       │                                                                     │
│       ▼                                                                     │
│  INV_AI_READY_DB.FEATURES.FACT_PRICE_FEATURES                               │
│       │                                                                     │
│       │  Training Data Preparation                                          │
│       │  ──────────────────────────                                         │
│       │  1. Join features with labels                                       │
│       │  2. Point-in-time correct join                                      │
│       │  3. Split train/validation/test                                     │
│       │                                                                     │
│       ▼                                                                     │
│  INV_AI_READY_DB.TRAINING.DS_RETURN_PREDICTION                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
*/


-- ============================================================================
-- SECTION 7: LAYER COMPARISON MATRIX
-- ============================================================================
/*
┌─────────────────────────────────────────────────────────────────────────────┐
│                       LAYER COMPARISON MATRIX                               │
├───────────────┬─────────────┬─────────────┬─────────────┬─────────────────┤
│ Attribute     │ 🥉 BRONZE   │ 🥈 SILVER   │ 🥇 GOLD     │ 💎 PLATINUM     │
│               │ RAW_DB      │ TRANSFORM   │ ANALYTICS   │ AI_READY        │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Purpose       │ Landing     │ Cleansed    │ Analytics   │ ML Features     │
│               │ Zone        │ Validated   │ Business    │ Training Data   │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Data Quality  │ As-is       │ Validated   │ Optimized   │ ML-Ready        │
│               │ Raw         │ Cleaned     │ Aggregated  │ Engineered      │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Schema Type   │ Source-     │ Enterprise  │ Star        │ Feature         │
│               │ aligned     │ Model       │ Schema      │ Store           │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Data Format   │ VARIANT     │ Typed       │ Typed       │ Typed           │
│               │ JSON/XML    │ Structured  │ Structured  │ Numerical       │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Retention     │ 90 days     │ 30 days     │ 90 days     │ 30 days         │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Users         │ Data Eng    │ Data Eng    │ Analysts    │ ML Engineers    │
│               │             │ Analysts    │ Business    │ Data Scientists │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Primary       │ Audit       │ Enterprise  │ BI/Reports  │ ML Training     │
│ Use Case      │ Debug       │ Data        │ Dashboards  │ Predictions     │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Transforms    │ None        │ Clean       │ Aggregate   │ Engineer        │
│               │             │ Validate    │ Denormalize │ Compute         │
├───────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤
│ Schemas       │ MARKET_DATA │ MASTER      │ CORE        │ FEATURES        │
│               │ PORTFOLIO   │ CLEANSED    │ PERFORMANCE │ TRAINING        │
│               │ REFERENCE   │ HISTORY     │ RISK        │ MODELS          │
│               │ EXTERNAL    │ INTER-      │ REPORTING   │ PREDICTIONS     │
│               │ STAGING     │ MEDIATE     │ COMPLIANCE  │ EXPERIMENTS     │
└───────────────┴─────────────┴─────────────┴─────────────┴─────────────────┘
*/


-- ============================================================================
-- SECTION 8: VERIFICATION QUERIES
-- ============================================================================

-- 8.1 Database Summary
SELECT 
    'DATABASE SUMMARY' AS section,
    database_name,
    CASE database_name
        WHEN 'INV_RAW_DB' THEN '🥉 BRONZE'
        WHEN 'INV_TRANSFORM_DB' THEN '🥈 SILVER'
        WHEN 'INV_ANALYTICS_DB' THEN '🥇 GOLD'
        WHEN 'INV_AI_READY_DB' THEN '💎 PLATINUM'
        ELSE 'GOVERNANCE'
    END AS layer,
    retention_time AS retention_days,
    comment
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
WHERE database_name LIKE 'INV_%'
  AND deleted IS NULL
ORDER BY 
    CASE database_name
        WHEN 'INV_RAW_DB' THEN 1
        WHEN 'INV_TRANSFORM_DB' THEN 2
        WHEN 'INV_ANALYTICS_DB' THEN 3
        WHEN 'INV_AI_READY_DB' THEN 4
        ELSE 5
    END;

-- 8.2 Schema Count per Layer
SELECT 
    'SCHEMA COUNT PER LAYER' AS section,
    catalog_name AS database_name,
    COUNT(*) AS schema_count
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE catalog_name LIKE 'INV_%'
  AND deleted IS NULL
  AND schema_name NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
GROUP BY catalog_name
ORDER BY 
    CASE catalog_name
        WHEN 'INV_RAW_DB' THEN 1
        WHEN 'INV_TRANSFORM_DB' THEN 2
        WHEN 'INV_ANALYTICS_DB' THEN 3
        WHEN 'INV_AI_READY_DB' THEN 4
        ELSE 5
    END;

-- 8.3 Table Count per Layer
SELECT 
    'TABLE COUNT PER LAYER' AS section,
    table_catalog AS database_name,
    COUNT(*) AS table_count
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES
WHERE table_catalog LIKE 'INV_%'
  AND deleted IS NULL
  AND table_schema NOT IN ('INFORMATION_SCHEMA')
GROUP BY table_catalog
ORDER BY 
    CASE table_catalog
        WHEN 'INV_RAW_DB' THEN 1
        WHEN 'INV_TRANSFORM_DB' THEN 2
        WHEN 'INV_ANALYTICS_DB' THEN 3
        WHEN 'INV_AI_READY_DB' THEN 4
        ELSE 5
    END;

-- 8.4 Row Count Summary
SELECT 'RECORD COUNT SUMMARY' AS section;

SELECT 
    '🥈 SILVER - DIM_SECURITY' AS table_name, 
    COUNT(*) AS row_count 
FROM INV_TRANSFORM_DB.MASTER.DIM_SECURITY
UNION ALL
SELECT '🥈 SILVER - DIM_PORTFOLIO', COUNT(*) FROM INV_TRANSFORM_DB.MASTER.DIM_PORTFOLIO
UNION ALL
SELECT '🥈 SILVER - DIM_DATE', COUNT(*) FROM INV_TRANSFORM_DB.MASTER.DIM_DATE
UNION ALL
SELECT '🥈 SILVER - FACT_HOLDINGS', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_HOLDINGS
UNION ALL
SELECT '🥈 SILVER - FACT_DAILY_PRICES', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_DAILY_PRICES
UNION ALL
SELECT '🥈 SILVER - FACT_NAV_HISTORY', COUNT(*) FROM INV_TRANSFORM_DB.CLEANSED.FACT_NAV_HISTORY
ORDER BY table_name;


-- ============================================================================
-- SECTION 9: SUMMARY
-- ============================================================================
/*
================================================================================
                    MEDALLION ARCHITECTURE SUMMARY
================================================================================

🥉 BRONZE - INV_RAW_DB (Landing Zone)
   ├── Purpose: Raw data storage, audit trail
   ├── Schemas: MARKET_DATA, PORTFOLIO_DATA, REFERENCE_DATA, EXTERNAL_DATA, STAGING
   ├── Tables: RAW_DAILY_PRICES, RAW_HOLDINGS, RAW_TRANSACTIONS
   ├── Retention: 90 days
   └── Access: Data Engineers only

🥈 SILVER - INV_TRANSFORM_DB (Cleansed Layer)
   ├── Purpose: Validated, standardized enterprise data
   ├── Schemas: MASTER (dimensions), CLEANSED (facts), HISTORY, INTERMEDIATE
   ├── Tables: DIM_SECURITY, DIM_PORTFOLIO, DIM_DATE, FACT_HOLDINGS, FACT_NAV
   ├── Retention: 30 days
   └── Access: Data Engineers, Analysts, ML Engineers (read)

🥇 GOLD - INV_ANALYTICS_DB (Business Analytics)
   ├── Purpose: Business-ready analytics for BI/reporting
   ├── Schemas: CORE, PERFORMANCE, RISK, REPORTING, COMPLIANCE
   ├── Views: VW_PORTFOLIO_PERFORMANCE, VW_PORTFOLIO_RISK, VW_INVESTMENT_SUMMARY
   ├── Retention: 90 days
   └── Access: All roles (read), Analysts (create views), App Admin (Streamlit)

💎 PLATINUM - INV_AI_READY_DB (ML Feature Store)
   ├── Purpose: ML features, training data, predictions
   ├── Schemas: FEATURES, TRAINING, MODELS, PREDICTIONS, EXPERIMENTS
   ├── Tables: FACT_PRICE_FEATURES, DS_RETURN_PREDICTION, FACT_PREDICTIONS
   ├── Retention: 30 days
   └── Access: ML Engineers, ML Admin only

================================================================================
KEY INVESTMENT ATTRIBUTES TRACKED:
================================================================================
✓ cost_basis          - Original purchase cost (holding cost)
✓ market_value        - Current market value
✓ unrealized_pnl      - Gain/loss amount (market_value - cost_basis)
✓ gain_loss_pct       - Return percentage
✓ benchmark_value     - Benchmark comparison value
✓ annualized_return   - Annualized return rate
✓ nav_per_share       - Net Asset Value per share
✓ daily_return        - Daily return percentage
✓ ytd_return          - Year-to-date return
✓ alpha               - Excess return vs benchmark
✓ beta                - Systematic risk measure
✓ sharpe_ratio        - Risk-adjusted return
✓ var_95, var_99      - Value at Risk metrics

================================================================================
END OF PHASE 11: MEDALLION ARCHITECTURE DOCUMENTATION
================================================================================
*/
