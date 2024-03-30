-- ################## COVID DEATHS #################### --
SELECT
	*
FROM covid_deaths

-- Select data to be used
SELECT
	location,
	date,
	total_cases,
	new_cases,
	total_deaths,
	population
FROM covid_deaths
ORDER BY 1, 2;

-- Total Cases VS Total Deaths
SELECT
	location,
	date,
	total_cases,
	total_deaths,
	CASE
		WHEN CAST(total_cases AS float) < CAST(total_deaths AS float) THEN 0
		ELSE ROUND(CAST(total_deaths AS float) / CAST(total_cases AS float) * 100, 2)
	END AS deaths_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY 2 DESC

-- Total Cases VS Population
SELECT
	location,
	date,
	total_cases,
	population,
	ROUND(CAST(total_cases AS float) / CAST(population AS float) * 100, 2) AS cases_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- Countries with highest infection rate per population
SELECT
	location,
	population,
	MAX(CAST(total_cases AS bigint)) AS highest_infection_count,
	ROUND(MAX(CAST(total_cases AS float) / CAST(population AS float) * 100), 2) AS population_infected_percentage
FROM covid_deaths
WHERE total_cases IS NOT NULL AND continent IS NOT NULL
GROUP BY location, population
ORDER BY 4 DESC

-- Countries with highest covid deathrate
SELECT
	location,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE total_deaths IS NOT NULL AND continent IS NOT NULL
GROUP BY location
ORDER BY 2 DESC

-- Continent with highest covid deathrate
SELECT
	continent,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY 2 DESC

-- Continent with highest covid deathrate MOST ACCURATE
SELECT
	location,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE continent IS NULL AND location NOT IN ('World', 'European Union', 'High income', 'Upper middle income', 'Lower middle income', 'Low income') 
GROUP BY location
ORDER BY 2 DESC

SELECT
	*
FROM covid_deaths
WHERE location = 'European Union'

-- Covid deathrate by social class
SELECT
	location,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE location = 'High income' OR location = 'Upper middle income' OR location = 'Lower middle income' OR location = 'Low income'
GROUP BY location
ORDER BY 2 DESC

-- Global yearly death percentage by country
SELECT
	location AS country,
	YEAR(date) AS year,
	SUM(CAST(new_cases AS bigint)) AS total_cases, 
	SUM(CAST(new_deaths AS bigint)) AS total_deaths,
	ROUND(SUM(CAST(NULLIF(new_deaths, 0) AS float)) / SUM(CAST(NULLIF(new_cases, 0) AS float)) * 100, 3) AS death_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, YEAR(date)
ORDER BY 1, 2
	
-- ################## COVID VACCINATION #################### --
-- Select data to be used
SELECT
	*
FROM covid_vaccinations AS V JOIN covid_deaths AS D
ON V.location = D.location AND V.date = D.date
WHERE D.continent IS NOT NULL

-- Population VS Vaccination
SELECT
	D.continent,
	D.location, 
	YEAR(D.date) AS year,
	D.population,
	SUM(CAST(V.new_vaccinations AS bigint)) AS total_vaccinations,
	ROUND(SUM(CAST(V.new_vaccinations AS float)) / CAST(D.population AS bigint) * 100, 3) AS percentage_vaccination
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL
GROUP BY D.continent, D.location, YEAR(D.date), D.population
ORDER BY 1, 2, 3

-- USING CTE
WITH population_vs_vaccinations(continent, location, date, population, new_vaccinations, total_rolling_vaccinations)
AS (
SELECT
	D.continent,
	D.location, 
	D.date,
	D.population,
	V.new_vaccinations,
	SUM(CAST(V.new_vaccinations AS bigint)) OVER (PARTITION BY D.location ORDER BY D.location, D.date) AS total_rolling_vaccinations
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL
)
SELECT
	*, 
	CASE
		WHEN total_rolling_vaccinations > population THEN 100 -- Accounting for more than 1 vaccination shot
		ELSE ROUND(total_rolling_vaccinations / CAST(population AS float) * 100, 2)
	END AS percentage_vaccinations
FROM population_vs_vaccinations

-- USING TEMP
DROP TABLE IF EXISTS #rolling_vaccinations
CREATE TABLE #rolling_vaccinations (
	continent nvarchar(255),
	location nvarchar(255),
	date datetime,
	population bigint,
	new_vaccinations bigint,
	total_rolling_vaccination bigint,
)

INSERT INTO #rolling_vaccinations
SELECT
	D.continent,
	D.location, 
	D.date,
	D.population,
	V.new_vaccinations,
	SUM(CAST(V.new_vaccinations AS bigint)) OVER (PARTITION BY D.location ORDER BY D.location, D.date) AS total_rolling_vaccination
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL

SELECT
	*,
	ROUND(CAST(total_rolling_vaccination AS float) / population * 100, 3) AS vaccination_percentage
FROM #rolling_vaccinations

--> Over 100% could mean that more than 1 vaccination shot is also counted.

-- VIEWS for visualizations
CREATE VIEW rolling_vaccinations AS
SELECT
	D.continent,
	D.location, 
	D.date,
	D.population,
	V.new_vaccinations,
	SUM(CAST(V.new_vaccinations AS bigint)) OVER (PARTITION BY D.location ORDER BY D.location, D.date) AS total_rolling_vaccinations
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL

SELECT
	*
FROM rolling_vaccinations

CREATE VIEW annual_covid_mortality AS
SELECT
	location AS country,
	YEAR(date) AS year,
	SUM(CAST(new_cases AS bigint)) AS total_cases, 
	SUM(CAST(new_deaths AS bigint)) AS total_deaths,
	ROUND(SUM(CAST(NULLIF(new_deaths, 0) AS float)) / SUM(CAST(NULLIF(new_cases, 0) AS float)) * 100, 3) AS death_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, YEAR(date)

SELECT 
	*
FROM annual_covid_mortality

CREATE VIEW cases_vs_population AS
SELECT
	location,
	date,
	total_cases,
	population,
	ROUND(CAST(total_cases AS float) / CAST(population AS float) * 100, 4) AS cases_percentage
FROM covid_deaths
WHERE continent IS NOT NULL

SELECT
	*
FROM cases_vs_population

CREATE VIEW country_infection_rate AS
SELECT
	location,
	population,
	MAX(CAST(total_cases AS bigint)) AS highest_infection_count,
	ROUND(MAX(CAST(total_cases AS float) / CAST(population AS float) * 100), 2) AS population_infected_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, population

SELECT
	*
FROM country_infection_rate

CREATE VIEW continent_covid_deaths AS -- MOST ACCURATE
SELECT
	location,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE continent IS NULL AND location NOT IN ('World', 'European Union', 'High income', 'Upper middle income', 'Lower middle income', 'Low income') 
GROUP BY location

SELECT
	*
FROM continent_covid_deaths

CREATE VIEW cases_vs_deaths AS
SELECT
	location,
	date,
	total_cases,
	total_deaths,
	CASE
		WHEN CAST(total_cases AS float) < CAST(total_deaths AS float) THEN 0
		ELSE ROUND(CAST(total_deaths AS float) / CAST(total_cases AS float) * 100, 2)
	END AS deaths_percentage
FROM covid_deaths
WHERE continent IS NOT NULL

SELECT
	*
FROM cases_vs_deaths

-- Issues with the country field
-- Continents included as locations whenever NULL
-- Social classes also included as locations
SELECT
	DISTINCT location
FROM covid_deaths
WHERE continent IS NOT NULL
ORDER BY location DESC

SELECT
	*
FROM covid_deaths
WHERE continent IS NULL

-- 