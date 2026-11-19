# YouTube Trending Data Lakehouse \| Snowflake & Azure

An end-to-end data engineering and analytics project that integrates,
transforms, cleans and analyses YouTube trending video data across 10
countries using Microsoft Azure Blob Storage and Snowflake.

## Project Overview

This project explores global YouTube trending-video patterns by building
a cloud-based data lakehouse workflow.

Using video-level CSV data and category metadata stored in JSON files,
the pipeline ingests raw data from Azure Blob Storage into Snowflake,
applies SQL-based transformations and data quality checks, and produces
an integrated dataset for analytical exploration.

The final dataset enables comparisons of video popularity, audience
engagement and category trends across different countries and time
periods.

## Project Objectives

-   Build a cloud-based data ingestion pipeline using Azure Blob Storage
    and Snowflake.
-   Integrate structured CSV data and semi-structured JSON metadata.
-   Perform data cleaning, validation and deduplication using SQL.
-   Analyse video performance, engagement metrics and category
    popularity.
-   Generate data-driven insights to support content strategy decisions.

## Technology Stack

  Category              Technologies
  --------------------- ------------------------------------------
  Cloud Storage         Microsoft Azure Blob Storage
  Data Warehouse        Snowflake
  Query Language        SQL
  Data Formats          CSV, JSON
  Data Transformation   SQL, CTEs, Joins
  Data Quality          NULL handling, validation, deduplication
  Analytics             Aggregations, Window Functions, Ranking

## Data Engineering Workflow

### 1. Data Ingestion

-   Stored raw YouTube trending CSV files and category JSON metadata in
    Azure Blob Storage.
-   Configured Snowflake external stages to access cloud storage.
-   Created external tables to query raw CSV and JSON data.
-   Transformed raw data into structured Snowflake tables.
-   Combined video records with category metadata using country and
    category identifiers.

### 2. Data Cleaning and Transformation

Performed data quality checks and transformations to prepare the dataset
for analysis:

-   Identified duplicate category labels and missing category metadata.
-   Replaced missing category titles with the appropriate category
    information.
-   Removed invalid records containing incorrect video identifiers.
-   Applied `ROW_NUMBER()` to identify duplicate video records.
-   Retained the record with the highest view count for each video,
    country and trending date.
-   Validated the final dataset using SQL queries and row counts.

### 3. Exploratory Data Analysis

Used Snowflake SQL to investigate YouTube trending patterns:

-   **Gaming Performance:** Identified the three most-viewed Gaming
    videos in each country for a selected date.
-   **BTS Popularity:** Analysed distinct BTS-related videos across
    countries.
-   **Monthly Video Performance:** Identified the most-viewed video for
    each country and month in 2024, including likes-to-views ratios.
-   **Category Distribution:** Compared distinct video counts and
    category popularity across countries.
-   **Channel Performance:** Identified channels producing the highest
    number of distinct trending videos.

### 4. Business Analysis

Investigated which YouTube content categories offer potential
opportunities for a new channel, excluding Music and Entertainment.

Compared category popularity across individual countries and globally to
identify differences in audience preferences and content opportunities.

## Key Results

  Metric                              Result
  ------------------------------ -----------
  Countries analysed                      10
  Initial trending records         2,667,041
  Category metadata records              311
  Final records after cleaning     2,597,494
  Duplicate records removed           37,466

The analysis highlights differences in trending video categories and
audience engagement across international markets.

## Repository Structure

``` text
youtube-trending-data-lakehouse/
│
├── README.md
│
├── sql/
│   ├── part_1_data_ingestion.sql
│   ├── part_2_data_cleaning.sql
│   ├── Part_3_exploratory_analysis.sql
│   └── part_4_business_analysis.sql
│
└── results/
    ├── top_gaming_videos_by_country.csv
    └── monthly_top_videos_2024.csv
```

## Data Source

[YouTube Trending Video Dataset --
Kaggle](https://www.kaggle.com/datasets/rsrishav/youtube-trending-video-dataset)

The dataset contains daily trending video records and category metadata
across 10 countries.

## How to Run

The SQL scripts are designed for Snowflake.

1.  Download the source dataset from Kaggle.
2.  Upload the CSV and JSON files to your own Azure Blob Storage
    container.
3.  Configure an external stage in Snowflake using your Azure storage
    credentials.
4.  Update the placeholder storage configuration in `data_ingestion.sql` with
    your own settings.
5.  Execute the SQL scripts in sequence, from `data_ingestion.sql` to
    `business_analysis.sql`.
6.  Review the validation queries and analytical outputs.

**Security:** Never commit actual SAS tokens, passwords, private keys or
other credentials to GitHub. Use secure credential management practices.

## Skills Demonstrated

-   Cloud Data Engineering
-   Data Lakehouse Architecture
-   Microsoft Azure Blob Storage
-   Snowflake Data Warehousing
-   SQL Data Transformation
-   Data Cleaning and Quality Assurance
-   ETL / ELT Workflows
-   Exploratory Data Analysis
-   Analytical SQL and Business Insights

------------------------------------------------------------------------

*This project demonstrates an end-to-end approach to cloud-based data
integration, data quality management and analytical reporting using
Azure and Snowflake.*
