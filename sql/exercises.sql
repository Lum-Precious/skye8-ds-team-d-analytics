SELECT name, town, opened_year
FROM dim_branch
WHERE region = 'Littoral'
ORDER BY name;



SELECT product_code, name, strength, unit_price
FROM dim_product
WHERE category = 'Analgesics' AND unit_price > 500
ORDER BY unit_price DESC;



SELECT COUNT(*) AS transaction_count
FROM fact_sales
WHERE sold_on >= '2026-07-01' AND sold_on < '2026-08-01';



SELECT payment_method, SUM(quantity_units) AS total_units
FROM fact_sales
GROUP BY payment_method
ORDER BY total_units DESC;



SELECT b.name AS branch_name, p.product_name, s.sold_on, s.quantity_units
FROM fact_sales s
JOIN dim_branch b ON b.branch_key = s.branch_key
JOIN dim_product p ON p.product_key = s.product_key
ORDER BY s.sold_on
LIMIT 20;



SELECT b.name AS branch_name, SUM(s.quantity_units * s.unit_price) AS revenue
FROM fact_sales s
JOIN dim_branch b ON b.branch_key = s.branch_key
GROUP BY b.name
ORDER BY revenue DESC;



SELECT p.category, SUM(s.quantity_units * s.unit_price) AS revenue
FROM fact_sales s
JOIN dim_product p ON p.product_key = s.product_key
GROUP BY p.category
ORDER BY revenue DESC;



SELECT b.name AS branch_name, SUM(s.quantity_units) AS total_units
FROM fact_sales s
JOIN dim_branch b ON b.branch_key = s.branch_key
GROUP BY b.name
HAVING SUM(s.quantity_units) > 10000
ORDER BY total_units DESC;



SELECT p.product_code, p.product_name, COUNT(DISTINCT s.branch_key) AS branch_count
FROM fact_sales s
JOIN dim_product p ON p.product_key = s.product_key
GROUP BY p.product_code, p.product_name
HAVING COUNT(DISTINCT s.branch_key) < 5
ORDER BY branch_count;



SELECT product_code, name, unit_price
FROM dim_product
WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
ORDER BY unit_price DESC;



SELECT name, region
FROM dim_branch
WHERE branch_key IN (SELECT DISTINCT branch_key FROM fact_wastage)
ORDER BY name;



SELECT name, region
FROM dim_branch
WHERE branch_key NOT IN (SELECT branch_key FROM fact_wastage)
ORDER BY name;



SELECT p.product_code, p.product_name,
       (SELECT MAX(s.sold_on) FROM fact_sales s WHERE s.product_key = p.product_key) AS last_sold_on
FROM dim_product p
ORDER BY last_sold_on DESC NULLS LAST;



SELECT p.product_code, p.product_name
FROM dim_product p
WHERE NOT EXISTS (SELECT 1 FROM fact_sales s WHERE s.product_key = p.product_key);



SELECT b.region, DATE_TRUNC('month', s.sold_on)::date AS sales_month,
       SUM(s.quantity_units * s.unit_price) AS revenue
FROM fact_sales s
JOIN dim_branch b ON b.branch_key = s.branch_key
GROUP BY b.region, DATE_TRUNC('month', s.sold_on)
ORDER BY b.region, sales_month;



SELECT count_key, typed_branch_raw, typed_description_raw,
       COALESCE(product_key::text, 'UNRESOLVED') AS product_status
FROM fact_stock_count
WHERE resolution_confidence = 'escalated';



SELECT sc.count_key, sc.typed_description_raw, p.product_name AS resolved_product_name
FROM fact_stock_count sc
LEFT JOIN dim_product p ON p.product_key = sc.product_key
WHERE sc.resolution_confidence = 'escalated';



SELECT DISTINCT p.product_code
FROM fact_sales s JOIN dim_product p ON p.product_key = s.product_key
WHERE s.sold_on >= '2026-01-01'
UNION
SELECT DISTINCT p.product_code
FROM fact_delivery d JOIN dim_product p ON p.product_key = d.product_key
WHERE d.delivered_on >= '2026-01-01';



SELECT p.product_code, p.product_name
FROM dim_product p JOIN fact_sales s ON s.product_key = p.product_key
INTERSECT
SELECT p.product_code, p.product_name
FROM dim_product p JOIN fact_wastage w ON w.product_key = p.product_key;



SELECT p.product_code, p.product_name
FROM dim_product p JOIN fact_delivery d ON d.product_key = p.product_key
EXCEPT
SELECT p.product_code, p.product_name
FROM dim_product p JOIN fact_sales s ON s.product_key = p.product_key;



SELECT region, AVG(monthly_revenue) AS avg_branch_month_revenue
FROM (
    SELECT b.region, b.branch_key, DATE_TRUNC('month', s.sold_on) AS sales_month,
           SUM(s.quantity_units * s.unit_price) AS monthly_revenue
    FROM fact_sales s
    JOIN dim_branch b ON b.branch_key = s.branch_key
    GROUP BY b.region, b.branch_key, DATE_TRUNC('month', s.sold_on)
) branch_months
GROUP BY region
HAVING AVG(monthly_revenue) > 2000000
ORDER BY avg_branch_month_revenue DESC;



SELECT region, branch_name, revenue,
       RANK() OVER (PARTITION BY region ORDER BY revenue DESC) AS rank_in_region
FROM (
    SELECT b.region, b.name AS branch_name, SUM(s.quantity_units * s.unit_price) AS revenue
    FROM fact_sales s JOIN dim_branch b ON b.branch_key = s.branch_key
    GROUP BY b.region, b.name
) branch_revenue
ORDER BY region, rank_in_region;



SELECT b.name AS branch_name, COUNT(DISTINCT p.product_key) AS cheap_products_sold
FROM fact_sales s
JOIN dim_branch b ON b.branch_key = s.branch_key
JOIN dim_product p ON p.product_key = s.product_key
WHERE p.unit_price < (SELECT AVG(unit_price) FROM dim_product)
GROUP BY b.name
ORDER BY cheap_products_sold DESC;



       AVG(d.expiry - d.delivered_on) FILTER (WHERE d.expiry IS NOT NULL) AS avg_days_to_expiry
FROM fact_delivery d
JOIN dim_product p ON p.product_key = d.product_key
GROUP BY p.category
ORDER BY avg_days_to_expiry;



WITH branch_wastage AS (
    SELECT b.branch_key, b.name,
           SUM(w.quantity_units * p.unit_price) AS wastage_value
    FROM fact_wastage w
    JOIN dim_branch b ON b.branch_key = w.branch_key
    JOIN dim_product p ON p.product_key = w.product_key
    GROUP BY b.branch_key, b.name
),
branch_sales AS (
    SELECT b.branch_key, b.name,
           SUM(s.quantity_units * s.unit_price) AS revenue
    FROM fact_sales s
    JOIN dim_branch b ON b.branch_key = s.branch_key
    GROUP BY b.branch_key, b.name
),
top_wastage AS (
    SELECT branch_key FROM branch_wastage ORDER BY wastage_value DESC LIMIT 3
),
bottom_sales AS (
    SELECT branch_key FROM branch_sales ORDER BY revenue ASC LIMIT 3
)
SELECT bw.name, bw.wastage_value, bs.revenue
FROM branch_wastage bw
JOIN branch_sales bs ON bs.branch_key = bw.branch_key
WHERE bw.branch_key IN (SELECT branch_key FROM top_wastage)
  AND bw.branch_key IN (SELECT branch_key FROM bottom_sales);