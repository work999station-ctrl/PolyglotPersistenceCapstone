#!/usr/bin/env bash
# ==============================================================================
# Polyglot Persistence Capstone — Component C Benchmark Runner
# ==============================================================================
set -e

CONTAINER="advdb-postgres"
DB_USER="student"
DB_NAME="advdb"

echo "=== Component C: Performance & Tuning Study Benchmark ==="

# Check container status
if [ ! "$(docker ps -q -f name=$CONTAINER)" ]; then
    echo "Error: Container $CONTAINER is not running."
    echo "Start it with: docker compose --profile sql up -d"
    exit 1
fi

echo "--- Step 1: Running EXPLAIN (ANALYZE, BUFFERS) Before Tuning ---"
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME < component_c/01_explain_before_tuning.sql | tee component_c/results_before_tuning.txt

echo "--- Step 2: Applying B-Tree and GIN Indexes ---"
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME < component_c/02_apply_indexes.sql | tee component_c/results_indexing.txt

echo "--- Step 3: Running EXPLAIN (ANALYZE, BUFFERS) After Tuning ---"
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME < component_c/03_explain_after_tuning.sql | tee component_c/results_after_tuning.txt

echo "--- Step 4: Measuring Storage and Write Overhead Trade-Offs ---"
docker exec -i $CONTAINER psql -U $DB_USER -d $DB_NAME < component_c/04_tradeoff_benchmarks.sql | tee component_c/results_tradeoffs.txt

echo "=== Benchmark Complete! Results recorded in component_c/ ==="
