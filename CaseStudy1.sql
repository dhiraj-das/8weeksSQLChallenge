CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-------------------------------------------------------------------------------------------------------

/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?

SELECT
  	a.customer_id,
    sum(b.price)
FROM dannys_diner.sales a
LEFT JOIN dannys_diner.menu b
ON a.product_id = b.product_id
GROUP BY 1;

-- 2. How many days has each customer visited the restaurant?

SELECT
  	a.customer_id,
    count(distinct order_date)
FROM dannys_diner.sales a
GROUP BY 1;

-- 3. What was the first item from the menu purchased by each customer?

select customer_id, array_agg(product_name) from (
	select *, min(order_date) over (partition by customer_id) 		as first_order_date
  from dannys_diner.sales
)a 
left join dannys_diner.menu b
on a.product_id = b.product_id
where order_date = first_order_date
group by 1
order by 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select customer_id, product_name, count(c.product_id)
from dannys_diner.sales d
inner join 
(
  select product_id, ranking from
	(
    select *, dense_rank() over (order by order_count desc) 		as ranking from 
		(
      select product_id, count(product_id) as order_count
		  from dannys_diner.sales
		  group by 1
      )a
    )b
  where ranking = 1
)c
on c.product_id = d.product_id
left join dannys_diner.menu e
on e.product_id = d.product_id
group by 1,2
;

-- 5. Which item was the most popular for each customer?

select customer_id, array_agg(product_name) from 
(
  select *, dense_rank() over (partition by customer_id order by  item_count desc) as ranking from
  (
    select customer_id, product_id, count(product_id) as item_count
	  from dannys_diner.sales
	  group by 1,2
  )a
)b 
left join dannys_diner.menu c
on c.product_id = b.product_id
where ranking = 1
group by 1
;

-- 6. Which item was purchased first by the customer after they became a member?

select customer_id, product_id from
(
  select *, dense_rank() over (partition by a.customer_id order by order_date asc) 
  as chronological_orders from
  (
    select a.customer_id, a.product_id, order_date
    from dannys_diner.sales a
    left join dannys_diner.menu b
    on a.product_id = b.product_id
    inner join dannys_diner.members c
    on a.customer_id = c.customer_id 
    and a.order_date > c.join_date
  )a
)b
where chronological_orders =1
;

-- 7. Which item was purchased just before the customer became a member?

select customer_id, product_id from (
  select *, dense_rank() over (partition by a.customer_id order by order_date desc) as chronological_orders 
  from
  (
    select a.customer_id, a.product_id, order_date
    from dannys_diner.sales a
    left join dannys_diner.menu b
    on a.product_id = b.product_id
    inner join dannys_diner.members c
    on a.customer_id = c.customer_id 
    and a.order_date < c.join_date
    )a
  )b 
  where chronological_orders =1
;

-- 8. What is the total items and amount spent for each member before they became a member?

select customer_id, count(a.product_id), sum(price) from 
(
  select a.customer_id, a.product_id, order_date 
  from dannys_diner.sales a
  left join dannys_diner.menu b
  on a.product_id = b.product_id
  inner join dannys_diner.members c
  on a.customer_id = c.customer_id 
  and a.order_date < c.join_date
)a
left join dannys_diner.menu b
on a.product_id = b.product_id
group by 1
; 

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select customer_id, sum(points) from 
(
  select *,
  case when product_id = 1 then 20*total_spent else 10*total_spent end as points from 
  (
    select customer_id, a.product_id, count(a.product_id) as qty_per_item, sum(price) as total_spent
    from dannys_diner.sales a
    left join dannys_diner.menu b
    on a.product_id = b.product_id
    group by 1,2
  )a
)b
group by 1
;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

select b.customer_id, sum(points) from 
(
  select a.customer_id, a.product_id, 
  case 
    when order_date < join_date + 6 and order_date >= join_date then 20*price
    when a.product_id = 1 then 20*price
    when a.product_id <> 1 then 10*price 
  end as points from 
  (
    select a.product_id, 
    a.customer_id, order_date, join_date, price
    from dannys_diner.sales a
    left join dannys_diner.menu b
    on a.product_id = b.product_id
    inner join dannys_diner.members c
    on a.customer_id = c.customer_id
    and a.order_date <= '2021-01-31'
  )a
)b
group by 1
;
