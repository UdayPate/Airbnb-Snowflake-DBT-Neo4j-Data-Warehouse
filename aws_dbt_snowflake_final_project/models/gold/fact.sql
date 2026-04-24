{% set configs = [
    {
        "table"  : "AIRBNB.DBT_SCHEMA_GOLD.OBT",
        "columns": "obt.BOOKING_ID,
                    obt.LISTING_ID,
                    obt.GUEST_ID,
                    obt.HOST_ID,
                    obt.BOOKING_DATE,
                    obt.NIGHTS_BOOKED,
                    obt.TOTAL_AMOUNT,
                    obt.TOTAL_FEES,
                    obt.SERVICE_FEE,
                    obt.CLEANING_FEE,
                    obt.BOOKING_STATUS,
                    obt.BOOKING_DURATION_CATEGORY,
                    obt.PRICE_PER_NIGHT,
                    obt.RESPONSE_RATE",
        "alias"  : "obt"
    },
    {
        "table"  : "(SELECT * FROM AIRBNB.DBT_SCHEMA_GOLD.DIM_LISTINGS
                     QUALIFY ROW_NUMBER() OVER (PARTITION BY LISTING_ID ORDER BY DBT_UPDATED_AT DESC) = 1)",
        "columns": "dim_listings.PROPERTY_TYPE,
                    dim_listings.ROOM_TYPE,
                    dim_listings.CITY,
                    dim_listings.COUNTRY,
                    dim_listings.ACCOMMODATES,
                    dim_listings.PRICE_PER_NIGHT_TAG,
                    dim_listings.PRICE_PER_PERSON,
                    dim_listings.CAPACITY_CATEGORY,
                    dim_listings.DBT_VALID_FROM  AS LISTING_VALID_FROM,
                    dim_listings.DBT_VALID_TO    AS LISTING_VALID_TO",
        "alias"  : "dim_listings",
        "join_condition": "obt.LISTING_ID = dim_listings.LISTING_ID"
    },
    {
        "table"  : "(SELECT * FROM AIRBNB.DBT_SCHEMA_GOLD.DIM_HOSTS
                     QUALIFY ROW_NUMBER() OVER (PARTITION BY HOST_ID ORDER BY DBT_UPDATED_AT DESC) = 1)",
        "columns": "dim_hosts.HOST_NAME,
                    dim_hosts.IS_SUPERHOST,
                    dim_hosts.HOST_TIER,
                    dim_hosts.YEARS_AS_HOST,
                    dim_hosts.RESPONSE_RATE_QUALITY,
                    dim_hosts.DBT_VALID_FROM     AS HOST_VALID_FROM,
                    dim_hosts.DBT_VALID_TO       AS HOST_VALID_TO",
        "alias"  : "dim_hosts",
        "join_condition": "obt.HOST_ID = dim_hosts.HOST_ID"
    }
] %}

SELECT
    {% for config in configs %}
        {{ config['columns'] }}{% if not loop.last %},{% endif %}
    {% endfor %}
FROM
    {% for config in configs %}
        {% if loop.first %}
            {{ config['table'] }} AS {{ config['alias'] }}
        {% else %}
            LEFT JOIN {{ config['table'] }} AS {{ config['alias'] }}
            ON {{ config['join_condition'] }}
        {% endif %}
    {% endfor %}