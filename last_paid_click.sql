with atribution_showcase as (
    select
        s.visitor_id,
        s.visit_date,
        s."source" as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
    where s.medium != 'organic'
    order by 8 desc nulls last, 2, 3, 4, 5
),

last_paid_visits as (
    select
        visitor_id,
        MAX(visit_date) as last_paid_click_date
    from atribution_showcase
    where utm_medium != 'organic'
    group by 1
)

select
    a.visitor_id,
    a.lead_id,
    a.created_at,
    a.amount,
    a.closing_reason,
    a.status_id,
    l.last_paid_click_date,
    a.utm_source,
    a.utm_medium,
    a.utm_campaign
from atribution_showcase as a
inner join last_paid_visits as l
    on a.visitor_id = l.visitor_id
where
    a.created_at is not null
    and a.created_at >= l.last_paid_click_date;
	
