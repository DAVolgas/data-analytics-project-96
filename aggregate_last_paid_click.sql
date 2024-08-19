with vy_ads_cost as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from vk_ads

    union

    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent
    from ya_ads
),

total_cost as (
    select
        campaign_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vy_ads_cost
    group by 1, 2, 3, 4
),

last_visit as (
    select
        visitor_id,
        max(visit_date) as last_paid_click_date
    from sessions
    where medium != 'organic'
    group by 1
),

total_amount as (
    select
        lv.last_paid_click_date::date as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        count(distinct s.visitor_id) as visitors_count,
        count(distinct l.lead_id) as leads_count,
        count(case
            when l.status_id = 142 then 1
        end)
        as purchases_count,
        sum(l.amount) as revenue
    from last_visit as lv
    inner join sessions as s
        on
            lv.visitor_id = s.visitor_id
            and lv.last_paid_click_date = s.visit_date
    left join leads as l
        on
            lv.last_paid_click_date <= l.created_at
            and lv.visitor_id = l.visitor_id
    group by 1, 2, 3, 4
)

select
    ta.visit_date,
    ta.visitors_count,
    ta.utm_source,
    ta.utm_medium,
    ta.utm_campaign,
    tc.total_cost,
    ta.leads_count,
    ta.purchases_count,
    ta.revenue
from total_amount as ta
left join total_cost as tc
    on
        ta.visit_date = tc.campaign_date
        and ta.utm_source = tc.utm_source
        and ta.utm_medium = tc.utm_medium
        and ta.utm_campaign = tc.utm_campaign
order by 9 desc nulls last, 1, 2 desc, 3, 4, 5
