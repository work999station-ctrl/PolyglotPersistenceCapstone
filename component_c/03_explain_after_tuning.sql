-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component C: Query Performance & Tuning Study
-- Step 3: Capture EXPLAIN (ANALYZE, BUFFERS) AFTER Tuning (Indexed)
-- ============================================================================

\timing on

-- Warm up cache
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM products;

-- ----------------------------------------------------------------------------
-- QUERY 1: Customer Order History with Status & Date Range Filtering
-- ----------------------------------------------------------------------------
-- Tuned Plan Expectation:
--   - Replaces Parallel Seq Scan + Sort with an Index Scan using
--     idx_orders_customer_placed.
--   - Directly navigates the B-Tree root -> branch -> leaf pages for customer_id=4287.
--   - Tuples are already sorted in descending placed_at order, eliminating the
--     Sort step entirely.
--   - Buffer blocks read drop from thousands to ~3-6 blocks.
--   - Execution time drops from ~50-150 ms to sub-millisecond (< 0.2 ms).
-- ----------------------------------------------------------------------------

\echo '======================================================================'
\echo 'QUERY 1 (AFTER TUNING): EXPLAIN (ANALYZE, BUFFERS)'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT
    order_id,
    customer_id,
    status,
    placed_at,
    total_amount
FROM orders
WHERE customer_id = 4287
  AND status IN ('paid', 'shipped', 'delivered')
  AND placed_at >= NOW() - INTERVAL '180 days'
ORDER BY placed_at DESC;


-- ----------------------------------------------------------------------------
-- QUERY 2: Product Multi-Tag Discovery via Array Containment (GIN Index)
-- ----------------------------------------------------------------------------
-- Tuned Plan Expectation:
--   - Replaces Seq Scan on products with a Bitmap Index Scan on idx_products_tags_gin
--     followed by a Bitmap Heap Scan.
--   - Fast posting list lookup: finds posting list for 'gaming' and posting list
--     for 'laptop', intersects them in memory, and fetches only candidate pages.
--   - Buffer reads and execution time drop dramatically.
-- ----------------------------------------------------------------------------

\echo '======================================================================'
\echo 'QUERY 2 (AFTER TUNING): EXPLAIN (ANALYZE, BUFFERS)'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT
    product_id,
    sku,
    title,
    unit_price,
    stock_qty,
    tags
FROM products
WHERE is_active = TRUE
  AND tags @> ARRAY['gaming', 'laptop']::TEXT[]
ORDER BY unit_price ASC;


-- ----------------------------------------------------------------------------
-- QUERY 3: Seller Quarterly Revenue & Product Performance Aggregation
-- ----------------------------------------------------------------------------
-- Tuned Plan Expectation:
--   - Replaces Parallel Seq Scans on order_items (480k rows) and orders (200k rows)
--     with selective index lookups.
--   - Index Scan on idx_products_seller_id retrieves only vendor 42's products (~50).
--   - Bitmap Index Scan on idx_order_items_product_id pulls only line items for those 50 products.
--   - Eliminates scanning 480k rows and reduces buffer hits/reads by orders of magnitude.
--   - Latency drops from ~200-400 ms to a few milliseconds.
-- ----------------------------------------------------------------------------

\echo '======================================================================'
\echo 'QUERY 3 (AFTER TUNING): EXPLAIN (ANALYZE, BUFFERS)'
\echo '======================================================================'

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT
    p.product_id,
    p.title,
    c.name AS category_name,
    COUNT(oi.order_item_id) AS total_order_items,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.unit_price_at_purchase) AS gross_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE p.seller_id = 42
  AND o.status IN ('paid', 'shipped', 'delivered')
  AND o.placed_at >= NOW() - INTERVAL '120 days'
GROUP BY p.product_id, p.title, c.name
ORDER BY gross_revenue DESC;
