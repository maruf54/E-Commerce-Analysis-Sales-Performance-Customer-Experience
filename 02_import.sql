-- 02_import.sql
-- Run inside psql (NOT pgAdmin's Query Tool) — \copy is a psql client command.
--   macOS:  /Library/PostgreSQL/18/bin/psql -U postgres -d olist
-- Replace /path/to/olist/ with the folder where you unzipped the Kaggle dataset.

\copy customers FROM '/path/to/olist/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy orders FROM '/path/to/olist/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy order_items FROM '/path/to/olist/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy payments FROM '/path/to/olist/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy reviews FROM '/path/to/olist/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy products FROM '/path/to/olist/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy sellers FROM '/path/to/olist/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true);
\copy category_translation FROM '/path/to/olist/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true);

-- Sanity check: row counts per table
SELECT 'orders' AS tbl, COUNT(*) FROM orders
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;
