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

showcase_total_cost as (
    select
        date_trunc('day', s.visit_date) as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        count(s.visitor_id) as visitors_count,
        coalesce(vy.total_cost, 0) as total_cost,
        count(distinct l.lead_id) as leads_count,
        count(p.lead_id) as purchases_count,
        coalesce(sum(p.amount), 0) as revenue
    from sessions as s
    left join vy_ads_cost as vy
        on
            s.source = vy.utm_source
            and s.medium = vy.utm_medium
            and s.campaign = vy.utm_campaign
            and date_trunc('day', s.visit_date) = vy.campaign_date
    left join leads as l
        on s.visitor_id = l.visitor_id
    left join purchases as p
        on s.visitor_id = p.visitor_id
    where s.medium != 'organic'
    group by 1, 2, 3, 4, 6
    order by 9 desc, 1, 5 desc, 2, 3, 4
),

last_visit as (
    select
        visitor_id,
        max(date_trunc('day', visit_date)) as last_paid_click_date
    from sessions
    where medium != 'organic'
    group by 1
)

select distinct
    lv.last_paid_click_date,
    stc.utm_source,
    stc.utm_medium,
    stc.utm_campaign,
    stc.total_cost
from showcase_total_cost as stc
inner join last_visit as lv
    on lv.last_paid_click_date = stc.visit_date
order by 5 desc, 1;
