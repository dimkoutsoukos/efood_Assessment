-- The idea is to create as many CTE'as needed, in order to have temporary tables to store the required data, and later to JOIN all the temporary tables together in one query, and have the final result


-- First, the cities that have more than 1000 orders are identifies
WITH top1k AS
(
  SELECT city, COUNT(*) AS citycount
  FROM `main_assessment.orders`
  GROUP BY city
  HAVING citycount > 1000
)

-- Then we use the table created above in a JOIN, so as we keep only the cities that have more than 1000 order, in the original table
, cities1k AS
(
  SELECT orders.*
  FROM `main_assessment.orders` AS orders
  INNER JOIN top1k ON top1k.city = orders.city
)

-- A new temporary table is created from the above table, but this table costist only of orders containing breakfast
, breakfast AS
(
  SELECT * 
  FROM cities1k
  WHERE cuisine = 'Breakfast' 
)

-- Here we start calculating the required metrics, starting with the baskets, that are the amount per order for every city. In this step, the calculation takes place only for the Breakfast baskets
, breakfast_basket AS
(
  SELECT city, SUM(amount)/COUNT(*) as breakfast_basket
  FROM breakfast
  GROUP BY city
)

-- The same methodology is applied to calculate the baskets for all the orders
, efood_basket AS
(
  SELECT city, SUM(amount)/COUNT(*) as efood_basket
  FROM cities1k
  GROUP BY city
)

-- Here we calculate the frequency, meaning the amount of orders per customer, for each city. First the calculation is done for Breakfast orders.
, breakfast_freq AS
(
  SELECT city, COUNT(*)/ COUNT(DISTINCT user_id) AS breakfast_freq
  FROM breakfast
  GROUP BY city
)

--  And here the same calculation is done for all the orders
, efood_freq AS
(
  SELECT city, COUNT(*)/ COUNT(DISTINCT user_id) AS efood_freq
  FROM cities1k
  GROUP BY city
)

--  Here we need to calculate the percentage of users for each city, that have order more than 3 times. The first step is to count how many orders each customer has, and keep in a temporary
--  table only those who have more than 3 orders. Information about the city from which each customer has placed the order, is also stored. This is calculated for Breakfast orders
, breakfast_users3 AS 
(
  SELECT user_id,city, COUNT(*) AS breakfast_users3
  FROM breakfast
  GROUP BY user_id, city
  HAVING COUNT(*) > 3

)

-- Next, the number of these users per city is calculated
, breakfast_users3_count AS
(
  SELECT city, COUNT(user_id) AS breakfast_users3_count
  FROM breakfast_users3
  GROUP BY city
)

-- Now, the number of total users per city is calculated, only for Breakfast orders
, breakfast_users_count AS
(
  SELECT city, count(distinct user_id) AS breakfast_users_count
  FROM breakfast
  GROUP BY city
)

-- Having all the information needed for the final calculation, the 2 temporary tables are JOINed,and the percentage of the users with 3 or more orders compared to the total users per city 
-- for Breakfast orders is calculated
, breakfast_users3freq_perc AS
(
  SELECT breakfast_users_count.city, breakfast_users3_count.breakfast_users3_count/breakfast_users_count.breakfast_users_count AS  breakfast_users3freq_perc
  FROM breakfast_users_count
  INNER JOIN breakfast_users3_count ON breakfast_users3_count.city=breakfast_users_count.city

)


-- The same methodology is applied to calculate the metric for all the orders
, city_users3 AS 
(
  SELECT user_id,city, COUNT(*) AS city_users3
  FROM cities1k
  GROUP BY user_id, city
  HAVING COUNT(*) > 3

)

, efood_users3_count AS
(
  SELECT city, COUNT(user_id) AS efood_users3_count
  FROM city_users3
  GROUP BY city
)

, efood_users_count AS
(
  SELECT city, count(distinct user_id) AS efood_users_count
  FROM cities1k
  GROUP BY city
)

, efood_users3freq_perc AS
(
  SELECT efood_users_count.city, efood_users3_count.efood_users3_count/efood_users_count.efood_users_count AS  efood_users3freq_perc
  FROM efood_users_count
  INNER JOIN efood_users3_count ON efood_users3_count.city=efood_users_count.city

)

-- This temporary table is created to have a sorted list of the cities with the most breakfast orders.
, temp_order AS
(
  SELECT city, COUNT(*) AS sort
  FROM breakfast
  GROUP BY city
  ORDER BY sort
)


-- In this main query, all the temporary tables containing the needed data are JOINed together to form the final requested result. The raws are sorted according to the above temporary table
-- while we show only the top 5 entries of the table created.
SELECT breakfast_basket.city,
breakfast_basket.breakfast_basket,
efood_basket.efood_basket,
breakfast_freq.breakfast_freq,
efood_freq.efood_freq,
breakfast_users3freq_perc.breakfast_users3freq_perc,
efood_users3freq_perc.efood_users3freq_perc
FROM breakfast_basket
INNER JOIN efood_basket ON efood_basket.city= breakfast_basket.city
INNER JOIN breakfast_freq ON breakfast_freq.city= breakfast_basket.city
INNER JOIN efood_freq ON efood_freq.city= breakfast_basket.city
INNER JOIN breakfast_users3freq_perc ON breakfast_users3freq_perc.city= breakfast_basket.city
INNER JOIN efood_users3freq_perc ON efood_users3freq_perc.city= breakfast_basket.city
INNER JOIN temp_order ON temp_order.city=breakfast_basket.city
ORDER BY temp_order.sort DESC
LIMIT 5
