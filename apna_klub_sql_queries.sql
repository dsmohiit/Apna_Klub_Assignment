-- CREATING TABLE
DROP TABLE IF EXISTS apna_klub;
CREATE TABLE apna_klub(
	user_id VARCHAR(15),
	order_date DATE,
	order_id VARCHAR(15),
	sku_id VARCHAR(15),
	warehouse_name VARCHAR(50),
	quantity INT,
	placed_gmv FLOAT
);

SELECT * 
FROM apna_klub;


-- User Order Analysis: Analyzing the order patterns of users by 
-- calculating the total number of orders, average order value, and total placed_gmv per 'user'. 
-- Identifying the top 10 'users' by total placed_gmv.
SELECT user_id, 
	   SUM(quantity) AS "total_order", 
	   ROUND(CAST(SUM(placed_gmv) AS numeric), 2) AS "total_placed_gmv",
	   ROUND(CAST(AVG(placed_gmv) AS numeric), 2) AS "avg_order_value"
FROM apna_klub 
GROUP BY user_id
ORDER BY total_placed_gmv DESC LIMIT 10;

-- Product Performance: Analyze the performance of individual products 'sku_id' by
-- calculating the total quantity sold, total placed_gmv, and average placed_gmv per 'sku_id'. 
-- Identify the top 10 best-selling products.
SELECT sku_id, 
	   SUM(quantity) AS "total_quantity_sold",
	   ROUND(CAST(SUM(placed_gmv) AS numeric), 2) AS "total_placed_gmv",
	   ROUND(CAST(AVG(placed_gmv) AS numeric), 2) AS "avg_order_value"
	   
FROM apna_klub
GROUP BY sku_id
ORDER BY total_placed_gmv DESC LIMIT 10;

-- Order Trends over Time: Analyze the order trends over time. 
-- Calculate the total number of orders, total placed_gmv, and average order value per month or quarter. 
-- Identify any seasonal patterns or trends.
SELECT EXTRACT(YEAR FROM order_date) AS "year",
	   EXTRACT(QUARTER FROM order_date) AS "quarter",
	   SUM(quantity) AS "total_order",
	   ROUND(CAST(SUM(placed_gmv) AS numeric), 2) AS "total_placed_gmv",
	   ROUND(CAST(AVG(placed_gmv) AS numeric), 2) AS "avg_order_value"
FROM apna_klub
GROUP BY year, quarter
ORDER BY total_placed_gmv DESC;

-- Warehouse Performance: Analyze the performance of different warehouses. 
-- Calculate the total placed_gmv, total quantity sold, and average order value per warehouse. 
-- Identify the top-performing warehouses.
SELECT warehouse_name,
	   SUM(quantity) AS "total_order",
	   ROUND(CAST(SUM(placed_gmv) AS numeric), 2) AS "total_placed_gmv",
	   ROUND(CAST(AVG(placed_gmv) AS numeric), 2) AS "avg_order_value"
FROM apna_klub
GROUP BY warehouse_name
ORDER BY total_placed_gmv DESC;

-- User Segmentation: Cluster users based on their order behavior.
-- Identify distinct user segments.
CREATE TABLE user_behaviour AS 
(SELECT user_id, 
CASE 
	WHEN COUNT(quantity) > 2 THEN 'repeat_customer'
	ELSE 'new_customer'
END AS "customer_type"
FROM apna_klub
GROUP BY user_id);

-- Product Cannibalization: Identify any potential product cannibalization by 
-- analyzing the correlation between sales of similar sku_ids.

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,
        sku_id,
        SUM(quantity) AS total_quantity,
        SUM(placed_gmv) AS total_gmv
    FROM
        apna_klub
    GROUP BY
        DATE_TRUNC('month', order_date),
        sku_id
),
product_pairs AS (
    SELECT
        a.sku_id AS sku_id1,
        b.sku_id AS sku_id2,
        CORR(a.total_quantity, b.total_quantity) AS quantity_correlation,
        CORR(a.total_gmv, b.total_gmv) AS gmv_correlation
    FROM
        monthly_sales a
    JOIN
        monthly_sales b ON a.month = b.month AND a.sku_id < b.sku_id
    GROUP BY
        a.sku_id,
        b.sku_id
    HAVING
        COUNT(*) >= 6  -- Require at least 6 months of data for correlation
)
SELECT
    sku_id1,
    sku_id2,
    ROUND(quantity_correlation::numeric, 2) AS quantity_correlation,
    ROUND(gmv_correlation::numeric, 2) AS gmv_correlation,
    CASE
        WHEN quantity_correlation < -0.5 OR gmv_correlation < -0.5 THEN 'Strong Negative (Potential Cannibalization)'
        WHEN quantity_correlation BETWEEN -0.5 AND -0.3 OR gmv_correlation BETWEEN -0.5 AND -0.3 THEN 'Moderate Negative'
        WHEN quantity_correlation BETWEEN -0.3 AND 0 OR gmv_correlation BETWEEN -0.3 AND 0 THEN 'Weak Negative'
        WHEN quantity_correlation BETWEEN 0 AND 0.3 OR gmv_correlation BETWEEN 0 AND 0.3 THEN 'Weak Positive'
        WHEN quantity_correlation BETWEEN 0.3 AND 0.5 OR gmv_correlation BETWEEN 0.3 AND 0.5 THEN 'Moderate Positive'
        ELSE 'Strong Positive'
    END AS correlation_interpretation
FROM
    product_pairs
WHERE
    quantity_correlation < -0.3 OR gmv_correlation < -0.3
ORDER BY
    LEAST(quantity_correlation, gmv_correlation) ASC
LIMIT 20;

























































