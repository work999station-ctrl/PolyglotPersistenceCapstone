-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component C: Optional Bonus — Distributed Table with Citus
-- ============================================================================
-- Project syllabus bonus requirement:
--   "For extra credit, distribute one hot table with Citus (create_distributed_table)
--    and compare a query single-node vs distributed.
--    Start it with docker compose --profile citus up -d."
-- ============================================================================

-- Note: Ensure the Citus extension is enabled on the coordinator node
CREATE EXTENSION IF NOT EXISTS citus;

\echo '======================================================================'
\echo '1. DISTRIBUTING THE HOT EVENT TABLE (orders)'
\echo '======================================================================'
-- We choose order_id or customer_id as the distribution column (sharding key).
-- Using order_id shards orders evenly across Citus worker nodes.
-- Reference tables (e.g. categories, sellers) can be replicated across all nodes.

-- Step 1: Create distributed table
-- SELECT create_distributed_table('orders', 'order_id');

-- Step 2: Create reference tables for co-located joins without cross-node network shuffles
-- SELECT create_reference_table('categories');

\echo '======================================================================'
\echo '2. QUERY PLAN COMPARISON: SINGLE-NODE VS. DISTRIBUTED CITUS EXECUTION'
\echo '======================================================================'

-- Single-Node Execution Plan (Traditional PostgreSQL Planner):
-- Scans local heap and local B-tree/GIN indexes sequentially or in parallel workers
-- within the single PostgreSQL backend.

-- Distributed Citus Execution Plan:
-- The Citus query coordinator splits the query into parallel tasks, dispatching
-- each task to worker nodes where the respective shards reside:
--
-- EXPLAIN VERBOSE
-- SELECT status, count(*), sum(total_amount)
-- FROM orders
-- WHERE placed_at >= NOW() - INTERVAL '30 days'
-- GROUP BY status;
--
-- Distributed Plan Output Structure:
--   Distributed Run: Router / Adaptive Executor
--     -> Citus Task 1 (worker1:5432 shard orders_102008)
--     -> Citus Task 2 (worker2:5432 shard orders_102009)
--     ...
--   Coordinator aggregates partial results from workers.
--
-- Benefits:
--   - Horizontal scaling of storage and compute beyond single-machine limits.
--   - Parallel I/O throughput across independent worker disks.
-- Trade-Off:
--   - Distributed transactions incur 2PC (Two-Phase Commit) overhead.
--   - Non-colocated joins (across different distribution keys) require expensive
--     network shuffles or map-reduce style data redistribution.
