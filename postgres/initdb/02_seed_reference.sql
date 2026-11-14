-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component A (Part 2): Hand-written Reference Seed Data
-- ============================================================================

-- 1. Categories (10 core categories with parent-child hierarchy)
INSERT INTO categories (name, slug, parent_category_id) VALUES
('Electronics',       'electronics',       NULL), -- id 1
('Fashion',           'fashion',           NULL), -- id 2
('Books & Media',     'books-media',       NULL), -- id 3
('Home & Kitchen',    'home-kitchen',      NULL), -- id 4
('Laptops',           'laptops',           1),    -- id 5
('Smartphones',       'smartphones',       1),    -- id 6
('Audio & Wearables', 'audio-wearables',   1),    -- id 7
('Men Clothing',      'men-clothing',      2),    -- id 8
('Footwear',          'footwear',          2),    -- id 9
('Technical Books',   'technical-books',   3);    -- id 10

-- 2. Sellers (5 realistic local/regional vendors)
INSERT INTO sellers (store_name, contact, business_address, rating, is_verified) VALUES
(
    'Atlas Tech Store',
    ROW('sales@atlastech.dz', '+213-31-555-0101', 'https://atlastech.dz')::contact_info_t,
    ROW('14 Rue Didouche Mourad', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    4.85, TRUE
),
(
    'Numidia Fashion House',
    ROW('contact@numidiafashion.dz', '+213-21-555-0102', 'https://numidiafashion.dz')::contact_info_t,
    ROW('88 Boulevard Mohamed V', 'Algiers', 'Algiers', '16000', 'DZ')::address_t,
    4.60, TRUE
),
(
    'Cirta Bookshop',
    ROW('hello@cirtabooks.dz', '+213-31-555-0103', 'https://cirtabooks.dz')::contact_info_t,
    ROW('5 Place du 1er Novembre', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    4.92, TRUE
),
(
    'Oran Home Essentials',
    ROW('support@oranhome.dz', '+213-41-555-0104', NULL)::contact_info_t,
    ROW('22 Avenue de l''ALN', 'Oran', 'Oran', '31000', 'DZ')::address_t,
    4.35, FALSE
),
(
    'Maghreb Gadgets',
    ROW('orders@maghrebgadgets.dz', '+213-21-555-0105', 'https://maghrebgadgets.dz')::contact_info_t,
    ROW('19 Rue Larbi Ben Mhidi', 'Algiers', 'Algiers', '16000', 'DZ')::address_t,
    4.70, TRUE
);

-- 3. Customers (5 realistic reference buyers)
INSERT INTO customers (full_name, email, default_address, loyalty_tier) VALUES
(
    'Amine Benali',
    'amine.benali@example.dz',
    ROW('12 Cite Zouaghi Slimane', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    'gold'
),
(
    'Sarah Khelifi',
    'sarah.khelifi@example.dz',
    ROW('45 Rue Hassiba Ben Bouali', 'Algiers', 'Algiers', '16014', 'DZ')::address_t,
    'platinum'
),
(
    'Yacine Mansouri',
    'yacine.mansouri@example.dz',
    ROW('7 Boulevard Millenium', 'Oran', 'Oran', '31000', 'DZ')::address_t,
    'silver'
),
(
    'Lina Boudiaf',
    'lina.boudiaf@example.dz',
    ROW('30 Cite Ali Mendjeli UV5', 'El Khroub', 'Constantine', '25100', 'DZ')::address_t,
    'bronze'
),
(
    'Karim Ziani',
    'karim.ziani@example.dz',
    ROW('9 Rue de la Liberte', 'Setif', 'Setif', '19000', 'DZ')::address_t,
    'bronze'
);

-- 4. Products (15 realistic reference SKUs across Electronics, Fashion, Books, Home)
INSERT INTO products (seller_id, category_id, sku, title, unit_price, stock_qty, tags, is_active) VALUES
(1, 5,  'SKU-LAP-001', 'ThinkBook 14 Gen 6 Laptop',         145000.00, 12, ARRAY['laptop', 'ultrabook', 'work', 'nvme'], TRUE),
(1, 5,  'SKU-LAP-002', 'ProBook Nitro 16 Gaming Laptop',    215000.00,  5, ARRAY['laptop', 'gaming', 'rtx', '16gb'], TRUE),
(5, 6,  'SKU-PHN-001', 'Galaxy A55 5G Smartphone',           68000.00, 25, ARRAY['smartphone', '5g', 'amoled', 'android'], TRUE),
(5, 6,  'SKU-PHN-002', 'Pixel 8a 128GB',                     89000.00,  8, ARRAY['smartphone', 'camera', '5g'], TRUE),
(1, 7,  'SKU-AUD-001', 'SoundCore ANC Wireless Headphones',  14500.00, 40, ARRAY['audio', 'wireless', 'bluetooth', 'anc'], TRUE),
(5, 7,  'SKU-AUD-002', 'FitPulse Pro Smartwatch',            18900.00, 18, ARRAY['wearable', 'smartwatch', 'fitness', 'bluetooth'], TRUE),
(2, 8,  'SKU-CLO-001', 'Organic Cotton Oxford Shirt',         4500.00, 50, ARRAY['shirt', 'cotton', 'formal', 'breathable'], TRUE),
(2, 8,  'SKU-CLO-002', 'Atlas Heavyweight Hoodie',            5800.00, 32, ARRAY['hoodie', 'winter', 'cotton', 'casual'], TRUE),
(2, 9,  'SKU-SHOE-01', 'Nomad Trail Running Sneakers',       11200.00, 20, ARRAY['shoes', 'running', 'trail', 'waterproof'], TRUE),
(3, 10, 'SKU-BOK-001', 'Designing Data-Intensive Applications', 6500.00, 15, ARRAY['book', 'databases', 'distributed', 'engineering'], TRUE),
(3, 10, 'SKU-BOK-002', 'PostgreSQL Internals & Tuning',       5200.00, 22, ARRAY['book', 'postgresql', 'sql', 'performance'], TRUE),
(3, 10, 'SKU-BOK-003', 'MongoDB Modeling Patterns',           4800.00, 14, ARRAY['book', 'mongodb', 'nosql', 'schema'], TRUE),
(4, 4,  'SKU-HOM-001', 'Espresso Barista Machine 15-Bar',    34000.00,  7, ARRAY['kitchen', 'coffee', 'espresso'], TRUE),
(4, 4,  'SKU-HOM-002', 'Smart Air Purifier HEPA-13',         27500.00, 11, ARRAY['home', 'air-purifier', 'smart'], TRUE),
(1, 5,  'SKU-LAP-003', 'Limited Edition Workstation (1 left)', 290000.00, 1, ARRAY['laptop', 'workstation', 'limited'], TRUE);

-- 5. Sample initial orders + items + payments (demonstrates full relational chain)
INSERT INTO orders (customer_id, status, shipping_address, flags, total_amount, placed_at) VALUES
(
    1, 'delivered',
    ROW('12 Cite Zouaghi Slimane', 'Constantine', 'Constantine', '25000', 'DZ')::address_t,
    ARRAY['express', 'verified'],
    159500.00,
    NOW() - INTERVAL '10 days'
),
(
    2, 'paid',
    ROW('45 Rue Hassiba Ben Bouali', 'Algiers', 'Algiers', '16014', 'DZ')::address_t,
    ARRAY['gift', 'fragile'],
    11700.00,
    NOW() - INTERVAL '2 days'
);

INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase) VALUES
(1, 1, 1, 145000.00),
(1, 5, 1,  14500.00),
(2, 10, 1,  6500.00),
(2, 11, 1,  5200.00);

INSERT INTO payments (order_id, payment_method, amount, payment_status, paid_at) VALUES
(1, 'cib',      159500.00, 'captured', NOW() - INTERVAL '10 days'),
(2, 'edahabia',  11700.00, 'captured', NOW() - INTERVAL '2 days');

