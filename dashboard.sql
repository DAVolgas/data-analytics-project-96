-- общее количество посетителей
SELECT
    visit_date::DATE,
    source,
    medium,
    campaign,
    CASE
        WHEN medium = 'organic' THEN 'organic'
        ELSE 'paid'
    END AS source_type,
    count(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY 1, 2, 3, 4, 5
ORDER BY 6 DESC;

-- общее количество лидов
SELECT
    created_at::DATE,
    count(DISTINCT lead_id) AS leads_count
FROM leads
GROUP BY 1;

-- LPC использована в следующих графиках:
-- количество лидов по LPC, количество лидов по платным каналам,
-- количество посетителей по платным каналам, ТОП-10 по посетителям
WITH last_paid_visits AS (
    SELECT
        visitor_id,
        max(visit_date) AS last_paid_click_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY 1
)

SELECT
    lp.visitor_id,
    lp.last_paid_click_date AS visit_date,
    s."source" AS utm_source,
    s.medium AS utm_medium,
    s.campaign AS utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id,
    l.created_at::DATE - visit_date::DATE AS intervals
FROM sessions AS s
INNER JOIN last_paid_visits AS lp
    ON
        s.visitor_id = lp.visitor_id
        AND s.visit_date = lp.last_paid_click_date
LEFT JOIN leads AS l
    ON
        s.visitor_id = l.visitor_id
        AND s.visit_date <= l.created_at
WHERE s.medium != 'organic'
ORDER BY 8 DESC NULLS LAST, 2, 3, 4, 5;

-- срок, через который закрывается 90% лидов
WITH last_paid_visits AS (
    SELECT
        visitor_id,
        max(visit_date) AS last_paid_click_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY 1
),

show_case_lpc AS (
    SELECT
        lp.visitor_id,
        lp.last_paid_click_date AS visit_date,
        s."source" AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        l.created_at::DATE - visit_date::DATE AS intervals
    FROM sessions AS s
    INNER JOIN last_paid_visits AS lp
        ON
            s.visitor_id = lp.visitor_id
            AND s.visit_date = lp.last_paid_click_date
    LEFT JOIN leads AS l
        ON
            s.visitor_id = l.visitor_id
            AND s.visit_date <= l.created_at
    WHERE s.medium != 'organic'
    ORDER BY 8 DESC NULLS LAST, 2, 3, 4, 5
)

SELECT
    percentile_disc(0.9) WITHIN GROUP
    (ORDER BY intervals) AS leads_close_interval
FROM show_case_lpc
WHERE lead_id IS NOT NULL;

-- aggregate LPC использована в следущих графиках:
-- затраты на рекламу по платным кампаниям и по vk/yandex
WITH total_cost AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4

    UNION

    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

last_visit AS (
    SELECT
        visitor_id,
        max(visit_date) AS last_paid_click_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY 1
),

total_amount AS (
    SELECT
        lv.last_paid_click_date::DATE AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        count(DISTINCT s.visitor_id) AS visitors_count,
        count(DISTINCT l.lead_id) AS leads_count,
        count(CASE
            WHEN l.status_id = 142 THEN 1
        END)
        AS purchases_count,
        sum(l.amount) AS revenue
    FROM last_visit AS lv
    INNER JOIN sessions AS s
        ON
            lv.visitor_id = s.visitor_id
            AND lv.last_paid_click_date = s.visit_date
    LEFT JOIN leads AS l
        ON
            lv.last_paid_click_date <= l.created_at
            AND lv.visitor_id = l.visitor_id
    GROUP BY 1, 2, 3, 4
)

SELECT
    ta.visit_date,
    ta.visitors_count,
    ta.utm_source,
    ta.utm_medium,
    ta.utm_campaign,
    tc.total_cost,
    ta.leads_count,
    ta.purchases_count,
    ta.revenue
FROM total_amount AS ta
LEFT JOIN total_cost AS tc
    ON
        ta.visit_date = tc.campaign_date
        AND ta.utm_source = tc.utm_source
        AND ta.utm_medium = tc.utm_medium
        AND ta.utm_campaign = tc.utm_campaign
ORDER BY 9 DESC NULLS LAST, 1, 2 DESC, 3, 4, 5;

-- для итоговых метрик и общего графика по окупаемости рекламы
WITH total_cost AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4

    UNION

    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

last_visit AS (
    SELECT
        visitor_id,
        max(visit_date) AS last_paid_click_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY 1
),

total_amount AS (
    SELECT
        lv.last_paid_click_date::DATE AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        count(DISTINCT s.visitor_id) AS visitors_count,
        count(DISTINCT l.lead_id) AS leads_count,
        count(CASE
            WHEN l.status_id = 142 THEN 1
        END)
        AS purchases_count,
        sum(l.amount) AS revenue
    FROM last_visit AS lv
    INNER JOIN sessions AS s
        ON
            lv.visitor_id = s.visitor_id
            AND lv.last_paid_click_date = s.visit_date
    LEFT JOIN leads AS l
        ON
            lv.last_paid_click_date <= l.created_at
            AND lv.visitor_id = l.visitor_id
    GROUP BY 1, 2, 3, 4
),

showcase AS (
    SELECT
        ta.visit_date,
        ta.visitors_count,
        ta.utm_source,
        ta.utm_medium,
        ta.utm_campaign,
        tc.total_cost,
        ta.leads_count,
        ta.purchases_count,
        ta.revenue
    FROM total_amount AS ta
    LEFT JOIN total_cost AS tc
        ON
            ta.visit_date = tc.campaign_date
            AND ta.utm_source = tc.utm_source
            AND ta.utm_medium = tc.utm_medium
            AND ta.utm_campaign = tc.utm_campaign
    ORDER BY 9 DESC NULLS LAST, 1, 2 DESC, 3, 4, 5
)

SELECT
    utm_source,
    utm_medium,
    utm_campaign,
    sum(total_cost) AS total_cost,
    coalesce(sum(revenue), 0) AS revenue,
    sum(visitors_count) AS visitors_count,
    round((sum(leads_count) / sum(visitors_count) * 100.0), 2) AS conv_to_leads,
    sum(leads_count) AS leads_count,
    CASE
        WHEN
            sum(leads_count) > 0
            THEN round((sum(purchases_count) / sum(leads_count) * 100.0), 2)
    END AS conv_to_purchases,
    sum(purchases_count) AS purchases_count,
    round(sum(total_cost) / sum(visitors_count), 2) AS cpu,
    CASE
        WHEN
            sum(leads_count) > 0
            THEN round(sum(total_cost) / sum(leads_count), 2)
    END AS cpl,
    CASE
        WHEN
            sum(purchases_count) > 0
            THEN round(sum(total_cost) / sum(purchases_count), 2)
    END AS cppu,
    round(
        (coalesce(sum(revenue), 0) - sum(total_cost)) * 100.0 / sum(total_cost),
        2
    ) AS roi,
    CASE
        WHEN
            sum(purchases_count) > 0
            THEN round(sum(revenue) / sum(purchases_count))
    END AS avg_amount
FROM showcase
WHERE total_cost > 0
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- конверсия клик-лид-покупка
-- аналогичные запросы с фильтром по vk и yandex для этих источников
WITH total_cost AS (
    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY 1, 2, 3, 4

    UNION

    SELECT
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY 1, 2, 3, 4
),

last_visit AS (
    SELECT
        visitor_id,
        max(visit_date) AS last_paid_click_date
    FROM sessions
    WHERE medium != 'organic'
    GROUP BY 1
),

total_amount AS (
    SELECT
        lv.last_paid_click_date::DATE AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        count(DISTINCT s.visitor_id) AS visitors_count,
        count(DISTINCT l.lead_id) AS leads_count,
        count(CASE
            WHEN l.status_id = 142 THEN 1
        END)
        AS purchases_count,
        sum(l.amount) AS revenue
    FROM last_visit AS lv
    INNER JOIN sessions AS s
        ON
            lv.visitor_id = s.visitor_id
            AND lv.last_paid_click_date = s.visit_date
    LEFT JOIN leads AS l
        ON
            lv.last_paid_click_date <= l.created_at
            AND lv.visitor_id = l.visitor_id
    GROUP BY 1, 2, 3, 4
),

showcase AS (
    SELECT
        ta.visit_date,
        ta.visitors_count,
        ta.utm_source,
        ta.utm_medium,
        ta.utm_campaign,
        tc.total_cost,
        ta.leads_count,
        ta.purchases_count,
        ta.revenue
    FROM total_amount AS ta
    LEFT JOIN total_cost AS tc
        ON
            ta.visit_date = tc.campaign_date
            AND ta.utm_source = tc.utm_source
            AND ta.utm_medium = tc.utm_medium
            AND ta.utm_campaign = tc.utm_campaign
    ORDER BY 9 DESC NULLS LAST, 1, 2 DESC, 3, 4, 5
)

SELECT
    sum(visitors_count) AS counting,
    CASE WHEN sum(visitors_count) = sum(visitors_count) THEN 'clicks'
    END AS group_names
FROM showcase
UNION
SELECT
    sum(leads_count) AS counting,
    CASE WHEN sum(leads_count) = sum(leads_count) THEN 'leads'
    END AS group_names
FROM showcase
UNION
SELECT
    sum(purchases_count) AS counting,
    CASE WHEN sum(purchases_count) = sum(purchases_count) THEN 'purchases'
    END AS group_names
FROM showcase
ORDER BY 1 DESC;

-- количество посещений по органике и неорганике
-- для определения их корреляции в google sheets
WITH org_tab AS (
    SELECT
        visit_date::DATE,
        count(medium) AS organic_count
    FROM sessions
    WHERE medium = 'organic'
    GROUP BY 1
)

SELECT
    s.visit_date::DATE,
    ot.organic_count,
    count(s.medium) AS not_organic_count
FROM sessions AS s
LEFT JOIN org_tab AS ot
    ON
        s.visit_date::DATE = ot.visit_date::DATE
WHERE s.medium != 'organic'
GROUP BY 1, 3;
