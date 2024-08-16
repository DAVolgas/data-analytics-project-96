-- общее количество посетителей
SELECT
    visit_date::DATE,
    CASE
        WHEN medium = 'organic' THEN 'organic'
        ELSE 'paid'
    END AS source_type,
    source,
    medium,
    campaign,
    count(DISTINCT visitor_id)
FROM sessions
GROUP BY 1, 2, 3, 4, 5
ORDER BY 6 DESC;

-- общее количество лидов
SELECT
    created_at::DATE,
    count(DISTINCT lead_id)
FROM leads
GROUP BY 1;

-- LPC использована в следующих графиках:
-- количество лидов по LPC, количество лидов по платным каналам,
-- количество посетителей по платным каналам, ТОП-10 по посетителям
with last_paid_visits as (
    select
        visitor_id,
        MAX(visit_date) as last_paid_click_date
    from sessions
    where medium != 'organic'
    group by 1
)

select
    lp.visitor_id,
    lp.last_paid_click_date as visit_date,
    s."source" as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
from sessions as s
inner join last_paid_visits as lp
    on
        s.visitor_id = lp.visitor_id
        and s.visit_date = lp.last_paid_click_date
left join leads as l
    on
        s.visitor_id = l.visitor_id
        and s.visit_date <= l.created_at
where s.medium != 'organic'
order by 8 desc nulls last, 2, 3, 4, 5;

-- срок, через который закрывается 90% лидов
-- запрос к витрине lpc
select 
	percentile_disc(0.9) within group (order by interval) as leads_close_interval
from show_case_lpc
where lead_id is not NULL;

-- aggregate LPC использована в следущих графиках:
-- затраты на рекламу по платным кампаниям и по vk/yandex
with vy_ads_cost as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4

    union

    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
),

purchases as (
    select
        visitor_id,
        lead_id,
        amount
    from leads
    where status_id = 142
),

last_visit as (
    select
        visitor_id,
        max(visit_date) as last_paid_click_date
    from sessions
    where medium != 'organic'
    group by 1
),

showcase as (
    select
        lv.last_paid_click_date::date as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        vy.total_cost,
        count(distinct s.visitor_id) as visitors_count,
        count(distinct l.lead_id) as leads_count,
        count(p.lead_id) as purchases_count,
        sum(p.amount) as revenue
    from last_visit as lv
    inner join sessions as s
        on
            lv.visitor_id = s.visitor_id
            and lv.last_paid_click_date = s.visit_date
    left join vy_ads_cost as vy
        on
            lv.last_paid_click_date::date = vy.campaign_date
            and s.source = vy.utm_source
            and s.medium = vy.utm_medium
            and s.campaign = vy.utm_campaign
    left join leads as l
        on
            lv.last_paid_click_date <= l.created_at
            and lv.visitor_id = l.visitor_id
    left join purchases as p
        on
            lv.visitor_id = p.visitor_id
            and l.lead_id = p.lead_id
    group by 1, 2, 3, 4, 5
    order by 9 desc nulls last, 1, 2 desc, 3, 4, 5
)

select
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
from showcase;

-- для общего графика по окупаемости рекламы
-- запрос к витрине aggregate lpc
SELECT
    utm_source,
    SUM(total_cost) AS total_cost,
    SUM(revenue) AS revenue,
    ROUND((SUM(revenue) - SUM(total_cost)) * 100.0 / SUM(total_cost), 2) AS roi
FROM showcase
WHERE total_cost > 0
GROUP BY 1
ORDER BY 2 DESC;

-- для итоговой таблицы с метриками по utm_source
-- запрос к витрине aggregate lpc
SELECT
    visit_date::DATE,
    utm_source,
    SUM(total_cost) AS total_cost,
    COALESCE(SUM(revenue), 0) AS revenue,
    SUM(visitors_count) AS visitors_count,
    SUM(leads_count) AS leads_count,
    SUM(purchases_count) AS purchases_count,
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    CASE
        WHEN
            SUM(leads_count) > 0
            THEN ROUND(SUM(total_cost) / SUM(leads_count), 2)
    END AS cpl,
    CASE
        WHEN
            SUM(purchases_count) > 0
            THEN ROUND(SUM(total_cost) / SUM(purchases_count), 2)
    END AS cppu,
    ROUND(
        (COALESCE(SUM(revenue), 0) - SUM(total_cost)) * 100.0 / SUM(total_cost),
        2
    ) AS roi,
    CASE
        WHEN
            SUM(purchases_count) > 0
            THEN ROUND(SUM(revenue) / SUM(purchases_count))
    END AS avg_amount
FROM showcase
WHERE total_cost > 0
GROUP BY 1, 2
ORDER BY 3 DESC;

-- аналогичный предыдущему запрос с метриками по всем utm
-- запрос к витрине aggregate lpc
SELECT
    utm_source,
    utm_medium,
    utm_campaign,
    SUM(total_cost) AS total_cost,
    COALESCE(SUM(revenue), 0) AS revenue,
    SUM(visitors_count) AS visitors_count,
    ROUND((SUM(leads_count) / SUM(visitors_count) * 100.0), 2) AS conv_to_leads,
    SUM(leads_count) AS leads_count,
    CASE
        WHEN
            SUM(leads_count) > 0
            THEN ROUND((SUM(purchases_count) / SUM(leads_count) * 100.0), 2)
    END AS conv_to_purchases,
    SUM(purchases_count) AS purchases_count,
    ROUND(SUM(total_cost) / SUM(visitors_count), 2) AS cpu,
    CASE
        WHEN
            SUM(leads_count) > 0
            THEN ROUND(SUM(total_cost) / SUM(leads_count), 2)
    END AS cpl,
    CASE
        WHEN
            SUM(purchases_count) > 0
            THEN ROUND(SUM(total_cost) / SUM(purchases_count), 2)
    END AS cppu,
    ROUND(
        (COALESCE(SUM(revenue), 0) - SUM(total_cost)) * 100.0 / SUM(total_cost),
        2
    ) AS roi,
    CASE
        WHEN
            SUM(purchases_count) > 0
            THEN ROUND(SUM(revenue) / SUM(purchases_count))
    END AS avg_amount
FROM showcase
WHERE total_cost > 0
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- конверсия клик-лид-покупка
-- аналогичные запросы с фильтром по vk и yandex для этих источников
-- запрос к витрине aggregate lpc 
select
    sum(visitors_count),
    case when sum(visitors_count) = sum(visitors_count) then 'clicks'
    end as groups
from showcase

union

select
    sum(leads_count),
    case when sum(leads_count) = sum(leads_count) then 'leads'
    end as groups
from showcase

union

select
    sum(purchases_count),
    case when sum(purchases_count) = sum(purchases_count) then 'purchases'
    end as groups
from showcase
order by 1 DESC;

-- количество посещений по органике и неорганике
-- для определения их корреляции в google sheets
with org_tab as (
    select
        visit_date::date,
        count(medium) as organic_count
    from sessions
    where medium = 'organic'
    group by 1
)

select
    s.visit_date::date,
    count(s.medium) as not_organic_count,
    ot.organic_count
from sessions as s
left join org_tab as ot
    on
        s.visit_date::date = ot.visit_date::date
where s.medium != 'organic'
group by 1, 3;
