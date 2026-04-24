{{ config(materialized='incremental', unique_key='HOST_ID') }}

SELECT
    HOST_ID,
    REPLACE(HOST_NAME, ' ', '_')                        AS HOST_NAME,
    HOST_SINCE,
    IS_SUPERHOST,
    RESPONSE_RATE,

    -- Derived: how long they've been a host
    DATEDIFF(year, HOST_SINCE, CURRENT_DATE)            AS YEARS_AS_HOST,

    -- Existing response rate quality bucket
    CASE
        WHEN RESPONSE_RATE > 95 THEN 'VERY_GOOD'
        WHEN RESPONSE_RATE > 80 THEN 'GOOD'
        WHEN RESPONSE_RATE > 60 THEN 'FAIR'
        ELSE                         'POOR'
    END AS RESPONSE_RATE_QUALITY,

    -- New: combined tier using superhost + response rate
    CASE
        WHEN IS_SUPERHOST = TRUE AND RESPONSE_RATE > 90 THEN 'ELITE'
        WHEN IS_SUPERHOST = TRUE                        THEN 'SUPERHOST'
        WHEN RESPONSE_RATE > 80                         THEN 'PROFESSIONAL'
        ELSE                                                 'STANDARD'
    END AS HOST_TIER,

    CREATED_AT

FROM {{ ref('bronze_hosts') }}

WHERE HOST_ID   IS NOT NULL
  AND HOST_NAME IS NOT NULL

{% if is_incremental() %}
    AND CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}