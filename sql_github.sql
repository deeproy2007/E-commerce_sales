create database ecommerce;
use ecommerce;
-- Table: ecommercep
-- Columns:
-- Order_ID (INT)
-- Date (DATE)
-- Customer_ID (INT)
-- Total_Amount (DECIMAL)
-- Discount_Amount (DECIMAL)
-- Device_Type (VARCHAR)
-- City (VARCHAR)
-- Product_Category (VARCHAR)
-- Customer_Rating (INT)
-- Delivery_Time_Days (INT)
-- Payment_Method (VARCHAR)
-- Is_Returning_Customer (BOOLEAN)


-- Check negative or zero revenue
SELECT COUNT(*) 
FROM ecommercep
WHERE Total_Amount <= 0;
-- why this metric matters:(Ensures revenue calculations are reliable. Negative or zero order values usually indicate data errors, refunds, or failed transactions that can distort financial KPIs if not handled explicitly).

-- Check missing critical fields
SELECT COUNT(*) 
FROM ecommercep
WHERE Date IS NULL OR Customer_ID IS NULL;
-- why this metric matters:(Missing dates break time-series analysis and missing customer IDs prevent customer-level insights such as retention and lifetime value, making downstream analysis unreliable.).
-- MONTH-OVER-MONTH ANALYSIS
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(Date, '%Y-%m-01') AS month,
        SUM(Total_Amount) AS revenue
    FROM ecommercep
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) 
        / LAG(revenue) OVER (ORDER BY month) * 100, 2
    ) AS mom_growth_pct
FROM monthly_sales;
-- Why this metric matters:(Identifies revenue trends and detects early warning signs of business decline or growth. Month-over-month percentage change helps leadership distinguish between normal seasonality and structural performance issues.)

-- Business Problem: Are discounts actually increasing sales?

SELECT 
    CASE
        WHEN Discount_Amount > 0 THEN 'Discounted'
        ELSE 'no discount'
    END AS discount_flag,
    COUNT(Order_ID) AS Total_orders,
    ROUND(SUM(Total_Amount) / COUNT(Order_ID),2) AS revenue_per_order,
    SUM(Total_Amount) AS revenue,
    SUM(Discount_Amount) AS total_discount
FROM
    ecommercep
GROUP BY discount_flag;
-- Why this metric matters:(Evaluates whether discounts are driving higher order volume or merely reducing order value. This helps decide if discounts should be scaled, limited, or targeted to specific customer segments.)
-- Business Problem: Which cities drive the highest revenue?

SELECT 
    City, SUM(Total_Amount) AS revenue
FROM
    ecommercep
GROUP BY City
ORDER BY revenue DESC
LIMIT 10;
-- Why this metric matters:(Reveals geographic demand concentration. High-revenue cities are prime candidates for marketing investment, faster logistics, or localized promotions.)
-- Business Problem: Who are the high-value customers and top 25% customer?
WITH customer_value as(
SELECT
    Customer_ID,
    SUM(Total_Amount) AS lifetime_value
    FROM ecommercep
GROUP BY Customer_ID
)
SELECT Customer_ID,
      lifetime_value,
      ntile(4) over (order by lifetime_value desc) as value_segment
from customer_value;

-- Why this metric matters:(Identifies the most valuable customers contributing a disproportionate share of revenue. Segmenting customers enables targeted retention strategies and more efficient marketing spend.)
-- Business Problem: Does delivery time affect customer ratings?

SELECT 
    Delivery_Time_Days,
    count(*) as total_order,
    AVG(Customer_Rating) AS avg_rating,
    round(STDDEV(Customer_Rating),2)AS rating_variability
FROM
    ecommercep
GROUP BY Delivery_Time_Days
ORDER BY Delivery_Time_Days;
-- Why this metric matters:(Measures how operational performance impacts customer satisfaction. Longer delivery times with higher rating variability indicate inconsistent service quality that can harm repeat purchases.)
-- Business Problem:-- Which device type generates higher revenue and order volume?

SELECT 
    Payment_Method,
    SUM(Total_Amount) AS revenue,
    COUNT(Order_ID) AS total_orders
FROM
    ecommercep
GROUP BY Payment_Method
ORDER BY revenue DESC;
-- Why this metric matters:(Understanding payment preferences helps optimize checkout experience, reduce friction, and prioritize integrations with the most revenue-generating payment methods.)
-- . Business Problem: Are repeat customers contributing more revenue?
SELECT
    Is_Returning_Customer,
    COUNT(DISTINCT Customer_ID) AS customers,
    COUNT(Order_ID) AS total_orders,
    SUM(Total_Amount) AS revenue,
    ROUND(SUM(Total_Amount) / COUNT(DISTINCT Customer_ID),2) AS revenue_per_customer
FROM ecommercep
GROUP BY Is_Returning_Customer;
-- Why this metric matters:(Quantifies the value of customer retention. Repeat customers typically generate higher revenue per customer and are cheaper to retain than acquiring new users.)
-- Business Problem: Which device type converts better?
SELECT 
    Device_Type,
    SUM(Total_Amount) AS revenue,
    COUNT(Order_ID) AS total_orders
FROM
    ecommercep
GROUP BY Device_Type;
-- Why this metric matters:(Identifies which device types generate the most revenue and orders, helping optimize UI/UX investments and marketing strategies for the most profitable platforms.)
-- Business Problem: What KPIs should leadership track?

SELECT 
    SUM(Total_Amount) AS total_revenue,
    COUNT(DISTINCT Order_ID) AS total_orders,
    COUNT(DISTINCT Customer_ID) AS total_customers,
    AVG(Total_Amount) AS avg_order_value
FROM
    ecommercep;
    -- Why this metric matters:(Provides leadership with a high-level view of business health by summarizing revenue scale, customer base, order volume, and purchasing behavior in a single snapshot.)
-- Business problem: How is revenue accumulating over time?    
SELECT
    date,
    SUM(total_amount) AS daily_revenue,
    SUM(SUM(total_amount)) OVER (
        ORDER BY date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM ecommercep
GROUP BY date
ORDER BY date;
-- Why this metric matters:(Tracks how revenue builds over time and highlights periods of acceleration or slowdown. Useful for cash flow forecasting and performance monitoring.)
-- Business problem: Which categories perform best?
SELECT
    product_category,
    SUM(total_amount) AS revenue,
    RANK() OVER (ORDER BY SUM(total_amount) DESC) AS revenue_rank
FROM ecommercep
GROUP BY product_category;
-- Why this metric matters:(Identifies which categories drive the majority of revenue, enabling better inventory planning, merchandising focus, and category-level marketing decisions.)
-- Business problem: Which cities have slower deliveries?
SELECT 
     City,
     Delivery_Time_Days,
	 rank() over  
        (partition by City order by Delivery_Time_Days desc) as rnk
from ecommercep; 
-- Why this metric matters:(Highlights logistics bottlenecks at the city level. Cities with consistently slower deliveries are candidates for warehouse optimization or carrier performance review.)
-- outlier
SELECT
    MIN(Total_Amount),
    MAX(Total_Amount),
    AVG(Total_Amount)
FROM ecommercep;
-- Why this metric matters: