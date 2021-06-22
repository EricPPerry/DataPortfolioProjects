/*
Exploration of daily logs for infection/death rates from Covid 19 across the world. 
Skills used in SQL (via Microsoft SQL Server Management): Basic/Advanced joins, Temp Tables, CTEs, aggregate functions, windows functions, changing/converting data types and creating views
*/

--General SELECT statement to make sure our table CovidDeaths was imported correctly
--Noting that there are instances where the continent is listed as the location/country, which can be filtered out by recognizing that those instances have continent = NULL
SELECT *
FROM Portfolio..CovidDeaths
WHERE continent is not null;


--Showing location, date, total_cases, new_cases, total_deaths and population, then ordering first by location (country) and then by date
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Portfolio..CovidDeaths
WHERE continent is not null
ORDER BY 1,2;

--Looking at total cases vs. total deaths in USA
--Shows mortality rate/chance of dying after contracting covid in specific country
SELECT location, date, total_cases, total_deaths, CONCAT(ROUND((total_deaths/total_cases)*100,2),'%') as mortality_rate
FROM Portfolio..CovidDeaths
WHERE location like '%states%'
ORDER BY 1,2;

--Looking at total cases vs population
SELECT location, date, total_cases, population, ROUND((total_cases/population)*100,2) as CasesPercentTotalPop
FROM Portfolio..CovidDeaths
WHERE iso_code like '%USA%'
ORDER BY 1,2;

--Looking at countries with highest infection rate compared to population
SELECT Location, Population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 as PercentPopulationInfected
FROM Portfolio..CovidDeaths
WHERE continent is not null
GROUP BY Location, Population
order BY PercentPopulationInfected desc;

--Showing countries with the highest death count per population, taking into account the data needing to be converted/cast to int
SELECT Location, MAX(cast(total_deaths as int)) as TotalDeathCount
FROM Portfolio..CovidDeaths
WHERE continent is not null
GROUP BY Location
ORDER BY TotalDeathCount desc;

--Looking at it from a contintent breakdown, seeing which continents have the highest death count per population
SELECT continent, max(cast(total_deaths as int)) as TotalDeathCount
FROM Portfolio..CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount desc;
--Shows that data is off, for instance North America seems to only consist of USAs numbers, as noted previously it looks like a correct way around this is to use the situations where location is listed a continent names instead of country names
SELECT location, max(cast(total_deaths as int)) as TotalDeathCount
FROM Portfolio..CovidDeaths
WHERE continent is null
GROUP BY location
ORDER BY TotalDeathCount desc;


--GLOBAL VIEW
--Tracking global daily new cases against total global cases by day
SELECT date, SUM(new_cases) as WorldwideNewCases,SUM(total_cases) as TotalWorldwideCases
FROM Portfolio..CovidDeaths
WHERE continent is not null
GROUP BY date
ORDER BY 1,2;

SELECT date, SUM(new_cases) as total_world_cases, SUM(cast(new_deaths as int)) as total_world_deaths, SUM(cast(new_deaths as int))/SUM(new_cases) * 100 as world_death_percentage
FROM Portfolio..CovidDeaths
WHERE continent is not null
GROUP BY date
order by 1,2;

--Checking global figures in total (not daily)
SELECT SUM(new_cases) as total_world_cases, SUM(cast(new_deaths as int)) as total_world_deaths, SUM(cast(new_deaths as int))/SUM(new_cases) * 100 as world_death_percentage
FROM Portfolio..CovidDeaths
WHERE continent is not null
order by 1,2;


--Working with CovidVaccinations table (table created out of tests/vaccination numbers)
SELECT * 
FROM Portfolio..CovidVaccinations;

--Joining two tables together, so we can work with death and vaccination rates together
SELECT *
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date;

--Looking at Total Population vs Vaccinated Population
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date
WHERE dea.continent is not null
ORDER BY 1,2;

--Creating our own total column, even though there is one already provided in table - showing off my SUM/Partition ability so that we can track the rolling/daily updated total vaccination numbers
--Adding additional ORDER BY logic to partition so that the new_vaccinations column shows current day numbers, while RollingVaccinationTotal column updates accordingly
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
SUM(Cast(vacc.new_vaccinations as int)) OVER (Partition by dea.Location ORDER BY dea.date) as RollingVaccinationTotal
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date
WHERE dea.continent is not null
ORDER BY 2,3;


--Utilizing a temporary table to show population vaccinated, on a rolling/daily update rate
DROP TABLE IF exists #PercentagePopulationVaccinated
CREATE TABLE #PercentagePopulationVaccinated(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingVaccinationTotal numeric
)
INSERT INTO #PercentagePopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
SUM(Cast(vacc.new_vaccinations as int)) OVER (Partition by dea.Location ORDER BY dea.date) as RollingVaccinationTotal
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date
WHERE dea.continent is not null


SELECT *, (RollingVaccinationTotal/Population)*100 AS PercentPopulationVaccinated
FROM #PercentagePopulationVaccinated
ORDER BY 2,3;



--Utilizing CTE to do the same
With PopvsVac (Continent, Location, Date, Population, new_vaccinations, RollingVaccinationTotal)
as(
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
SUM(Cast(vacc.new_vaccinations as int)) OVER (Partition by dea.Location ORDER BY dea.date) as RollingVaccinationTotal
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date
WHERE dea.continent is not null
)
SELECT *, (RollingVaccinationTotal/CAST(Population as FLOAT))*100 as PopulationVaccinated
FROM PopvsVac
ORDER BY 2,3;

--Creating any views I want to use for future use/when I transition to visualizations or Tableau
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vacc.new_vaccinations, 
SUM(Cast(vacc.new_vaccinations as int)) OVER (Partition by dea.Location ORDER BY dea.date) as RollingVaccinationTotal
FROM Portfolio..CovidDeaths dea
Join Portfolio..CovidVaccinations vacc
	On dea.location = vacc.location
	AND dea.date = vacc.date
WHERE dea.continent is not null

SELECT *
FROM PercentPopulationVaccinated




--STARTING to work on Tableau portion of project
--Due to using Tableau public, first ran queries, then transferred/copied over to excel for import into Tableau
--Fine tuned queries for visualization with Tableau

--Table 1 for Tableau
--Start with basic comparison of total deaths, total cases and % of deaths vs cases
--Keeping in mind to filter out where continent = NULL, as those entries have the continent under 'location', could produce duplicate data
Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From Portfolio..CovidDeaths
where continent is not null 
order by 1,2

--Table 2 for Tableau
--Breaking death count totals down by continent 

Select location, SUM(cast(new_deaths as int)) as TotalDeathCount
From Portfolio..CovidDeaths
Where continent is null 
--Taking these out as they are not inluded in the above queries and want to stay consistent
--Keeping in mind data set formatting, so 'Europe' is in 'European Union' 
and location not in ('World', 'European Union', 'International')
Group by location
order by TotalDeathCount desc


--Table 3 for Tableau
--Finding infection cases vs population rates by country, using highest/max figures instead of day-by-day
--CLEANED FURTHER in excel, as this produces NULL values, replaced NULL with 0 - for easier importing into Tableau
Select Location, Population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From Portfolio..CovidDeaths
Group by Location, Population
order by PercentPopulationInfected desc


--Table 4 for Tableau
--Similar to Table 3, but showing daily figures since start of pandemic via grouping
--Slight cleaning in excel via replacing NULL with 0, and also formatting dates for Tableau to be in MM/DD/YYYY format
Select Location, Population,date, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as PercentPopulationInfected
From Portfolio..CovidDeaths
Group by Location, Population, date
order by PercentPopulationInfected desc