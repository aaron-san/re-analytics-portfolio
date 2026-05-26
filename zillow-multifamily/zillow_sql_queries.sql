-- ============================================================
-- Zillow Multifamily Rent Intelligence — SQL Query Suite
-- Database: zillow_multifamily.db (SQLite)
-- Tables: rent_index, home_value_index
-- ============================================================


-- ============================================================
-- QUERY 1: Year-over-Year Rent Growth by Metro (2023 vs 2024)
-- Skills demonstrated: CTEs, self-join, calculated fields, ranking
-- ============================================================
WITH rent_by_year AS (
    SELECT
        RegionName,
        StateName,
        year,
        ROUND(AVG(rent_index), 2) AS avg_rent
    FROM rent_index
    WHERE RegionType = 'msa'
      AND year IN (2023, 2024)
    GROUP BY RegionName, StateName, year
),
pivoted AS (
    SELECT
        r2024.RegionName,
        r2024.StateName,
        r2023.avg_rent AS rent_2023,
        r2024.avg_rent AS rent_2024,
        ROUND((r2024.avg_rent - r2023.avg_rent) / r2023.avg_rent * 100, 2) AS yoy_pct_change
    FROM rent_by_year r2024
    JOIN rent_by_year r2023
        ON r2024.RegionName = r2023.RegionName
        AND r2024.year = 2024
        AND r2023.year = 2023
)
SELECT
    RegionName,
    StateName,
    rent_2023,
    rent_2024,
    yoy_pct_change,
    RANK() OVER (ORDER BY yoy_pct_change DESC) AS growth_rank
FROM pivoted
ORDER BY yoy_pct_change DESC
LIMIT 20;


-- ============================================================
-- QUERY 2: Top Markets by Cumulative Rent Growth (2019–2024)
-- Skills demonstrated: multi-year window, percent change, filtering
-- ============================================================
WITH anchor AS (
    SELECT RegionName, StateName,
           ROUND(AVG(rent_index), 2) AS rent_2019
    FROM rent_index
    WHERE year = 2019 AND RegionType = 'msa'
    GROUP BY RegionName, StateName
),
recent AS (
    SELECT RegionName,
           ROUND(AVG(rent_index), 2) AS rent_2024
    FROM rent_index
    WHERE year = 2024 AND RegionType = 'msa'
    GROUP BY RegionName
)
SELECT
    a.RegionName,
    a.StateName,
    a.rent_2019,
    r.rent_2024,
    ROUND((r.rent_2024 - a.rent_2019) / a.rent_2019 * 100, 1) AS cumulative_growth_pct
FROM anchor a
JOIN recent r ON a.RegionName = r.RegionName
ORDER BY cumulative_growth_pct DESC
LIMIT 20;


-- ============================================================
-- QUERY 3: Price-to-Rent Ratio by Metro (Latest Available Month)
-- Skills demonstrated: join across tables, derived metric, business insight
-- Note: PTR = Home Value / (Annual Rent). >20 = rent-favorable market
-- ============================================================
WITH latest_rent AS (
    SELECT RegionName, StateName,
           ROUND(AVG(rent_index), 2) AS monthly_rent
    FROM rent_index
    WHERE date >= '2024-07-01' AND date <= '2024-12-31'
      AND RegionType = 'msa'
    GROUP BY RegionName, StateName
),
latest_hv AS (
    SELECT RegionName,
           ROUND(AVG(home_value), 0) AS home_value
    FROM home_value_index
    WHERE date >= '2024-07-01' AND date <= '2024-12-31'
      AND RegionType = 'msa'
    GROUP BY RegionName
)
SELECT
    r.RegionName,
    r.StateName,
    r.monthly_rent,
    h.home_value,
    ROUND(h.home_value / (r.monthly_rent * 12), 1) AS price_to_rent_ratio,
    CASE
        WHEN h.home_value / (r.monthly_rent * 12) > 25 THEN 'Strong Buy Signal (Rent)'
        WHEN h.home_value / (r.monthly_rent * 12) BETWEEN 16 AND 25 THEN 'Neutral'
        ELSE 'Own-Favorable'
    END AS market_signal
FROM latest_rent r
JOIN latest_hv h ON r.RegionName = h.RegionName
ORDER BY price_to_rent_ratio DESC
LIMIT 25;


-- ============================================================
-- QUERY 4: Rent Momentum — 3-Month Rolling Average vs Spot
-- Skills demonstrated: window functions, lag, trend detection
-- ============================================================
WITH monthly_avg AS (
    SELECT
        RegionName,
        StateName,
        date,
        year,
        month,
        ROUND(AVG(rent_index), 2) AS rent
    FROM rent_index
    WHERE RegionType = 'msa'
      AND year >= 2023
    GROUP BY RegionName, StateName, date, year, month
),
with_rolling AS (
    SELECT *,
           ROUND(AVG(rent) OVER (
               PARTITION BY RegionName
               ORDER BY date
               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
           ), 2) AS rolling_3mo_avg,
           LAG(rent, 3) OVER (PARTITION BY RegionName ORDER BY date) AS rent_3mo_ago
    FROM monthly_avg
)
SELECT
    RegionName,
    StateName,
    date,
    rent,
    rolling_3mo_avg,
    rent_3mo_ago,
    ROUND((rent - rent_3mo_ago) / rent_3mo_ago * 100, 2) AS qoq_change_pct
FROM with_rolling
WHERE date = (SELECT MAX(date) FROM rent_index)
  AND rent_3mo_ago IS NOT NULL
ORDER BY qoq_change_pct DESC
LIMIT 20;


-- ============================================================
-- QUERY 5: Sun Belt vs. Gateway City Rent Comparison
-- Skills demonstrated: CASE bucketing, group aggregation, business narrative
-- ============================================================
WITH classified AS (
    SELECT
        RegionName,
        StateName,
        year,
        ROUND(AVG(rent_index), 2) AS avg_rent,
        CASE
            WHEN RegionName IN ('Austin, TX', 'Dallas, TX', 'Houston, TX',
                                'Phoenix, AZ', 'Nashville, TN', 'Charlotte, NC',
                                'Atlanta, GA', 'Tampa, FL', 'Miami, FL', 'Orlando, FL')
                THEN 'Sun Belt'
            WHEN RegionName IN ('New York, NY', 'Los Angeles, CA', 'San Francisco, CA',
                                'Chicago, IL', 'Boston, MA', 'Washington, DC',
                                'Seattle, WA')
                THEN 'Gateway City'
            ELSE 'Other'
        END AS market_tier
    FROM rent_index
    WHERE RegionType = 'msa'
      AND year BETWEEN 2019 AND 2024
    GROUP BY RegionName, StateName, year
)
SELECT
    market_tier,
    year,
    ROUND(AVG(avg_rent), 0) AS tier_avg_rent,
    COUNT(DISTINCT RegionName) AS metro_count
FROM classified
WHERE market_tier != 'Other'
GROUP BY market_tier, year
ORDER BY market_tier, year;


-- ============================================================
-- QUERY 6: Markets with Rent Deceleration (Peak vs. Current)
-- Skills demonstrated: subquery, MAX/MIN with condition, real underwriting insight
-- ============================================================
WITH peak AS (
    SELECT RegionName, StateName,
           MAX(rent_index) AS peak_rent,
           MAX(CASE WHEN rent_index = (
               SELECT MAX(r2.rent_index) FROM rent_index r2
               WHERE r2.RegionName = r.RegionName
           ) THEN date END) AS peak_date
    FROM rent_index r
    WHERE RegionType = 'msa'
    GROUP BY RegionName, StateName
),
current_rent AS (
    SELECT RegionName,
           rent_index AS current_rent,
           date AS current_date
    FROM rent_index
    WHERE date = (SELECT MAX(date) FROM rent_index)
      AND RegionType = 'msa'
)
SELECT
    p.RegionName,
    p.StateName,
    ROUND(p.peak_rent, 0)   AS peak_rent,
    p.peak_date,
    ROUND(c.current_rent, 0) AS current_rent,
    ROUND((c.current_rent - p.peak_rent) / p.peak_rent * 100, 1) AS pct_off_peak
FROM peak p
JOIN current_rent c ON p.RegionName = c.RegionName
WHERE c.current_rent < p.peak_rent
ORDER BY pct_off_peak ASC
LIMIT 20;
