{{ config(materialized='ephemeral') }}

WITH bookings AS (
    SELECT
        BOOKING_ID,
        LISTING_ID,
        GUEST_ID,
        BOOKING_DATE,
        NIGHTS_BOOKED,
        TOTAL_AMOUNT,
        TOTAL_FEES,
        BOOKING_STATUS,
        BOOKING_DURATION_CATEGORY,
        CREATED_AT
    FROM {{ ref('obt') }}
)
SELECT * FROM bookings