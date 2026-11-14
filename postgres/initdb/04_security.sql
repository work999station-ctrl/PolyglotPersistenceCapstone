-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component A (Part 4): Security Model — Roles, GRANT/REVOKE, and RLS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Roles (Least-Privilege Separation)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_read') THEN
        CREATE ROLE app_read NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_write') THEN
        CREATE ROLE app_write NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin NOLOGIN BYPASSRLS;
    END IF;
END
$$;

-- ----------------------------------------------------------------------------
-- 2. Revoke Default Public Access & Grant Explicit Privileges
-- ----------------------------------------------------------------------------

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO app_read, app_write, app_admin;

-- app_read: Catalog browsing and aggregated analytics only (no customer PII, no writes)
GRANT SELECT ON
    categories,
    sellers,
    products,
    v_active_catalog,
    mv_daily_category_sales
TO app_read;

GRANT EXECUTE ON FUNCTION
    fn_calculate_order_total(BIGINT),
    fn_customer_lifetime_spend(INT)
TO app_read;

-- app_write: Application checkout & customer self-service (subject to RLS on orders)
GRANT SELECT ON
    categories,
    sellers,
    customers,
    products,
    orders,
    order_items,
    payments,
    v_active_catalog
TO app_write;

GRANT UPDATE (stock_qty) ON products TO app_write;
GRANT INSERT, UPDATE ON orders TO app_write;
GRANT INSERT ON order_items, payments, order_audit_event, stock_audit_event TO app_write;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_write;

GRANT EXECUTE ON FUNCTION
    fn_calculate_order_total(BIGINT),
    fn_customer_lifetime_spend(INT),
    fn_trg_audit_product_stock(),
    fn_trg_audit_order_status()
TO app_write;

GRANT EXECUTE ON PROCEDURE
    sp_place_order(INT, INT, INT, VARCHAR, TEXT[], BIGINT)
TO app_write;

-- app_admin: Full administrative control over marketplace schema + BYPASSRLS
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_admin;

-- Grant student (lab user) membership so SET ROLE works smoothly in demos
GRANT app_read, app_write, app_admin TO student;

-- ----------------------------------------------------------------------------
-- 3. Row-Level Security (RLS) on `orders`
-- ----------------------------------------------------------------------------
-- Ensures an application session acting as `app_write` can only read, insert,
-- or update orders belonging to the authenticated customer ID stored in the
-- session setting `app.current_customer_id`.

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: app_write can SELECT only their own orders
CREATE POLICY orders_customer_select
    ON orders
    FOR SELECT
    TO app_write
    USING (
        customer_id = NULLIF(current_setting('app.current_customer_id', TRUE), '')::INT
    );

-- Policy: app_write can INSERT only orders for themselves
CREATE POLICY orders_customer_insert
    ON orders
    FOR INSERT
    TO app_write
    WITH CHECK (
        customer_id = NULLIF(current_setting('app.current_customer_id', TRUE), '')::INT
    );

-- Policy: app_write can UPDATE only their own orders
CREATE POLICY orders_customer_update
    ON orders
    FOR UPDATE
    TO app_write
    USING (
        customer_id = NULLIF(current_setting('app.current_customer_id', TRUE), '')::INT
    )
    WITH CHECK (
        customer_id = NULLIF(current_setting('app.current_customer_id', TRUE), '')::INT
    );

-- Policy: app_admin can access all orders (and also has BYPASSRLS)
CREATE POLICY orders_admin_all
    ON orders
    FOR ALL
    TO app_admin
    USING (TRUE)
    WITH CHECK (TRUE);

