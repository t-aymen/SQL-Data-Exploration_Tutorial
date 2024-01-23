-- ################## COVID DEATHS #################### --
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
	YEAR(date) AS year,
	AVG(CAST(total_cases AS bigint)) AS total_cases,
	AVG(CAST(total_deaths AS bigint)) AS total_deaths,
	ROUND(AVG(CAST(total_deaths AS float)) / AVG(CAST(total_cases AS float)) * 100, 2) as total_death_percentage
FROM covid_deaths
WHERE total_cases IS NOT NULL AND total_deaths IS NOT NULL
GROUP BY location, YEAR(date)
ORDER BY 1, 2

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
WHERE total_cases IS NOT NULL AND location = 'Germany'
ORDER BY 1, 2

SELECT
	location,
	YEAR(date) AS year,
	AVG(CAST(total_cases AS bigint)) AS total_cases,
	AVG(CAST(population AS bigint)) AS avg_population,
	ROUND(AVG(CAST(total_cases AS float)) / AVG(CAST(population AS float)) * 100, 2) as total_cases_percentage
FROM covid_deaths
WHERE total_cases IS NOT NULL
GROUP BY location, YEAR(date)
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
	SUM(CAST(V.new_vaccinations AS bigint)) AS total_vaccinations
	-- ROUND(SUM(CAST(V.new_vaccinations AS float)) / CAST(D.population AS bigint) * 100, 3) AS percentage_vaccination
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL
GROUP BY D.continent, D.location, YEAR(D.date), D.population
ORDER BY 1, 2, 3


-- USING CTE
WITH population_vs_vaccinations (continent, location, date, population, new_vaccinations, total_rolling_vaccinations)
AS (
SELECT
	D.continent,
	D.location, 
	D.date,
	D.population,
	V.new_vaccinations,
	SUM(CAST(V.new_vaccinations AS bigint)) OVER (PARTITION BY D.location ORDER BY D.location, D.date) AS total_rolling_vaccinations
	-- ROUND(total_rolling_vaccinations / CAST(D.population AS float) * 100, 3) AS vaccination_percentage
FROM covid_deaths AS D JOIN covid_vaccinations AS V
ON D.location = V.location AND D.date = V.date
WHERE D.continent IS NOT NULL
--ORDER BY 2, 3
)
SELECT
	*, 
	CASE
		WHEN total_rolling_vaccinations > population THEN 100.0
		ELSE ROUND(total_rolling_vaccinations / CAST(population AS float) * 100, 2)
	END AS percentage_vaccinations
FROM population_vs_vaccinations
WHERE location = 'Germany'

-- USING TEMP
DROP TABLE IF EXISTS #percent_population_vaccinated
CREATE TABLE #percent_population_vaccinated (
	continent nvarchar(255),
	location nvarchar(255),
	date datetime,
	population bigint,
	new_vaccinations bigint,
	total_rolling_vaccination bigint,
)

INSERT INTO #percent_population_vaccinated 
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
	*,
	ROUND(CAST(total_rolling_vaccination AS float) / population * 100, 3) AS vaccination_percentage
FROM #percent_population_vaccinated
WHERE new_vaccinations IS NOT NULL AND location = 'France' AND YEAR(date) = 2021

--> Over 100% could mean that more than 1 dosage is also counted.

-- VIEWS for visualizations
CREATE VIEW percent_population_vaccinated AS
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

CREATE VIEW cases_vs_population AS
SELECT
	location,
	date,
	total_cases,
	population,
	ROUND(CAST(total_cases AS float) / CAST(population AS float) * 100, 4) AS cases_percentage
FROM covid_deaths
WHERE continent IS NOT NULL

CREATE VIEW country_infection_rate AS
SELECT
	location,
	population,
	MAX(CAST(total_cases AS bigint)) AS highest_infection_count,
	ROUND(MAX(CAST(total_cases AS float) / CAST(population AS float) * 100), 2) AS population_infected_percentage
FROM covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, population

CREATE VIEW continent_covid_deaths AS -- MOST ACCURATE
SELECT
	location,
	MAX(CAST(total_deaths AS bigint)) AS highest_death_count
FROM covid_deaths
WHERE continent IS NULL AND location NOT IN ('World', 'European Union', 'High income', 'Upper middle income', 'Lower middle income', 'Low income') 
GROUP BY location

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