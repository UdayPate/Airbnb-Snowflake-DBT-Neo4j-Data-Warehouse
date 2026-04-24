{{ config(materialized='incremental', unique_key='BOOKING_ID') }}

SELECT
    BOOKING_ID,
    LISTING_ID,

    -- Synthetic GUEST_ID: in real world this would come from source
    -- Generated as a deterministic hash for consistency across runs
    'GUEST_' || LPAD(MOD(ABS(HASH(BOOKING_ID)), 500)::STRING, 4, '0') AS GUEST_ID,

    BOOKING_DATE,
    NIGHTS_BOOKED,
    BOOKING_AMOUNT,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} AS TOTAL_AMOUNT,
    SERVICE_FEE,
    CLEANING_FEE,
    SERVICE_FEE + CLEANING_FEE                          AS TOTAL_FEES,
    BOOKING_STATUS,

    -- Derived: stay duration category
    CASE
        WHEN NIGHTS_BOOKED <= 2  THEN 'SHORT_STAY'
        WHEN NIGHTS_BOOKED <= 7  THEN 'MEDIUM_STAY'
        ELSE                          'LONG_STAY'
    END AS BOOKING_DURATION_CATEGORY,

    CREATED_AT

FROM {{ ref('bronze_bookings') }}

WHERE BOOKING_ID   IS NOT NULL
  AND LISTING_ID   IS NOT NULL
  AND BOOKING_STATUS IS NOT NULL

{% if is_incremental() %}
    AND CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}