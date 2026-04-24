{{ config(materialized='incremental', unique_key='LISTING_ID') }}

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

    -- Existing price tag macro
    {{ tag('CAST(PRICE_PER_NIGHT AS INT)') }}           AS PRICE_PER_NIGHT_TAG,

    -- New: price per person metric
    ROUND(PRICE_PER_NIGHT / NULLIF(ACCOMMODATES, 0), 2) AS PRICE_PER_PERSON,

    -- New: capacity category based on how many guests it fits
    CASE
        WHEN ACCOMMODATES = 1 THEN 'SOLO'
        WHEN ACCOMMODATES = 2 THEN 'COUPLE'
        WHEN ACCOMMODATES <= 4 THEN 'SMALL_GROUP'
        ELSE                        'LARGE_GROUP'
    END AS CAPACITY_CATEGORY,

    -- New: bedroom to bathroom ratio (useful for quality scoring)
    CASE
        WHEN BATHROOMS = 0 THEN NULL
        ELSE ROUND(BEDROOMS / NULLIF(BATHROOMS, 0), 1)
    END AS BEDROOM_BATHROOM_RATIO,

    CREATED_AT

FROM {{ ref('bronze_listings') }}

WHERE LISTING_ID IS NOT NULL
  AND HOST_ID    IS NOT NULL
  AND PRICE_PER_NIGHT > 0

{% if is_incremental() %}
    AND CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}