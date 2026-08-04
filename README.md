# 🎬 Netflix Movies & TV Shows — SQL Data Analysis

## 📌 Project Overview

**Project Title**: Netflix Content Analysis
**Level**: Intermediate
**Database**: `netflix_db`

This is my practice SQL project analyzing the Netflix titles dataset (8,807 movies and TV shows). I explored, cleaned, and queried the data to answer real business questions about Netflix's content library — from content mix and ratings to top countries, genres, and cast trends — and turned each query result into a short, plain-language business insight.

## 🎯 Objectives

1. **Explore the dataset**: Understand its structure, size, and data quality.
2. **Clean the data**: Handle blank/missing values, multi-value columns, and inconsistent data types.
3. **Answer business questions**: Write SQL queries to uncover patterns in Netflix's catalog.
4. **Translate results into insight**: Turn raw query output into takeaways a non-technical stakeholder could use.

## 🗂️ Dataset & Schema

```sql
CREATE TABLE netflix_titles(
    show_id       VARCHAR(20),
    type          VARCHAR(15),
    title         VARCHAR(150),
    director      VARCHAR(250),
    casts         VARCHAR(1000),
    country       VARCHAR(150),
    date_added    VARCHAR(50),
    release_year  INT,
    rating        VARCHAR(15),
    duration      VARCHAR(15),
    listed_in     VARCHAR(100),
    description   VARCHAR(300)
);
```

## 🔍 Data Exploration & Cleaning

Before answering any business questions, I ran a first pass over the data to understand what I was working with:

| Check | Finding |
|---|---|
| Total rows | 8,807 |
| Distinct `type` values | 2 — `Movie`, `TV Show` |
| Duplicate `show_id` / `title` | None — every `show_id` and `title` is unique |
| Rows missing a `director` | 2,634 (stored as empty strings, not `NULL`) |
| Rows with at least one blank field (`director`, `country`, `rating`, or `duration`) | 3,060 |
| Column types | All `VARCHAR` except `release_year` (`INT`) |

**Key cleaning steps:**
- Treated blank strings (`''`) as missing data, since the source doesn't use true `NULL`s consistently.
- Converted `date_added` from text (e.g. `"September 24, 2021"`) into a proper `DATE` column with `TO_DATE()`, then altered the column type in place.
- Since `country`, `casts`, and `listed_in` can hold multiple comma-separated values in a single cell (e.g. `"United States, India"`), I used `STRING_TO_ARRAY()` + `UNNEST()` to split them into one row per value before aggregating — otherwise a combination like "United States, India" would be counted as its own unique group instead of contributing to each country separately.
- Converted `duration` (e.g. `"90 min"` or `"3 Seasons"`) into a numeric value with `SPLIT_PART()` + `CAST()` for sorting and filtering.

## 📊 Business Questions & Insights

Each question below shows the query I judged the cleanest/most efficient (where I had written more than one version), followed by the answer and what it means in plain terms.

### 1. How many movies vs. TV shows are on Netflix?
```sql
SELECT type, COUNT(*) AS num
FROM netflix_titles
GROUP BY type;
```
**Result**: Movie — 6,131 | TV Show — 2,676
**💡 Insight**: Movies make up ~70% of the catalog. Netflix's library skews heavily toward one-off films rather than ongoing series.

### 2. What's the most common rating for Movies and TV Shows?
```sql
SELECT type, rating
FROM (
    SELECT
        type,
        rating,
        COUNT(*),
        RANK() OVER (PARTITION BY type ORDER BY COUNT(*) DESC) AS ranking
    FROM netflix_titles
    GROUP BY type, rating
) AS t1
WHERE ranking = 1;
```
**Result**: `TV-MA` for both Movies and TV Shows
**💡 Insight**: Mature-audience content is the single largest rating bucket in both formats — Netflix's catalog leans adult, not family-first.

### 3. What are the top 5 countries by content volume?
```sql
SELECT
    TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country,
    COUNT(show_id) AS total_content
FROM netflix_titles
GROUP BY new_country
ORDER BY total_content DESC
LIMIT 5;
```
**Result**: United States (3,690) → India (1,046) → United Kingdom (806) → Canada (445) → France (393)
**💡 Insight**: The US alone accounts for roughly 3.5x the content of the next closest country, but India, the UK, Canada, and France form a clear second tier — showing where Netflix has invested most in local/licensed content.

### 4. What's the longest movie on Netflix?
```sql
SELECT *
FROM netflix_titles
WHERE type = 'Movie'
    AND duration IS NOT NULL
    AND duration != ''
ORDER BY CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER) DESC
LIMIT 1;
```
**Result**: *Black Mirror: Bandersnatch* — 312 minutes
**💡 Insight**: The longest "movie" isn't a traditional film at all — it's an interactive, choose-your-own-path title, which explains the outlier runtime.

### 5. How much content was added in the last 5 years?
```sql
SELECT *
FROM netflix_titles
WHERE date_added >= CURRENT_DATE - INTERVAL '5 years';
```
**Result**: 313 titles
**💡 Insight**: This number is relative to whenever the query is run, so it should be read as "titles added in a rolling 5-year window," not a fixed historical figure — worth flagging for anyone reusing this query later.

### 6. Which titles were directed by Rajiv Chilaka?
```sql
SELECT *
FROM netflix_titles
WHERE director ILIKE '%Rajiv Chilaka%';
```
**Result**: 22 titles
**💡 Insight**: Rajiv Chilaka (creator of the *Chhota Bheem* animated franchise) is one of the most prolific single directors in the dataset — a sign of how much Indian animated content Netflix has licensed.

### 7. Which TV shows have more than 5 seasons?
```sql
SELECT *
FROM netflix_titles
WHERE type = 'TV Show'
    AND duration ~ '^\d+'
    AND CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER) > 5;
```
**Result**: 99 shows
**💡 Insight**: Only about 4% of TV shows on Netflix run past 5 seasons — long-running series are the exception, not the norm, on the platform.

### 8. What are the top 5 genres by content count?
```sql
SELECT
    TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre,
    COUNT(show_id) AS num_of_content
FROM netflix_titles
GROUP BY genre
ORDER BY num_of_content DESC
LIMIT 5;
```
**Result**: International Movies (2,752) → Dramas (2,427) → Comedies (1,674) → International TV Shows (1,351) → Documentaries (869)
**💡 Insight**: "International" content appears twice in the top 5, underlining Netflix's global-content strategy rather than a US-centric one.

### 9. What's the average year US content was added to Netflix?
```sql
WITH countries AS (
    SELECT
        *,
        TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country,
        EXTRACT(YEAR FROM date_added) AS year_added_netflix
    FROM netflix_titles
)
SELECT new_country, ROUND(AVG(year_added_netflix), 2) AS avg_year_added
FROM countries
WHERE new_country = 'United States'
GROUP BY new_country;
```
**Result**: 2015.55
**💡 Insight**: On average, US content was added to the platform around mid-2015 — consistent with Netflix's major push into original and licensed content in the mid-2010s.

### 10. What percentage of US content was added each year? (Top 5 years)
```sql
WITH countries AS (
    SELECT
        *,
        TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country,
        EXTRACT(YEAR FROM date_added) AS year_added_netflix
    FROM netflix_titles
)
SELECT
    year_added_netflix,
    COUNT(*),
    ROUND(
        COUNT(*)::NUMERIC /
        (SELECT COUNT(*) FROM countries
         WHERE new_country = 'United States' AND year_added_netflix > 1900)::NUMERIC,
    2) * 100 AS pct_of_us_content
FROM countries
WHERE new_country = 'United States'
    AND year_added_netflix > 1900
GROUP BY year_added_netflix
ORDER BY pct_of_us_content DESC
LIMIT 5;
```
**Result**: 2019 (23%) → 2020 (22%) → 2021 (17%) → 2018 (16%) → 2017 (13%)
**💡 Insight**: Nearly 80% of all US content in the dataset was added between 2017 and 2021, with 2019–2020 as the peak years — the height of Netflix's US content expansion before growth leveled off.

### 11. Which movies are classified as documentaries?
```sql
SELECT *
FROM netflix_titles
WHERE type = 'Movie'
    AND listed_in ILIKE '%Documentaries%';
```
**Result**: 869 movies
**💡 Insight**: Documentaries make up roughly 14% of all movies on the platform — a meaningful, if secondary, content category alongside Dramas and Comedies.

### 12. How many movies has Salman Khan appeared in over the last 10 years?
```sql
SELECT *
FROM netflix_titles
WHERE type = 'Movie'
    AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10
    AND casts ILIKE '%Salman Khan%';
```
**Result**: 1 movie
**💡 Insight**: Despite being one of Bollywood's biggest stars, Salman Khan has very limited recent representation on Netflix — his catalog is likely concentrated on other platforms or in theatrical releases not licensed to Netflix.

### 13. Who are the top 10 actors by movie count in US-produced content?
```sql
SELECT
    TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actor,
    COUNT(show_id) AS num_of_movies_produced
FROM netflix_titles
WHERE country ILIKE '%United States%'
GROUP BY actor
ORDER BY num_of_movies_produced DESC
LIMIT 10;
```
**Result**: Samuel L. Jackson & Tara Strong (22 each) → Fred Tatasciore (21) → Adam Sandler (20) → James Franco & Nicolas Cage (19 each) → Seth Rogen & Morgan Freeman (18 each) → Molly Shannon (17) → Fred Armisen (16)
**💡 Insight**: Voice actors (Tara Strong, Fred Tatasciore) rank right alongside major live-action stars — a reminder of how much of Netflix's US catalog is animated content, which the raw ranking alone wouldn't make obvious.

### 14. How much content mentions "kill" or "violence" in its description?
```sql
WITH new_table AS (
    SELECT
        *,
        CASE
            WHEN show_id IN (
                SELECT show_id FROM netflix_titles
                WHERE description ILIKE '%kill%'
                   OR description ILIKE '%violence%'
            ) THEN 'Bad'
            ELSE 'Good'
        END AS category
    FROM netflix_titles
)
SELECT category, COUNT(show_id) AS num_of_content
FROM new_table
GROUP BY category;
```
**Result**: Good — 8,503 | Bad — 304
**💡 Insight**: Only about 3.5% of titles reference violent keywords in their description. This is a rough keyword-based content flag rather than a true content rating, but it suggests violent themes aren't heavily emphasized in how Netflix markets its catalog through synopses.

## 🧾 Conclusion & Key Takeaways

Pulling the individual findings together, a few themes stand out about Netflix's content library:

- **Movies dominate volume** (70% of titles), but the catalog is still heavily skewed toward mature (`TV-MA`) content in both formats.
- **The US is the anchor market** by a wide margin, but India, the UK, Canada, and France show Netflix's meaningful investment in international content — reinforced by "International Movies" and "International TV Shows" both landing in the top 5 genres.
- **Content growth was front-loaded in the late 2010s**: most US content was added between 2017–2021, peaking in 2019–2020, suggesting the platform's most aggressive content-acquisition years are behind it (at least within this dataset's window).
- **Long-running series are rare** — under 4% of TV shows exceed 5 seasons — while animated/voice talent quietly punches above its weight in the US cast rankings.
- **The dataset needs real cleaning before analysis**: blank strings instead of `NULL`s, comma-separated multi-value fields, and text-based durations/dates all had to be handled before any of the above queries would return correct results.

## 🛠️ How to Use

1. **Clone the repository** to your local machine.
2. **Set up the database**: run the `CREATE TABLE` statement and load the Netflix titles CSV into `netflix_titles`. [![Kaggle](https://shields.io)](https://www.kaggle.com/datasets/shivamb/netflix-shows)
3. **Run the queries**: execute the SQL in this README (or the accompanying `.sql` file) to reproduce the analysis.
4. **Explore further**: the cleaning steps (splitting multi-value columns, converting dates/durations) make this dataset a good base for additional questions of your own.

## 📎 About This Project

This project is based on a publicly available Netflix titles dataset. I wrote and ran all queries myself as a SQL practice exercise, then converted the raw results into business-style insights as part of my own data analysis learning.

— Gabriel
