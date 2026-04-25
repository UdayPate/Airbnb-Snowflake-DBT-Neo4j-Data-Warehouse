import snowflake.connector
import pandas as pd
from neo4j import GraphDatabase

# ─────────────────────────────────────────────
# CONFIG — fill in your credentials
# ─────────────────────────────────────────────
SNOWFLAKE_CONFIG = {
    "account"  : "DNMDMVL-GCB58331",
    "user"     : "UDAY0803",
    "password" : "*************",
    "warehouse": "COMPUTE_WH",
    "database" : "AIRBNB",
    "schema"   : "DBT_SCHEMA_GOLD",
}

NEO4J_URI      = "neo4j+s://75b3490d.databases.neo4j.io"
NEO4J_USER     = "75b3490d"
NEO4J_PASSWORD = "********"

# ─────────────────────────────────────────────
# STEP 1 — Pull data from Snowflake OBT
# ─────────────────────────────────────────────
def fetch_snowflake_data():
    print("Connecting to Snowflake...")
    conn = snowflake.connector.connect(**SNOWFLAKE_CONFIG)
    query = """
        SELECT
            BOOKING_ID,
            GUEST_ID,
            LISTING_ID,
            HOST_ID,
            BOOKING_DATE,
            BOOKING_STATUS,
            BOOKING_DURATION_CATEGORY,
            TOTAL_AMOUNT,
            PROPERTY_TYPE,
            ROOM_TYPE,
            CITY,
            COUNTRY,
            PRICE_PER_NIGHT,
            PRICE_PER_NIGHT_TAG,
            CAPACITY_CATEGORY,
            HOST_NAME,
            IS_SUPERHOST,
            HOST_TIER,
            YEARS_AS_HOST
        FROM AIRBNB.DBT_SCHEMA_GOLD.OBT
    """
    df = pd.read_sql(query, conn)
    conn.close()
    print(f"Fetched {len(df)} rows from Snowflake")
    return df

# ─────────────────────────────────────────────
# STEP 2 — Load graph into Neo4j
# ─────────────────────────────────────────────
def load_graph(df):
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    with driver.session() as session:
        # Clear existing graph before reloading
        print("Clearing existing graph...")
        session.run("MATCH (n) DETACH DELETE n")

        # -- Constraints (run once, ensure uniqueness) --
        print("Creating constraints...")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (g:Guest)   REQUIRE g.guest_id   IS UNIQUE")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (l:Listing) REQUIRE l.listing_id IS UNIQUE")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (h:Host)    REQUIRE h.host_id    IS UNIQUE")

        # -- Load nodes and relationships in batches --
        records = df.to_dict("records")
        batch_size = 500
        total = len(records)

        for i in range(0, total, batch_size):
            batch = records[i:i + batch_size]
            print(f"Loading batch {i // batch_size + 1} / {-(-total // batch_size)}...")

            session.run("""
                UNWIND $rows AS row

                // Guest node
                MERGE (g:Guest {guest_id: row.GUEST_ID})

                // Listing node
                MERGE (l:Listing {listing_id: toString(row.LISTING_ID)})
                SET l.property_type    = row.PROPERTY_TYPE,
                    l.room_type        = row.ROOM_TYPE,
                    l.city             = row.CITY,
                    l.country          = row.COUNTRY,
                    l.price_per_night  = row.PRICE_PER_NIGHT,
                    l.price_tag        = row.PRICE_PER_NIGHT_TAG,
                    l.capacity         = row.CAPACITY_CATEGORY

                // Host node
                MERGE (h:Host {host_id: toString(row.HOST_ID)})
                SET h.name          = row.HOST_NAME,
                    h.is_superhost  = row.IS_SUPERHOST,
                    h.tier          = row.HOST_TIER,
                    h.years_as_host = row.YEARS_AS_HOST

                // Relationships
                MERGE (g)-[b:BOOKED {booking_id: row.BOOKING_ID}]->(l)
                SET b.booking_date = toString(row.BOOKING_DATE),
                    b.status       = row.BOOKING_STATUS,
                    b.duration     = row.BOOKING_DURATION_CATEGORY,
                    b.total_amount = row.TOTAL_AMOUNT

                MERGE (l)-[:HOSTED_BY]->(h)
            """, rows=batch)

    driver.close()
    print("Graph loaded successfully!")

# ─────────────────────────────────────────────
# STEP 3 — Recommendation query
# ─────────────────────────────────────────────
def get_recommendations(listing_id, top_n=5):
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    with driver.session() as session:
        result = session.run("""
            MATCH (target:Listing {listing_id: $listing_id})<-[:BOOKED]-(g:Guest)-[:BOOKED]->(rec:Listing)
            WHERE rec.listing_id <> $listing_id
            WITH rec,
                 count(DISTINCT g) AS shared_guests
            ORDER BY shared_guests DESC
            LIMIT $top_n
            RETURN rec.listing_id    AS listing_id,
                   rec.city          AS city,
                   rec.property_type AS property_type,
                   rec.room_type     AS room_type,
                   rec.price_tag     AS price_tag,
                   shared_guests
        """, listing_id=str(listing_id), top_n=top_n)

        recommendations = result.data()

    driver.close()
    return recommendations


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
if __name__ == "__main__":
    # Load data into graph
    df = fetch_snowflake_data()
    load_graph(df)

    # Test recommendation
    test_listing = df["LISTING_ID"].iloc[0]
    print(f"\nRecommendations for listing {test_listing}:")
    recs = get_recommendations(test_listing)
    for r in recs:
        print(r)