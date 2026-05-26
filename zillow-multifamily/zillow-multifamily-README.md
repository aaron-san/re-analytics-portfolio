# Multifamily Rent Intelligence Dashboard

**Tools:** SQL (SQLite) · Tableau · Python  
**Data:** Zillow ZORI (Observed Rent Index) + ZHVI (Home Value Index)  
**Period:** January 2015 – April 2026 | 613 metros

---

## Business Question

Which multifamily markets are decelerating, which are still growing, and where does the rent-vs-own math favor investors — right now?

---

## Key Findings

- **Austin, TX is -15.6% off peak rent** and forecasting another ~3.5% decline over the next 12 months — consistent with post-2022 oversupply dynamics in high-growth Sun Belt markets
- **Sun Belt markets closed an ~$800/mo gap with Gateway Cities** between 2019–2022, but have since reversed — tier convergence has stalled
- **San Jose PTR = 43.6x** — strongest rent-favorable signal in the dataset; owning at current prices requires outsized appreciation assumptions to pencil
- **US national rent is effectively flat** (~$1,770/mo), consistent with a supply/demand normalization thesis heading into 2026–2027

---

## Project Structure

```
zillow-multifamily/
├── data/
│   ├── tableau_rent_dashboard.csv        # Long-format ZORI, all metros, with YoY%
│   ├── tableau_rent_homeval_joined.csv   # ZORI + ZHVI joined, with price-to-rent ratio
│   └── rent_forecast_12mo.csv           # 12-month forecast for 11 key metros, 90% CI
├── sql/
│   └── zillow_sql_queries.sql           # 6 analytical queries (CTEs, window functions, joins)
├── zillow_multifamily.db                # SQLite database (35K rent rows, 233K home value rows)
└── README.md
```

---

## SQL Highlights

Six queries covering core analytical patterns:

| Query | Technique | Business Output |
|---|---|---|
| YoY Rent Growth by Metro | CTE + self-join + RANK() | Top/bottom growth markets, 2023 vs 2024 |
| Cumulative Growth 2019–2024 | Anchor/recent CTE pattern | Post-COVID rent appreciation by metro |
| Price-to-Rent Ratio | Cross-table join, derived metric | Buy vs. rent signal by market |
| 3-Month Rolling Average | Window function + LAG() | Rent momentum / deceleration detection |
| Sun Belt vs. Gateway Cities | CASE bucketing + aggregation | Tier convergence/divergence narrative |
| Markets Off Peak | Subquery + percent change | Identifies softening markets for underwriting |

---

## Forecast Methodology

- **Model:** Holt-Winters additive exponential smoothing (trend, no seasonal — data is seasonally adjusted)
- **Horizon:** 12 months forward from April 2026
- **Confidence bands:** 90% CI, margin scaled by √horizon to reflect growing uncertainty
- **Metros covered:** US National + NY, LA, Chicago, Austin, Miami, Phoenix, Dallas, Nashville, Seattle, Atlanta

---

## Data Sources

- [Zillow Research Data](https://www.zillow.com/research/data/) — ZORI All Homes Multifamily, ZHVI SFR/Condo Middle Tier
- Both series are smoothed and seasonally adjusted by Zillow
