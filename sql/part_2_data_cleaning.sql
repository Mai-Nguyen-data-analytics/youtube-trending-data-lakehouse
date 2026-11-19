------------------------------------------------------------
-- PART 2: DATA QUALITY & CLEANING
-- YouTube Trending Data Lakehouse Project | Snowflake & Azure
------------------------------------------------------------
-- Objective:
-- This section cleans and validates the tables created 
-- earlier (trending, category, final). 
-- We check for duplicates, missing values, and fix them 
-- to prepare the dataset for analysis.
---------------------------------------------------
---------------------------------------------------
-- Part 2.0: Set Context
-- Ensure we are using the correct warehouse, database, and schema
---------------------------------------------------

USE WAREHOUSE COMPUTE_WH;
USE DATABASE YOUTUBE_TRENDING_DB;
USE SCHEMA PUBLIC;

-- Confirm current context (check where we are)
SELECT 
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_DATABASE()  AS database,
    CURRENT_SCHEMA()    AS schema;

    
   ---------------------------------------------------
-- Part 2.1: Analysis 1 — Duplicate category_title
---------------------------------------------------
-- Objective:
-- Find which category_title has duplicates if we 
-- ignore the category_id. 
-- The question requires us to return only a 
-- single row, even if multiple titles are duplicated.
---------------------------------------------------
-- Final analytical output
-- Return only one row (as the analysis requires).
SELECT 
    category_title,
    COUNT(*) AS total_rows
FROM table_youtube_category
GROUP BY category_title
HAVING COUNT(*) > 1
LIMIT 1; -- return only a single row

-- Check all duplicates category_title that appears more
-- than once, along with how many times it occurs.
SELECT 
    category_title,
    COUNT(*) AS total_rows
FROM table_youtube_category
GROUP BY category_title
HAVING COUNT(*) > 1
ORDER BY total_rows DESC;


---------------------------------------------------
-- Part 2.2: Analysis 2 — category_title in only one country
---------------------------------------------------
-- Objective:
-- List all category_title values that are present in 
-- exactly one country.
---------------------------------------------------
-- Final analytical output
SELECT 
    category_title,
    COUNT(DISTINCT country) AS num_countries
FROM table_youtube_category
GROUP BY category_title
HAVING COUNT(DISTINCT country) = 1
ORDER BY category_title;


---- check counts across all countries
SELECT 
    category_title,
    COUNT(DISTINCT country) AS num_countries
FROM table_youtube_category
GROUP BY category_title
ORDER BY num_countries ASC;


---------------------------------------------------
-- Part 2.3: Analysis 3 — Missing category_titles
---------------------------------------------------
-- Objective:
-- Find the category_id values in table_youtube_final 
-- where category_title is missing (NULL).
---------------------------------------------------
--Final analytical output
SELECT DISTINCT categoryid
FROM table_youtube_final
WHERE category_title IS NULL
ORDER BY categoryid;

---------------------------------------------------
--- Double check, how many null count category_title per categoryid
SELECT 
    categoryid,
    COUNT(*) AS null_count
FROM table_youtube_final
WHERE category_title IS NULL
GROUP BY categoryid
ORDER BY null_count DESC;


---------------------------------------------------
-- Part 2.4: Analysis 4 — Fix NULL category_title
---------------------------------------------------
-- Objective:
-- Replace NULL category_title in table_youtube_final
-- with the correct category_title for categoryId = 29
---------------------------------------------------
--- Step 1 - Lookup category_title for id = 29
SELECT DISTINCT 
    categoryid,
    category_title,
    country
FROM table_youtube_category
WHERE categoryid = '29';

-- Step 2: Update rows where category_title is NULL 
-- and categoryId = 29
UPDATE table_youtube_final
SET category_title = 'Nonprofits & Activism'
WHERE category_title IS NULL
  AND categoryId = 29;

-- Step 3: Validation - confirm no NULL remain
SELECT COUNT(*) AS null_after
FROM table_youtube_final
WHERE category_title IS NULL;

-- Optional: preview updated rows
SELECT video_id, categoryId, category_title, country
FROM table_youtube_final
WHERE categoryId = 29
LIMIT 10;

---------------------------------------------------
-- Part 2.5: Analysis 5 — Videos without channelTitle
---------------------------------------------------
-- Objective:
-- Find which videos in table_youtube_final do not have 
-- a channelTitle. Only return the title of the video.
---------------------------------------------------

-- Step 1: Validation - see full rows where channelTitle is NULL
SELECT *
FROM table_youtube_final
WHERE channelTitle IS NULL;

-- Step 2: Final analytical output - only return the video title
SELECT DISTINCT title
FROM table_youtube_final
WHERE channelTitle IS NULL;


---------------------------------------------------
-- Part 2.6: Analysis 6 — Remove invalid rows with video_id = '#NAME?'
--------------------------------------------------- 
--- step 1 checking the number of rows WHERE video_id = '#NAME?
SELECT 
    video_id,
    COUNT(*) AS count_video_id
FROM table_youtube_final
WHERE video_id = '#NAME?'
GROUP BY video_id;
---the results is 32081

-- Step 2: Delete invalid rows (video_id = '#NAME?')
DELETE FROM table_youtube_final
WHERE video_id = '#NAME?';

-- step 3 Validation: confirm none remain
SELECT COUNT(*) AS invalid_remaining
FROM table_youtube_final
WHERE video_id = '#NAME?';




------------------------------------------------------
-- Part 2.7: Question 7
-- Create a new table table_youtube_duplicates 
-- containing only the “bad” duplicates using ROW_NUMBER.
------------------------------------------------------

CREATE OR REPLACE TABLE table_youtube_duplicates AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY video_id, country, trending_date
               ORDER BY view_count DESC
           ) AS rn
    FROM table_youtube_final
)
WHERE rn > 1; 
-- these are the duplicates (not the top view_count)


-- Checking: preview sample duplicates
SELECT * 
FROM table_youtube_duplicates
ORDER BY rn DESC
LIMIT 10;

-- Checking: count total duplicates found
SELECT COUNT(*)
FROM table_youtube_duplicates;
-- Results: 37,466


------------------------------------------------------
-- Part 2.8 - Question 8
-- Delete the duplicates in table_youtube_final 
-- by referencing table_youtube_duplicates.
------------------------------------------------------

DELETE FROM table_youtube_final f
USING table_youtube_duplicates d
WHERE f.id = d.id;
-- Results: number of rows deleted = 37,466


------------------------------------------------------
-- Part 2.9 - Question 9
-- Validation: check row count of duplicates 
-- after cleanup in table_youtube_final.
------------------------------------------------------

SELECT COUNT(*) AS duplicates_remaining
FROM (
    SELECT video_id, country, trending_date, COUNT(*) AS cnt
    FROM table_youtube_final
    GROUP BY video_id, country, trending_date
    HAVING COUNT(*) > 1
);
--result: 0 (no duplicates remaining)

---Count the number of rows in “table_youtube_final“ and check that it is equal to 2,597,494 rows.
SELECT COUNT(*) AS number_of_rows
FROM table_youtube_final;
---result: 2,597,494


------------------------------------------------------
-- END OF PART 2: Final Checks Before Part 3
------------------------------------------------------

-- 1. Confirm current environment
SELECT 
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_DATABASE()  AS database,
    CURRENT_SCHEMA()    AS schema;

-- 2. Count rows in each important table
SELECT COUNT(*) AS trending_rows FROM table_youtube_trending; -- result: 2,667,041
SELECT COUNT(*) AS category_rows FROM table_youtube_category; -- result: 311
SELECT COUNT(*) AS final_rows    FROM table_youtube_final; -- result: 2,597,494

-- 3. Quick preview of final cleaned table
SELECT *
FROM table_youtube_final
LIMIT 10;

-- 4. Optional: check distinct countries and categories 
-- to ensure values look consistent before analysis
SELECT DISTINCT country 
FROM table_youtube_final
ORDER BY country;

SELECT DISTINCT category_title 
FROM table_youtube_final
ORDER BY category_title;
