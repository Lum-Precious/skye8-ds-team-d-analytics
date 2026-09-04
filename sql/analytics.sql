SELECT
    b.region,
    p.category,
    DATE_TRUNC('month', s.sold_on)::date AS sales_month,
    SUM(s.quantity_units)                AS units_sold,
    SUM(s.quantity_units * s.unit_price) AS revenue
FROM fact_sales s
JOIN dim_branch  b ON b.branch_key  = s.branch_key
JOIN dim_product p ON p.product_key = s.product_key
GROUP BY b.region, p.category, DATE_TRUNC('month', s.sold_on)
ORDER BY sales_month, b.region, p.category;



WITH delivered AS (
    SELECT branch_key, product_key, SUM(quantity_units) AS units_delivered
    FROM fact_delivery
    GROUP BY branch_key, product_key
),
sold AS (
    SELECT branch_key, product_key, SUM(quantity_units) AS units_sold
    FROM fact_sales
    GROUP BY branch_key, product_key
),
wasted AS (
    SELECT branch_key, product_key, SUM(quantity_units) AS units_wasted
    FROM fact_wastage
    GROUP BY branch_key, product_key
)
SELECT
    b.name AS branch_name,
    p.product_name,
    COALESCE(d.units_delivered, 0)                                            AS units_delivered,
    COALESCE(so.units_sold, 0)                                                AS units_sold,
    COALESCE(w.units_wasted, 0)                                               AS units_wasted,
    COALESCE(d.units_delivered, 0) - COALESCE(so.units_sold, 0) - COALESCE(w.units_wasted, 0)
                                                                               AS estimated_closing_stock
FROM dim_branch b
CROSS JOIN dim_product p
LEFT JOIN delivered d   ON d.branch_key = b.branch_key AND d.product_key = p.product_key
LEFT JOIN sold so       ON so.branch_key = b.branch_key AND so.product_key = p.product_key
LEFT JOIN wasted w      ON w.branch_key = b.branch_key AND w.product_key = p.product_key
ORDER BY branch_name, p.product_name;



WITH latest_count AS (
    SELECT DISTINCT ON (branch_key, product_key)
        branch_key, product_key, quantity_units, counted_on
    FROM fact_stock_count
    WHERE product_key IS NOT NULL   -- exclude escalated/unresolved rows
    ORDER BY branch_key, product_key, counted_on DESC
)
SELECT
    b.name AS branch_name,
    p.product_name,
    lc.quantity_units                          AS current_stock_units,
    p.reorder_level_packs * p.pack_size         AS reorder_level_units,
    lc.counted_on AS as_of
FROM latest_count lc
JOIN dim_branch  b ON b.branch_key  = lc.branch_key
JOIN dim_product p ON p.product_key = lc.product_key
WHERE lc.quantity_units < (p.reorder_level_packs * p.pack_size)
ORDER BY ((p.reorder_level_packs * p.pack_size) - lc.quantity_units) DESC;


 
WITH zero_counts AS (
    SELECT branch_key, product_key, counted_on
    FROM fact_stock_count
    WHERE product_key IS NOT NULL AND quantity_units = 0
)
SELECT
    b.name AS branch_name,
    COUNT(DISTINCT (zc.product_key, zc.counted_on)) AS stockout_instances
FROM zero_counts zc
JOIN dim_branch b ON b.branch_key = zc.branch_key
GROUP BY b.name
ORDER BY stockout_instances DESC;


-- 5. Wastage value by reason and branch.
SELECT
    b.name  AS branch_name,
    w.reason,
    SUM(w.quantity_units)                AS units_wasted,
    SUM(w.quantity_units * p.unit_price) AS wastage_value
FROM fact_wastage w
JOIN dim_branch  b ON b.branch_key  = w.branch_key
JOIN dim_product p ON p.product_key = w.product_key
GROUP BY b.name, w.reason
ORDER BY wastage_value DESC;



WITH monthly_revenue AS (
    SELECT
        b.branch_key,
        b.name AS branch_name,
        DATE_TRUNC('month', s.sold_on)::date AS sales_month,
        SUM(s.quantity_units * s.unit_price) AS revenue
    FROM fact_sales s
    JOIN dim_branch b ON b.branch_key = s.branch_key
    GROUP BY b.branch_key, b.name, DATE_TRUNC('month', s.sold_on)
)
SELECT
    branch_name,
    sales_month,
    revenue,
    LAG(revenue) OVER (PARTITION BY branch_key ORDER BY sales_month) AS prior_month_revenue,
    revenue - LAG(revenue) OVER (PARTITION BY branch_key ORDER BY sales_month) AS mom_change,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (PARTITION BY branch_key ORDER BY sales_month))
        / NULLIF(LAG(revenue) OVER (PARTITION BY branch_key ORDER BY sales_month), 0)
    , 1) AS mom_change_pct
FROM monthly_revenue
ORDER BY branch_name, sales_month;