# Airbnb End-to-End Data Engineering & Recommendation System

## The Story

We started with raw Airbnb data and asked — *what's the best way to store, transform, and extract value from it?*

The answer became a full data engineering pipeline that moves data from raw CSV files all the way to a graph-based recommendation engine using cloud storage, a modern data warehouse, a transformation framework, a graph database, and a REST API.

---

## Architecture

```
CSV Files (bookings, hosts, listings)
      ↓
AWS S3 (cloud storage)
      ↓
Snowflake (staging)
      ↓
Bronze Layer — raw ingestion (dbt incremental)
      ↓
Silver Layer — cleaned & enriched (dbt incremental)
      ↓
Gold Layer — analytics ready (dbt table + SCD Type 2 snapshots)
      ↓
Neo4j AuraDB — property graph database
      ↓
Flask REST API — recommendation endpoints
```

---

## Chapter 1 — Get the Data to the Cloud

We had raw CSV files for bookings, hosts, and listings. We chose **AWS S3** as our cloud storage layer it's cheap, reliable, and integrates naturally with Snowflake. From S3 we loaded the data into **Snowflake** as our staging layer, giving us a scalable, queryable home for the raw data.

**Source tables in Snowflake staging:**
- `AIRBNB.STAGING.BOOKINGS` — 5,000 booking records
- `AIRBNB.STAGING.HOSTS` — 200 host records
- `AIRBNB.STAGING.LISTINGS` — 500 listing records

---

## Chapter 2 — Build a Proper Data Warehouse with dbt

Raw data is messy. We used **dbt** to build a **Medallion Architecture** that progressively cleans, enriches, and models the data across three layers.

### Bronze Layer — Raw Ingestion
Incremental models that pull directly from staging with no transformation. New records only on each run.

| Model | Rows | Strategy |
|---|---|---|
| `bronze_bookings` | 5,000 | Incremental |
| `bronze_hosts` | 200 | Incremental |
| `bronze_listings` | 500 | Incremental |

### Silver Layer — Cleaned & Enriched
This is where the business logic lives. We added derived columns, null guards, data quality filters, and enriched each entity with meaningful segments.

**`silver_bookings`**
- `GUEST_ID` — synthetic deterministic ID (real systems would have this from source)
- `TOTAL_FEES` — service fee + cleaning fee combined
- `BOOKING_DURATION_CATEGORY` — SHORT_STAY / MEDIUM_STAY / LONG_STAY

**`silver_hosts`**
- `YEARS_AS_HOST` — derived from `HOST_SINCE` to current date
- `RESPONSE_RATE_QUALITY` — VERY_GOOD / GOOD / FAIR / POOR
- `HOST_TIER` — ELITE / SUPERHOST / PROFESSIONAL / STANDARD (combined superhost + response rate)

**`silver_listings`**
- `PRICE_PER_PERSON` — price per night divided by accommodates
- `CAPACITY_CATEGORY` — SOLO / COUPLE / SMALL_GROUP / LARGE_GROUP
- `BEDROOM_BATHROOM_RATIO` — quality signal for listings

### Gold Layer — Analytics Ready

**OBT (One Big Table)**
A fully denormalized table joining all three silver models. 5,000 rows with every enriched column available for analytics and export.

**FACT Table**
Joins OBT with SCD Type 2 dimension tables, showing only the current version of each listing and host using a `ROW_NUMBER()` deduplication pattern.

**SCD Type 2 Snapshots**
Track historical changes with valid from/to dates:
- `dim_bookings` — historical booking changes
- `dim_hosts` — historical host profile changes
- `dim_listings` — historical listing changes

### Key dbt Features Used
- Incremental materialization with `is_incremental()` filter
- Custom macros: `multiply()`, `tag()`, `trimmer()`
- Jinja templating with config-driven loops in OBT and FACT
- SCD Type 2 snapshots with `dbt_valid_to_current`
- Schema separation: Bronze / Silver / Gold auto-routing

---

## Chapter 3 — We Looked at the Data Differently

Once the Gold layer was ready, we asked — *what's the best way to represent this data for recommendations?*

A traditional SQL table answers "what did guest X book?" but struggles to answer "what do guests who book similar listings have in common?" That's a **graph problem**.

The relationships between guests, listings, and hosts are naturally modeled as a graph:

```
(Guest)-[:BOOKED]->(Listing)-[:HOSTED_BY]->(Host)
```

This is why we chose **Neo4j** — a native graph database that makes relationship traversal fast and elegant.

---

## Chapter 4 — Build the Recommendation Engine

We exported the Gold OBT to Neo4j and modeled the data as a property graph.

### Graph Schema

**Nodes:**
| Node | Properties |
|---|---|
| `Guest` | `guest_id` |
| `Listing` | `listing_id`, `city`, `country`, `property_type`, `room_type`, `price_per_night`, `price_tag`, `capacity` |
| `Host` | `host_id`, `name`, `is_superhost`, `tier`, `years_as_host` |

**Relationships:**
| Relationship | Properties |
|---|---|
| `(Guest)-[:BOOKED]->(Listing)` | `booking_id`, `booking_date`, `status`, `duration`, `total_amount` |
| `(Listing)-[:HOSTED_BY]->(Host)` | — |

### Graph Stats
- **1,189 nodes** — 500 Guests, 500 Listings, 189 Hosts
- **5,500 relationships** — 5,000 BOOKED + 500 HOSTED_BY

### Recommendation Logic
Item-based collaborative filtering using graph traversal:

```cypher
MATCH (target:Listing {listing_id: $listing_id})<-[:BOOKED]-(g:Guest)-[:BOOKED]->(rec:Listing)
WHERE rec.listing_id <> $listing_id
WITH rec, count(DISTINCT g) AS shared_guests
ORDER BY shared_guests DESC
LIMIT $top_n
RETURN rec.listing_id, rec.city, rec.property_type, rec.room_type, rec.price_tag, shared_guests
```

*"Find all guests who booked this listing, then find what other listings those same guests also booked, ranked by how many shared guests"*

---

## Chapter 5 — Make it Accessible

We wrapped the graph queries in a **Flask REST API** so recommendations can be consumed by any frontend or service.

### API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Health check |
| GET | `/stats` | Graph statistics |
| GET | `/recommend/{listing_id}?top_n=5` | Top N recommendations for a listing |
| GET | `/listing/{listing_id}` | Listing details with host info |
| GET | `/city/{city}?top_n=5` | Top listings in a city by bookings |
| GET | `/hosts?top_n=5` | Top hosts by total bookings |

### Example Response — `/recommend/379`
```json
{
  "listing_id": "379",
  "count": 5,
  "recommendations": [
    {
      "listing_id": "418",
      "city": "East Nicholasberg",
      "property_type": "Condo",
      "room_type": "Private room",
      "price_tag": "high",
      "capacity": "SMALL_GROUP",
      "shared_guests": 3
    }
  ]
}
```

---

## Getting Started

### Prerequisites
- Python 3.12+
- Snowflake account
- AWS account (S3)
- Neo4j AuraDB free account

### Installation

```bash
# Clone the repo
git clone <your-repo-url>
cd AWS_DBT_Snowflake

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\Activate.ps1 on Windows

# Install dependencies
pip install -r requirements.txt
```

### Configuration

Create a `.env` file in the project root:

```bash
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_WAREHOUSE=COMPUTE_WH
SNOWFLAKE_DATABASE=AIRBNB
SNOWFLAKE_SCHEMA=DBT_SCHEMA_GOLD

NEO4J_URI=neo4j+s://xxxxxxxx.databases.neo4j.io
NEO4J_USER=your_neo4j_user
NEO4J_PASSWORD=your_neo4j_password
```

Create `~/.dbt/profiles.yml`:
```yaml
aws_dbt_snowflake_project:
  outputs:
    dev:
      type: snowflake
      account: your_account
      user: your_user
      password: your_password
      role: ACCOUNTADMIN
      database: AIRBNB
      warehouse: COMPUTE_WH
      schema: dbt_schema
      threads: 4
  target: dev
```

### Running the Pipeline

```bash
# 1. Run the full dbt pipeline
cd aws_dbt_snowflake_final_project
dbt build

# 2. Load data into Neo4j
cd ..
python neo4j_loader.py

# 3. Start the API
python api.py
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Cloud Storage | AWS S3 |
| Data Warehouse | Snowflake |
| Transformation | dbt (Data Build Tool) |
| Graph Database | Neo4j AuraDB |
| API Framework | Flask |
| Language | Python 3.12 |
| Package Manager | uv / pip |

---

## Project Structure

```
AWS_DBT_Snowflake/
├── .env                          # Credentials (gitignored)
├── neo4j_loader.py               # Snowflake → Neo4j export + recommendations
├── api.py                        # Flask REST API
│
├── aws_dbt_snowflake_final_project/
│   ├── models/
│   │   ├── bronze/               # Raw ingestion layer
│   │   ├── silver/               # Cleaned & enriched layer
│   │   └── gold/                 # Analytics layer
│   │       ├── ephemeral/        # Intermediate CTEs
│   │       ├── obt.sql           # One Big Table
│   │       └── fact.sql          # Fact table with SCD dims
│   ├── snapshots/                # SCD Type 2 definitions
│   ├── macros/                   # Reusable SQL functions
│   └── tests/                    # Data quality tests
│
└── SourceData/                   # Raw CSV files
    ├── bookings.csv
    ├── hosts.csv
    └── listings.csv
```

---

## Authors

Uday Patel (ID: 015639871)
Vedant Vilas Vartak (ID: 019103539 )
Tanya Shah (ID: 019138145)
Himja Patel (ID: 019131346)

**Technologies:** AWS · Snowflake · dbt · Neo4j · Flask · Python