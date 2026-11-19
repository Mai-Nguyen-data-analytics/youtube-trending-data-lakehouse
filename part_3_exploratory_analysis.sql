------------------------------------------------------------
-- PART 3: EXPLORATORY DATA ANALYSIS
-- YouTube Trending Data Lakehouse Project | Snowflake & Azure
------------------------------------------------------------
------------------------------------------------------
-- Objectives:
-- In this part, we use the cleaned final table 
-- (table_youtube_final) to perform analytical queries. 
-- The aim is to answer specific questions about trending 
-- videos across different countries, categories, and time 
-- periods.
--
-- Key goals:
-- 1. Identify the most viewed videos in specific categories 
--    and dates (e.g., Gaming on 2024-04-01).
-- 2. Count distinct videos matching search terms 
--    (e.g., titles containing "BTS").
-- 3. Perform time-based analysis (year/month) to find 
--    the most viewed videos and calculate likes ratios.
-- 4. Compare category popularity by distinct video counts 
--    and calculate percentages across countries.
-- 5. Identify which channels produce the most distinct videos.
--
-- These results will be used to build insights into 
-- viewing patterns, category performance, and channel 
-- strategies across regions.
------------------------------------------------------
------------------------------------------------------




-- Part 3.0: Setup for Analysis
-- Ensure we are in the correct environment
------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE YOUTUBE_TRENDING_DB;
USE SCHEMA PUBLIC;

-- Confirm context (double-check before analysis)
SELECT 
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_DATABASE()  AS database,
    CURRENT_SCHEMA()    AS schema;

-- Quick sanity check: total rows in cleaned final tables
SELECT COUNT(*) AS trending_rows FROM table_youtube_trending; -- result: 2,667,041
SELECT COUNT(*) AS category_rows FROM table_youtube_category; -- result: 311
SELECT COUNT(*) AS final_rows    FROM table_youtube_final; -- result: 2,597,494



------------------------------------------------------
-- Part 3.1: Analysis 1 — Top 3 most viewed Gaming videos 
-- for each country on a chosen date
------------------------------------------------------
-----------------------------------------------------
-- Step 1: Define the date we want to analyze
WITH params AS (
    SELECT '2024-04-01'::DATE AS target_date
),

-- Step 2: Rank videos by view_count within each country
ranked AS (
    SELECT
        f.country,
        f.title,
        f.channelTitle,
        f.view_count,
        ROW_NUMBER() OVER (
            PARTITION BY f.country
            ORDER BY f.view_count DESC
        ) AS rk
    FROM table_youtube_final f, params p
    WHERE f.category_title ILIKE 'Gaming'
      AND CAST(f.trending_date AS DATE) = p.target_date
)

-- Step 3: Return top 3 per country
SELECT country, title, channelTitle, view_count, rk
FROM ranked
WHERE rk <= 3
ORDER BY country, rk;


------------------------------------------------------
-- Part 3.2: Analysis 2 — Distinct BTS videos by country
------------------------------------------------------
-- Objective:
-- Count how many distinct videos have titles containing 
-- the word 'BTS' (case insensitive). Group results by 
-- country and order by count descending.
------------------------------------------------------
SELECT
    country,
    COUNT(DISTINCT video_id) AS ct
FROM table_youtube_final
WHERE title ILIKE '%BTS%'   -- case-insensitive search
GROUP BY country
ORDER BY ct DESC;







------------------------------------------------------
-- Part 3.3: Analysis 3 — Most viewed video per country/month in 2024
------------------------------------------------------
-- Objective:
-- For each country, and each year_month in 2024,
-- find the most viewed video. Also calculate likes_ratio
-- (likes ÷ view_count × 100) truncated to 2 decimals.
-- Final output: country, year_month, title, channel, 
-- category, view_count, likes_ratio.
------------------------------------------------------

-- Step 1: Add and populate a clean DATE column
-- trending_date was originally stored as string (VARCHAR).
-- We add trending_date_dt (DATE) for easier analysis.
ALTER TABLE table_youtube_final 
ADD COLUMN trending_date_dt DATE;

UPDATE table_youtube_final
SET trending_date_dt = CAST(trending_date AS DATE);
---result: 2,597,494

-- Quick check
SELECT trending_date, trending_date_dt
FROM table_youtube_final
LIMIT 20;
------------------------------------------------------
-- Step 2: Explore 2024 data with year-month
-- Use DATE_TRUNC to get the year and month in one column.
------------------------------------------------------
SELECT 
    country,
    DATE_TRUNC('month', trending_date_dt) AS year_month,
    title,
    view_count,
    likes
FROM table_youtube_final
WHERE EXTRACT(YEAR FROM trending_date_dt) = 2024
LIMIT 20;
------------------------------------------------------
-- Step 3: Add likes_ratio calculation
-- likes_ratio = (likes ÷ view_count × 100), truncated to 2 decimals.
------------------------------------------------------
SELECT 
    country,
    DATE_TRUNC('month', trending_date_dt) AS year_month,
    title,
    view_count,
    TRUNC((likes / NULLIF(view_count,0)) * 100, 2) AS likes_ratio
FROM table_youtube_final
WHERE EXTRACT(YEAR FROM trending_date_dt) = 2024
LIMIT 20;
------------------------------------------------------
-- Step 4: Rank videos within each country and month
-- Use ROW_NUMBER to rank by view_count for each
-- (country, year_month). The top video will have rk = 1.
------------------------------------------------------
SELECT 
    country,
    DATE_TRUNC('month', trending_date_dt) AS year_month,
    title,
    view_count,
    TRUNC((likes / NULLIF(view_count,0)) * 100, 2) AS likes_ratio,
    ROW_NUMBER() OVER (
        PARTITION BY country, DATE_TRUNC('month', trending_date_dt)
        ORDER BY view_count DESC
    ) AS rk
FROM table_youtube_final
WHERE EXTRACT(YEAR FROM trending_date_dt) = 2024;
------------------------------------------------------
-- Step 5: Final analytical output
-- Keep only rk = 1 (the most viewed video) for each
-- country and month. Order by year_month then country.
------------------------------------------------------
WITH ranked AS (
    SELECT 
        country,
        DATE_TRUNC('month', trending_date_dt) AS year_month,
        title,
        channelTitle,
        category_title,
        view_count,
        TRUNC((likes / NULLIF(view_count,0)) * 100, 2) AS likes_ratio,
        ROW_NUMBER() OVER (
            PARTITION BY country, DATE_TRUNC('month', trending_date_dt)
            ORDER BY view_count DESC
        ) AS rk
    FROM table_youtube_final
    WHERE EXTRACT(YEAR FROM trending_date_dt) = 2024
)
SELECT 
    country,
    year_month,
    title,
    channelTitle,
    category_title,
    view_count,
    likes_ratio
FROM ranked
WHERE rk = 1
ORDER BY year_month, country;




------------------------------------------------------
-- Part 3.4 - Question 4 
-- For each country, which category_title has the most 
-- distinct videos in 2022, and what is its percentage 
-- (to 2 decimals) out of the total distinct videos 
-- of that country.
------------------------------------------------------
-- Step 1: Count distinct videos by country + category
WITH category_counts AS (
    SELECT 
        country,
        category_title,
        COUNT(DISTINCT video_id) AS total_category_video
    FROM table_youtube_final
    WHERE EXTRACT(YEAR FROM trending_date_dt) >= 2022
    GROUP BY country, category_title
),
-- Step 2: Count distinct videos by country (denominator)
country_totals AS (
    SELECT 
        country,
        COUNT(DISTINCT video_id) AS total_country_video
    FROM table_youtube_final
    WHERE EXTRACT(YEAR FROM trending_date_dt) >= 2022
    GROUP BY country
),
-- Step 3: Join and rank categories within each country
ranked AS (
    SELECT 
        c.country,
        c.category_title,
        c.total_category_video,
        t.total_country_video,
        CAST(CEIL((c.total_category_video / t.total_country_video) * 100 * 100) / 100 AS NUMBER(5,2)) AS percentage,
        ROW_NUMBER() OVER (
            PARTITION BY c.country 
            ORDER BY c.total_category_video DESC
        ) AS rk
    FROM category_counts c
    JOIN country_totals t
        ON c.country = t.country
)
-- Step 4: Select only the top category per country
SELECT 
    country,
    category_title,
    total_category_video,
    total_country_video,
    percentage
FROM ranked
WHERE rk = 1
ORDER BY category_title, country;


------------------------------------------------------
----Part 3.5 -  Question 5
-- Which channelTitle has produced the most distinct videos
-- and what is this number?
------------------------------------------------------
SELECT 
    channelTitle,
    COUNT(DISTINCT video_id) AS distinct_video_count
FROM table_youtube_final
GROUP BY channelTitle
ORDER BY distinct_video_count DESC
LIMIT 1;
--result: 2049
