# Polyglot Persistence Capstone — SoukTech Marketplace

**Advanced Databases (UEF11) · Final Capstone Project · Université Constantine 2 · 2026/2027**

---

## Overview

**SoukTech** is an Algerian e-commerce marketplace built as a polyglot persistence architecture. It integrates an object-relational PostgreSQL 17 core for transactional integrity and business logic with a dedicated NoSQL store for document/graph workloads, accompanied by an in-depth query optimization and tuning study under realistic enterprise volume.

---

## Repository Structure

```
PolyglotPersistenceCapstone/
├── docker-compose.yml                  # Lab environment definition (Postgres, Mongo, Neo4j, Cassandra)
├── README.md                           # This guide & exact evaluation commands
├── postgres/
│   └── initdb/                         # Auto-executed in alphabetical order on container startup
│       ├── 01_schema.sql               # Component A: 3NF tables, composite types, arrays, inheritance
│       ├── 02_seed_reference.sql       # Component A: Hand-crafted reference entities for testing
│       ├── 03_logic_and_views.sql      # Component A: PL/pgSQL functions, triggers, concurrency-safe SP, views
│       ├── 04_security.sql             # Component A: Roles (app_read/write/admin), grants, and RLS
│       └── 05_seed_volume.sql          # Component C: Realistic scale generator (200k orders, 480k items)
└── component_c/                        # Component C: Performance & Index Tuning Study
    ├── 01_explain_before_tuning.sql    # Capture EXPLAIN (ANALYZE, BUFFERS) before indexing
    ├── 02_apply_indexes.sql            # Add targeted B-Tree & Inverted GIN indexes
    ├── 03_explain_after_tuning.sql     # Capture EXPLAIN (ANALYZE, BUFFERS) after indexing
    ├── 04_tradeoff_benchmarks.sql      # Quantitative storage & write amplification benchmarks
    ├── 05_citus_bonus.sql              # Optional extra credit: Distributed table study with Citus
    ├── run_benchmark.sh                # Linux/macOS automated benchmark runner
    ├── run_benchmark.ps1               # Windows PowerShell automated benchmark runner
    └── PERFORMANCE_REPORT.md           # Comprehensive study report with plans, timings & defense Q&A
```

---

## Quickstart & Clean Rebuild (For Markers)

To rebuild the database cleanly from scratch:

```bash
# 1. Stop and wipe existing volumes
docker compose down -v

# 2. Boot the PostgreSQL core (initializes schema, logic, security, and seeds realistic volume)
docker compose --profile sql up -d

# 3. Verify PostgreSQL is healthy
docker compose ps
```

---

## Running Component C (Performance & Tuning Study)

You can run the entire tuning study automatically with one command:

### On Windows (PowerShell):
```powershell
.\component_c\run_benchmark.ps1
```

### On Linux / macOS (Bash):
```bash
chmod +x component_c/run_benchmark.sh
./component_c/run_benchmark.sh
```

### Manual Step-by-Step via `psql`:

1. **Capture Plans Before Tuning (Unindexed Baseline)**:
   ```bash
   docker exec -i advdb-postgres psql -U student -d advdb < component_c/01_explain_before_tuning.sql
   ```

2. **Apply B-Tree and Inverted GIN Indexes**:
   ```bash
   docker exec -i advdb-postgres psql -U student -d advdb < component_c/02_apply_indexes.sql
   ```

3. **Capture Plans After Tuning (Indexed Speedup)**:
   ```bash
   docker exec -i advdb-postgres psql -U student -d advdb < component_c/03_explain_after_tuning.sql
   ```

4. **Measure Trade-Offs (Write Amplification & Disk Storage Footprint)**:
   ```bash
   docker exec -i advdb-postgres psql -U student -d advdb < component_c/04_tradeoff_benchmarks.sql
   ```

Detailed analysis, plan comparisons, buffer statistics, and oral defense answers can be found in [`component_c/PERFORMANCE_REPORT.md`](file:///c:/Users/zaki/PolyglotPersistenceCapstone/component_c/PERFORMANCE_REPORT.md).
