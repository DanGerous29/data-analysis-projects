/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Заславский Данила
 * Дата: 28.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
--title: Запрос 1.1
SELECT COUNT(id) AS count_id,
       SUM(payer) AS count_payers,
       ROUND(AVG(payer)::numeric,3) AS share_payers --округляем до 3 знаков для читаемости
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
--title: Запрос 1.2
SELECT race,
       count_payers,
       count_id,
       ROUND(count_payers::numeric/count_id,3) AS share_payer_race
FROM (
		SELECT DISTINCT race,
       	    SUM(payer) OVER(PARTITION BY race_id) AS count_payers,       
        	COUNT(*) OVER(PARTITION BY race_id) AS count_id
		FROM fantasy.users
		LEFT JOIN fantasy.race USING(race_id) ) AS t1 
ORDER BY share_payer_race DESC;     
       
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
--title: Запрос 2.1
SELECT 'all' AS filter_type,
       COUNT(transaction_id) AS count_tranc,
	   SUM(amount) AS sum_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount,
       ROUND(AVG(amount)::numeric,3) AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS med_amount,
       ROUND(STDDEV(amount)::numeric,3) AS stddev_amount
FROM fantasy.events
UNION ALL
SELECT 'filtered' AS filter_type,
       COUNT(transaction_id) AS count_tranc,
	   SUM(amount) AS sum_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount,
       ROUND(AVG(amount)::numeric,3) AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS med_amount,
       ROUND(STDDEV(amount)::numeric,3) AS stddev_amount
FROM fantasy.events
WHERE amount <> 0;

-- 2.2: Аномальные нулевые покупки:
--title: Запрос 2.2
WITH zero_price_purchases AS (
    SELECT e.id, 
           e.item_code, 
           i.game_items,
           COUNT(*) AS zero_purchases
    FROM fantasy.events e
    LEFT JOIN fantasy.items i USING(item_code)
    WHERE e.amount = 0
    GROUP BY e.id, e.item_code, i.game_items
),
total_counts AS (
    SELECT COUNT(transaction_id) AS total_count,
           COUNT(CASE WHEN amount = 0 THEN transaction_id END) AS zero_amount
    FROM fantasy.events
)
SELECT zpp.id,
       zpp.item_code,
       zpp.game_items,
       zpp.zero_purchases,
       tc.zero_amount,
       ROUND(tc.zero_amount::numeric / tc.total_count, 5) AS share_zero_amount
FROM zero_price_purchases zpp
LEFT JOIN total_counts tc ON TRUE
ORDER BY zpp.zero_purchases DESC;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--title: Запрос 2.3
WITH purchase_stats AS (
    SELECT  u.id,
            COUNT(fe.transaction_id) AS total_transactions,
            SUM(fe.amount) AS total_spent
    FROM fantasy.users AS u
    LEFT JOIN fantasy.events AS fe ON u.id = fe.id
    WHERE fe.amount <> 0
    GROUP BY u.id
    HAVING COUNT(fe.transaction_id) > 0
)
SELECT CASE WHEN u.payer = 1 THEN 'Платящие' ELSE 'Неплатящие' END AS payer,
       COUNT(p.id) AS count_players,  
       ROUND(AVG(p.total_transactions)::numeric, 3) AS avg_transaction,  
       ROUND(AVG(p.total_spent)::numeric, 3) AS avg_amount  
FROM fantasy.users AS u
LEFT JOIN purchase_stats AS p ON u.id = p.id
GROUP BY u.payer;

--Дополнительная таблица для сравнения платящих/неплатящих в разрезе рас
--title:2.3.1
WITH purchase_stats AS (
    SELECT u.id,
           COUNT(fe.transaction_id) AS total_transactions,
           SUM(fe.amount) AS total_spent
    FROM fantasy.users AS u
    LEFT JOIN fantasy.events AS fe ON u.id = fe.id
    WHERE fe.amount <> 0
    GROUP BY u.id
    HAVING COUNT(fe.transaction_id) > 0
)
SELECT r.race,
       CASE WHEN u.payer = 1 THEN 'Платящие' ELSE 'Неплатящие' END AS payer,
       COUNT(p.id) AS count_players,  
       ROUND(AVG(p.total_transactions)::numeric, 3) AS avg_transaction,  
       ROUND(AVG(p.total_spent)::numeric, 3) AS avg_amount
FROM fantasy.users AS u
LEFT JOIN purchase_stats AS p ON u.id = p.id
LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
GROUP BY  u.payer, r.race
ORDER BY  r.race, avg_amount DESC;

-- 2.4: Популярные эпические предметы:
--title: Запрос 2.4
WITH 
  t1 AS (
    SELECT item_code,
           COUNT(transaction_id) AS count_abs, --абс. кол-во продаж
           COUNT(DISTINCT id) AS count_users --кол-во игроков, купивших предмет
    FROM fantasy.events 
    WHERE amount <> 0
    GROUP BY item_code 
  ),
  t2 AS (
  SELECT  item_code,
  		  count_abs,
          count_users,
          SUM(count_abs) OVER() AS count_all_sales, -- общее кол-во продаж всех предметов
          ROUND(count_abs::numeric / SUM(count_abs) OVER (), 3) AS relative_sales, -- отн. количество продаж
          ROUND(count_users::numeric / (SELECT COUNT(DISTINCT id) 
                                        FROM fantasy.events 
                                        WHERE amount <> 0), 3) AS user_ratio -- доля игроков, купивших предмет
  FROM t1
  )
   SELECT game_items,
          count_abs,
          relative_sales,
          user_ratio
   FROM t2
   LEFT JOIN fantasy.items i USING(item_code)
   ORDER BY relative_sales DESC;
    
-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--title: ad hoc запрос 1
WITH t1 AS (
  SELECT u.race_id,
         COUNT(u.id) AS count_id 
  FROM fantasy.users u
  GROUP BY u.race_id
),
t2 AS (
  SELECT u.race_id,
         COUNT(DISTINCT CASE WHEN e.amount > 0 THEN u.id END) AS count_events, 
         COUNT(DISTINCT CASE WHEN u.payer = 1 AND e.amount > 0 THEN u.id END)::numeric 
         / COUNT(DISTINCT CASE WHEN e.amount > 0 THEN u.id END) AS user_ratio_pay, 
         COUNT(e.transaction_id)::numeric / COUNT(DISTINCT e.id) AS avg_pay_for_user, 
         SUM(e.amount) / COUNT(e.transaction_id) AS avg_amount_per_purchase, 
         SUM(e.amount) / COUNT(DISTINCT e.id) AS avg_amount_for_user 
  FROM fantasy.users u
  LEFT JOIN fantasy.events e ON e.id = u.id AND e.amount > 0 
  GROUP BY u.race_id
)
SELECT t1.race_id,
       r.race,
       t1.count_id, -- Общее количество зарегистрированных игроков
       t2.count_events, -- Количество игроков, которые совершают покупки
       ROUND(t2.count_events::NUMERIC / t1.count_id, 3) AS user_ratio, -- Доля игроков, совершающих покупки
       ROUND(t2.user_ratio_pay::numeric, 3) AS user_ratio_pay, -- Доля платящих от совершивших покупки
       ROUND(t2.avg_pay_for_user::numeric, 3) AS avg_pay_for_user, -- Среднее количество покупок на одного игрока
       ROUND(t2.avg_amount_per_purchase::numeric, 3) AS avg_amount_per_purchase, -- Средняя стоимость одной покупки
       ROUND(t2.avg_amount_for_user::numeric, 3) AS avg_amount_for_user -- Средняя суммарная стоимость всех покупок на одного игрока
FROM t1
LEFT JOIN t2 ON t1.race_id = t2.race_id
INNER JOIN fantasy.race r ON t1.race_id = r.race_id
ORDER BY avg_pay_for_user;

-- Задача 2: Частота покупок
--title: ad hoc запрос 2
WITH purchase_intervals AS (
  SELECT e.id,
         e.date::DATE AS purchase_date,
         LAG(e.date::DATE) OVER (PARTITION BY e.id ORDER BY e.date::DATE) AS prev_purchase_date,
         u.payer
  FROM fantasy.events e
  JOIN fantasy.users u ON e.id = u.id
  WHERE e.amount > 0 
),
user_purchase_stats AS (
  SELECT id,
         COUNT(purchase_date) AS total_purchases, 
         AVG(purchase_date - prev_purchase_date) AS avg_days_between_purchases,
         payer,
         NTILE(3) OVER (ORDER BY AVG(purchase_date - prev_purchase_date)) AS frequency_group
  FROM purchase_intervals
  GROUP BY id, payer
  HAVING COUNT(purchase_date) >= 25 
)
SELECT CASE 
	        WHEN frequency_group = 1 THEN 'высокая частота'
            WHEN frequency_group = 2 THEN 'умеренная частота'
            WHEN frequency_group = 3 THEN 'низкая частота'
       END AS frequency_label,
       COUNT(id) AS total_users, 
       COUNT(CASE WHEN payer = 1 THEN id END) AS paying_users, 
       ROUND(COUNT(CASE WHEN payer = 1 THEN id END)::NUMERIC / COUNT(id),3) AS paying_ratio, 
       ROUND(AVG(total_purchases)::NUMERIC,3) AS avg_purchases_per_user, 
       ROUND(AVG(avg_days_between_purchases)::NUMERIC,3) AS avg_days_between_purchases 
FROM user_purchase_stats
GROUP BY frequency_group;
