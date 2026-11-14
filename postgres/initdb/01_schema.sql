-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component A (Part 1): PostgreSQL Object-Relational Schema (3NF)
-- Engine: PostgreSQL 17
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Object-Relational Composite Types (Chapter 3)
-- ----------------------------------------------------------------------------

-- Composite type representing a structured physical/shipping address
CREATE TYPE address_t AS (
    street      VARCHAR(150),
    city        VARCHAR(80),
    wilaya      VARCHAR(80),
    postal_code VARCHAR(12),
    country     CHAR(2)
);

-- Composite type representing seller contact details
CREATE TYPE contact_info_t AS (
    email       VARCHAR(150),
    phone       VARCHAR(25),
    website_url VARCHAR(200)
);

-- ----------------------------------------------------------------------------
-- 2. Core Normalized Tables in 3NF
-- ----------------------------------------------------------------------------

-- 2.1 Categories (Lookup / Reference with self-referencing hierarchy)
CREATE TABLE categories (
    category_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name               VARCHAR(100) NOT NULL UNIQUE,
    slug               VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INT REFERENCES categories(category_id) ON DELETE SET NULL,
    CONSTRAINT chk_category_not_self_parent
        CHECK (parent_category_id IS NULL OR parent_category_id <> category_id)
);

-- 2.2 Sellers (Marketplace vendors)
CREATE TABLE sellers (
    seller_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_name       VARCHAR(120) NOT NULL UNIQUE,
    contact          contact_info_t NOT NULL,
    business_address address_t NOT NULL,
    rating           NUMERIC(3,2) NOT NULL DEFAULT 5.00,
    is_verified      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_seller_rating_range
        CHECK (rating >= 0.00 AND rating <= 5.00),
    CONSTRAINT chk_seller_contact_email
        CHECK ((contact).email IS NOT NULL AND position('@' IN (contact).email) > 1)
);

-- 2.3 Customers (Registered buyers)
CREATE TABLE customers (
    customer_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name       VARCHAR(120) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    default_address address_t NOT NULL,
    loyalty_tier    VARCHAR(20) NOT NULL DEFAULT 'bronze',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_customer_email_format
        CHECK (position('@' IN email) > 1),
    CONSTRAINT chk_customer_loyalty_tier
        CHECK (loyalty_tier IN ('bronze', 'silver', 'gold', 'platinum'))
);

-- 2.4 Products (Core transactional SKU catalog; rich specs live in MongoDB)
CREATE TABLE products (
    product_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id   INT NOT NULL REFERENCES sellers(seller_id) ON DELETE RESTRICT,
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    sku         VARCHAR(40) NOT NULL UNIQUE,
    title       VARCHAR(200) NOT NULL,
    unit_price  NUMERIC(10,2) NOT NULL,
    stock_qty   INT NOT NULL,
    tags        TEXT[] NOT NULL DEFAULT '{}',
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_product_price_positive CHECK (unit_price > 0),
    CONSTRAINT chk_product_stock_nonneg   CHECK (stock_qty >= 0)
);

-- 2.5 Orders (Main high-volume transactional event table)
CREATE TABLE orders (
    order_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id      INT NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    status           VARCHAR(20) NOT NULL DEFAULT 'pending',
    shipping_address address_t NOT NULL,
    flags            TEXT[] NOT NULL DEFAULT '{}',
    total_amount     NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    placed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_order_status
        CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    CONSTRAINT chk_order_total_nonneg
        CHECK (total_amount >= 0)
);

-- 2.6 Order Items (Line items linking orders and products)
CREATE TABLE order_items (
    order_item_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id                BIGINT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id              INT NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity                INT NOT NULL,
    unit_price_at_purchase  NUMERIC(10,2) NOT NULL,
    CONSTRAINT chk_order_item_qty_positive   CHECK (quantity > 0),
    CONSTRAINT chk_order_item_price_positive CHECK (unit_price_at_purchase > 0),
    CONSTRAINT uq_order_product              UNIQUE (order_id, product_id)
);

-- 2.7 Payments (1-to-1 payment record per order)
CREATE TABLE payments (
    payment_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id       BIGINT NOT NULL UNIQUE REFERENCES orders(order_id) ON DELETE CASCADE,
    payment_method VARCHAR(30) NOT NULL,
    amount         NUMERIC(12,2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    paid_at        TIMESTAMPTZ,
    CONSTRAINT chk_payment_method
        CHECK (payment_method IN ('card', 'cib', 'edahabia', 'cod', 'wallet')),
    CONSTRAINT chk_payment_amount_positive
        CHECK (amount > 0),
    CONSTRAINT chk_payment_status
        CHECK (payment_status IN ('pending', 'authorized', 'captured', 'failed', 'refunded'))
);

-- ----------------------------------------------------------------------------
-- 3. Object-Relational Table Inheritance Hierarchy (Chapter 3)
-- ----------------------------------------------------------------------------
-- Parent audit table: querying audit_event returns all audit records across
-- child tables, while each child adds domain-specific columns without forcing
-- sparse NULLs into a single table. (Audit logs are append-only and do not
-- serve as FK targets, avoiding PostgreSQL's FK-inheritance limitation.)

CREATE SEQUENCE audit_event_id_seq;

CREATE TABLE audit_event (
    event_id    BIGINT NOT NULL DEFAULT nextval('audit_event_id_seq'),
    actor_role  TEXT NOT NULL DEFAULT CURRENT_USER,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason      TEXT
);

CREATE TABLE order_audit_event (
    order_id   BIGINT NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL
) INHERITS (audit_event);

CREATE TABLE stock_audit_event (
    product_id INT NOT NULL,
    old_qty    INT NOT NULL,
    new_qty    INT NOT NULL
) INHERITS (audit_event);

