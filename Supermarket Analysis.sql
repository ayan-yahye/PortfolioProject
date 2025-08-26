-- Project Title: Supermarket Sales Performance & Customer Analytics 
-- Create a new database for this project
CREATE DATABASE supermarket_analysis;

USE supermarket_analysis;

-- Create a table structure that matches the CSV file
CREATE TABLE sales (
    sales_id INT PRIMARY KEY, -- The unique ID for each sale
    branch VARCHAR(10),
    city VARCHAR(50),
    customer_type VARCHAR(10),
    gender VARCHAR(10),
    product_name VARCHAR(100),
    product_category VARCHAR(50),
    unit_price DECIMAL(10, 2), -- e.g., 10.50
    quantity INT,
    tax_amount DECIMAL(10, 2),
    total_price DECIMAL(10, 2),
    reward_points INT
);

SELECT *
FROM sales;

-- Question 1:
-- How are each of our three branches (cities) performing? Which one is the star performer
-- and which one might need help?
SELECT
    branch,
    city,
    SUM(quantity) as Total_Units_Sold,
    SUM(total_price) as Total_Revenue,
    SUM(total_price - (unit_price * quantity)) as Total_Profit,
    (SUM(total_price - (unit_price * quantity)) / SUM(total_price)) * 100 as Profit_Margin
FROM sales
GROUP BY branch, city
ORDER BY Total_Revenue DESC;

-- Question 2:
-- Is our 'Member' loyalty program actually working? 
-- Are member customers more valuable to our business than normal customers?
SELECT
    customer_type,
    COUNT(sales_id) as Number_of_Transactions,
    AVG(total_price) as Average_Transaction_Value,
    SUM(total_price - (unit_price * quantity)) as Total_Profit
FROM sales
GROUP BY customer_type;

-- Questin 3:
-- Which product categories are making us the most money? Should we promote some more than others?
SELECT
    product_category,
    SUM(total_price - (unit_price * quantity)) as Total_Profit,
    (SUM(total_price - (unit_price * quantity)) / SUM(total_price)) * 100 as Profit_Margin
FROM sales
GROUP BY product_category
ORDER BY Total_Profit DESC;

-- Question 4:
-- "What are the shopping trends between different genders? 
SELECT
    gender,
    product_category,
    SUM(quantity) as Total_Units_Sold,
    SUM(total_price) as Total_Revenue
FROM sales
GROUP BY gender, product_category
ORDER BY Total_Revenue DESC;