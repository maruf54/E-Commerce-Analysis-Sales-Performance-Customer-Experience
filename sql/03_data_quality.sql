-- 03_data_quality.sql
-- Checks run before any analysis. Findings and decisions are in the README.

-- 1. Order status breakdown (canceled/unavailable orders must not count as revenue)
SELECT order_status, COUNT(*) FROM orders GROUP BY order_status ORDER BY 2 DESC;

-- 2. Delivered orders with no delivery date (can't compute delivery time for these)
SELECT COUNT(*) FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;

-- 3. Products with no category
SELECT COUNT(*) FROM products WHERE product_category_name IS NULL;

-- 4. Date range of the data (first/last months are partial)
SELECT MIN(order_purchase_timestamp), MAX(order_purchase_timestamp) FROM orders;

-- 5. Orders with more than one review (would double-count after a JOIN)
SELECT order_id, COUNT(*) FROM reviews
GROUP BY order_id HAVING COUNT(*) > 1 LIMIT 10;
