/* Анализ данных для агентства недвижимости
 * Часть 2. Решение ad hoc задач
 * 
 * Автор: Заславский Данила
 * Дата: 19.02.2025
*/

--Задача 1.Время активности объявлений
--title: adhoc_1
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--выделим сегменты недвижимости Санкт-Петербурга и Лен. области и посчитаем хар-ки:  
table_segment AS (
    SELECT 
    CASE
    	WHEN city_id = '6X8I'
    	    THEN 'Санкт-Петербург'
    	ELSE 'ЛенОбл'    
    END AS region,
    CASE 
    	WHEN a.days_exposition BETWEEN 1 AND 30
    	    THEN 'до месяца'
    	WHEN  a.days_exposition BETWEEN 31 AND 90
    	    THEN 'до трёх месяцев'
    	WHEN a.days_exposition BETWEEN 91 AND 180
    	    THEN 'до полугода'
    	WHEN a.days_exposition > 180
    	    THEN 'более полугода'
    	    END AS segment,
      	last_price/total_area::NUMERIC AS m_price,
      	total_area,
      	rooms,
      	balcony,
      	floor,
      	f.id
    FROM real_estate.flats f
    LEFT JOIN real_estate.advertisement a USING(id)
    LEFT JOIN real_estate.type t USING(type_id)
    WHERE id IN (SELECT * FROM filtered_id) 
          AND t.TYPE = 'город' 
          AND a.days_exposition IS NOT NULL
    )
    SELECT region,
           segment,
           COUNT(id) AS count_apart,
           AVG(m_price)::NUMERIC(10,2) AS avg_m_price,
           AVG(total_area)::NUMERIC(10,2) AS avg_area,
           PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS avg_rooms,
           PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS avg_balcony,
           PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS avg_floor
    FROM table_segment
    GROUP BY region, segment
    
--Задача 2.Сезоннность объявлений
--title: adhoc_2
  -- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
             AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))
            OR ceiling_height IS NULL
        )
),
listing_published AS (
    SELECT 
        EXTRACT(MONTH FROM first_day_exposition) AS month,
        COUNT(*) AS listings_published,
        AVG(last_price / total_area::NUMERIC) AS m_price,
        AVG(total_area) AS avg_area
    FROM real_estate.flats
    JOIN real_estate.advertisement a USING(id)
    LEFT JOIN real_estate.type t USING(type_id)
    WHERE id IN (SELECT id FROM filtered_id) AND t.TYPE = 'город'
    GROUP BY month
),
listing_removed AS (
    SELECT 
        EXTRACT(MONTH FROM (first_day_exposition + a.days_exposition::integer)) AS month,
        COUNT(*) AS listings_removed,
        AVG(last_price / total_area::NUMERIC) AS m_price,
        AVG(total_area) AS avg_area
    FROM real_estate.flats
    JOIN real_estate.advertisement a USING(id)
    LEFT JOIN real_estate.type t USING(type_id)
    WHERE id IN (SELECT id FROM filtered_id) AND a.days_exposition IS NOT NULL AND t.TYPE = 'город'
    GROUP BY month
)
SELECT 
    pub.month AS month,
    listings_published,
    RANK() OVER (ORDER BY listings_published DESC) AS rank_published,
    listings_removed,
    RANK() OVER (ORDER BY listings_removed DESC) AS rank_removed,
    ROUND(pub.m_price::NUMERIC, 2) AS avg_price_per_sqm,
    ROUND(pub.avg_area::NUMERIC, 2) AS avg_area
FROM listing_published pub
FULL JOIN listing_removed rem ON pub.month = rem.month
ORDER BY pub.month;

    --Задача 3. Анализ рынка недвижимости Ленобласти
    --title: adhoc_3
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
city_activity AS (
    SELECT 
        c.city,  -- Идентификатор города
        COUNT(*) AS total_listings,  -- Общее количество объявлений
        COUNT(days_exposition) AS total_removed,  -- Количество снятых объявлений
        AVG(a.last_price / f.total_area::NUMERIC) AS avg_m_price,  -- Средняя цена за м2
        AVG(f.total_area) AS avg_area  -- Средняя площадь
    FROM real_estate.flats f
    LEFT JOIN real_estate.advertisement a USING(id)
    LEFT JOIN real_estate.type t USING(type_id)
    LEFT JOIN real_estate.city c USING(city_id)
    WHERE f.id IN (SELECT id FROM filtered_id)  -- Используем только id из filtered_id
        AND c.city <> 'Санкт-Петербург'  -- Фильтрация по типу (город)
    GROUP BY c.city
)
SELECT 
    city,
    total_listings,
    total_removed,
    ROUND((total_removed::NUMERIC / total_listings), 2) AS share_removed,  -- Процент снятых объявлений
    avg_m_price,
    avg_area
FROM city_activity
ORDER BY total_listings DESC  -- Сортировка по количеству объявлений
LIMIT 15;
