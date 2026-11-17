-- 05_views_for_powerbi.sql
-- Two clean reporting views. Payments and reviews are aggregated to one row per
-- order BEFORE joining, to avoid fan-out (double counting) when an order has
-- several payments or reviews.

-- Grain: one row per order
CREATE VIEW v_order_summary AS
SELECT o.order_id,
       o.order_purchase_timestamp::date AS order_date,
       o.order_status,
       c.customer_unique_id,
       c.customer_state,
       c.customer_city,
       pay.payment_value,
       pay.main_payment_type,
       r.review_score,
       EXTRACT(EPOCH FROM (o.order_delivered_customer_date
                           - o.order_purchase_timestamp)) / 86400 AS delivery_days,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN 'Not delivered'
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
            ELSE 'On time' END AS delivery_status
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN (
  SELECT order_id,
         SUM(payment_value) AS payment_value,
         (ARRAY_AGG(payment_type ORDER BY payment_value DESC))[1] AS main_payment_type
  FROM payments GROUP BY order_id
) pay ON pay.order_id = o.order_id
LEFT JOIN (
  SELECT order_id, AVG(review_score) AS review_score
  FROM reviews GROUP BY order_id
) r ON r.order_id = o.order_id;

-- Grain: one row per item sold (delivered orders only)
CREATE VIEW v_category_sales AS
SELECT oi.order_id,
       o.order_purchase_timestamp::date AS order_date,
       COALESCE(t.product_category_name_english, 'unknown') AS category,
       oi.price,
       oi.freight_value,
       oi.seller_id
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products pr ON pr.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = pr.product_category_name
WHERE o.order_status = 'delivered';

-- Export both views to CSV for Power BI (run in psql):
-- \copy (SELECT * FROM v_order_summary) TO '/path/to/v_order_summary.csv' WITH (FORMAT csv, HEADER true);
-- \copy (SELECT * FROM v_category_sales) TO '/path/to/v_category_sales.csv' WITH (FORMAT csv, HEADER true);
