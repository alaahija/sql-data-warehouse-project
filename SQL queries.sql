USE Datawarehouse;

--✅ 1. Customer Behavior 👥
--Customer Lifetime Value (CLV)

SELECT 
    dc.customer_key,
    dc.First_name + ' ' + dc.Last_name AS Customer_Name,
    dc.Country,
    SUM(fs.sales_amount) AS Lifetime_Value,
    COUNT(DISTINCT fs.order_number) AS Total_Orders,
    MIN(fs.order_date) AS First_Order,
    MAX(fs.order_date) AS Last_Order
FROM gold.fact_sales fs
JOIN gold.dim_customers dc ON fs.customer_key = dc.customer_key
GROUP BY dc.customer_key, dc.First_name, dc.Last_name, dc.Country
ORDER BY Lifetime_Value DESC;


--🧍‍♀️ 2. Retention vs Churn
--➕ Retained = made a purchase in multiple years
--➖ Churned = only purchased in one year

WITH CustomerYears AS (
    SELECT 
        customer_key,
        YEAR(order_date) AS Order_Year
    FROM gold.fact_sales
    GROUP BY customer_key, YEAR(order_date)
)

SELECT 
    customer_key,
    COUNT(DISTINCT Order_Year) AS Active_Years,
    CASE 
        WHEN COUNT(DISTINCT Order_Year) > 1 THEN 'Retained'
        ELSE 'Churned'
    END AS Status
FROM CustomerYears 
GROUP BY customer_key;

--♻️ 3. New vs Repeat Customers 🧠 A customer is new if their first purchase is within the last N months.

WITH FirstPurchase AS (
    SELECT 
        customer_key,
        MIN(order_date) AS First_Purchase
    FROM gold.fact_sales
    GROUP BY customer_key
)

SELECT 
    fs.customer_key,
    dc.First_name + ' ' + dc.Last_name AS Customer_Name,
    First_Purchase,
    CASE 
        WHEN DATEDIFF(MONTH, First_Purchase, MAX(fs.order_date)) = 0 THEN 'New Customer'
        ELSE 'Repeat Customer'
    END AS Customer_Type,
    COUNT(DISTINCT fs.order_number) AS Total_Orders,
    SUM(fs.sales_amount) AS Total_Revenue
FROM FirstPurchase fp
JOIN gold.fact_sales fs ON fp.customer_key = fs.customer_key
JOIN gold.dim_customers dc ON fs.customer_key = dc.customer_key
GROUP BY fs.customer_key, dc.First_name, dc.Last_name, First_Purchase;

--✅ 2. Product Performance 📦
--Best-Selling Products by Revenue

SELECT 
    dp.product_name,
    dp.Category,
    SUM(fs.sales_amount) AS Total_Revenue,
    SUM(fs.Quantity) AS Units_Sold
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON fs.product_key = dp.product_key
GROUP BY dp.product_name, dp.Category
ORDER BY Total_Revenue DESC;

--Product Category Performance

SELECT 
    dp.Category,
    dp.Subcategory,
    SUM(fs.sales_amount) AS Category_Revenue,
    COUNT(DISTINCT fs.order_number) AS Orders
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON fs.product_key = dp.product_key
GROUP BY dp.Category, dp.Subcategory
ORDER BY Category_Revenue DESC;


--✅ 3. Sales Trends 📈
 --Monthly Sales Trend

 SELECT 
    FORMAT(fs.order_date, 'yyyy-MM') AS Month,
    SUM(fs.sales_amount) AS Total_Sales
FROM gold.fact_sales fs
GROUP BY FORMAT(fs.order_date, 'yyyy-MM')
ORDER BY Month;

--Year-over-Year Growth

SELECT 
    YEAR(fs.order_date) AS Year,
    SUM(fs.sales_amount) AS Annual_Sales,
    LAG(SUM(fs.sales_amount)) OVER (ORDER BY YEAR(fs.order_date)) AS Previous_Year_Sales,
    (SUM(fs.sales_amount) - LAG(SUM(fs.sales_amount)) OVER (ORDER BY YEAR(fs.order_date))) * 100.0 
        / LAG(SUM(fs.sales_amount)) OVER (ORDER BY YEAR(fs.order_date)) AS YoY_Growth_Percentage
FROM gold.fact_sales fs
GROUP BY YEAR(fs.order_date)
ORDER BY Year;

--Customer Profitability Over Time with Product Category Trends

WITH CustomerSales AS (
    SELECT 
        fs.customer_key,
        fs.product_key,
        dp.Category,
        dp.Subcategory,
        dc.Country,
        FORMAT(fs.order_date, 'yyyy-MM') AS Order_Month,
        SUM(fs.sales_amount) AS Revenue,
        SUM(fs.Quantity * dp.Cost) AS Cost,
        SUM(fs.Quantity) AS Units_Sold
    FROM gold.fact_sales fs
    JOIN gold.dim_customers dc ON fs.customer_key = dc.customer_key
    JOIN gold.dim_products dp ON fs.product_key = dp.product_key
    GROUP BY 
        fs.customer_key, fs.product_key, dp.Category, dp.Subcategory, dc.Country, FORMAT(fs.order_date, 'yyyy-MM')
),

CustomerProfitability AS (
    SELECT 
        customer_key,
        Country,
        Order_Month,
        SUM(Revenue) AS Total_Revenue,
        SUM(Cost) AS Total_Cost,
        (SUM(Revenue) - SUM(Cost)) AS Profit,
        COUNT(DISTINCT product_key) AS Product_Variety
    FROM CustomerSales
    GROUP BY customer_key, Country, Order_Month
),

RankedCustomers AS (
    SELECT *,
        RANK() OVER (PARTITION BY Order_Month ORDER BY Profit DESC) AS Profit_Rank
    FROM CustomerProfitability
)

SELECT 
    rc.Order_Month,
    rc.customer_key,
    dc.First_name + ' ' + dc.Last_name AS Customer_Name,
    rc.Country,
    rc.Total_Revenue,
    rc.Total_Cost,
    rc.Profit,
    rc.Product_Variety,
    rc.Profit_Rank
FROM RankedCustomers rc
JOIN gold.dim_customers dc ON rc.customer_key = dc.customer_key
WHERE rc.Profit_Rank <= 5
ORDER BY rc.Order_Month, rc.Profit_Rank;

-- Category Trend, Profitability & Customer Segmentation

WITH SalesData AS (
    SELECT 
        dp.Category,
        dp.Subcategory,
        dc.marital_status,
        dc.Gender,
        FORMAT(fs.order_date, 'yyyy-MM') AS Order_Month,
        SUM(fs.sales_amount) AS Revenue,
        SUM(fs.Quantity * dp.Cost) AS Cost,
        SUM(fs.sales_amount) - SUM(fs.Quantity * dp.Cost) AS Profit,
        COUNT(DISTINCT fs.customer_key) AS Unique_Customers,
        COUNT(fs.order_number) AS Total_Orders
    FROM gold.fact_sales fs
    JOIN gold.dim_products dp ON fs.product_key = dp.product_key
    JOIN gold.dim_customers dc ON fs.customer_key = dc.customer_key
    GROUP BY 
        dp.Category, dp.Subcategory, dc.marital_status, dc.Gender, FORMAT(fs.order_date, 'yyyy-MM')
),

-- Monthly aggregates for each category + customer group

CategorySummary AS (
    SELECT 
        Category,
        Subcategory,
        marital_status,
        Gender,
        Order_Month,
        SUM(Revenue) AS Monthly_Revenue,
        SUM(Profit) AS Monthly_Profit,
        SUM(Unique_Customers) AS Total_Customers,
        SUM(Total_Orders) AS Orders
    FROM SalesData
    GROUP BY Category, Subcategory, marital_status, Gender, Order_Month
),

-- Trend analysis with window functions: previous month comparison

CategoryTrend AS (
    SELECT *,
        LAG(Monthly_Revenue) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month) AS Prev_Revenue,
        LAG(Monthly_Profit) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month) AS Prev_Profit,
        CASE 
            WHEN LAG(Monthly_Revenue) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month) IS NULL THEN NULL
            ELSE ROUND((Monthly_Revenue - LAG(Monthly_Revenue) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month)) 
                       * 100.0 / NULLIF(LAG(Monthly_Revenue) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month), 0), 2)
        END AS Revenue_Growth_Percentage,
        CASE 
            WHEN LAG(Monthly_Profit) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month) IS NULL THEN NULL
            ELSE ROUND((Monthly_Profit - LAG(Monthly_Profit) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month)) 
                       * 100.0 / NULLIF(LAG(Monthly_Profit) OVER (PARTITION BY Category, Subcategory, marital_status, Gender ORDER BY Order_Month), 0), 2)
        END AS Profit_Growth_Percentage
    FROM CategorySummary
)

--focus on last 3 months, highlight growth or decline

SELECT 
    Order_Month,
    Category,
    Subcategory,
    marital_status,
    Gender,
    Monthly_Revenue,
    Monthly_Profit,
    Revenue_Growth_Percentage,
    Profit_Growth_Percentage,
    Total_Customers,
    Orders,
    CASE 
        WHEN Revenue_Growth_Percentage > 20 THEN '🚀 Growing'
        WHEN Revenue_Growth_Percentage < -20 THEN '📉 Declining'
        ELSE '↔️ Stable'
    END AS Revenue_Trend,
    CASE 
        WHEN Profit_Growth_Percentage > 20 THEN '💰 High Profit Growth'
        WHEN Profit_Growth_Percentage < -20 THEN '⚠️ Profit Declining'
        ELSE '🟡 Flat'
    END AS Profitability_Trend
FROM CategoryTrend
WHERE Order_Month >= FORMAT(DATEADD(MONTH, -3, (SELECT MAX(order_date) FROM gold.fact_sales)), 'yyyy-MM')
ORDER BY Order_Month DESC, Monthly_Profit DESC;

--Segment-Centric Profitability by Product Category

WITH SegmentCategorySales AS (
    SELECT 
        dc.Gender,
        dc.Marital_status,
        dp.Category,
        dp.Subcategory,
        SUM(fs.sales_amount) AS Total_Revenue,
        SUM(fs.Quantity * dp.Cost) AS Total_Cost,
        SUM(fs.sales_amount - fs.Quantity * dp.Cost) AS Profit,
        COUNT(DISTINCT fs.customer_key) AS Unique_Customers,
        COUNT(fs.order_number) AS Total_Orders,
        AVG(fs.sales_amount) AS Avg_Order_Value
    FROM gold.fact_sales fs
    JOIN gold.dim_customers dc ON fs.customer_key = dc.customer_key
    JOIN gold.dim_products dp ON fs.product_key = dp.product_key
    GROUP BY 
        dc.Gender, dc.Marital_status, dp.Category, dp.Subcategory
),

RankedSegments AS (
    SELECT *,
        RANK() OVER (PARTITION BY Category ORDER BY Profit DESC) AS Profit_Rank
    FROM SegmentCategorySales
)

SELECT 
    Gender,
    Marital_status,
    Category,
    Subcategory,
    Total_Revenue,
    Total_Cost,
    Profit,
    Unique_Customers,
    Total_Orders,
    Avg_Order_Value,
    Profit_Rank
FROM RankedSegments
WHERE Profit_Rank <= 3  -- Top 3 segments per category
ORDER BY Category, Profit_Rank;
