with last_paid_visits as (
    select
        visitor_id,
        MAX(visit_date) as last_paid_click_date
    from sessions
    where medium != 'organic'
    group by 1
),

atribution_showcase as (
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
    from last_paid_visits as lp
    left join sessions as s
        on
            lp.visitor_id = s.visitor_id
            and lp.last_paid_click_date = s.visit_date
            and s.medium != 'organic'
    left join leads as l
        on s.visitor_id = l.visitor_id
    order by 8 desc nulls last, 2, 3, 4, 5
)

select
    utm_source,
    utm_medium,
    utm_campaign,
    COUNT(distinct lead_id) as leads_count
from atribution_showcase
group by 1, 2, 3
order by 4 DESC;
	
