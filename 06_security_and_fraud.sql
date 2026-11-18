-- 06_security_and_fraud.sql
-- Security lens on the Olist data, in three parts:
--   A. Fraud / anomaly detection on payments and ordering behavior
--   B. Database access control (least privilege)
--   C. Privacy: PII masking and a k-anonymity check
-- Run in pgAdmin's Query Tool, section by section. Part B is safest to run in psql

WITH items AS (
  SELECT order_id, SUM(price + freight_value) AS item_total
  FROM order_items GROUP BY 1
),
pay AS (
  SELECT order_id, SUM(payment_value) AS paid, COUNT(*) AS n_payments
  FROM payments GROUP BY 1
)
SELECT p.order_id,
       ROUND(i.item_total, 2)          AS item_total,
       ROUND(p.paid, 2)                AS paid,
       p.n_payments,
       ROUND(p.paid - i.item_total, 2) AS difference
FROM pay p
JOIN items i ON i.order_id = p.order_id
WHERE ABS(p.paid - i.item_total) > 1
ORDER BY ABS(p.paid - i.item_total) DESC
LIMIT 20;

-- A2. Statistical outliers: order value more than 3 standard deviations above the mean.
WITH pay AS (
  SELECT order_id, SUM(payment_value) AS paid FROM payments GROUP BY 1
),
stats AS (
  SELECT AVG(paid) AS mu, STDDEV(paid) AS sd FROM pay
)
SELECT p.order_id,
       ROUND(p.paid, 2)                 AS paid,
       ROUND((p.paid - s.mu) / s.sd, 1) AS z_score
FROM pay p CROSS JOIN stats s
WHERE p.paid > s.mu + 3 * s.sd
ORDER BY p.paid DESC
LIMIT 20;

-- A3. Voucher stacking: 5 or more vouchers on a single order (possible promo abuse).
SELECT order_id,
       COUNT(*)                    AS vouchers_used,
       ROUND(SUM(payment_value), 2) AS voucher_value
FROM payments
WHERE payment_type = 'voucher'
GROUP BY order_id
HAVING COUNT(*) >= 5
ORDER BY vouchers_used DESC
LIMIT 20;

-- A4. Burst ordering: the same customer places 3 orders within 24 hours

WITH o AS (
  SELECT c.customer_unique_id,
         o.order_id,
         o.order_purchase_timestamp AS ts,
         LAG(o.order_purchase_timestamp, 2) OVER (
           PARTITION BY c.customer_unique_id
           ORDER BY o.order_purchase_timestamp) AS ts_two_orders_ago
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
)
SELECT customer_unique_id, order_id, ts, ts_two_orders_ago,
       ts - ts_two_orders_ago AS window_for_3_orders
FROM o
WHERE ts - ts_two_orders_ago <= INTERVAL '24 hours'
ORDER BY window_for_3_orders
LIMIT 20;

-- A5. Odd payments: zero-value payments or an undefined payment type.
SELECT order_id, payment_type, payment_value
FROM payments
WHERE payment_value = 0 OR payment_type = 'not_defined';

-- A6. One risk view for reporting: every order with its flags and a simple risk score.
CREATE OR REPLACE VIEW v_order_risk_flags AS
WITH items AS (
  SELECT order_id, SUM(price + freight_value) AS item_total
  FROM order_items GROUP BY 1
),
pay AS (
  SELECT order_id,
         SUM(payment_value) AS paid,
         SUM(CASE WHEN payment_type = 'voucher' THEN 1 ELSE 0 END) AS n_vouchers,
         BOOL_OR(payment_type = 'not_defined' OR payment_value = 0) AS odd_payment
  FROM payments GROUP BY 1
),
stats AS (
  SELECT AVG(paid) AS mu, STDDEV(paid) AS sd FROM pay
),
flags AS (
  SELECT p.order_id,
         p.paid,
         i.item_total,
         CASE WHEN i.item_total IS NOT NULL
               AND ABS(p.paid - i.item_total) > 1 THEN 1 ELSE 0 END AS flag_amount_mismatch,
         CASE WHEN p.paid > s.mu + 3 * s.sd THEN 1 ELSE 0 END      AS flag_high_value,
         CASE WHEN p.n_vouchers >= 5 THEN 1 ELSE 0 END             AS flag_voucher_stacking,
         CASE WHEN p.odd_payment THEN 1 ELSE 0 END                 AS flag_odd_payment
  FROM pay p
  LEFT JOIN items i ON i.order_id = p.order_id
  CROSS JOIN stats s
)
SELECT *,
       flag_amount_mismatch + flag_high_value
       + flag_voucher_stacking + flag_odd_payment AS risk_score
FROM flags;

-- Summary: how many orders carry each flag
SELECT SUM(flag_amount_mismatch)  AS amount_mismatch,
       SUM(flag_high_value)       AS high_value,
       SUM(flag_voucher_stacking) AS voucher_stacking,
       SUM(flag_odd_payment)      AS odd_payment,
       SUM(CASE WHEN risk_score >= 2 THEN 1 ELSE 0 END) AS orders_with_2plus_flags,
       COUNT(*)                   AS total_orders
FROM v_order_risk_flags;


CREATE ROLE analyst_ro LOGIN;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

GRANT CONNECT ON DATABASE olist TO analyst_ro;
GRANT USAGE ON SCHEMA public TO analyst_ro;
GRANT SELECT ON v_order_summary, v_category_sales TO analyst_ro;


-- Test it: switch to the analyst role and try both.
SET ROLE analyst_ro;
SELECT COUNT(*) FROM v_order_summary;   -- works
SELECT * FROM customers LIMIT 1;        -- expected: ERROR: permission denied for table customers
RESET ROLE;

-- C. PRIVACY: PII MASKING + K-ANONYMITY

CREATE OR REPLACE VIEW v_customers_masked AS
SELECT encode(sha256((customer_unique_id || 'change-this-salt')::bytea), 'hex') AS customer_hash,
       LEFT(customer_zip_code_prefix, 3) || 'XX' AS zip_masked,
       customer_city,
       customer_state
FROM customers;

GRANT SELECT ON v_customers_masked TO analyst_ro;

SELECT * FROM v_customers_masked LIMIT 5;

-- C2. k-anonymity check (k = 5): city + state groups with fewer than 5 customers.
SELECT customer_city, customer_state,
       COUNT(DISTINCT customer_unique_id) AS customers
FROM customers
GROUP BY 1, 2
HAVING COUNT(DISTINCT customer_unique_id) < 5
ORDER BY customers
LIMIT 20;

-- How big is the problem?
WITH g AS (
  SELECT customer_city, customer_state,
         COUNT(DISTINCT customer_unique_id) AS customers
  FROM customers GROUP BY 1, 2
)
SELECT COUNT(*)                                           AS total_city_groups,
       SUM(CASE WHEN customers < 5 THEN 1 ELSE 0 END)     AS groups_below_k5,
       SUM(CASE WHEN customers < 5 THEN customers ELSE 0 END) AS customers_at_risk
FROM g;
