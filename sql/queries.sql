-- ============================================================
-- PROYECTO: Dashboard de Ventas Ecommerce — Sample Superstore
-- HERRAMIENTA: MySQL Workbench
-- DATASET: superstore_clean (importado desde superstore.csv)
-- ============================================================
-- NOTA: El dataset fue importado usando un script de Python
-- (import_to_mysql.py) en lugar del wizard de Workbench,
-- ya que el wizard omitía ~300 filas al procesar el CSV.
-- El script garantiza las 9,994 filas completas.
-- ============================================================


-- ============================================================
-- PASO 1 — PREPARACIÓN DE FECHAS
-- Las fechas originales vienen como texto (M/DD/YYYY).
-- Se crean columnas nuevas con formato DATE para operar con ellas.
-- ============================================================

ALTER TABLE superstore_clean
  ADD COLUMN order_date_clean DATE,
  ADD COLUMN ship_date_clean  DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE superstore_clean
SET order_date_clean = STR_TO_DATE(order_date, '%m/%d/%Y'),
    ship_date_clean  = STR_TO_DATE(ship_date,  '%m/%d/%Y');

SET SQL_SAFE_UPDATES = 1;

-- Verificar conversión correcta
SELECT order_date, order_date_clean, ship_date, ship_date_clean
FROM superstore_clean
LIMIT 5;

-- Verificar que no quedaron NULLs
SELECT COUNT(*) AS nulos_fecha
FROM superstore_clean
WHERE order_date_clean IS NULL;
-- Resultado esperado: 0


-- ============================================================
-- PASO 2 — MÉTRICAS GENERALES
-- ============================================================

-- Ventas totales
SELECT SUM(sales) AS total_sales
FROM superstore_clean;
-- Resultado: $2,297,201

-- Ventas totales y ticket promedio
SELECT
  SUM(sales) AS total_sales,
  AVG(sales) AS avg_ticket
FROM superstore_clean;
-- Resultado: $2,297,201 | ticket promedio $229.85

-- Clientes únicos
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM superstore_clean;
-- Resultado: 793

-- Pedidos únicos
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM superstore_clean;
-- Resultado: 5,009

-- Ciudades únicas
SELECT COUNT(DISTINCT city) AS total_cities
FROM superstore_clean;
-- Resultado: 529


-- ============================================================
-- PASO 3 — ANÁLISIS TEMPORAL
-- ============================================================

-- Ventas por año
SELECT
  YEAR(order_date_clean) AS year,
  SUM(sales)             AS total_sales
FROM superstore_clean
GROUP BY year
ORDER BY year;
-- 2014: $484,247 | 2015: $470,532 | 2016: $609,205 | 2017: $733,215

-- Ventas por mes
SELECT
  DATE_FORMAT(order_date_clean, '%Y-%m') AS month,
  SUM(sales)                             AS total_sales
FROM superstore_clean
GROUP BY month
ORDER BY month;


-- ============================================================
-- PASO 4 — ANÁLISIS GEOGRÁFICO
-- ============================================================

-- Top 10 ciudades con más ventas
SELECT
  city,
  SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY city
ORDER BY total_sales DESC
LIMIT 10;
-- New York City $256,368 | Los Angeles $175,851 | Seattle $119,540

-- Margen de profit por región
SELECT
  region,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct
FROM superstore_clean
GROUP BY region
ORDER BY margin_pct DESC;
-- West 14.9% | East 13.5% | South 11.9% | Central 7.9%


-- ============================================================
-- PASO 5 — ANÁLISIS DE CLIENTES Y SEGMENTOS
-- ============================================================

-- Ventas por segmento
SELECT
  segment,
  SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY segment
ORDER BY total_sales DESC;
-- Consumer $1,161,401 | Corporate $706,146 | Home Office $429,653

-- Top 10 clientes por número de órdenes
SELECT
  customer_name,
  COUNT(DISTINCT order_id) AS total_orders
FROM superstore_clean
GROUP BY customer_name
ORDER BY total_orders DESC
LIMIT 10;

-- Top 10 clientes por gasto total
SELECT
  customer_name,
  SUM(sales) AS total_spent
FROM superstore_clean
GROUP BY customer_name
ORDER BY total_spent DESC
LIMIT 10;
-- Sean Miller $25,043 | Tamara Chand $19,052 | Raymond Buch $15,117

-- Clientes no recurrentes (una sola compra)
SELECT
  customer_id,
  COUNT(order_id) AS orders
FROM superstore_clean
GROUP BY customer_id
HAVING orders = 1;


-- ============================================================
-- PASO 6 — ANÁLISIS DE RENTABILIDAD
-- ============================================================

-- Margen de profit por categoría
SELECT
  category,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct,
  ROUND(AVG(discount) * 100, 2)               AS avg_discount_pct
FROM superstore_clean
GROUP BY category
ORDER BY margin_pct DESC;
-- Technology 17.4% | Office Supplies 17.0% | Furniture 2.5%

-- Subcategorías menos rentables
SELECT
  `sub-category`,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct
FROM superstore_clean
GROUP BY `sub-category`
ORDER BY total_profit ASC
LIMIT 6;
-- Tables: -$17,725 | Bookcases: -$3,473 | Supplies: -$1,189

-- Impacto de los descuentos en el profit
SELECT
  CASE
    WHEN discount = 0      THEN '0%'
    WHEN discount <= 0.20  THEN '1-20%'
    WHEN discount <= 0.40  THEN '21-40%'
    ELSE '41%+'
  END                       AS discount_range,
  COUNT(*)                  AS total_orders,
  ROUND(AVG(profit), 2)    AS avg_profit,
  ROUND(SUM(profit), 2)    AS total_profit
FROM superstore_clean
GROUP BY discount_range
ORDER BY avg_profit DESC;
-- 0%: avg $66.90 | 1-20%: avg $26.50 | 21-40%: avg -$77.86 | 41%+: avg -$106.71


-- ============================================================
-- PASO 7 — ANÁLISIS LOGÍSTICO
-- ============================================================

-- Métodos de envío más usados
SELECT
  ship_mode,
  COUNT(*) AS total_orders
FROM superstore_clean
GROUP BY ship_mode
ORDER BY total_orders DESC;
-- Standard Class 5,903 | Second Class 1,945 | First Class 1,538 | Same Day 543 (aprox)

-- Tiempo promedio general de envío
SELECT AVG(DATEDIFF(ship_date_clean, order_date_clean)) AS avg_shipping_days
FROM superstore_clean;
-- Resultado: 3.96 días

-- Eficiencia logística por método de envío
SELECT
  ship_mode,
  ROUND(AVG(DATEDIFF(ship_date_clean, order_date_clean)), 2) AS avg_days,
  COUNT(*) AS total_orders
FROM superstore_clean
GROUP BY ship_mode
ORDER BY avg_days;
-- Same Day 0.04d | First Class 2.18d | Second Class 3.24d | Standard Class 5.00d
