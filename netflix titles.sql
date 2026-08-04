-- Netflix Project

DROP TABLE IF EXISTS netflix_titles;
CREATE TABLE netflix_titles(
							show_id	VARCHAR(20),
							type VARCHAR(15),
							title VARCHAR(150),
							director VARCHAR(250),
							casts VARCHAR (1000),
							country	VARCHAR(150),
							date_added VARCHAR(50),
							release_year INT,
							rating	VARCHAR(15),
							duration VARCHAR(15),	
							listed_in VARCHAR(100),
							description VARCHAR(300)
							);

SELECT * FROM netflix_titles;

SELECT
	COUNT(*) AS total_content
FROM netflix_titles;
-- total_content is 8807

SELECT
	DISTINCT type
FROM netflix_titles;
-- two types: movie and Tv shows

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT show_id) AS unique_show_ids,
    COUNT(DISTINCT title) AS unique_titles
FROM netflix_titles;
--The three are all 8807

-- check whether show_id is duplicated:
SELECT
    show_id,
    COUNT(*) AS occurrences
FROM netflix_titles
GROUP BY show_id
HAVING COUNT(*) > 1;
-- there is no duplicated value

-- Find all content without a director

SELECT * 
FROM netflix_titles
WHERE director IS NULL
	OR TRIM(director) = '';
-- There are 2634 rows/content without director, and the value in the cells are empty not null


--check whether the same title appears more than once:

SELECT 
	title,
	type,
	release_year,
	COUNT(*) AS occurences 
FROM netflix_titles
GROUP BY title, type, release_year
HAVING COUNT(*) > 1
ORDER BY occurences DESC;

-- there is no same title

--Inspect the schema and data types
SELECT 
	column_name,
	data_type
FROM information_schema.columns
WHERE table_schema = 'public'
	AND table_name = 'netflix_titles'
ORDER BY ordinal_position;
-- all are strings(varchar) besides release year, which is integer

SELECT *
FROM netflix_titles
WHERE director = ''
   OR country = ''
   OR rating = ''
   OR duration ='';
-- 3060 rows contain at least one of above

-- problems

-- 1 count the num of movies vs tv shows -- actually asking, each type

SELECT
	type,
	COUNT(*) AS num
FROM netflix_titles
GROUP BY type ;

-- Movie	6131
-- TV Show	2676

-- 2. Find the most common rating for Movies and TV Shows -- the rating that appears the most times

SELECT	
	type,
	rating
FROM
(
	SELECT
		type,
		rating,
		COUNT(*),
		RANK() OVER(PARTITION BY type ORDER BY COUNT(*) DESC) AS ranking
	FROM netflix_titles
	GROUP BY type, rating
	ORDER BY type, COUNT(*) DESC
) AS t1 
WHERE ranking = 1;
-- answer:
-- Movie	TV-MA
-- TV Show	TV-MA

-- 3. find the top 5 countries with most content on Netflix;

SELECT 
	country,
	COUNT(show_id)
FROM netflix_titles
GROUP BY country

-- From the result we can see a row with multiple countries, we need to separate them.

SELECT 
	UNNEST(STRING_TO_ARRAY(country,',')) AS new_country
FROM netflix_titles;

SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(country,','))) AS new_country,
	COUNT(show_id)
FROM netflix_titles
GROUP BY new_country
ORDER BY COUNT(show_id) DESC
LIMIT 5;
-- answer:
-- United States	3690
-- India	1046
-- United Kingdom	806
-- Canada	445
-- France	393

-- 4. Identify the longest movie 
-- the duration column is varchar, need to convert it into int

SELECT show_id, title, type, duration
FROM netflix_titles
WHERE type = 'Movie'
  AND (duration IS NULL OR duration = '' OR duration !~ '^\d+');

SELECT * 
FROM netflix_titles
WHERE type = 'Movie'
	AND duration IS NOT NULL 
	AND duration != ''
ORDER BY CAST(SPLIT_PART(duration,' ',1) AS INTEGER) DESC
LIMIT 1;

SELECT *
FROM netflix_titles
WHERE type = 'Movie'
	AND duration ~ '^\d+'
	AND CAST(SPLIT_PART(duration,' ', 1)AS INTEGER) = 
	(SELECT 
			MAX(CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER))
			FROM netflix_titles
			WHERE type = 'Movie'
			AND duration ~ '^\d+');
-- answer: s4254	Movie	Black Mirror: Bandersnatch		Fionn Whitehead, Will Poulter, Craig Parkinson, Alice Lowe, Asim Chaudhry	United States	2018-12-28	2018	TV-MA	312 min	Dramas, International Movies, Sci-Fi & Fantasy	In 1984, a young programmer begins to question reality as he adapts a dark fantasy novel into a video game. A mind-bending tale with multiple endings. which is 312 minutes

-- 5. find content added in the last five years
-- convert date from varchar to standard date
SELECT date_added
FROM netflix_titles
LIMIT 5;

SELECT 
	date_added,
	TO_DATE(TRIM(date_added), 'Month, DD, YYYY') AS converted_date
FROM netflix_titles
LIMIT 10;

ALTER TABLE netflix_titles
ALTER COLUMN date_added TYPE DATE 
USING TO_DATE(TRIM(date_added), 'Month, DD, YYYY');

SELECT *
FROM netflix_titles
WHERE date_added >= CURRENT_DATE - INTERVAL '5 years'
-- There are 313 contents added last 5 years

-- 6. Find all the movies/TV shows by director 'Rajiv Chilaka'
-- director can be more than one person, so

SELECT *
FROM netflix_titles
WHERE director ILIKE '%Rajiv Chilaka%'; -- ILIKE case insensitive, LIKE case sensitive

--appears in 22 movies/contents

-- 7. List all the TV shows more than 5 seasons

SELECT
	*
FROM netflix_titles
WHERE type = 'TV Show'
	AND duration ~ '^\d+'
	AND CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER) > 5
 -- there are 99 tv shows more than 5 seasons


-- 8. Count the number of content items in each genre, show top 5

SELECT
	TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre,
	COUNT(show_id) AS num_of_content
FROM netflix_titles
GROUP BY genre
ORDER BY num_of_content DESC
LIMIT 5;
--answer:
-- International Movies	2752
-- Dramas	2427
-- Comedies	1674
-- International TV Shows	1351
-- Documentaries	869

-- 9. Find the average year for content added in the United States On Netflix
-- we have release year column, but not for the year added on netflix, extract the year first.
WITH countries
AS
(SELECT
	*,
	TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country,
	EXTRACT(YEAR FROM date_added) AS year_added_netflix
FROM netflix_titles)
SELECT 
	new_country,
	ROUND(AVG(year_added_netflix),2) AS avg_released_year
FROM countries
WHERE new_country = 'United States'
GROUP BY new_country
-- answer: United States	2015.55
 
-- 10. Find each year and the percentage of total US content added to Netflix in that year
-- Return the top 5 years by percentage
WITH countries
AS 
(
	SELECT 
		*,
		TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS new_country,
		EXTRACT(YEAR FROM date_added) AS year_added_netflix
	FROM netflix_titles
)
SELECT 
	year_added_netflix,
	COUNT(*),
	ROUND(COUNT(*)::NUMERIC/
	(SELECT COUNT(*) 
	FROM countries 
	WHERE new_country = 'United States' AND year_added_netflix > 1900)::NUMERIC, 2)*100 AS year_avg_added
FROM countries
WHERE new_country = 'United States'
	AND year_added_netflix > 1900
GROUP BY year_added_netflix
ORDER BY year_avg_added DESC
LIMIT 5

-- answer: 
-- 2019	856	23.00
-- 2020	828	22.00
-- 2021	627	17.00
-- 2018	600	16.00
-- 2017	462	13.00


-- 11. List all movies that are documentaries

WITH new_listed_in 
AS 
(
	SELECT 
		*,
		TRIM(UNNEST(STRING_TO_ARRAY(listed_in,','))) AS genre 
	FROM netflix_titles
)	
SELECT 
	*
FROM new_listed_in
WHERE type = 'Movie'
	AND genre = 'Documentaries';
		
SELECT *
FROM netflix_titles
WHERE type = 'Movie'
	AND listed_in ILIKE '%Documentaries%'

-- there are 869 movies are listed in documentaries

-- 12. Find how many movies actor 'Salman Khan' appeared in last 10 years!

SELECT *
FROM netflix_titles 
WHERE 
	type = 'Movie'
	AND release_year > EXTRACT(YEAR FROM CURRENT_DATE) - 10
	AND casts ILIKE '%Salman Khan%';
-- only 1 


-- 13. Find the top 10 actors who have appeared in the highest number of movies produced in the United States.

SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actor,
	COUNT(show_id) AS num_of_movies_produced
FROM netflix_titles
WHERE country ILIKE '%United States%'
GROUP BY actor 
ORDER BY num_of_movies_produced DESC 
LIMIT 10;
-- answer:
-- Samuel L. Jackson	22
-- Tara Strong	22
-- Fred Tatasciore	21
-- Adam Sandler	20
-- James Franco	19
-- Nicolas Cage	19
-- Seth Rogen	18
-- Morgan Freeman	18
-- Molly Shannon	17
-- Fred Armisen	16



/* 15. Categorize the content based on the presence of the keywords 'kill' and 'violence' in the description field. Label content containing these keywords as 'Bad' and all other content as 'Good'. Count how many items fall into each category. */
WITH new_table 
AS
(
SELECT
	*,
	CASE 
		WHEN show_id IN (
						SELECT 
							show_id 
						FROM netflix_titles
						WHERE description ILIKE '%kill%'
							OR description ILIKE 'violence'
		) THEN 'Bad'
		ELSE 'Good'
	END AS category
FROM netflix_titles
 )
SELECT 
	category,
	COUNT(show_id) AS num_of_content
FROM new_table
GROUP BY category
-- answer
-- Good	8503
-- Bad	304

