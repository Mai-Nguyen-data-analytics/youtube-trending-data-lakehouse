------------------------------------------------------------
-- PART 1: DATA INGESTION
-- YouTube Trending Data Lakehouse Project | Snowflake & Azure
------------------------------------------------------------

-- 1. Create database

CREATE DATABASE IF NOT EXISTS YOUTUBE_TRENDING_DB;

-- Use the database
USE DATABASE YOUTUBE_TRENDING_DB;

------------------------------------------------------------
-- 2. Create Stage (linking Azure storage to Snowflake)
------------------------------------------------------------

CREATE OR REPLACE STAGE stage_assignment_1
URL='azure://<your-storage-account>.blob.core.windows.net/<your-container>'
CREDENTIALS=(AZURE_SAS_TOKEN='<YOUR_AZURE_SAS_TOKEN>')
;

LIST @stage_assignment_1;

------------------------------------------------------------
-- 3. Create YouTube Trending Table (CSV)
------------------------------------------------------------
-- NOTES:
-- 1. First, we create an external table (ex_table_youtube_trending) 
--    that references the YouTube trending CSV files in Azure Blob 
--    Storage via the stage @stage_assignment_1.
-- 2. The external table only points to the files and does not 
--    store data inside Snowflake. Columns initially appear as 
--    VALUE:c1, VALUE:c2, etc.
-- 3. Next, we map these raw columns to meaningful names 
--    (video_id, title, publishedAt, channel_id, etc.) 
--    and cast them into the correct data types.
-- 4. Finally, we create a permanent table (table_youtube_trending) 
--    inside Snowflake using CREATE TABLE AS SELECT. This step 
--    copies the data into Snowflake’s optimized storage, making 
--    queries faster and enforcing the schema.
-- 5. The permanent table will be the cleaned base table for all 
--    further analysis and joins with the category dataset.
------------------------------------------------------------


--- 3.1 Create External Table for YouTube Trending
CREATE OR REPLACE EXTERNAL TABLE ex_table_youtube_trending
WITH LOCATION = @stage_assignment_1
FILE_FORMAT = (TYPE=CSV FIELD_OPTIONALLY_ENCLOSED_BY='"' SKIP_HEADER=1)
PATTERN = '(?i).*trending.*[.]csv';   -- (?i) makes it case-insensitive

-- 3.2 Verify Files Matched by the External Table
LIST @stage_assignment_1 PATTERN='(?i).*trending.*[.]csv';

-- Preview Raw External Data (columns appear as VALUE:c1, VALUE:c2, etc.)
SELECT *
FROM ex_table_youtube_trending
LIMIT 10;


-- 3.3 Map Raw Columns to Proper Schema
SELECT
    value:c1::string      AS video_id,
    value:c2::string      AS title,
    value:c3::timestamp   AS publishedat,
    value:c4::string      AS channel_id,
    value:c5::string      AS channel_title,
    value:c6::string      AS category_id,
    value:c7::date        AS trending_date,
    value:c8::number      AS view_count,
    value:c9::number      AS likes,
    value:c10::number     AS dislikes,
    value:c11::number     AS comment_count
FROM ex_table_youtube_trending
LIMIT 10;

SELECT COUNT(*) 
FROM ex_table_youtube_trending;


-- 3.4 Create Permanent Table tabel_youtube_trending in Snowflake
CREATE OR REPLACE TABLE table_youtube_trending AS
SELECT
    value:c1::string    AS video_id,
    value:c2::string    AS title,
    value:c3::string    AS publishedat,
    value:c4::string    AS channelid,
    value:c5::string    AS channeltitle,
    value:c6::string    AS categoryid,
    value:c7::string    AS trending_date,
    value:c8::int       AS view_count,
    value:c9::int       AS likes,
    value:c10::int      AS dislikes,
    value:c11::int      AS comment_count,

    -- Extract country code from filename (e.g. "US_videos.csv")
    SPLIT_PART(METADATA$FILENAME, '_', 1) AS country

FROM ex_table_youtube_trending;


-- 3.5 Validate the Permanent Table
-- Check sample rows
SELECT * 
FROM table_youtube_trending
LIMIT 10;

-- Count total rows (should be ~2.66M)
SELECT COUNT(*) 
FROM table_youtube_trending;

--Row count per source file (to verify all files loaded)
SELECT 
    METADATA$FILENAME AS file_name,
    COUNT(*) AS row_count
FROM ex_table_youtube_trending
GROUP BY file_name
ORDER BY file_name;

SELECT 
    COUNTRY,
    COUNT(*) AS total_rows
FROM TABLE_YOUTUBE_TRENDING
GROUP BY COUNTRY
ORDER BY total_rows DESC;

------------------------------------------------------------
-- Part 4. Create Table for YouTube Category Data (JSON)
------------------------------------------------------------
-- NOTES:
-- 1. Each JSON file contains an array under "items".
-- 2. We must use LATERAL FLATTEN to extract rows from that array.
-- 3. Key fields: id (category_id), snippet.title (category_title),
--    snippet.assignable (boolean).
-- 4. After extraction, save into permanent table.
------------------------------------------------------------

-- 4.1 Create External Table (raw JSON)
CREATE OR REPLACE EXTERNAL TABLE ex_table_youtube_category
WITH LOCATION = @stage_assignment_1
FILE_FORMAT = (TYPE=JSON)
PATTERN = '(?i).*category.*[.]json';

SELECT *
FROM ex_table_youtube_category
limit 5;

-- 4.2 Preview Files Found
LIST @stage_assignment_1 PATTERN='(?i).*category.*[.]json';


-- 4.3 Extract Categories (Flatten items array, include all fields)
SELECT
    f.value:id::string                     AS category_id,
    f.value:kind::string                   AS kind,
    f.value:etag::string                   AS etag,
    f.value:snippet.title::string          AS category_title,
    f.value:snippet.assignable::boolean    AS assignable,
    f.value:snippet.channelId::string      AS channel_id,
    METADATA$FILENAME                      AS source_file
FROM ex_table_youtube_category,
     LATERAL FLATTEN(input => value:items) f
LIMIT 10;

-- 4.4 Create Permanent Table for Categories (clean version)
CREATE OR REPLACE TABLE table_youtube_category AS
SELECT
    -- Country first (derived from filename)
    SPLIT_PART(METADATA$FILENAME, '_', 1) AS country,
    
    -- Category information
    f.value:id::string            AS categoryid,
    f.value:snippet.title::string AS category_title

FROM ex_table_youtube_category,
     LATERAL FLATTEN(input => value:items) f;

-- 4.5 Validate Permanent Table

-- Check sample rows
SELECT * 
FROM table_youtube_category
LIMIT 10;

-- Count categories per country
SELECT country, COUNT(*) 
FROM table_youtube_category
GROUP BY country
ORDER BY country;

-- Distinct categories overall
SELECT DISTINCT category_title
FROM table_youtube_category
ORDER BY category_title;




---------------------------------------------------
-- 5 Final Combined Table
---------------------------------------------------
-- Objective:
-- This step creates the final combined table
-- by joining trending videos (table_youtube_trending)
-- with category metadata (table_youtube_category)
-- on both category_id and country.
-- It also adds a unique ID column using UUID_STRING().
---------------------------------------------------

-- 5.1 Create Final Table
CREATE OR REPLACE TABLE table_youtube_final AS
SELECT
    -- Unique ID
    UUID_STRING()                         AS id,

    -- Video-level information
    t.video_id,
    t.title,
    t.publishedat,
    t.channelid,
    t.channeltitle,
    t.categoryid,
    c.category_title,
    t.trending_date,
    t.view_count,
    t.likes,
    t.dislikes,
    t.comment_count,
    t.country

FROM table_youtube_trending t
LEFT JOIN table_youtube_category c
    ON t.categoryid = c.categoryid
   AND t.country = c.country;

---------------------------------------------------
-- 5.2 Validation Checks

-- Total rows in final table
SELECT COUNT(*) FROM table_youtube_final;

-- Sample preview
SELECT * 
FROM table_youtube_final
LIMIT 20;

-- Distinct country codes
SELECT DISTINCT country
FROM table_youtube_final
ORDER BY country;

-- check null value
SELECT
    COUNT_IF(id IS NULL)              AS id_nulls,
    COUNT_IF(video_id IS NULL)        AS video_id_nulls,
    COUNT_IF(title IS NULL)           AS title_nulls,
    COUNT_IF(publishedat IS NULL)     AS publishedAt_nulls,
    COUNT_IF(channelid IS NULL)       AS channelId_nulls,
    COUNT_IF(channeltitle IS NULL)    AS channelTitle_nulls,
    COUNT_IF(categoryId IS NULL)      AS categoryId_nulls,
    COUNT_IF(category_title IS NULL)  AS category_title_nulls,
    COUNT_IF(trending_date IS NULL)   AS trending_date_nulls,
    COUNT_IF(view_count IS NULL)      AS view_count_nulls,
    COUNT_IF(likes IS NULL)           AS likes_nulls,
    COUNT_IF(dislikes IS NULL)        AS dislikes_nulls,
    COUNT_IF(comment_count IS NULL)   AS comment_count_nulls,
    COUNT_IF(country IS NULL)         AS country_nulls
FROM table_youtube_final;

SELECT DISTINCT t.categoryId, t.country
FROM table_youtube_final t
WHERE t.category_title IS NULL;

---------------------------------------------------
-- END OF PART 1
-- Validation and context setup before Part 2
---------------------------------------------------

-- Confirm we are in the right environment to move to part 2
SELECT CURRENT_WAREHOUSE() AS warehouse,
       CURRENT_DATABASE()  AS database,
       CURRENT_SCHEMA()    AS schema;

-- Count rows in final combined table
SELECT COUNT(*) AS total_rows
FROM table_youtube_final;

-- Preview sample rows
SELECT *
FROM table_youtube_final
LIMIT 10;
