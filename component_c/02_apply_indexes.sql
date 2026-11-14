-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component C: Query Performance & Tuning Study
-- Step 2: Add Targeted Indexes (B-Tree + Mandatory GIN Index)
-- ============================================================================

\timing on

\echo '----------------------------------------------------------------------'
\echo 'Creating Index 1: Composite B-Tree for Query 1'
\echo 'Target: orders(customer_id, placed_at DESC)'
\echo 'Purpose: Eliminates Seq Scan and Sort by clustering customer order history'
\echo '----------------------------------------------------------------------'
CREATE INDEX idx_orders_customer_placed
    ON orders (customer_id, placed_at DESC);

\echo '----------------------------------------------------------------------'
\echo 'Creating Index 2: Inverted GIN Index for Query 2 (Mandatory GIN)'
\echo 'Target: products USING gin (tags)'
\echo 'Purpose: Accelerates array containment queries (@>) via posting list intersections'
\echo '----------------------------------------------------------------------'
CREATE INDEX idx_products_tags_gin
    ON products USING gin (tags);

\echo '----------------------------------------------------------------------'
\echo 'Creating Indexes 3, 4, 5: Foreign Key & Range B-Trees for Query 3'
\echo 'Targets: products(seller_id), order_items(product_id), orders(placed_at, status)'
\echo 'Purpose: Eliminates multi-table parallel seq scans and massive hash joins'
\echo '----------------------------------------------------------------------'
CREATE INDEX idx_products_seller_id
    ON products (seller_id);

CREATE INDEX idx_order_items_product_id
    ON order_items (product_id);

CREATE INDEX idx_orders_placed_status
    ON orders (placed_at, status);

-- Update planner statistics with the new index distributions
ANALYZE orders;
ANALYZE products;
ANALYZE order_items;

\echo 'All tuning indexes created successfully and catalog statistics updated.'
