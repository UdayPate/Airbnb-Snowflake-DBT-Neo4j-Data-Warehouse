{{ config(materialized='ephemeral') }}

WITH listings AS (
    SELECT
        LISTING_ID,
        HOST_ID,
        PROPERTY_TYPE,
        ROOM_TYPE,
        CITY,
        COUNTRY,
        ACCOMMODATES,
        BEDROOMS,
        BATHROOMS,
        PRICE_PER_NIGHT,
        PRICE_PER_NIGHT_TAG,
        PRICE_PER_PERSON,
        CAPACITY_CATEGORY,
        BEDROOM_BATHROOM_RATIO,
        LISTING_CREATED_AT
    FROM {{ ref('obt') }}
)
SELECT * FROM listings