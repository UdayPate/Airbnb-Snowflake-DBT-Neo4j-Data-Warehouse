-- ============================================================
-- OLAP Analysis Queries
-- Project: Airbnb End-to-End Data Engineering Pipeline
-- Table:   AIRBNB.DBT_SCHEMA_GOLD.OBT
-- ============================================================

-- ── 1. ROLL-UP — Revenue by City and Country ────────────────
-- Aggregates from city grain up to country grain.
-- Business use: identify which countries generate the most 
-- revenue to support geographic expansion decisions.

SELECT
    COUNTRY,
    CITY,
    SUM(TOTAL_AMOUNT)    AS total_revenue,
    COUNT(BOOKING_ID)    AS total_bookings,
    AVG(PRICE_PER_NIGHT) AS avg_price
FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
GROUP BY ROLLUP(COUNTRY, CITY)
ORDER BY COUNTRY, CITY;


-- ── 2. DRILL-DOWN — Revenue by Property Type and Room Type ──
-- Breaks high-level property type down into room type grain.
-- Business use: identify which listing configurations drive 
-- the most revenue to optimise the listing mix.

SELECT
    PROPERTY_TYPE,
    ROOM_TYPE,
    COUNT(BOOKING_ID)    AS total_bookings,
    SUM(TOTAL_AMOUNT)    AS total_revenue,
    AVG(TOTAL_AMOUNT)    AS avg_booking_value
FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
GROUP BY PROPERTY_TYPE, ROOM_TYPE
ORDER BY PROPERTY_TYPE, total_revenue DESC;


-- ── 3. SLICE — Confirmed Bookings Only ──────────────────────
-- Fixes one dimension (BOOKING_STATUS) to a single value.
-- Business use: remove cancelled bookings from revenue 
-- analysis to get a clean view of actual earned revenue.

SELECT
    CITY,
    PROPERTY_TYPE,
    COUNT(BOOKING_ID)    AS total_bookings,
    SUM(TOTAL_AMOUNT)    AS total_revenue
FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
WHERE BOOKING_STATUS = 'confirmed'
GROUP BY CITY, PROPERTY_TYPE
ORDER BY total_revenue DESC;


-- ── 4. DICE — Premium Segment Analysis ──────────────────────
-- Applies multiple dimension filters simultaneously (sub-cube).
-- Business use: isolate confirmed long-stay superhost bookings
-- to identify and target the premium revenue segment.

SELECT
    CITY,
    HOST_TIER,
    CAPACITY_CATEGORY,
    COUNT(BOOKING_ID)    AS total_bookings,
    SUM(TOTAL_AMOUNT)    AS total_revenue
FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
WHERE BOOKING_STATUS             = 'confirmed'
  AND BOOKING_DURATION_CATEGORY  = 'LONG_STAY'
  AND IS_SUPERHOST                = TRUE
GROUP BY CITY, HOST_TIER, CAPACITY_CATEGORY
ORDER BY total_revenue DESC;


-- ── 5. CUBE — Full Multidimensional View ────────────────────
-- Generates all possible dimension combinations in one query.
-- Business use: complete multidimensional revenue view across
-- city, property type, and host tier for executive reporting.

SELECT
    CITY,
    PROPERTY_TYPE,
    HOST_TIER,
    COUNT(BOOKING_ID)    AS total_bookings,
    SUM(TOTAL_AMOUNT)    AS total_revenue
FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
GROUP BY CUBE(CITY, PROPERTY_TYPE, HOST_TIER)
ORDER BY CITY, PROPERTY_TYPE, HOST_TIER;


-- ── 6. PIVOT — Booking Duration by Property Type ────────────
-- Restructures rows into columns for compact comparison.
-- Business use: compare SHORT, MEDIUM, and LONG stay revenue
-- side by side per property type for pricing strategy.

SELECT *
FROM (
    SELECT
        PROPERTY_TYPE,
        BOOKING_DURATION_CATEGORY,
        TOTAL_AMOUNT
    FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
) PIVOT (
    SUM(TOTAL_AMOUNT)
    FOR BOOKING_DURATION_CATEGORY IN (
        'SHORT_STAY', 'MEDIUM_STAY', 'LONG_STAY'
    )
)
ORDER BY PROPERTY_TYPE;





