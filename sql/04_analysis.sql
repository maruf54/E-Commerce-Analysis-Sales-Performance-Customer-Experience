-- 04_analysis.sql
-- 10 business questions. Revenue = delivered orders only.

-- Q1. Total orders, revenue and average order value (AOV)
SELECT COUNT(DISTINCT o.order_id) AS total_orders,
       ROUND(SUM(p.payment_value), 2) AS total_revenue,
       ROUND(SUM(p.payment_value) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered';

-- Q2. Monthly revenue and month-over-month growth (CTE + LAG)
WITH monthly AS (
  SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
         SUM(p.payment_value) AS revenue
  FROM orders o
  JOIN payments p ON o.order_id = p.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly
ORDER BY month;

-- Q3. Top 10 categories by revenue
SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products pr ON pr.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = pr.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- Q4. Revenue by customer state
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY revenue DESC;

-- Q5. Payment method share
SELECT payment_type,
       COUNT(*) AS payments,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM payments
GROUP BY 1
ORDER BY payments DESC;

-- Q6. Do late deliveries get worse reviews?
WITH d AS (
  SELECT order_id,
         CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
              THEN 'Late' ELSE 'On time' END AS delivery_status
  FROM orders
  WHERE order_status = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
)
SELECT d.delivery_status,
       COUNT(*) AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_review
FROM d
JOIN reviews r ON r.order_id = d.order_id
GROUP BY 1;

-- Q7. Average delivery days by state
SELECT c.customer_state,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date
                                     - o.order_purchase_timestamp)) / 86400), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
ORDER BY avg_delivery_days DESC;

-- Q8. Repeat-customer rate (customer_unique_id = the real person;
--     customer_id is regenerated for every order)
WITH per_customer AS (
  SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS n_orders
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY 1
)
SELECT COUNT(*) AS total_customers,
       SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       ROUND(100.0 * SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_pct
FROM per_customer;

-- Q9. Top 10 sellers by revenue (RANK)
SELECT seller_id,
       ROUND(SUM(price), 2) AS revenue,
       RANK() OVER (ORDER BY SUM(price) DESC) AS seller_rank
FROM order_items
GROUP BY seller_id
ORDER BY seller_rank
LIMIT 10;

-- Q10. Busiest weekday + hour for orders
SELECT TO_CHAR(order_purchase_timestamp, 'Day') AS weekday,
       EXTRACT(HOUR FROM order_purchase_timestamp)::int AS hour,
       COUNT(*) AS orders
FROM orders
GROUP BY 1, 2
ORDER BY orders DESC
LIMIT 10;
