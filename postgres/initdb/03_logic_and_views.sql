-- ============================================================================
-- Polyglot Persistence Capstone — E-Commerce Marketplace (SoukTech)
-- Component A (Part 3): PL/pgSQL Functions, Triggers, Concurrency-Safe
--                       Procedure, Views, and Materialized View
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PL/pgSQL Functions
-- ----------------------------------------------------------------------------

-- Function 1: Computes the exact order total from its line items
CREATE OR REPLACE FUNCTION fn_calculate_order_total(p_order_id BIGINT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(quantity * unit_price_at_purchase), 0.00)
    INTO v_total
    FROM order_items
    WHERE order_id = p_order_id;

    RETURN v_total;
END;
$$;

-- Function 2: Computes a customer's lifetime spend across valid completed orders
CREATE OR REPLACE FUNCTION fn_customer_lifetime_spend(p_customer_id INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_spend NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(total_amount), 0.00)
    INTO v_spend
    FROM orders
    WHERE customer_id = p_customer_id
      AND status IN ('paid', 'shipped', 'delivered');

    RETURN v_spend;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. Audit Triggers (writing into inherited audit_event child tables)
-- ----------------------------------------------------------------------------

-- Trigger function for product stock changes -> stock_audit_event
CREATE OR REPLACE FUNCTION fn_trg_audit_product_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.stock_qty IS DISTINCT FROM OLD.stock_qty THEN
        INSERT INTO stock_audit_event (actor_role, reason, product_id, old_qty, new_qty)
        VALUES (
            CURRENT_USER,
            CASE
                WHEN NEW.stock_qty < OLD.stock_qty THEN 'Stock decremented (sale/adjustment)'
                ELSE 'Stock replenished'
            END,
            NEW.product_id,
            OLD.stock_qty,
            NEW.stock_qty
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_product_stock
AFTER UPDATE OF stock_qty ON products
FOR EACH ROW
EXECUTE FUNCTION fn_trg_audit_product_stock();

-- Trigger function for order status transitions -> order_audit_event
CREATE OR REPLACE FUNCTION fn_trg_audit_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO order_audit_event (actor_role, reason, order_id, old_status, new_status)
        VALUES (
            CURRENT_USER,
            'Order status transition',
            NEW.order_id,
            OLD.status,
            NEW.status
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_order_status
AFTER UPDATE OF status ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_trg_audit_order_status();

-- ----------------------------------------------------------------------------
-- 3. Critical Concurrency-Safe Operation: sp_place_order
-- ----------------------------------------------------------------------------
-- Anomaly prevented: LOST UPDATE (and overselling / negative stock) under
-- concurrent checkouts in PostgreSQL's default READ COMMITTED isolation level.
--
-- Mechanism:
--   `SELECT ... FROM products WHERE product_id = p_product_id FOR UPDATE`
--   acquires a row-level exclusive lock on the target product row. Any
--   concurrent transaction attempting to purchase the same product blocks
--   until this transaction commits or rolls back, then sees the updated
--   committed `stock_qty` instead of a stale pre-decrement value.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_place_order(
    IN  p_customer_id    INT,
    IN  p_product_id     INT,
    IN  p_quantity       INT,
    IN  p_payment_method VARCHAR(30),
    IN  p_flags          TEXT[],
    OUT p_order_id       BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_shipping_addr address_t;
    v_unit_price    NUMERIC(10,2);
    v_stock_qty     INT;
    v_is_active     BOOLEAN;
    v_total_amount  NUMERIC(12,2);
BEGIN
    -- 1. Validate quantity
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Order quantity must be positive (got %)', p_quantity
            USING ERRCODE = '22023';
    END IF;

    -- 2. Verify customer exists and retrieve default shipping address
    SELECT default_address
    INTO v_shipping_addr
    FROM customers
    WHERE customer_id = p_customer_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found', p_customer_id
            USING ERRCODE = '02000';
    END IF;

    -- 3. Lock the product row exclusively to prevent concurrent Lost Updates
    SELECT unit_price, stock_qty, is_active
    INTO v_unit_price, v_stock_qty, v_is_active
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id
            USING ERRCODE = '02000';
    END IF;

    IF NOT v_is_active THEN
        RAISE EXCEPTION 'Product % is not active for sale', p_product_id
            USING ERRCODE = 'P0001';
    END IF;

    IF v_stock_qty < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product % (requested %, available %)',
            p_product_id, p_quantity, v_stock_qty
            USING ERRCODE = 'P0002';
    END IF;

    -- 4. Decrement stock safely (fires trg_audit_product_stock)
    UPDATE products
    SET stock_qty = stock_qty - p_quantity
    WHERE product_id = p_product_id;

    -- 5. Create order header
    INSERT INTO orders (customer_id, status, shipping_address, flags, total_amount)
    VALUES (p_customer_id, 'paid', v_shipping_addr, COALESCE(p_flags, '{}'), 0.00)
    RETURNING order_id INTO p_order_id;

    -- 6. Insert order line item
    INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
    VALUES (p_order_id, p_product_id, p_quantity, v_unit_price);

    -- 7. Compute and persist order total using our PL/pgSQL function
    v_total_amount := fn_calculate_order_total(p_order_id);

    UPDATE orders
    SET total_amount = v_total_amount
    WHERE order_id = p_order_id;

    -- 8. Record captured payment
    INSERT INTO payments (order_id, payment_method, amount, payment_status, paid_at)
    VALUES (p_order_id, p_payment_method, v_total_amount, 'captured', NOW());
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. Views & Materialized Views
-- ----------------------------------------------------------------------------

-- Regular VIEW: Live active, in-stock marketplace catalog
CREATE OR REPLACE VIEW v_active_catalog AS
SELECT
    p.product_id,
    p.sku,
    p.title,
    c.name            AS category_name,
    s.store_name      AS seller_name,
    s.is_verified     AS seller_verified,
    p.unit_price,
    p.stock_qty,
    p.tags
FROM products p
JOIN categories c ON c.category_id = p.category_id
JOIN sellers    s ON s.seller_id   = p.seller_id
WHERE p.is_active = TRUE
  AND p.stock_qty > 0;

-- MATERIALIZED VIEW: Pre-aggregated daily sales by category for analytics
CREATE MATERIALIZED VIEW mv_daily_category_sales AS
SELECT
    DATE(o.placed_at)                         AS sale_date,
    c.category_id,
    c.name                                    AS category_name,
    COUNT(DISTINCT o.order_id)                AS order_count,
    SUM(oi.quantity)                          AS units_sold,
    SUM(oi.quantity * oi.unit_price_at_purchase) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id  = o.order_id
JOIN products    p  ON p.product_id = oi.product_id
JOIN categories  c  ON c.category_id = p.category_id
WHERE o.status IN ('paid', 'shipped', 'delivered')
GROUP BY DATE(o.placed_at), c.category_id, c.name
WITH DATA;

-- Unique index enables REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_daily_category_sales_pk
    ON mv_daily_category_sales (sale_date, category_id);
