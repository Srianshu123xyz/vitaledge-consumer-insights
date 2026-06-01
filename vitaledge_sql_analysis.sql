-- ============================================================
-- VITALEDGE CONSUMER INSIGHTS — SQL ANALYSIS
-- Author: Sri Anshu Chaturvedi
-- Dataset: 2,000 respondents | Survey period: Jun–Nov 2024
-- Tool: Run on DB Browser for SQLite (free) or sqliteonline.com
-- ============================================================

-- NOTE: Import vitaledge_survey_data.csv as table: survey


-- ============================================================
-- 1. FUNNEL ANALYSIS
--    How many respondents reached each stage?
--    What is the drop-off rate between each stage?
-- ============================================================

WITH funnel_counts AS (
    SELECT
        funnel_stage,
        COUNT(*) AS respondents,
        CASE funnel_stage
            WHEN 'Awareness'        THEN 1
            WHEN 'Consideration'    THEN 2
            WHEN 'Intent'           THEN 3
            WHEN 'Trial'            THEN 4
            WHEN 'Purchase'         THEN 5
            WHEN 'Repeat Purchase'  THEN 6
        END AS stage_order
    FROM survey
    GROUP BY funnel_stage
),
cumulative AS (
    SELECT
        funnel_stage,
        stage_order,
        respondents,
        SUM(respondents) OVER (ORDER BY stage_order DESC) AS reached_this_stage_or_beyond
    FROM funnel_counts
)
SELECT
    stage_order,
    funnel_stage,
    reached_this_stage_or_beyond AS total_reached,
    ROUND(100.0 * reached_this_stage_or_beyond / 2000, 1) AS pct_of_total,
    ROUND(100.0 * reached_this_stage_or_beyond /
        LAG(reached_this_stage_or_beyond) OVER (ORDER BY stage_order), 1) AS conversion_from_prev_stage
FROM cumulative
ORDER BY stage_order;


-- ============================================================
-- 2. CHANNEL EFFECTIVENESS
--    Which awareness channels drive the most purchasers?
--    Cost-quality tradeoff insight for media planning.
-- ============================================================

SELECT
    awareness_channel,
    COUNT(*) AS total_reached,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS purchase_conversion_rate,
    ROUND(AVG(CASE WHEN monthly_spend_inr > 0 THEN monthly_spend_inr END), 0) AS avg_monthly_spend_inr
FROM survey
GROUP BY awareness_channel
ORDER BY purchase_conversion_rate DESC;


-- ============================================================
-- 3. DEMOGRAPHIC PROFILE OF PURCHASERS VS NON-PURCHASERS
--    Who is buying vs who is dropping off?
-- ============================================================

SELECT
    age_group,
    gender,
    COUNT(*) AS total,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate
FROM survey
GROUP BY age_group, gender
ORDER BY conversion_rate DESC
LIMIT 15;


-- ============================================================
-- 4. PURCHASE BARRIER ANALYSIS
--    Why are people NOT buying?
--    Focus on Intent + Trial drop-offs — highest-value cohort.
-- ============================================================

SELECT
    purchase_barrier,
    COUNT(*) AS respondents_citing_barrier,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_non_purchasers
FROM survey
WHERE funnel_stage IN ('Awareness','Consideration','Intent','Trial')
  AND purchase_barrier != 'None'
  AND purchase_barrier != ''
GROUP BY purchase_barrier
ORDER BY respondents_citing_barrier DESC;


-- ============================================================
-- 5. PRODUCT-LEVEL FUNNEL PERFORMANCE
--    Which products convert best? Which have the most drop-off?
-- ============================================================

SELECT
    product_interest,
    COUNT(*) AS total_interested,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate,
    ROUND(AVG(CASE WHEN monthly_spend_inr > 0 THEN monthly_spend_inr END), 0) AS avg_spend_inr,
    SUM(CASE WHEN funnel_stage = 'Repeat Purchase' THEN 1 ELSE 0 END) AS repeat_buyers
FROM survey
GROUP BY product_interest
ORDER BY conversion_rate DESC;


-- ============================================================
-- 6. NPS ANALYSIS
--    Net Promoter Score breakdown.
--    NPS = % Promoters - % Detractors
-- ============================================================

SELECT
    nps_category,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM survey
WHERE nps_category != ''
GROUP BY nps_category
ORDER BY CASE nps_category WHEN 'Promoter' THEN 1 WHEN 'Passive' THEN 2 WHEN 'Detractor' THEN 3 END;

-- Overall NPS Score
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN nps_category = 'Promoter' THEN 1 ELSE 0 END) / COUNT(*) -
        100.0 * SUM(CASE WHEN nps_category = 'Detractor' THEN 1 ELSE 0 END) / COUNT(*),
    1) AS net_promoter_score
FROM survey
WHERE nps_category != '';


-- ============================================================
-- 7. INCOME VS SPEND CORRELATION
--    Do higher-income buyers actually spend more?
--    Useful for premium product positioning.
-- ============================================================

SELECT
    income_bracket,
    COUNT(*) AS total_respondents,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(AVG(CASE WHEN monthly_spend_inr > 0 THEN monthly_spend_inr END), 0) AS avg_monthly_spend_inr,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate
FROM survey
GROUP BY income_bracket
ORDER BY CASE income_bracket
    WHEN '<3L' THEN 1 WHEN '3-6L' THEN 2 WHEN '6-10L' THEN 3
    WHEN '10-20L' THEN 4 WHEN '20L+' THEN 5 END;


-- ============================================================
-- 8. CITY-LEVEL PERFORMANCE
--    Which cities show highest purchase intent and conversion?
-- ============================================================

SELECT
    city,
    COUNT(*) AS total_respondents,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS conversion_rate,
    ROUND(AVG(CASE WHEN monthly_spend_inr > 0 THEN monthly_spend_inr END), 0) AS avg_spend_inr
FROM survey
GROUP BY city
ORDER BY conversion_rate DESC;


-- ============================================================
-- 9. REPEAT BUYER PROFILE
--    Who are the most loyal customers?
--    Retention insight for CRM and email marketing.
-- ============================================================

SELECT
    age_group,
    income_bracket,
    top_satisfaction_driver,
    COUNT(*) AS repeat_buyers,
    ROUND(AVG(monthly_spend_inr), 0) AS avg_spend_inr
FROM survey
WHERE funnel_stage = 'Repeat Purchase'
GROUP BY age_group, income_bracket, top_satisfaction_driver
ORDER BY repeat_buyers DESC
LIMIT 10;


-- ============================================================
-- 10. MONTHLY SURVEY TREND
--     How did awareness and purchase intent evolve over time?
-- ============================================================

SELECT
    STRFTIME('%Y-%m', survey_date) AS survey_month,
    COUNT(*) AS total_respondents,
    SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) AS purchasers,
    ROUND(100.0 * SUM(CASE WHEN funnel_stage IN ('Purchase','Repeat Purchase') THEN 1 ELSE 0 END) / COUNT(*), 1) AS monthly_conversion_rate
FROM survey
GROUP BY survey_month
ORDER BY survey_month;
