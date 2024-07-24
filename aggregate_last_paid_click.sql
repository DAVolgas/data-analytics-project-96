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
)

select
    lv.last_paid_click_date::date as visit_date,
    count(distinct s.visitor_id) as visitors_count,
    s.source as utm_source,
    s.medium as utm_medium,
    s.campaign as utm_campaign,
    vy.total_cost,
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
    on lv.visitor_id = p.visitor_id
    and l.lead_id = p.lead_id
group by 1, 3, 4, 5, 6
order by 9 desc nulls last, 1, 2 desc, 3, 4, 5;