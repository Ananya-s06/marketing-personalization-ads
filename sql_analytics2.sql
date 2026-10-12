USE market_personalization_ads;

SHOW TABLES;

USE market_personalization_ads;

DESCRIBE recommendations_impressions;
DESCRIBE orders;
DESCRIBE customers;
DESCRIBE products;
DESCRIBE recommendation_feedback;

DESCRIBE recommendations_impressions;
DESCRIBE orders;
DESCRIBE customers;
DESCRIBE products;

USE market_personalization_ads;

WITH rec_metrics AS (
SELECT
customer_id,
product_id,
COUNT(*) AS recommendation_impressions,
SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks
FROM recommendations_impressions
WHERE clicked IN (0, 1)
AND `rank` > 0
GROUP BY customer_id, product_id
),

order_metrics AS (
SELECT
customer_id,
product_id,
COUNT(*) AS order_count,
SUM(COALESCE(Valid_GMV, 0)) AS valid_gmv,
AVG(margin) AS avg_margin
FROM orders
GROUP BY customer_id, product_id
),

feedback_metrics AS (
SELECT
customer_id,
COUNT(*) AS feedback_count,
SUM(CASE
WHEN LOWER(feedback_type) IN
('irrelevant', 'repeated items', 'too many ads')
THEN 1 ELSE 0
END) AS negative_feedback_count,
AVG(rating) AS avg_feedback_rating
FROM recommendation_feedback
GROUP BY customer_id
)

SELECT
c.customer_id,
c.customer_segment,
c.city,
c.acquisition_channel,
p.product_id,
p.category,
p.seller_id,
r.recommendation_impressions,
r.clicks,
ROUND(
100.0 * r.clicks /
NULLIF(r.recommendation_impressions, 0), 2
) AS recommendation_ctr_percent,
COALESCE(o.order_count, 0) AS order_count,
ROUND(COALESCE(o.valid_gmv, 0), 2) AS valid_gmv,
ROUND(o.avg_margin, 3) AS avg_order_margin,
COALESCE(f.feedback_count, 0) AS feedback_count,
COALESCE(f.negative_feedback_count, 0)
AS negative_feedback_count,
ROUND(f.avg_feedback_rating, 2) AS avg_feedback_rating

FROM rec_metrics r
JOIN customers c
ON c.customer_id = r.customer_id
JOIN products p
ON p.product_id = r.product_id
LEFT JOIN order_metrics o
ON o.customer_id = r.customer_id
AND o.product_id = r.product_id
LEFT JOIN feedback_metrics f
ON f.customer_id = r.customer_id

ORDER BY valid_gmv DESC, recommendation_impressions DESC
LIMIT 100;

SHOW COLUMNS FROM customers;

SELECT
    c.`ï»¿customer_id` AS customer_id,
    c.city,
    c.customer_segment
FROM customers c
LIMIT 5;

USE market_personalization_ads;

WITH rec_metrics AS (
SELECT
customer_id,
product_id,
COUNT(*) AS recommendation_impressions,
SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks
FROM recommendations_impressions
WHERE clicked IN (0, 1)
AND `rank` > 0
GROUP BY customer_id, product_id
),

order_metrics AS (
SELECT
customer_id,
product_id,
COUNT(*) AS order_count,
SUM(COALESCE(Valid_GMV, 0)) AS valid_gmv,
AVG(margin) AS avg_margin
FROM orders
GROUP BY customer_id, product_id
),

feedback_metrics AS (
SELECT
customer_id,
COUNT(*) AS feedback_count,
SUM(
CASE
WHEN LOWER(feedback_type) IN
('irrelevant', 'repeated items', 'too many ads')
THEN 1 ELSE 0
END
) AS negative_feedback_count,
AVG(rating) AS avg_feedback_rating
FROM recommendation_feedback
GROUP BY customer_id
)

SELECT
c.`ï»¿customer_id` AS customer_id,
c.customer_segment,
c.city,
c.acquisition_channel,
p.`ï»¿product_id` AS product_id,
p.category,
p.seller_id,
r.recommendation_impressions,
r.clicks,
ROUND(
100.0 * r.clicks /
NULLIF(r.recommendation_impressions, 0), 2
) AS recommendation_ctr_percent,
COALESCE(o.order_count, 0) AS order_count,
ROUND(COALESCE(o.valid_gmv, 0), 2) AS valid_gmv,
ROUND(o.avg_margin, 3) AS avg_order_margin,
COALESCE(f.feedback_count, 0) AS feedback_count,
COALESCE(f.negative_feedback_count, 0)
AS negative_feedback_count,
ROUND(f.avg_feedback_rating, 2) AS avg_feedback_rating

FROM rec_metrics r

JOIN customers c
ON c.`ï»¿customer_id` = r.customer_id

JOIN products p
ON p.`ï»¿product_id` = r.product_id

LEFT JOIN order_metrics o
ON o.customer_id = r.customer_id
AND o.product_id = r.product_id

LEFT JOIN feedback_metrics f
ON f.customer_id = r.customer_id

ORDER BY valid_gmv DESC, recommendation_impressions DESC
LIMIT 100;

USE market_personalization_ads;

WITH model_metrics AS (
SELECT
model_version,
COUNT(*) AS impressions,
SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks,
COUNT(DISTINCT customer_id) AS unique_customers,
COUNT(DISTINCT CASE
WHEN clicked = 1 THEN customer_id
END) AS unique_clickers
FROM recommendations_impressions
WHERE clicked IN (0, 1)
AND `rank` > 0
GROUP BY model_version
)
SELECT
model_version,
impressions,
clicks,
unique_customers,
unique_clickers,
ROUND(100.0 * clicks / NULLIF(impressions, 0), 2)
AS ctr_percent,
ROUND(100.0 * unique_clickers / NULLIF(unique_customers, 0), 2)
AS customer_click_rate_percent
FROM model_metrics
ORDER BY ctr_percent DESC;

USE market_personalization_ads;

WITH customer_model AS (
    SELECT
        model_version,
        customer_id,
        COUNT(*) AS impressions,
        SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY model_version, customer_id
),
customer_orders AS (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        SUM(COALESCE(Valid_GMV, 0)) AS total_valid_gmv
    FROM orders
    GROUP BY customer_id
)
SELECT
    r.model_version,
    COUNT(*) AS exposed_customers,
    SUM(r.impressions) AS total_impressions,
    SUM(r.clicks) AS total_clicks,
    COUNT(DISTINCT CASE
        WHEN r.clicks > 0 THEN r.customer_id
    END) AS customers_who_clicked,
    COUNT(DISTINCT CASE
        WHEN o.total_orders > 0 THEN r.customer_id
    END) AS customers_who_ordered,
    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN o.total_orders > 0 THEN r.customer_id
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS customer_order_rate_percent
FROM customer_model r
LEFT JOIN customer_orders o
    ON r.customer_id = o.customer_id
GROUP BY r.model_version
ORDER BY customer_order_rate_percent DESC;

USE market_personalization_ads;

WITH ranked_recommendations AS (
    SELECT
        customer_id,
        product_id,
        `rank`,
        COUNT(*) AS impressions,
        SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY customer_id, product_id, `rank`
),
customer_product_orders AS (
    SELECT
        customer_id,
        product_id,
        COUNT(*) AS order_count,
        SUM(COALESCE(Valid_GMV, 0)) AS valid_gmv
    FROM orders
    GROUP BY customer_id, product_id
)
SELECT
    r.`rank`,
    SUM(r.impressions) AS impressions,
    SUM(r.clicks) AS clicks,
    ROUND(
        100.0 * SUM(r.clicks) / NULLIF(SUM(r.impressions), 0),
        2
    ) AS ctr_percent,
    COUNT(DISTINCT CASE
        WHEN o.order_count > 0 THEN r.customer_id
    END) AS customers_with_matching_product_orders
FROM ranked_recommendations r
LEFT JOIN customer_product_orders o
    ON r.customer_id = o.customer_id
   AND r.product_id = o.product_id
GROUP BY r.`rank`
ORDER BY r.`rank`;

USE market_personalization_ads;

WITH recommended_pairs AS (
    SELECT DISTINCT
        customer_id,
        product_id
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
),
matched_orders AS (
    SELECT
        o.customer_id,
        o.product_id,
        o.`ï»¿order_id` AS order_id,
        COALESCE(o.Valid_GMV, 0) AS valid_gmv,
        COALESCE(o.margin, 0) AS margin
    FROM orders o
    JOIN recommended_pairs r
      ON o.customer_id = r.customer_id
     AND o.product_id = r.product_id
)
SELECT
    COUNT(*) AS matched_order_count,
    ROUND(SUM(valid_gmv), 2) AS matched_order_gmv,
    ROUND(SUM(margin), 2) AS matched_margin_sum,
    ROUND(AVG(margin), 4) AS average_order_margin_value,
    ROUND(
        100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders),
        2
    ) AS percent_of_all_orders_matched
FROM matched_orders;

USE market_personalization_ads;

WITH recommended_pairs AS (
    SELECT DISTINCT customer_id, product_id
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
),
order_classification AS (
    SELECT
        o.`ï»¿order_id` AS order_id,
        o.customer_id,
        o.product_id,
        COALESCE(o.Valid_GMV, 0) AS valid_gmv,
        o.margin,
        CASE
            WHEN r.customer_id IS NOT NULL THEN 'Matched'
            ELSE 'Unmatched'
        END AS recommendation_match
    FROM orders o
    LEFT JOIN recommended_pairs r
        ON o.customer_id = r.customer_id
       AND o.product_id = r.product_id
)
SELECT
    recommendation_match,
    COUNT(*) AS order_count,
    ROUND(SUM(valid_gmv), 2) AS total_valid_gmv,
    ROUND(AVG(valid_gmv), 2) AS average_gmv_per_order,
    ROUND(AVG(margin), 4) AS average_margin_value,
    ROUND(
        100.0 * SUM(valid_gmv) /
        NULLIF((SELECT SUM(valid_gmv) FROM order_classification), 0),
        2
    ) AS share_of_total_gmv_percent
FROM order_classification
GROUP BY recommendation_match;

USE market_personalization_ads;

WITH model_metrics AS (
    SELECT
        model_version,
        COUNT(*) AS impressions,
        SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY model_version
),
feedback_metrics AS (
    SELECT
        COUNT(*) AS total_feedback,
        SUM(
            CASE
                WHEN LOWER(feedback_type) IN
                     ('irrelevant', 'repeated items', 'too many ads')
                THEN 1 ELSE 0
            END
        ) AS negative_feedback
    FROM recommendation_feedback
)
SELECT
    m.model_version,
    m.impressions,
    m.clicks,
    ROUND(100.0 * m.clicks / NULLIF(m.impressions, 0), 2) AS ctr_percent,
    m.unique_customers,
    f.total_feedback,
    f.negative_feedback,
    ROUND(
        100.0 * f.negative_feedback / NULLIF(f.total_feedback, 0),
        2
    ) AS negative_feedback_percent
FROM model_metrics m
CROSS JOIN feedback_metrics f
ORDER BY ctr_percent DESC;


USE market_personalization_ads;

WITH customer_model AS (
    SELECT DISTINCT
        customer_id,
        model_version,
        surface
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
),
model_feedback AS (
    SELECT
        cm.model_version,
        COUNT(*) AS feedback_records,
        SUM(
            CASE
                WHEN LOWER(rf.feedback_type) IN
                     ('irrelevant', 'repeated items', 'too many ads')
                THEN 1 ELSE 0
            END
        ) AS negative_feedback_records,
        COUNT(DISTINCT rf.customer_id) AS customers_with_feedback
    FROM customer_model cm
    JOIN recommendation_feedback rf
      ON cm.customer_id = rf.customer_id
     AND cm.surface = rf.surface
    GROUP BY cm.model_version
)
SELECT
    model_version,
    feedback_records,
    negative_feedback_records,
    customers_with_feedback,
    ROUND(
        100.0 * negative_feedback_records /
        NULLIF(feedback_records, 0),
        2
    ) AS negative_feedback_percent
FROM model_feedback
ORDER BY negative_feedback_percent;


USE market_personalization_ads;

WITH model_engagement AS (
    SELECT
        model_version,
        COUNT(*) AS impressions,
        SUM(CASE WHEN clicked = 1 THEN 1 ELSE 0 END) AS clicks,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
    GROUP BY model_version
),
customer_model AS (
    SELECT DISTINCT
        customer_id,
        model_version,
        surface
    FROM recommendations_impressions
    WHERE clicked IN (0, 1)
      AND `rank` > 0
),
model_feedback AS (
    SELECT
        cm.model_version,
        COUNT(*) AS feedback_records,
        SUM(
            CASE
                WHEN LOWER(rf.feedback_type) IN
                    ('irrelevant', 'repeated items', 'too many ads')
                THEN 1 ELSE 0
            END
        ) AS negative_feedback_records
    FROM customer_model cm
    JOIN recommendation_feedback rf
      ON cm.customer_id = rf.customer_id
     AND cm.surface = rf.surface
    GROUP BY cm.model_version
)
SELECT
    e.model_version,
    e.impressions,
    e.clicks,
    ROUND(100.0 * e.clicks / NULLIF(e.impressions, 0), 2) AS ctr_percent,
    e.unique_customers,
    f.feedback_records,
    f.negative_feedback_records,
    ROUND(
        100.0 * f.negative_feedback_records /
        NULLIF(f.feedback_records, 0),
        2
    ) AS associated_negative_feedback_percent
FROM model_engagement e
LEFT JOIN model_feedback f
    ON e.model_version = f.model_version
ORDER BY ctr_percent DESC;

USE market_personalization_ads;

SELECT
    Advertiser_Type,
    COUNT(*) AS campaign_event_rows,
    SUM(COALESCE(impressions, 0)) AS impressions,
    SUM(COALESCE(clicks, 0)) AS clicks,
    ROUND(SUM(COALESCE(spend, 0)), 2) AS total_spend,
    ROUND(SUM(COALESCE(ad_gmv, 0)), 2) AS total_ad_gmv,
    ROUND(
        SUM(COALESCE(ad_gmv, 0)) /
        NULLIF(SUM(COALESCE(spend, 0)), 0),
        2
    ) AS calculated_roas
FROM ad_events
WHERE campaign_id LIKE 'CAM%'
GROUP BY Advertiser_Type
ORDER BY calculated_roas DESC;

USE market_personalization_ads;

SELECT
    campaign_id,
    Advertiser_Type,
    COUNT(*) AS event_rows,
    SUM(COALESCE(impressions, 0)) AS impressions,
    SUM(COALESCE(clicks, 0)) AS clicks,
    ROUND(
        100.0 * SUM(COALESCE(clicks, 0)) /
        NULLIF(SUM(COALESCE(impressions, 0)), 0),
        2
    ) AS ctr_percent,
    ROUND(SUM(COALESCE(spend, 0)), 2) AS total_spend,
    ROUND(SUM(COALESCE(ad_gmv, 0)), 2) AS total_ad_gmv,
    ROUND(
        SUM(COALESCE(ad_gmv, 0)) /
        NULLIF(SUM(COALESCE(spend, 0)), 0),
        2
    ) AS roas,
    CASE
        WHEN SUM(COALESCE(impressions, 0)) < 100
            THEN 'Insufficient volume'
        ELSE 'Eligible for further review'
    END AS volume_status
FROM ad_events
WHERE campaign_id LIKE 'CAM%'
GROUP BY campaign_id, Advertiser_Type
ORDER BY roas DESC;

USE market_personalization_ads;

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_buyers,
    ROUND(SUM(COALESCE(Valid_GMV, 0)), 2) AS total_valid_gmv,
    ROUND(AVG(Valid_GMV), 2) AS average_gmv_per_order,
    ROUND(SUM(COALESCE(margin, 0)), 2) AS margin_value_sum,
    ROUND(AVG(margin), 4) AS average_margin_value,
    SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END) AS negative_margin_orders
FROM orders;

USE market_personalization_ads;

SELECT
    p.category,
    COUNT(*) AS negative_margin_orders,
    ROUND(SUM(COALESCE(o.Valid_GMV, 0)), 2) AS associated_gmv,
    ROUND(AVG(o.margin), 4) AS average_negative_margin_value,
    COUNT(DISTINCT o.customer_id) AS affected_customers
FROM orders o
JOIN products p
    ON o.product_id = p.`ï»¿product_id`
WHERE o.margin < 0
GROUP BY p.category
ORDER BY negative_margin_orders DESC;

USE market_personalization_ads;

SELECT
    CONCAT('[', category, ']') AS category_value,
    LENGTH(category) AS category_length,
    COUNT(*) AS product_count
FROM products
GROUP BY category, LENGTH(category)
ORDER BY category_value;

USE market_personalization_ads;

SELECT
    CASE
        WHEN LOWER(TRIM(p.category)) = 'electronics' THEN 'Electronics'
        WHEN LOWER(TRIM(p.category)) = 'fashion' THEN 'Fashion'
        WHEN LOWER(TRIM(p.category)) = 'beauty' THEN 'Beauty'
        WHEN LOWER(TRIM(p.category)) = 'grocery' THEN 'Grocery'
        WHEN LOWER(TRIM(p.category)) = 'home' THEN 'Home'
        WHEN LOWER(TRIM(p.category)) = 'sports' THEN 'Sports'
        ELSE TRIM(p.category)
    END AS cleaned_category,
    COUNT(*) AS negative_margin_orders,
    ROUND(SUM(COALESCE(o.Valid_GMV, 0)), 2) AS associated_gmv,
    ROUND(AVG(o.margin), 4) AS average_negative_margin_value,
    COUNT(DISTINCT o.customer_id) AS affected_customers
FROM orders o
JOIN products p
    ON o.product_id = p.`ï»¿product_id`
WHERE o.margin < 0
GROUP BY cleaned_category
ORDER BY negative_margin_orders DESC;

USE market_personalization_ads;

SELECT
    source,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END)
        AS negative_margin_orders,
    ROUND(
        100.0 * SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS negative_margin_order_rate_percent,
    ROUND(SUM(COALESCE(Valid_GMV, 0)), 2) AS total_valid_gmv,
    ROUND(AVG(margin), 4) AS average_margin_value
FROM orders
GROUP BY source
ORDER BY negative_margin_order_rate_percent DESC;

USE market_personalization_ads;

SELECT
    CASE
        WHEN discount IS NULL THEN 'Missing discount'
        WHEN discount <= 0 THEN 'No discount'
        WHEN discount <= 10 THEN 'Low discount (0-10]'
        WHEN discount <= 25 THEN 'Medium discount (10-25]'
        ELSE 'High discount (>25)'
    END AS discount_band,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END)
        AS negative_margin_orders,
    ROUND(
        100.0 * SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS negative_margin_rate_percent,
    ROUND(SUM(COALESCE(Valid_GMV, 0)), 2) AS total_valid_gmv,
    ROUND(AVG(margin), 4) AS average_margin_value
FROM orders
GROUP BY discount_band
ORDER BY negative_margin_rate_percent DESC;

USE market_personalization_ads;

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN discount IS NULL THEN 1 ELSE 0 END) AS missing_discounts,
    SUM(CASE WHEN discount = 0 THEN 1 ELSE 0 END) AS zero_discounts,
    SUM(CASE WHEN discount < 0 THEN 1 ELSE 0 END) AS negative_discounts,
    SUM(CASE WHEN discount > 25 THEN 1 ELSE 0 END) AS discounts_above_25,
    MIN(discount) AS minimum_discount,
    MAX(discount) AS maximum_discount,
    ROUND(AVG(discount), 4) AS average_discount
FROM orders;


USE market_personalization_ads;

SELECT
    COUNT(*) AS total_orders,
    ROUND(MIN(discount), 2) AS min_discount,
    ROUND(AVG(discount), 2) AS avg_discount,
    ROUND(MAX(discount), 2) AS max_discount,
    ROUND(MIN(Product_Price), 2) AS min_product_price,
    ROUND(AVG(Product_Price), 2) AS avg_product_price,
    ROUND(MAX(Product_Price), 2) AS max_product_price,
    SUM(
        CASE
            WHEN discount > Product_Price THEN 1
            ELSE 0
        END
    ) AS discounts_above_product_price
FROM orders;

USE market_personalization_ads;

SELECT
    `ï»¿order_id` AS order_id,
    product_id,
    Product_Price,
    discount,
    Valid_GMV,
    margin,
    source
FROM orders
WHERE discount > Product_Price
ORDER BY discount DESC
LIMIT 20;

USE market_personalization_ads;

SELECT
    source,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Product_Price = 0 THEN 1 ELSE 0 END)
        AS zero_price_orders,
    SUM(CASE WHEN discount > Product_Price THEN 1 ELSE 0 END)
        AS discount_above_price_orders,
    ROUND(
        100.0 * SUM(CASE WHEN discount > Product_Price THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS discount_above_price_rate_percent
FROM orders
GROUP BY source
ORDER BY discount_above_price_orders DESC;

USE market_personalization_ads;

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Product_Price = 0 THEN 1 ELSE 0 END)
        AS zero_price_orders,
    ROUND(
        100.0 * SUM(CASE WHEN Product_Price = 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS zero_price_rate_percent,
    SUM(CASE WHEN discount > Product_Price THEN 1 ELSE 0 END)
        AS discount_above_price_orders,
    ROUND(
        100.0 * SUM(CASE WHEN discount > Product_Price THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS discount_above_price_rate_percent,
    SUM(CASE WHEN margin < 0 THEN 1 ELSE 0 END)
        AS negative_margin_orders
FROM orders;