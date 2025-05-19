-- Main business question: what demographic and geographic factors most
-- strongly correlate with high-risk opioid-related deaths in Connecticut, and 
-- how can public health outreach be optimized to reduce future deaths/accidents?

-- year-over-year % growth in total deaths
WITH growth AS (
    SELECT 
        year,
        COUNT(*) AS total_deaths,
        LAG(COUNT(*)) OVER (ORDER BY year) AS prev_year_deaths
    FROM 
        drug_deaths
    GROUP BY 
        year
)
SELECT 
    year,
    total_deaths,
    ROUND(100.0 * (total_deaths - prev_year_deaths) / prev_year_deaths, 2) AS pct_change
FROM 
    growth
WHERE 
    prev_year_deaths IS NOT NULL

-- Classify deaths as opioid vs non-opioid
SELECT
    year,
    COUNT(*) FILTER(WHERE any_opioid = 'Y') AS opioid_deaths,
    COUNT(*) FILTER(WHERE any_opioid IS DISTINCT FROM 'Y') AS non_opioid,
    COUNT(*) AS total
FROM
    drug_deaths
GROUP BY
    year
ORDER BY
    year

-- Running total of opioid deaths
SELECT
    year,
    COUNT(*) FILTER(WHERE any_opioid = 'Y') AS opioid_deaths,
    SUM(COUNT(*) FILTER(WHERE any_opioid = 'N')) OVER(ORDER BY year) AS running_total
FROM
    drug_deaths
GROUP BY
    year
ORDER BY
    year

-- Age buckets with death cause
WITH grouped AS (
  SELECT 
    age_group,
    COUNT(*) AS total_deaths,
    COUNT(*) FILTER (WHERE fentanyl = 'Y') AS fentanyl_involved,
    COUNT(*) FILTER (WHERE heroin = 'Y') AS heroin_involved
  FROM drug_deaths
  GROUP BY age_group
)
SELECT *,
       ROUND(100.0 * fentanyl_involved / total_deaths, 1) AS pct_fentanyl,
       ROUND(100.0 * heroin_involved / total_deaths, 1) AS pct_heroin
FROM grouped
WHERE age_group IS NOT NULL
ORDER BY age_group

-- Cities with higher than average death
SELECT 
    death_city, 
    COUNT(*) AS city_deaths
FROM 
    drug_deaths
WHERE 
    death_city IS NOT NULL
GROUP BY 
    death_city
HAVING 
    COUNT(*) > (
        SELECT 
            AVG(city_total)
        FROM (
            SELECT 
                COUNT(*) AS city_total
            FROM 
                drug_deaths
            WHERE 
                death_city IS NOT NULL
            GROUP BY 
                death_city
        ) AS avg_table
    )
ORDER BY city_deaths DESC


-- Deaths by weekday with % of total amount
WITH weekday_counts AS (
    SELECT 
        weekday, 
        COUNT(*) AS total_deaths
    FROM 
        drug_deaths
    GROUP BY 
        weekday
),
total AS (
    SELECT 
        SUM(total_deaths) AS grand_total 
    FROM 
        weekday_counts
)
SELECT 
    w.weekday, 
    w.total_deaths,
    ROUND(100.0 * w.total_deaths / t.grand_total, 2) AS pct_of_total
FROM 
    weekday_counts w, 
    total t
ORDER BY 
    w.total_deaths DESC

-- Gender-based risk flag
SELECT 
    sex,
    COUNT(*) AS total_deaths,
    COUNT(*) FILTER (WHERE any_opioid = 'Y') AS opioid_deaths,
    CASE 
        WHEN COUNT(*) FILTER (WHERE any_opioid = 'Y') * 1.0 / COUNT(*) > 0.6 THEN 'High Risk'
        ELSE 'Standard Risk'
    END AS risk_level
FROM 
    drug_deaths
WHERE
    sex NOT LIKE 'X'
GROUP BY
    sex

-- Top 5 counties in 2022 with most opioid deaths
SELECT
    residence_county,
    COUNT(*) AS total_deaths
FROM
    drug_deaths
WHERE
    any_opioid = 'Y' AND year = 2022
GROUP BY
    residence_county
ORDER BY
    total_deaths DESC
LIMIT 5

-- Most dangerous age groups in each year
WITH ranked_group AS (
    SELECT
        year,
        age_group,
        COUNT(*) AS group_deaths,
        RANK() OVER(PARTITION BY year ORDER BY COUNT(*) DESC) AS rank
    FROM
        drug_deaths
    WHERE
        age_group IS NOT NULL
    GROUP BY
        year,
        age_group
)
SELECT
    year,
    age_group,
    group_deaths
FROM
    ranked_group
WHERE
    rank = 1
ORDER BY
    year