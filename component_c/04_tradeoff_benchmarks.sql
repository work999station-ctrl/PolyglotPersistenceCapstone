-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component C: Query Performance & Tuning Study
-- Step 4: Index Trade-Off Analysis — Storage Overhead & Write Cost
-- ============================================================================
-- The syllabus requires discussing at least one trade-off introduced by indexes.
-- This script provides reproducible quantitative measurements for BOTH:
--   1. Storage Footprint Overhead (Heap vs. Index bytes on disk)
--   2. Write Latency Degradation (Insert amplification overhead)
-- ============================================================================

\timing on

\echo '======================================================================'
\echo 'TRADE-OFF 1: STORAGE FOOTPRINT OVERHEAD ANALYSIS'
\echo '======================================================================'

-- 1.1 Summary per Table: Heap Size vs. Index Size vs. Total Size
SELECT
    relname AS table_name,
    pg_size_pretty(pg_relation_size(c.oid))       AS heap_size,
    pg_size_pretty(pg_indexes_size(c.oid))        AS total_index_size,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    ROUND(
        100.0 * pg_indexes_size(c.oid) / NULLIF(pg_relation_size(c.oid), 0),
        2
    ) AS index_overhead_pct
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('orders', 'order_items', 'products', 'sellers', 'customers')
ORDER BY pg_total_relation_size(c.oid) DESC;


-- 1.2 Breakdown of Individual Indexes and Their Disk Footprint
SELECT
    t.relname AS table_name,
    i.relname AS index_name,
    am.amname AS access_method,
    pg_size_pretty(pg_relation_size(i.oid)) AS index_size,
    idx.indisunique AS is_unique
FROM pg_index idx
JOIN pg_class t ON t.oid = idx.indrelid
JOIN pg_class i ON i.oid = idx.indexrelid
JOIN pg_am am   ON am.oid = i.relam
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relname IN ('orders', 'products', 'order_items')
ORDER BY t.relname, pg_relation_size(i.oid) DESC;


\echo '======================================================================'
\echo 'TRADE-OFF 2: WRITE AMPLIFICATION (INSERT LATENCY) BENCHMARK'
\echo '======================================================================'
-- We measure the exact wall-clock time required to insert 25,000 orders
-- into an unindexed table (PK only) vs. a fully indexed table.

-- Setup benchmark sandbox tables
DROP TABLE IF EXISTS bench_orders_unindexed;
DROP TABLE IF EXISTS bench_orders_indexed;

CREATE TABLE bench_orders_unindexed (LIKE orders INCLUDING DEFAULTS);
ALTER TABLE bench_orders_unindexed ADD PRIMARY KEY (order_id);

CREATE TABLE bench_orders_indexed (LIKE orders INCLUDING DEFAULTS);
ALTER TABLE bench_orders_indexed ADD PRIMARY KEY (order_id);
CREATE INDEX bench_idx_orders_customer_placed ON bench_orders_indexed (customer_id, placed_at DESC);
CREATE INDEX bench_idx_orders_placed_status   ON bench_orders_indexed (placed_at, status);

\echo '----------------------------------------------------------------------'
\echo 'Test A: Inserting 25,000 rows into UNINDEXED table (PK only)...'
\echo '----------------------------------------------------------------------'
INSERT INTO bench_orders_unindexed (customer_id, status, shipping_address, flags, total_amount, placed_at)
SELECT
    ((i % 10000) + 1),
    'paid',
    ROW('100 Test St', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    ARRAY['standard']::text[],
    1500.00,
    NOW() - ((i || ' seconds')::interval)
FROM generate_series(1, 25000) AS i;

\echo '----------------------------------------------------------------------'
\echo 'Test B: Inserting 25,000 rows into FULLY INDEXED table (PK + 2 B-Trees)...'
\echo '----------------------------------------------------------------------'
INSERT INTO bench_orders_indexed (customer_id, status, shipping_address, flags, total_amount, placed_at)
SELECT
    ((i % 10000) + 1),
    'paid',
    ROW('100 Test St', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    ARRAY['standard']::text[],
    1500.00,
    NOW() - ((i || ' seconds')::interval)
FROM generate_series(1, 25000) AS i;

-- Cleanup temporary benchmark tables
DROP TABLE bench_orders_unindexed;
DROP TABLE bench_orders_indexed;

\echo 'Trade-off benchmarks completed.'
