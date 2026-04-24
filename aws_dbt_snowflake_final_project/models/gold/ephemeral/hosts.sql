{{ config(materialized='ephemeral') }}

WITH hosts AS (
    SELECT
        HOST_ID,
        HOST_NAME,
        HOST_SINCE,
        IS_SUPERHOST,
        RESPONSE_RATE,
        RESPONSE_RATE_QUALITY,
        HOST_TIER,
        YEARS_AS_HOST,
        HOST_CREATED_AT
    FROM {{ ref('obt') }}
)
SELECT * FROM hosts