------------------------------------------------------
------------------------------------------------------
-- PART 4: BUSINESS INSIGHTS
-- YouTube Trending Data Lakehouse Project | Snowflake & Azure
------------------------------------------------------
-- BUSINESS INSIGHTS:
-- If you were to start a new YouTube channel, which category 
-- (excluding Music and Entertainment) should you choose, 
-- and would this strategy work in every country?
--
-- Objective:
-- 1. Exclude "Music" and "Entertainment" categories.
-- 2. Count distinct trending videos for each category by country.
-- 3. Rank categories within each country to find the most popular.
-- 4. Compare across countries to see if the same category dominates globally.
------------------------------------------------------
-- Part 4.0: Setup for Analysis
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
--------------------------------------------------



--------------------------------------------------
-- Part 1: top category per country
--------------------------------------------------
-- Step 1: Filter out Music & Entertainment
-- We only keep distinct video_id per country and category
WITH vids AS (
  SELECT DISTINCT 
         country,
         category_title,
         video_id
  FROM table_youtube_final
  WHERE category_title NOT IN ('Music','Entertainment')
),
-- Step 2: Count distinct videos for each category within each country
country_cat AS (
  SELECT 
      country,
      category_title,
      COUNT(video_id) AS distinct_videos
  FROM vids
  GROUP BY country, category_title
),

-- Step 3: Rank categories within each country
ranked AS (
  SELECT 
      country,
      category_title,
      distinct_videos,
      ROW_NUMBER() OVER (
          PARTITION BY country 
          ORDER BY distinct_videos DESC
      ) AS rk
  FROM country_cat
)

-- Step 4: Select top category per country (rk = 1)
SELECT 
    country,
    category_title AS top_category,
    distinct_videos
FROM ranked
WHERE rk = 1
ORDER BY country;


------------------------------------------------------
-- Part 2: Global Top Category (all countries combined)
------------------------------------------------------

SELECT 
    category_title,
    COUNT(DISTINCT video_id) AS total_distinct_videos
FROM table_youtube_final
WHERE category_title NOT IN ('Music','Entertainment')
GROUP BY category_title
ORDER BY total_distinct_videos DESC
LIMIT 5;
