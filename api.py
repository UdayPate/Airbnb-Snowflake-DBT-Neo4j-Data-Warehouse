from flask import Flask, jsonify, request
from neo4j import GraphDatabase

app = Flask(__name__)

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
NEO4J_URI      = "neo4j+s://75b3490d.databases.neo4j.io"
NEO4J_USER     = "75b3490d"
NEO4J_PASSWORD = "hkUt-4Lsd8j6MgW4fU0ReMvDVl6q0elOmthjO8z067M"

driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))


# ─────────────────────────────────────────────
# HELPER
# ─────────────────────────────────────────────
def run_query(query, params={}):
    with driver.session() as session:
        result = session.run(query, **params)
        return result.data()


# ─────────────────────────────────────────────
# ROUTES
# ─────────────────────────────────────────────

# 1. Health check
@app.route("/")
def health():
    return jsonify({"status": "ok", "message": "Airbnb Recommendation API is running"})


# 2. Get recommendations for a listing
# GET /recommend/379?top_n=5
@app.route("/recommend/<listing_id>")
def recommend(listing_id):
    top_n = int(request.args.get("top_n", 5))
    results = run_query("""
        MATCH (target:Listing {listing_id: $listing_id})<-[:BOOKED]-(g:Guest)-[:BOOKED]->(rec:Listing)
        WHERE rec.listing_id <> $listing_id
        WITH rec, count(DISTINCT g) AS shared_guests
        ORDER BY shared_guests DESC
        LIMIT $top_n
        RETURN rec.listing_id    AS listing_id,
               rec.city          AS city,
               rec.property_type AS property_type,
               rec.room_type     AS room_type,
               rec.price_tag     AS price_tag,
               rec.capacity      AS capacity,
               shared_guests
    """, params={"listing_id": str(listing_id), "top_n": top_n})

    if not results:
        return jsonify({"listing_id": listing_id, "recommendations": [], "message": "No recommendations found"}), 404

    return jsonify({
        "listing_id"     : listing_id,
        "recommendations": results,
        "count"          : len(results)
    })


# 3. Get listing details
# GET /listing/379
@app.route("/listing/<listing_id>")
def get_listing(listing_id):
    results = run_query("""
        MATCH (l:Listing {listing_id: $listing_id})-[:HOSTED_BY]->(h:Host)
        RETURN l.listing_id    AS listing_id,
               l.city          AS city,
               l.country       AS country,
               l.property_type AS property_type,
               l.room_type     AS room_type,
               l.price_per_night AS price_per_night,
               l.price_tag     AS price_tag,
               l.capacity      AS capacity,
               h.name          AS host_name,
               h.tier          AS host_tier,
               h.is_superhost  AS is_superhost,
               h.years_as_host AS years_as_host
    """, params={"listing_id": str(listing_id)})

    if not results:
        return jsonify({"error": f"Listing {listing_id} not found"}), 404

    return jsonify(results[0])


# 4. Get top listings by city
# GET /city/Paris?top_n=5
@app.route("/city/<city>")
def listings_by_city(city):
    top_n = int(request.args.get("top_n", 5))
    results = run_query("""
        MATCH (g:Guest)-[:BOOKED]->(l:Listing)
        WHERE toLower(l.city) CONTAINS toLower($city)
        WITH l, count(g) AS total_bookings
        ORDER BY total_bookings DESC
        LIMIT $top_n
        RETURN l.listing_id    AS listing_id,
               l.city          AS city,
               l.property_type AS property_type,
               l.room_type     AS room_type,
               l.price_tag     AS price_tag,
               total_bookings
    """, params={"city": city, "top_n": top_n})

    if not results:
        return jsonify({"error": f"No listings found for city: {city}"}), 404

    return jsonify({"city": city, "listings": results, "count": len(results)})


# 5. Get top hosts
# GET /hosts?top_n=5
@app.route("/hosts")
def top_hosts():
    top_n = int(request.args.get("top_n", 5))
    results = run_query("""
        MATCH (l:Listing)-[:HOSTED_BY]->(h:Host)
        MATCH (g:Guest)-[:BOOKED]->(l)
        RETURN h.name          AS host_name,
               h.tier          AS host_tier,
               h.is_superhost  AS is_superhost,
               h.years_as_host AS years_as_host,
               count(g)        AS total_bookings,
               count(DISTINCT l) AS total_listings
        ORDER BY total_bookings DESC
        LIMIT $top_n
    """, params={"top_n": top_n})

    return jsonify({"hosts": results, "count": len(results)})


# 6. Get graph stats
# GET /stats
@app.route("/stats")
def stats():
    guests   = run_query("MATCH (g:Guest)   RETURN count(g) AS count")[0]["count"]
    listings = run_query("MATCH (l:Listing) RETURN count(l) AS count")[0]["count"]
    hosts    = run_query("MATCH (h:Host)    RETURN count(h) AS count")[0]["count"]
    bookings = run_query("MATCH ()-[b:BOOKED]->() RETURN count(b) AS count")[0]["count"]

    return jsonify({
        "nodes": {
            "guests"  : guests,
            "listings": listings,
            "hosts"   : hosts
        },
        "relationships": {
            "bookings": bookings
        }
    })


# ─────────────────────────────────────────────
# RUN
# ─────────────────────────────────────────────
if __name__ == "__main__":
    app.run(debug=True, port=5000)