-- Project Title: Supermarket Sales Performance & Customer Analytics 
-- Create a new database for this project
CREATE DATABASE IF NOT EXISTS supermarket_analysis;
USE supermarket_analysis;

-- Create table structure
CREATE TABLE sales (
    sales_id INT PRIMARY KEY,
    branch VARCHAR(10),
    city VARCHAR(50),
    customer_type ENUM('Member', 'Normal') NOT NULL,
    gender ENUM('Male', 'Female') NOT NULL,
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    unit_price DECIMAL(10, 2),
    quantity INT CHECK (quantity > 0),
    tax_amount DECIMAL(10, 2),
    total_price DECIMAL(10, 2),
    reward_points INT,
    transaction_date DATE,
    transaction_time TIME,
    payment_method VARCHAR(20)
);
-- DATA EXPLORATION & QUALITY CHECK
-- 1. Basic dataset overview
SELECT 'Dataset Overview' AS 'Section';
SELECT 
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT branch) AS number_of_branches,
    COUNT(DISTINCT city) AS number_of_cities,
    COUNT(DISTINCT product_category) AS product_categories,
    MIN(total_price) AS min_transaction,
    MAX(total_price) AS max_transaction,
    AVG(total_price) AS avg_transaction,
    SUM(total_price) AS total_revenue
FROM sales;

-- 2. Check data distribution by branch
SELECT 'Data Distribution by Branch' AS 'Section';
SELECT 
    branch,
    city,
    COUNT(*) AS transactions,
    COUNT(DISTINCT customer_type) AS customer_types,
    ROUND(AVG(total_price), 2) AS avg_transaction_value,
    ROUND(SUM(total_price), 2) AS total_revenue,
    ROUND(SUM(total_price) / SUM(SUM(total_price)) OVER() * 100, 2) AS revenue_percentage
FROM sales
GROUP BY branch, city
ORDER BY total_revenue DESC;

-- 3: ANSWERING KEY BUSINESS QUESTIONS
-- QUESTION 1: How are each of our three branches performing? Which is the star performer?
SELECT 'QUESTION 1: Branch Performance Analysis' AS 'Section';

WITH branch_metrics AS (
    SELECT 
        branch,
        city,
        COUNT(*) AS total_transactions,
        SUM(quantity) AS total_units_sold,
        ROUND(SUM(total_price), 2) AS total_revenue,
        ROUND(SUM(total_price - (unit_price * quantity)), 2) AS total_profit,
        ROUND(AVG(total_price), 2) AS avg_transaction_value,
        ROUND(SUM(reward_points), 0) AS total_reward_points
    FROM sales
     GROUP BY branch, city
),
branch_with_metrics AS (
    SELECT 
        *,
        ROUND((total_profit / total_revenue) * 100, 2) AS profit_margin_percentage,
        ROUND(total_revenue / SUM(total_revenue) OVER() * 100, 2) AS revenue_share_percentage,
        ROUND(total_profit / SUM(total_profit) OVER() * 100, 2) AS profit_share_percentage,
        ROUND(AVG(total_revenue) OVER(), 2) AS avg_revenue_across_branches,
        ROUND(AVG(total_profit) OVER(), 2) AS avg_profit_across_branches
    FROM branch_metrics
)
SELECT 
    branch,
    city,
    total_transactions,
    total_units_sold,
    CONCAT('$', FORMAT(total_revenue, 2)) AS total_revenue,
    CONCAT('$', FORMAT(total_profit, 2)) AS total_profit,
    profit_margin_percentage,
    CONCAT(revenue_share_percentage, '%') AS revenue_share,
    CONCAT(profit_share_percentage, '%') AS profit_share,
    CASE 
        WHEN total_profit > avg_profit_across_branches * 1.1 THEN ' STAR PERFORMER'
        WHEN total_profit < avg_profit_across_branches * 0.9 THEN ' NEEDS ATTENTION'
        ELSE ' MEETING EXPECTATIONS'
    END AS performance_status,
    CASE 
        WHEN total_profit = (SELECT MAX(total_profit) FROM branch_with_metrics) THEN ' TOP PERFORMER'
        WHEN total_profit = (SELECT MIN(total_profit) FROM branch_with_metrics) THEN ' NEEDS IMPROVEMENT'
        ELSE ''
    END AS ranking
FROM branch_with_metrics
ORDER BY total_profit DESC;

-- Detailed branch comparison
SELECT 'Detailed Branch Comparison' AS 'Section';
SELECT 
    branch,
    city,
    ROUND(AVG(quantity), 1) AS avg_items_per_transaction,
    ROUND(AVG(total_price), 2) AS avg_basket_size,
    ROUND(SUM(CASE WHEN customer_type = 'Member' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS member_percentage,
    ROUND(SUM(CASE WHEN gender = 'Female' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS female_percentage
FROM sales
GROUP BY branch, city
ORDER BY branch;

-- QUESTION 2: Is our 'Member' loyalty program actually working?
SELECT 'QUESTION 2: Loyalty Program Effectiveness' AS 'Section';

WITH customer_metrics AS (
    SELECT 
        customer_type,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT sales_id) AS unique_transactions,
        ROUND(AVG(total_price), 2) AS avg_transaction_value,
        ROUND(SUM(total_price), 2) AS total_spent,
        ROUND(SUM(total_price - (unit_price * quantity)), 2) AS total_profit_generated,
        ROUND(AVG(quantity), 1) AS avg_items_per_purchase,
        ROUND(SUM(reward_points), 0) AS total_reward_points_earned,
        ROUND(AVG(reward_points), 0) AS avg_reward_points_per_transaction
    FROM sales
    GROUP BY customer_type
),
customer_comparison AS (
    SELECT 
        *,
        ROUND(total_spent / SUM(total_spent) OVER() * 100, 2) AS revenue_percentage,
        ROUND(total_profit_generated / SUM(total_profit_generated) OVER() * 100, 2) AS profit_percentage,
        ROUND((total_profit_generated / total_spent) * 100, 2) AS profit_margin
    FROM customer_metrics
)
SELECT 
customer_type,
    transaction_count,
    CONCAT('$', FORMAT(avg_transaction_value, 2)) AS avg_transaction_value,
    CONCAT('$', FORMAT(total_spent, 2)) AS total_spent,
    CONCAT('$', FORMAT(total_profit_generated, 2)) AS total_profit_generated,
    profit_margin AS profit_margin_percentage,
    avg_items_per_purchase,
    revenue_percentage,
    profit_percentage,
    CASE 
        WHEN customer_type = 'Member' AND avg_transaction_value > (SELECT avg_transaction_value FROM customer_metrics WHERE customer_type = 'Normal') 
        THEN ' Members spend MORE per transaction'
        WHEN customer_type = 'Member' AND avg_transaction_value < (SELECT avg_transaction_value FROM customer_metrics WHERE customer_type = 'Normal')
        THEN ' Members spend LESS per transaction'
        ELSE 'Equal spending'
    END AS program_insight
FROM customer_comparison;

-- Calculate loyalty program lift
SELECT 'Loyalty Program Lift Analysis' AS 'Section';
SELECT 
    ROUND(
        (SELECT AVG(total_price) FROM sales WHERE customer_type = 'Member') /
        (SELECT AVG(total_price) FROM sales WHERE customer_type = 'Normal') * 100 - 100, 
    2) AS member_spending_lift_percentage,
    CASE 
        WHEN (SELECT AVG(total_price) FROM sales WHERE customer_type = 'Member') >
             (SELECT AVG(total_price) FROM sales WHERE customer_type = 'Normal')
        THEN ' Loyalty program is driving higher spending'
        ELSE ' Loyalty program needs improvement'
    END AS program_recommendation;

-- Customer type by branch
SELECT 'Member Distribution by Branch' AS 'Section';
SELECT 
    branch,
    city,
    SUM(CASE WHEN customer_type = 'Member' THEN 1 ELSE 0 END) AS member_transactions,
    SUM(CASE WHEN customer_type = 'Normal' THEN 1 ELSE 0 END) AS normal_transactions,
    ROUND(SUM(CASE WHEN customer_type = 'Member' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS member_percentage,
    ROUND(AVG(CASE WHEN customer_type = 'Member' THEN total_price END), 2) AS member_avg_spend,
    ROUND(AVG(CASE WHEN customer_type = 'Normal' THEN total_price END), 2) AS normal_avg_spend
FROM sales
GROUP BY branch, city
ORDER BY member_percentage DESC;

-- QUESTION 3: Which product categories are making us the most money?
SELECT 'QUESTION 3: Product Category Performance' AS 'Section';

WITH category_metrics AS (
    SELECT 
        product_category,
        COUNT(*) AS transaction_count,
        SUM(quantity) AS units_sold,
        ROUND(SUM(total_price), 2) AS total_revenue,
        ROUND(SUM(total_price - (unit_price * quantity)), 2) AS total_profit,
        ROUND(AVG(total_price), 2) AS avg_transaction_value,
        ROUND(AVG(quantity), 1) AS avg_quantity_per_transaction
    FROM sales
    GROUP BY product_category
),
category_with_metrics AS (
    SELECT 
        *,
        ROUND((total_profit / total_revenue) * 100, 2) AS profit_margin,
        ROUND(total_revenue / SUM(total_revenue) OVER() * 100, 2) AS revenue_share,
        ROUND(total_profit / SUM(total_profit) OVER() * 100, 2) AS profit_share,
        ROW_NUMBER() OVER (ORDER BY total_profit DESC) AS profit_rank,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM category_metrics
)
SELECT 
    product_category,
    transaction_count,
    units_sold,
    CONCAT('$', FORMAT(total_revenue, 2)) AS total_revenue,
    CONCAT('$', FORMAT(total_profit, 2)) AS total_profit,
    profit_margin AS profit_margin_percentage,
    CONCAT(revenue_share, '%') AS revenue_share,
    CONCAT(profit_share, '%') AS profit_share,
    CASE 
        WHEN profit_rank = 1 THEN ' HIGHEST PROFIT'
        WHEN profit_rank = 2 THEN ' SECOND HIGHEST'
        WHEN profit_rank = (SELECT MAX(profit_rank) FROM category_with_metrics) THEN ' LOWEST PROFIT'
        ELSE ''
    END AS profitability_status,
    CASE 
        WHEN profit_margin > 30 THEN '⭐ HIGH MARGIN'
        WHEN profit_margin BETWEEN 20 AND 30 THEN ' GOOD MARGIN'
        ELSE ' LOW MARGIN'
    END AS margin_category
FROM category_with_metrics
ORDER BY profit_rank;

-- Category performance by branch
SELECT 'Category Performance by Branch' AS 'Section';
SELECT 
    branch,
    city,
    product_category,
    COUNT(*) AS transactions,
    SUM(quantity) AS units_sold,
    ROUND(SUM(total_price), 2) AS revenue,
    ROUND(SUM(total_price - (unit_price * quantity)), 2) AS profit,
    ROUND(AVG(total_price), 2) AS avg_transaction_value
FROM sales
GROUP BY branch, city, product_category
ORDER BY branch, profit DESC;

-- QUESTION 4: What are the shopping trends between different genders?
SELECT 'QUESTION 4: Gender-Based Shopping Trends' AS 'Section';

WITH gender_metrics AS (
    SELECT 
        gender,
        product_category,
        COUNT(*) AS transactions,
        SUM(quantity) AS units_sold,
        ROUND(SUM(total_price), 2) AS total_revenue,
        ROUND(AVG(total_price), 2) AS avg_spend_per_transaction,
        ROUND(AVG(quantity), 1) AS avg_items_per_transaction
    FROM sales
    GROUP BY gender, product_category
),
gender_totals AS (
    SELECT 
        gender,
        SUM(total_revenue) AS gender_total_revenue,
        COUNT(DISTINCT product_category) AS categories_purchased
    FROM gender_metrics
    GROUP BY gender
)
SELECT 
    gm.gender,
    gm.product_category,
    gm.transactions,
    gm.units_sold,
    CONCAT('$', FORMAT(gm.total_revenue, 2)) AS revenue,
    CONCAT('$', FORMAT(gm.avg_spend_per_transaction, 2)) AS avg_spend,
    gm.avg_items_per_transaction,
    ROUND(gm.total_revenue / gt.gender_total_revenue * 100, 2) AS category_share_of_gender_spend,
    CASE 
        WHEN gm.total_revenue = (SELECT MAX(total_revenue) FROM gender_metrics gm2 WHERE gm2.gender = gm.gender) 
        THEN 'FAVORITE CATEGORY'
        ELSE ''
    END AS favorite_for_gender
FROM gender_metrics gm
JOIN gender_totals gt ON gm.gender = gt.gender
ORDER BY gm.gender, gm.total_revenue DESC;

-- Gender spending comparison by category
SELECT 'Gender Spending Comparison by Category' AS 'Section';
SELECT 
    product_category,
    ROUND(AVG(CASE WHEN gender = 'Male' THEN total_price END), 2) AS male_avg_spend,
    ROUND(AVG(CASE WHEN gender = 'Female' THEN total_price END), 2) AS female_avg_spend,
    ROUND(
        (AVG(CASE WHEN gender = 'Female' THEN total_price END) - 
         AVG(CASE WHEN gender = 'Male' THEN total_price END)) / 
        AVG(CASE WHEN gender = 'Male' THEN total_price END) * 100, 
    2) AS female_vs_male_percentage_diff,
    CASE 
        WHEN AVG(CASE WHEN gender = 'Female' THEN total_price END) > 
             AVG(CASE WHEN gender = 'Male' THEN total_price END) 
        THEN ' Women spend more'
        WHEN AVG(CASE WHEN gender = 'Female' THEN total_price END) < 
             AVG(CASE WHEN gender = 'Male' THEN total_price END)
        THEN ' Men spend more'
        ELSE 'Equal spending'
    END AS spending_pattern
FROM sales
GROUP BY product_category
ORDER BY ABS(female_vs_male_percentage_diff) DESC;

