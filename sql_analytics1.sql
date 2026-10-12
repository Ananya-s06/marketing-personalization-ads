
create database market_personalization_ads;
USE market_personalization_ads;
SHOW TABLES;

SELECT *
FROM customers
LIMIT 10;

SELECT COUNT(*) AS total_customers
FROM customers;


DESCRIBE recommendations_impressions;

SELECT
    model_version,
    COUNT(*) AS valid_impressions,
    SUM(Valid_Click) AS valid_clicks,
    ROUND(100.0 * SUM(Valid_Click) / COUNT(*), 2) AS ctr_percent
FROM recommendations_impressions
WHERE clicked IN (0, 1)
AND `rank` > 0
GROUP BY model_version
ORDER BY ctr_percent DESC;

DESCRIBE orders;

DESCRIBE customer_events;

DESCRIBE ad_events;

DESCRIBE campaigns;

DESCRIBE recommendation_feedback;

USE market_personalization_ads;

WITH recommendation_funnel AS (
    SELECT
        r.customer_id,
        COUNT(*) AS impressions,
        SUM(CASE WHEN r.clicked = 1 THEN 1 ELSE 0 END) AS clicks
    FROM recommendations_impressions r
    WHERE r.clicked IN (0, 1)
      AND r.`rank` > 0
    GROUP BY r.customer_id
),
purchase_summary AS (
    SELECT
        customer_id,
        COUNT(*) AS orders,
        SUM(COALESCE(Valid_GMV, 0)) AS total_gmv,
        SUM(COALESCE(margin, 0)) AS total_margin
    FROM orders
    GROUP BY customer_id
)
SELECT
    f.customer_id,
    f.impressions,
    f.clicks,
    ROUND(100.0 * f.clicks / NULLIF(f.impressions, 0), 2) AS ctr_percent,
    COALESCE(p.orders, 0) AS orders,
    ROUND(COALESCE(p.total_gmv, 0), 2) AS total_gmv,
    ROUND(COALESCE(p.total_margin, 0), 2) AS total_margin
FROM recommendation_funnel f
LEFT JOIN purchase_summary p
    ON f.customer_id = p.customer_id
ORDER BY total_gmv DESC;

USE market_personalization_ads;

SELECT
    `rank` AS recommendation_rank,
    COUNT(*) AS impressions,
    SUM(clicked) AS clicks,
    ROUND(
        100.0 * SUM(clicked) / NULLIF(COUNT(*), 0),
        2
    ) AS ctr_percent
FROM recommendations_impressions
WHERE clicked IN (0, 1)
  AND `rank` > 0
GROUP BY `rank`
ORDER BY `rank`;

DESCRIBE products;

DESCRIBE customers;

USE market_personalization_ads;

WITH campaign_performance AS (
    SELECT
        c.advertiser_type,
        c.`ï»¿campaign_id` AS campaign_id,
        c.bid_strategy,
        COUNT(a.campaign_id) AS ad_events,
        SUM(COALESCE(a.spend, 0)) AS total_spend,
        SUM(COALESCE(a.attributed_gmv, 0)) AS attributed_gmv
    FROM campaigns c
    LEFT JOIN ad_events a
        ON c.`ï»¿campaign_id` = a.campaign_id
    GROUP BY
        c.advertiser_type,
        c.`ï»¿campaign_id`,
        c.bid_strategy
),
ranked_campaigns AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY advertiser_type
            ORDER BY attributed_gmv DESC
        ) AS campaign_rank
    FROM campaign_performance
)
SELECT *
FROM ranked_campaigns
ORDER BY advertiser_type, campaign_rank;

DESCRIBE ad_events;

USE market_personalization_ads;

SELECT
    model_version,
    COUNT(*) AS valid_impressions,
    ROUND(
        100.0 * SUM(clicked) / NULLIF(COUNT(*), 0),
        2
    ) AS ctr_percent,
    ROUND(AVG(position_score), 4) AS avg_position_score
FROM recommendations_impressions
WHERE clicked IN (0, 1)
  AND `rank` > 0
GROUP BY model_version
ORDER BY ctr_percent DESC;

USE market_personalization_ads;

WITH product_exposure AS (
    SELECT
        customer_id,
        product_id,
        COUNT(*) AS exposure_count,
        SUM(Valid_Click) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id, product_id
),
customer_repetition AS (
    SELECT
        customer_id,
        SUM(exposure_count) AS total_impressions,
        SUM(clicks) AS total_clicks,
        COUNT(*) AS distinct_products_seen,
        SUM(
            CASE WHEN exposure_count >= 3
                 THEN exposure_count ELSE 0 END
        ) AS repeated_product_impressions,
        SUM(
            CASE WHEN exposure_count >= 3
                 THEN 1 ELSE 0 END
        ) AS repeatedly_seen_products
    FROM product_exposure
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN repeated_product_impressions = 0 THEN 'No repeated exposure'
        WHEN 1.0 * repeated_product_impressions /
             NULLIF(total_impressions, 0) < 0.25
            THEN 'Low repetition'
        ELSE 'High repetition'
    END AS repetition_band,
    COUNT(*) AS customers,
    ROUND(
        100.0 * SUM(total_clicks) /
        NULLIF(SUM(total_impressions), 0), 2
    ) AS ctr_percent,
    ROUND(
        AVG(1.0 * repeated_product_impressions /
            NULLIF(total_impressions, 0)), 3
    ) AS avg_repeated_exposure_share
FROM customer_repetition
GROUP BY repetition_band
ORDER BY avg_repeated_exposure_share;

USE market_personalization_ads;

SELECT
    exposure_count,
    COUNT(*) AS customer_product_pairs
FROM (
    SELECT
        customer_id,
        product_id,
        COUNT(*) AS exposure_count
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id, product_id
) AS product_exposure
GROUP BY exposure_count
ORDER BY exposure_count;

WITH product_exposure AS (
    SELECT
        customer_id,
        product_id,
        COUNT(*) AS exposure_count,
        SUM(Valid_Click) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id, product_id
),
customer_repetition AS (
    SELECT
        customer_id,
        SUM(exposure_count) AS total_impressions,
        SUM(clicks) AS total_clicks,
        SUM(
            CASE WHEN exposure_count >= 2
                 THEN exposure_count ELSE 0 END
        ) AS repeated_impressions
    FROM product_exposure
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN repeated_impressions = 0
            THEN 'No repeated exposure'
        ELSE 'Repeated exposure'
    END AS repetition_band,
    COUNT(*) AS customers,
    ROUND(
        100.0 * SUM(total_clicks)
        / NULLIF(SUM(total_impressions), 0), 2
    ) AS ctr_percent
FROM customer_repetition
GROUP BY repetition_band
ORDER BY repetition_band;

WITH customer_recommendations AS (
    SELECT
        customer_id,
        COUNT(*) AS recommendation_impressions,
        SUM(Valid_Click) AS recommendation_clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id
),
customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        SUM(COALESCE(Valid_GMV, 0)) AS total_gmv,
        SUM(COALESCE(margin, 0)) AS total_margin
    FROM orders
    GROUP BY customer_id
)
SELECT
    r.customer_id,
    r.recommendation_impressions,
    r.recommendation_clicks,
    COALESCE(o.total_orders, 0) AS total_orders,
    ROUND(COALESCE(o.total_gmv, 0), 2) AS total_gmv,
    ROUND(COALESCE(o.total_margin, 0), 2) AS total_margin
FROM customer_recommendations r
LEFT JOIN customer_orders o
    ON r.customer_id = o.customer_id
ORDER BY total_gmv DESC
LIMIT 100;

SELECT
    `rank` AS recommendation_rank,
    COUNT(*) AS impressions,
    SUM(Valid_Click) AS clicks,
    ROUND(
        100.0 * SUM(Valid_Click) / NULLIF(COUNT(*), 0),
        2
    ) AS ctr_percent
FROM recommendations_impressions
WHERE clicked IN (0, 1)
  AND `rank` > 0
GROUP BY `rank`
ORDER BY `rank`;

SELECT
    model_version,
    COUNT(*) AS impressions,
    SUM(Valid_Click) AS clicks,
    ROUND(
        100.0 * SUM(Valid_Click) / NULLIF(COUNT(*), 0),
        2
    ) AS ctr_percent,
    ROUND(AVG(position_score), 4) AS avg_position_score
FROM recommendations_impressions
WHERE clicked IN (0, 1)
  AND `rank` > 0
GROUP BY model_version
ORDER BY ctr_percent DESC;

DESCRIBE ad_events;

WITH experience_metrics AS (
    SELECT
        model_version,
        COUNT(*) AS impressions,
        SUM(Valid_Click) AS clicks,
        ROUND(
            100.0 * SUM(Valid_Click) / NULLIF(COUNT(*), 0),
            2
        ) AS ctr_percent
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY model_version
)
SELECT
    model_version,
    impressions,
    clicks,
    ctr_percent,
    CASE
        WHEN ctr_percent >= 23.4 THEN 'High CTR'
        WHEN ctr_percent >= 22.5 THEN 'Medium CTR'
        ELSE 'Low CTR'
    END AS experience_quality_band
FROM experience_metrics
ORDER BY ctr_percent DESC;

SELECT *
FROM recommendation_feedback
LIMIT 10;

SELECT
    surface,
    COUNT(*) AS total_feedback,
    SUM(
        CASE
            WHEN LOWER(TRIM(feedback_reason)) IN (
                'irrelevant',
                'repeated items',
                'too many ads'
            )
            THEN 1 ELSE 0
        END
    ) AS negative_feedback,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(TRIM(feedback_reason)) IN (
                    'irrelevant',
                    'repeated items',
                    'too many ads'
                )
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_feedback_percent
FROM recommendation_feedback
GROUP BY surface
ORDER BY negative_feedback_percent DESC;

DESCRIBE recommendation_feedback;

WITH customer_performance AS (
    SELECT
        customer_id,
        Customer_Segment,
        SUM(COALESCE(Valid_GMV, 0)) AS total_gmv,
        SUM(COALESCE(margin, 0)) AS total_margin,
        COUNT(*) AS total_orders
    FROM orders
    GROUP BY customer_id, Customer_Segment
)
SELECT
    customer_id,
    Customer_Segment,
    ROUND(total_gmv, 2) AS total_gmv,
    ROUND(total_margin, 2) AS total_margin,
    total_orders,
    RANK() OVER (
        PARTITION BY Customer_Segment
        ORDER BY total_gmv DESC
    ) AS segment_gmv_rank
FROM customer_performance
ORDER BY Customer_Segment, segment_gmv_rank;

WITH product_metrics AS (
    SELECT
        category,
        product_id,
        COUNT(*) AS impressions,
        SUM(Valid_Click) AS clicks,
        SUM(Valid_Click) / NULLIF(COUNT(*), 0) AS ctr
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY category, product_id
    HAVING COUNT(*) >= 10
)
SELECT
    category,
    product_id,
    impressions,
    clicks,
    ROUND(100 * ctr, 2) AS ctr_percent,
    RANK() OVER (
        PARTITION BY category
        ORDER BY ctr DESC
    ) AS product_rank_in_category
FROM product_metrics
ORDER BY category, product_rank_in_category;

DESCRIBE ad_events;

DESCRIBE campaigns;

WITH recommendation_activity AS (
    SELECT
        customer_id,
        SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id
),
purchase_activity AS (
    SELECT
        customer_id,
        COUNT(*) AS orders
    FROM orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS customers_with_recommendation_activity,
    SUM(CASE WHEN r.clicks > 0 THEN 1 ELSE 0 END)
        AS customers_who_clicked,
    SUM(CASE WHEN r.clicks > 0
              AND COALESCE(p.orders, 0) > 0
             THEN 1 ELSE 0 END)
        AS clicked_customers_who_ordered,
    ROUND(
        100.0 * SUM(
            CASE WHEN r.clicks > 0
                   AND COALESCE(p.orders, 0) > 0
                 THEN 1 ELSE 0 END
        ) / NULLIF(SUM(CASE WHEN r.clicks > 0 THEN 1 ELSE 0 END), 0),
        2
    ) AS clicked_customer_order_rate_percent
FROM recommendation_activity r
LEFT JOIN purchase_activity p
    ON r.customer_id = p.customer_id;
    
    
WITH product_impressions AS (
    SELECT
        product_id,
        COUNT(*) AS impressions,
        SUM(Valid_Click) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY product_id
),
ranked_products AS (
    SELECT
        product_id,
        impressions,
        clicks,
        RANK() OVER (ORDER BY impressions DESC) AS impression_rank,
        SUM(impressions) OVER () AS total_impressions
    FROM product_impressions
)
SELECT
    product_id,
    impressions,
    clicks,
    impression_rank,
    ROUND(
        100.0 * impressions / NULLIF(total_impressions, 0),
        2
    ) AS impression_share_percent
FROM ranked_products
ORDER BY impression_rank
LIMIT 20;

WITH product_impressions AS (
    SELECT
        product_id,
        COUNT(*) AS impressions
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY product_id
),
ranked_products AS (
    SELECT
        product_id,
        impressions,
        RANK() OVER (ORDER BY impressions DESC) AS product_rank,
        SUM(impressions) OVER () AS total_impressions
    FROM product_impressions
)
SELECT
    SUM(CASE WHEN product_rank <= 10
             THEN impressions ELSE 0 END) AS top_10_impressions,
    MAX(total_impressions) AS total_impressions,
    ROUND(
        100.0 * SUM(CASE WHEN product_rank <= 10
                         THEN impressions ELSE 0 END)
        / NULLIF(MAX(total_impressions), 0),
        2
    ) AS top_10_impression_share_percent
FROM ranked_products;

DESCRIBE ad_events;

SELECT *
FROM ad_events
LIMIT 5;

SHOW COLUMNS FROM ad_events;

WITH campaign_performance AS (
    SELECT
        campaign_id,
        UPPER(TRIM(Advertiser_Type)) AS advertiser_type,
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks,
        SUM(Valid_Spend) AS total_spend,
        SUM(Valid_Ad_GMV) AS attributed_gmv
    FROM ad_events
    WHERE campaign_id LIKE 'CAM%'
      AND impressions > 0
      AND clicks >= 0
      AND clicks <= impressions
      AND Valid_Spend >= 0
      AND Valid_Ad_GMV >= 0
    GROUP BY
        campaign_id,
        UPPER(TRIM(Advertiser_Type))
)
SELECT
    campaign_id,
    advertiser_type,
    impressions,
    clicks,
    ROUND(100.0 * clicks / NULLIF(impressions, 0), 2) AS ctr_percent,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(total_spend / NULLIF(clicks, 0), 2) AS cpc,
    ROUND(attributed_gmv / NULLIF(total_spend, 0), 2) AS roas,
    ROUND(attributed_gmv, 2) AS attributed_gmv,
    RANK() OVER (
        PARTITION BY advertiser_type
        ORDER BY attributed_gmv / NULLIF(total_spend, 0) DESC
    ) AS campaign_roas_rank
FROM campaign_performance
ORDER BY advertiser_type, campaign_roas_rank;

SHOW COLUMNS FROM orders;

WITH campaign_performance AS (
    SELECT
        campaign_id,
        UPPER(TRIM(Advertiser_Type)) AS advertiser_type,
        SUM(Valid_Spend) AS total_spend,
        SUM(Valid_Ad_GMV) AS attributed_gmv,
        SUM(clicks) AS clicks,
        SUM(impressions) AS impressions
    FROM ad_events
    WHERE campaign_id LIKE 'CAM%'
      AND clicks >= 0
      AND clicks <= impressions
      AND Valid_Spend >= 0
      AND Valid_Ad_GMV >= 0
    GROUP BY campaign_id, UPPER(TRIM(Advertiser_Type))
),
order_margin AS (
    SELECT
        product_id,
        COUNT(*) AS order_count,
        SUM(COALESCE(Valid_GMV, 0)) AS valid_gmv,
        SUM(COALESCE(margin, 0)) AS total_margin
    FROM orders
    WHERE Valid_GMV >= 0
    GROUP BY product_id
)
SELECT
    c.campaign_id,
    c.advertiser_type,
    ROUND(c.total_spend, 2) AS ad_spend,
    ROUND(c.attributed_gmv, 2) AS attributed_gmv,
    ROUND(c.attributed_gmv / NULLIF(c.total_spend, 0), 2) AS roas,
    COALESCE(SUM(o.order_count), 0) AS product_order_count,
    ROUND(COALESCE(SUM(o.valid_gmv), 0), 2) AS product_valid_gmv,
    ROUND(COALESCE(SUM(o.total_margin), 0), 2) AS product_margin,
    ROUND(
        100.0 * COALESCE(SUM(o.total_margin), 0)
        / NULLIF(SUM(o.valid_gmv), 0),
        2
    ) AS product_margin_percent
FROM campaign_performance c
LEFT JOIN ad_events a
    ON a.campaign_id = c.campaign_id
   AND a.campaign_id LIKE 'CAM%'
LEFT JOIN order_margin o
    ON o.product_id = a.product_id
GROUP BY
    c.campaign_id,
    c.advertiser_type,
    c.total_spend,
    c.attributed_gmv
ORDER BY roas DESC;

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Valid_GMV > 0 THEN 1 ELSE 0 END) AS orders_with_valid_gmv,
    ROUND(SUM(Valid_GMV), 2) AS total_valid_gmv,
    ROUND(SUM(margin), 2) AS total_margin,
    ROUND(
        100.0 * SUM(margin) / NULLIF(SUM(Valid_GMV), 0),
        2
    ) AS overall_margin_percent,
    MIN(margin) AS minimum_margin,
    MAX(margin) AS maximum_margin,
    AVG(margin) AS average_margin
FROM orders
WHERE Valid_GMV >= 0;

SELECT
    margin,
    COUNT(*) AS row_count,
    ROUND(AVG(Valid_GMV), 2) AS avg_valid_gmv,
    ROUND(MIN(Valid_GMV), 2) AS min_valid_gmv,
    ROUND(MAX(Valid_GMV), 2) AS max_valid_gmv
FROM orders
WHERE Valid_GMV > 0
GROUP BY margin
ORDER BY row_count DESC
LIMIT 20;

SELECT
    CASE
        WHEN margin < 0 THEN '1. Negative'
        WHEN margin = 0 THEN '2. Zero'
        WHEN margin > 0 AND margin <= 0.3 THEN '3. 0–30%'
        WHEN margin > 0.3 AND margin <= 1 THEN '4. 30–100%'
        WHEN margin > 1 THEN '5. Above 100%'
        ELSE '6. Missing'
    END AS margin_band,
    COUNT(*) AS order_count,
    ROUND(AVG(margin), 4) AS average_margin_value,
    ROUND(SUM(Valid_GMV), 2) AS total_valid_gmv
FROM orders
GROUP BY margin_band
ORDER BY margin_band;

WITH campaign_metrics AS (
    SELECT
        campaign_id,
        UPPER(TRIM(Advertiser_Type)) AS advertiser_type,
        SUM(Valid_Spend) AS spend,
        SUM(Valid_Ad_GMV) AS ad_gmv,
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks
    FROM ad_events
    WHERE campaign_id LIKE 'CAM%'
      AND clicks >= 0
      AND clicks <= impressions
      AND Valid_Spend >= 0
      AND Valid_Ad_GMV >= 0
    GROUP BY campaign_id, UPPER(TRIM(Advertiser_Type))
),
product_margin AS (
    SELECT
        product_id,
        SUM(Valid_GMV) AS product_gmv,
        SUM(margin * Valid_GMV) / NULLIF(SUM(Valid_GMV), 0)
            AS weighted_margin_ratio
    FROM orders
    WHERE Valid_GMV > 0
      AND margin BETWEEN 0 AND 1
    GROUP BY product_id
),
campaign_product_metrics AS (
    SELECT
        c.campaign_id,
        c.advertiser_type,
        c.spend,
        c.ad_gmv,
        c.impressions,
        c.clicks,
        AVG(p.weighted_margin_ratio) AS avg_product_margin_ratio
    FROM campaign_metrics c
    LEFT JOIN ad_events a
        ON a.campaign_id = c.campaign_id
       AND a.campaign_id LIKE 'CAM%'
    LEFT JOIN product_margin p
        ON p.product_id = a.product_id
    GROUP BY
        c.campaign_id, c.advertiser_type, c.spend,
        c.ad_gmv, c.impressions, c.clicks
)
SELECT
    campaign_id,
    advertiser_type,
    ROUND(spend, 2) AS spend,
    ROUND(ad_gmv, 2) AS ad_gmv,
    ROUND(ad_gmv / NULLIF(spend, 0), 2) AS roas,
    ROUND(100 * avg_product_margin_ratio, 2) AS product_margin_percent,
    CASE
        WHEN ad_gmv / NULLIF(spend, 0) >= 5
             AND avg_product_margin_ratio < 0.15
            THEN 'High ROAS / Low Margin'
        WHEN ad_gmv / NULLIF(spend, 0) >= 3
             AND avg_product_margin_ratio >= 0.15
            THEN 'Potentially Attractive'
        WHEN ad_gmv / NULLIF(spend, 0) < 2
            THEN 'Restrict / Investigate'
        ELSE 'Monitor'
    END AS campaign_risk_band
FROM campaign_product_metrics
ORDER BY roas DESC;

WITH advertiser_performance AS (
    SELECT
        UPPER(TRIM(Advertiser_Type)) AS advertiser_type,
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks,
        SUM(Valid_Spend) AS spend,
        SUM(Valid_Ad_GMV) AS ad_gmv
    FROM ad_events
    WHERE campaign_id LIKE 'CAM%'
      AND clicks >= 0
      AND clicks <= impressions
      AND Valid_Spend >= 0
      AND Valid_Ad_GMV >= 0
    GROUP BY UPPER(TRIM(Advertiser_Type))
)
SELECT
    advertiser_type,
    impressions,
    clicks,
    ROUND(100.0 * clicks / NULLIF(impressions, 0), 2) AS ctr_percent,
    ROUND(spend, 2) AS spend,
    ROUND(ad_gmv, 2) AS ad_gmv,
    ROUND(ad_gmv / NULLIF(spend, 0), 2) AS roas,
    RANK() OVER (
        ORDER BY ad_gmv / NULLIF(spend, 0) DESC
    ) AS roas_rank
FROM advertiser_performance
ORDER BY roas_rank;

SELECT
    model_version,
    Customer_Segment,
    COUNT(*) AS impressions,
    SUM(Valid_Click) AS clicks,
    ROUND(
        100.0 * SUM(Valid_Click) / NULLIF(COUNT(*), 0),
        2
    ) AS ctr_percent
FROM recommendations_impressions
WHERE clicked IN (0, 1)
  AND `rank` > 0
GROUP BY model_version, Customer_Segment
HAVING COUNT(*) >= 100
ORDER BY Customer_Segment, ctr_percent DESC;

SHOW COLUMNS FROM recommendation_feedback;

SELECT
    feedback_type,
    COUNT(*) AS feedback_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS feedback_share_percent,
    ROUND(AVG(rating), 2) AS average_rating,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM recommendation_feedback
GROUP BY feedback_type
ORDER BY feedback_count DESC;

SELECT
    surface,
    COUNT(*) AS total_feedback,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(CASE
        WHEN LOWER(feedback_type) = 'irrelevant'
        THEN 1 ELSE 0
    END) AS irrelevant_count,
    SUM(CASE
        WHEN LOWER(feedback_type) = 'repeated items'
        THEN 1 ELSE 0
    END) AS repeated_items_count,
    SUM(CASE
        WHEN LOWER(feedback_type) = 'too many ads'
        THEN 1 ELSE 0
    END) AS too_many_ads_count,
    ROUND(AVG(rating), 2) AS average_rating,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(feedback_type) IN
                    ('irrelevant', 'repeated items', 'too many ads')
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS risk_feedback_percent
FROM recommendation_feedback
GROUP BY surface
ORDER BY risk_feedback_percent DESC;

WITH campaign_metrics AS (
    SELECT
        campaign_id,
        UPPER(TRIM(Advertiser_Type)) AS advertiser_type,
        SUM(impressions) AS impressions,
        SUM(clicks) AS clicks,
        SUM(Valid_Spend) AS spend,
        SUM(Valid_Ad_GMV) AS ad_gmv
    FROM ad_events
    WHERE campaign_id LIKE 'CAM%'
      AND clicks >= 0
      AND clicks <= impressions
      AND Valid_Spend >= 0
      AND Valid_Ad_GMV >= 0
    GROUP BY campaign_id, UPPER(TRIM(Advertiser_Type))
),
product_margin AS (
    SELECT
        product_id,
        SUM(Valid_GMV) AS product_gmv,
        SUM(margin * Valid_GMV) /
            NULLIF(SUM(Valid_GMV), 0) AS margin_ratio
    FROM orders
    WHERE Valid_GMV > 0
      AND margin BETWEEN 0 AND 1
    GROUP BY product_id
),
campaign_margin AS (
    SELECT
        c.campaign_id,
        AVG(pm.margin_ratio) AS product_margin_proxy
    FROM campaign_metrics c
    JOIN ad_events a
        ON a.campaign_id = c.campaign_id
       AND a.campaign_id LIKE 'CAM%'
    LEFT JOIN product_margin pm
        ON pm.product_id = a.product_id
    GROUP BY c.campaign_id
)
SELECT
    c.campaign_id,
    c.advertiser_type,
    c.impressions,
    c.clicks,
    ROUND(
        100.0 * c.clicks / NULLIF(c.impressions, 0), 2
    ) AS ctr_percent,
    ROUND(c.spend, 2) AS spend,
    ROUND(c.ad_gmv, 2) AS ad_gmv,
    ROUND(c.ad_gmv / NULLIF(c.spend, 0), 2) AS roas,
    ROUND(100 * cm.product_margin_proxy, 2) AS product_margin_proxy_percent,
    CASE
        WHEN c.impressions < 1000 THEN 'Insufficient data'
        WHEN c.ad_gmv / NULLIF(c.spend, 0) >= 5
             AND cm.product_margin_proxy >= 0.15
            THEN 'Test controlled investment'
        WHEN c.ad_gmv / NULLIF(c.spend, 0) < 2
            THEN 'Review / restrict'
        ELSE 'Monitor and validate'
    END AS recommendation
FROM campaign_metrics c
LEFT JOIN campaign_margin cm
    ON cm.campaign_id = c.campaign_id
ORDER BY roas DESC;