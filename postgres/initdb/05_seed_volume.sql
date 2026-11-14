-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component C: Realistic Volume Generation Script
-- Target Scale:
--   - 100 Categories (10 root + 90 subcategories)
--   - 500 Sellers (Marketplace vendors)
--   - 10,000 Customers
--   - 25,000 Products with multi-tag arrays
--   - 200,000 Orders (Event Table) spread across 2 years
--   - 480,000 Order Items (Normalized line items)
--   - 200,000 Payments
-- ============================================================================

\timing on

-- Temporarily adjust session parameters for high-throughput bulk insertion
SET synchronous_commit = off;

-- ----------------------------------------------------------------------------
-- 1. Scale Categories (Lookup table: 10 existing + 90 subcategories = 100 total)
-- ----------------------------------------------------------------------------
INSERT INTO categories (name, slug, parent_category_id)
SELECT
    'Subcategory ' || i,
    'subcategory-' || i,
    ((i % 10) + 1)
FROM generate_series(11, 100) AS i
ON CONFLICT (name) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. Scale Sellers (500 total vendors)
-- ----------------------------------------------------------------------------
INSERT INTO sellers (store_name, contact, business_address, rating, is_verified)
SELECT
    'Vendor ' || i || ' Store',
    ROW(
        'contact@vendor' || i || '.dz',
        '+213-555-' || LPAD((i % 10000)::text, 4, '0'),
        'https://vendor' || i || '.souktech.dz'
    )::contact_info_t,
    ROW(
        i || ' Commercial Zone, Lot ' || (i % 40 + 1),
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Batna'])[(i % 6) + 1],
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Batna'])[(i % 6) + 1],
        LPAD(((i * 137) % 48000 + 1000)::text, 5, '0'),
        'DZ'
    )::address_t,
    (3.50 + ((i % 151) / 100.00))::numeric(3,2), -- Ratings between 3.50 and 5.00
    (i % 3 = 0)                                   -- 33% verified
FROM generate_series(6, 500) AS i
ON CONFLICT (store_name) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. Scale Customers (10,000 buyers)
-- ----------------------------------------------------------------------------
INSERT INTO customers (full_name, email, default_address, loyalty_tier)
SELECT
    'Customer ' || i || ' ' || (ARRAY['Larbi', 'Boudiaf', 'Mansour', 'Zitouni', 'Haddad', 'Cherif', 'Meziane', 'Belkacem'])[(i % 8) + 1],
    'user.' || i || '.' || SUBSTR(MD5(i::text), 1, 6) || '@souktech.dz',
    ROW(
        (i % 250 + 1) || ' Rue de la Republique',
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Tlemcen', 'Blida', 'Bejaia'])[(i % 8) + 1],
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Tlemcen', 'Blida', 'Bejaia'])[(i % 8) + 1],
        LPAD(((i * 73) % 48000 + 1000)::text, 5, '0'),
        'DZ'
    )::address_t,
    (ARRAY['bronze', 'silver', 'gold', 'platinum'])[(i % 4) + 1]
FROM generate_series(6, 10000) AS i
ON CONFLICT (email) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Scale Products (25,000 catalog SKUs with multi-tag arrays)
-- ----------------------------------------------------------------------------
-- Predefined realistic e-commerce tag universe
WITH tag_universe AS (
    SELECT ARRAY[
        'electronics', 'laptop', 'gaming', 'wireless',
        'audio', 'smart', 'home', 'kitchen',
        'book', 'clothing', 'fashion', 'sale',
        'bestseller', 'premium', 'budget', 'accessories'
    ] AS tags
)
INSERT INTO products (seller_id, category_id, sku, title, unit_price, stock_qty, tags, is_active)
SELECT
    ((i % 500) + 1) AS seller_id,
    ((i % 100) + 1) AS category_id,
    'SKU-' || LPAD(i::text, 7, '0') AS sku,
    'Product ' || i || ' ' || (ARRAY['Pro', 'Ultra', 'Plus', 'Max', 'Lite', 'Edition', 'Series', 'Prime'])[(i % 8) + 1],
    (150.00 + ((i * 37) % 180000) + ((i % 99) * 0.50))::numeric(10,2) AS unit_price,
    ((i * 11) % 120) AS stock_qty,
    -- Construct deterministic, realistic multi-tag arrays
    ARRAY[
        (tu.tags)[((i * 2) % 16) + 1],
        (tu.tags)[((i * 3 + 1) % 16) + 1],
        (tu.tags)[((i * 5 + 2) % 16) + 1]
    ] AS tags,
    (i % 25 <> 0) AS is_active -- 96% active
FROM generate_series(16, 25000) AS i
CROSS JOIN tag_universe tu
ON CONFLICT (sku) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. Scale Orders (200,000 High-Volume Event Records spread across 730 days)
-- ----------------------------------------------------------------------------
INSERT INTO orders (customer_id, status, shipping_address, flags, total_amount, placed_at)
SELECT
    ((i % 10000) + 1) AS customer_id,
    (ARRAY['paid', 'shipped', 'delivered', 'delivered', 'delivered', 'pending', 'cancelled'])[(i % 7) + 1] AS status,
    ROW(
        (i % 300 + 1) || ' Delivery Avenue, Apt ' || (i % 20 + 1),
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Tlemcen', 'Blida', 'Bejaia'])[(i % 8) + 1],
        (ARRAY['Constantine', 'Algiers', 'Oran', 'Setif', 'Annaba', 'Tlemcen', 'Blida', 'Bejaia'])[(i % 8) + 1],
        LPAD(((i * 89) % 48000 + 1000)::text, 5, '0'),
        'DZ'
    )::address_t AS shipping_address,
    (ARRAY[
        ARRAY['standard']::text[],
        ARRAY['express']::text[],
        ARRAY['express', 'gift']::text[],
        ARRAY['fragile']::text[],
        ARRAY['express', 'fragile', 'priority']::text[]
    ])[(i % 5) + 1] AS flags,
    (800.00 + ((i * 43) % 45000) + ((i % 99) * 0.75))::numeric(12,2) AS total_amount,
    NOW() - (((i % 730) || ' days')::interval) - (((i % 86400) || ' seconds')::interval) AS placed_at
FROM generate_series(4, 200000) AS i;

-- ----------------------------------------------------------------------------
-- 6. Scale Order Items (480,000 Line Items linking orders and products)
-- ----------------------------------------------------------------------------
-- Guaranteed unique (order_id, product_id) per order

-- Item 1: Every order has at least 1 item (200,000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
SELECT
    i AS order_id,
    (((i * 3 + 1) % 25000) + 1) AS product_id,
    ((i % 4) + 1) AS quantity,
    (650.00 + ((i * 17) % 25000))::numeric(10,2) AS unit_price_at_purchase
FROM generate_series(4, 200000) AS i;

-- Item 2: 80% of orders have a 2nd item (160,000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
SELECT
    i AS order_id,
    (((i * 3 + 2) % 25000) + 1) AS product_id,
    ((i % 3) + 1) AS quantity,
    (420.00 + ((i * 29) % 18000))::numeric(10,2) AS unit_price_at_purchase
FROM generate_series(4, 200000) AS i
WHERE (i % 10) < 8;

-- Item 3: 40% of orders have a 3rd item (80,000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
SELECT
    i AS order_id,
    (((i * 3 + 3) % 25000) + 1) AS product_id,
    1 AS quantity,
    (1150.00 + ((i * 13) % 35000))::numeric(10,2) AS unit_price_at_purchase
FROM generate_series(4, 200000) AS i
WHERE (i % 10) < 4;

-- Item 4: 20% of orders have a 4th item (40,000 items)
INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
SELECT
    i AS order_id,
    (((i * 3 + 4) % 25000) + 1) AS product_id,
    2 AS quantity,
    (850.00 + ((i * 31) % 12000))::numeric(10,2) AS unit_price_at_purchase
FROM generate_series(4, 200000) AS i
WHERE (i % 10) < 2;

-- ----------------------------------------------------------------------------
-- 7. Scale Payments (200,000 records, 1-to-1 with orders)
-- ----------------------------------------------------------------------------
INSERT INTO payments (order_id, payment_method, amount, payment_status, paid_at)
SELECT
    i AS order_id,
    (ARRAY['card', 'cib', 'edahabia', 'cod', 'wallet'])[(i % 5) + 1] AS payment_method,
    (800.00 + ((i * 43) % 45000) + ((i % 99) * 0.75))::numeric(12,2) AS amount,
    (ARRAY['captured', 'captured', 'captured', 'authorized', 'failed'])[(i % 5) + 1] AS payment_status,
    NOW() - (((i % 730) || ' days')::interval) AS paid_at
FROM generate_series(4, 200000) AS i;

-- ----------------------------------------------------------------------------
-- 8. Refresh Analytics Materialized View & Update Planner Statistics
-- ----------------------------------------------------------------------------
REFRESH MATERIALIZED VIEW mv_daily_category_sales;

-- Re-enable synchronous_commit
SET synchronous_commit = on;

-- Compute accurate statistics so the PostgreSQL planner knows table sizes
ANALYZE categories;
ANALYZE sellers;
ANALYZE customers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
ANALYZE payments;
