# 📊 Dashboard de Ventas Ecommerce — Sample Superstore

Proyecto de portafolio de análisis de datos utilizando el dataset **Sample Superstore** (9,994 filas).  
El objetivo fue responder preguntas clave de negocio usando SQL, y visualizar los resultados en Power BI.

---

## 🗂️ Estructura del repositorio

```
├── data/
│   └── superstore.csv              # Dataset original (fuente: Kaggle)
├── sql/
│   └── queries.sql                 # Todas las consultas del análisis
├── python/
│   └── import_to_mysql.py          # Script de importación a MySQL
├── powerbi/
│   └── dashboard_superstore.pbix   # Dashboard Power BI (4 páginas)
├── backgrounds/
│   └── overview_bg.jpg             # Fondo página Resumen General
│   └── productos_bg.jpg            # Fondo página Productos y Rentabilidad
│   └── clientes_bg.jpg             # Fondo página Análisis de Clientes
│   └── logistica_bg.jpg            # Fondo página Logística y Envíos
├── screenshots/
│   └── overview.jpg                # Captura página Resumen General
│   └── productos_rentabilidad.jpg  # Captura página Productos y Rentabilidad
│   └── analisis_clientes.jpg       # Captura página Análisis de Clientes
│   └── logistica_envios.jpg        # Captura página Logística y Envíos
├── docs/
│   └── superstore_insights.docx    # Queries + insights documentados
└── README.md
```

---

## 🛠️ Stack utilizado

| Herramienta | Uso |
|-------------|-----|
| Excel | Exploración inicial del dataset |
| Python | Limpieza e importación a MySQL |
| MySQL Workbench | Análisis con SQL |
| Power BI Desktop | Dashboard y visualizaciones |
| GitHub | Control de versiones y portafolio |

---

## 📁 Dataset

- **Fuente:** [Sample Superstore — Kaggle](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
- **Filas:** 9,994
- **Columnas principales:** Order ID, Order Date, Ship Mode, Customer ID, Segment, Region, Category, Sub-Category, Sales, Quantity, Discount, Profit
- **Período:** 2014 – 2017
- **Nulos encontrados:** 0
- **Nota:** `Order ID` se repite por diseño (una orden puede tener múltiples productos). `Row ID` es el identificador único por fila.

---

## 🐍 Limpieza previa con Python

Antes de cargar los datos en MySQL, se usó Python para preparar e importar el dataset. El wizard de importación de MySQL Workbench presentó problemas con el CSV original — omitía consistentemente ~300 filas al procesar el archivo, dejando 9,694 filas en lugar de las 9,994 correctas. La causa probable son las fechas en formato `M/D/YYYY` y algunos caracteres especiales del CSV que el wizard no maneja bien.

La solución fue importar directamente con Python usando `pandas` y `SQLAlchemy`, lo que garantiza las 9,994 filas completas. Adicionalmente, el script normaliza los nombres de columnas (espacios y mayúsculas) que MySQL no maneja bien:

```python
import pandas as pd
from sqlalchemy import create_engine

# Leer CSV original de Kaggle
df = pd.read_csv("superstore.csv", encoding="latin1")

# Limpiar nombres de columnas: minúsculas y espacios → guion bajo
# Ejemplo: "Order Date" → "order_date", "Ship Mode" → "ship_mode"
df.columns = (
    df.columns
    .str.lower()
    .str.replace(" ", "_")
)

# Conectar a MySQL e importar
engine = create_engine("mysql+pymysql://root:TU_CONTRASEÑA@localhost/TU_BASE_DE_DATOS")
df.to_sql("superstore_clean", con=engine, if_exists="replace", index=False)

print(f"Importadas {len(df)} filas correctamente")
```

> **Nota sobre las fechas:** El CSV original tiene fechas en formato `MM/DD/YYYY` (ej: `11/8/2016`). MySQL solo acepta fechas en formato `YYYY-MM-DD`, por lo que al importar las columnas `order_date` y `ship_date` quedan como texto. Para trabajarlas como fechas reales en SQL se crean dos columnas nuevas con `STR_TO_DATE`:

```sql
ALTER TABLE superstore_clean
  ADD COLUMN order_date_clean DATE,
  ADD COLUMN ship_date_clean  DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE superstore_clean
SET order_date_clean = STR_TO_DATE(order_date, '%m/%d/%Y'),
    ship_date_clean  = STR_TO_DATE(ship_date,  '%m/%d/%Y');

SET SQL_SAFE_UPDATES = 1;
```

Todas las consultas SQL que usan fechas operan sobre `order_date_clean` y `ship_date_clean`.

---

## 🔍 Análisis exploratorio (Excel)

Antes de pasar a SQL se revisó el dataset en Excel para entender:
- Tipos de datos por columna
- Presencia de valores nulos (resultado: ninguno)
- Comportamiento de duplicados (Order ID duplicado por diseño, no por error)
- Rango de fechas, valores mínimos y máximos de ventas y descuentos

---

## 🗃️ Consultas SQL

### Métricas generales

```sql
-- Clientes únicos
SELECT COUNT(DISTINCT customer_id) FROM superstore_clean;
-- Resultado: 793

-- Pedidos únicos
SELECT COUNT(DISTINCT order_id) FROM superstore_clean;
-- Resultado: 5,009

-- Ventas totales y ticket promedio
SELECT
  SUM(sales) AS total_sales,
  AVG(sales) AS avg_ticket
FROM superstore_clean;
-- Resultado: $2,297,201 | ticket promedio $229.85
```

### Ventas por tiempo

```sql
-- Ventas por año
SELECT
  YEAR(order_date_clean) AS year,
  SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY year
ORDER BY year;
-- 2014: $484,247 | 2015: $470,532 | 2016: $609,205 | 2017: $733,215

-- Ventas por mes
SELECT
  DATE_FORMAT(order_date_clean, '%Y-%m') AS month,
  SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY month
ORDER BY month;
```

### Geografía

```sql
-- Top 10 ciudades con más ventas
SELECT city, SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY city
ORDER BY total_sales DESC
LIMIT 10;
-- New York City $256,368 | Los Angeles $175,851 | Seattle $119,540
-- San Francisco $112,669 | Philadelphia $109,077 | Houston $64,504
-- Chicago $48,539 | San Diego $47,521 | Jacksonville $44,713 | Springfield $43,054

-- Margen por región ★
SELECT
  region,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct
FROM superstore_clean
GROUP BY region
ORDER BY margin_pct DESC;
-- West 14.9% | East 13.5% | South 11.9% | Central 7.9%
```

### Clientes y segmentos

```sql
-- Ventas por segmento
SELECT segment, SUM(sales) AS total_sales
FROM superstore_clean
GROUP BY segment
ORDER BY total_sales DESC;
-- Consumer $1,161,401 | Corporate $706,146 | Home Office $429,653

-- Top 10 clientes con más órdenes
SELECT customer_name, COUNT(DISTINCT order_id) AS total_orders
FROM superstore_clean
GROUP BY customer_name
ORDER BY total_orders DESC
LIMIT 10;

-- Top 10 clientes por gasto total
SELECT customer_name, SUM(sales) AS total_spent
FROM superstore_clean
GROUP BY customer_name
ORDER BY total_spent DESC
LIMIT 10;
-- Sean Miller $25,043 | Tamara Chand $19,052 | Raymond Buch $15,117
-- Tom Ashbrook $14,595 | Adrian Barton $14,473

-- Clientes con una sola compra (no recurrentes)
SELECT customer_id, COUNT(order_id) AS orders
FROM superstore_clean
GROUP BY customer_id
HAVING orders = 1;
```

### Rentabilidad por categoría ★

```sql
SELECT
  category,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct,
  ROUND(AVG(discount) * 100, 2)               AS avg_discount_pct
FROM superstore_clean
GROUP BY category
ORDER BY margin_pct DESC;
-- Technology: ventas $836,154 | profit $145,455 | margen 17.4%
-- Office Supplies: ventas $719,047 | profit $122,491 | margen 17.0%
-- Furniture: ventas $741,999 | profit $18,451 | margen 2.5%
```

### Impacto de descuentos ★

```sql
SELECT
  CASE
    WHEN discount = 0      THEN '0%'
    WHEN discount <= 0.20  THEN '1-20%'
    WHEN discount <= 0.40  THEN '21-40%'
    ELSE '41%+'
  END AS discount_range,
  COUNT(*)              AS total_orders,
  ROUND(AVG(profit), 2) AS avg_profit,
  ROUND(SUM(profit), 2) AS total_profit
FROM superstore_clean
GROUP BY discount_range
ORDER BY avg_profit DESC;
-- 0%:    avg_profit $66.90  | total_profit  $320,988
-- 1-20%: avg_profit $26.50  | total_profit  $100,785
-- 21-40%: avg_profit -$77.86 | total_profit -$35,817
-- 41%+:  avg_profit -$106.71 | total_profit -$99,559
```

### Subcategorías menos rentables ★

```sql
SELECT
  `sub-category`,
  ROUND(SUM(sales), 2)                        AS total_sales,
  ROUND(SUM(profit), 2)                       AS total_profit,
  ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS margin_pct
FROM superstore_clean
GROUP BY `sub-category`
ORDER BY total_profit ASC
LIMIT 6;
-- Tables:    ventas $206,966 | profit -$17,725 | margen -8.6%
-- Bookcases: ventas $114,880 | profit  -$3,473 | margen -3.0%
-- Supplies:  ventas  $46,674 | profit  -$1,189 | margen -2.5%
```

### Logística

```sql
-- Tiempo promedio general de envío
SELECT AVG(DATEDIFF(ship_date_clean, order_date_clean)) AS avg_shipping_days
FROM superstore_clean;
-- Resultado: 3.96 días

-- Eficiencia por método de envío
SELECT
  ship_mode,
  ROUND(AVG(DATEDIFF(ship_date_clean, order_date_clean)), 2) AS avg_days,
  COUNT(*) AS total_orders
FROM superstore_clean
GROUP BY ship_mode
ORDER BY avg_days;
-- Same Day 0.04d | First Class 2.18d | Second Class 3.24d | Standard Class 5.00d
```

> ★ Consultas agregadas en la segunda etapa del análisis para profundizar en rentabilidad.

---

## 💡 Insights de negocio

Cada insight indica la(s) consulta(s) SQL en que se basa.

### Insight 1 — Furniture vende mucho pero casi no gana
Furniture generó $741,999 en ventas pero con un margen de apenas **2.5%**, frente al 17.4% de Technology. La subcategoría **Tables** es directamente destructora de valor: vendió $206,966 y registró una **pérdida neta de $17,725**. La causa: descuento promedio del 17.4%, el más alto de todas las categorías.  
📌 *Basado en: Query rentabilidad por categoría + subcategorías menos rentables*

---

### Insight 2 — Los descuentos mayores al 20% destruyen rentabilidad
Las órdenes sin descuento tienen un profit promedio de **$66.9**. Con descuento entre 21-40%, cae a **-$77.9**. Con más del 40%, llega a **-$106.7**. En total, las órdenes con descuento alto generaron **$135,376 en pérdidas netas**. La empresa está pagando para vender esas unidades.  
📌 *Basado en: Query impacto de descuentos*

---

### Insight 3 — Central es la región más ineficiente
West lidera con el **14.9% de margen**. Central tiene solo **7.9% de margen** — casi la mitad de eficiencia. Ninguna ciudad de Central aparece en el top 10 por volumen de ventas.  
📌 *Basado en: Query margen por región + top ciudades por ventas*

---

### Insight 4 — Crecimiento del 51% en 3 años, con estacionalidad clara en Q4
Las ventas crecieron de $484,247 (2014) a $733,215 (2017), un **+51%**. Sin embargo, los descuentos altos generaron $135,376 en pérdidas en el mismo período — el crecimiento en ventas no se tradujo proporcionalmente en ganancia. Patrón estacional claro: **septiembre y noviembre** son los meses pico en todos los años.  
📌 *Basado en: Query ventas por año + ventas por mes + impacto de descuentos*

---

### Insight 5 — Consumer concentra más del 50% de los ingresos
Consumer representa el **50.6% de las ventas totales** ($1,161,401 de $2,297,201). Esta concentración en un solo segmento representa un riesgo: si cambia el comportamiento de ese segmento, el impacto sobre el negocio es inmediato.  
📌 *Basado en: Query ventas por segmento + métricas generales*

---

## 📊 Dashboard Power BI

El dashboard está dividido en 4 páginas y usa el CSV original de Kaggle (`superstore.csv`) directamente como fuente de datos.

### ⚙️ Configuración necesaria antes de abrir el archivo

Para que los datos y fechas funcionen correctamente, Power BI debe estar configurado en inglés estadounidense en dos lugares:

**1. Configuración regional del modelo**
`Archivo → Opciones y configuración → Opciones → Regional → Configuración regional para la importación → Inglés (Estados Unidos)`

Esto permite que Power BI interprete correctamente los números decimales con punto (ej: `261.96`) y las fechas en formato `M/D/YYYY`. Sin esta configuración los valores numéricos se distorsionan y las fechas dan error.

**2. Conversión de fechas en Power Query**
Al importar el CSV, las columnas `Order Date` y `Ship Date` deben convertirse a tipo Fecha usando:
`Clic derecho en la columna → Cambiar tipo → Con configuración regional → Fecha → Inglés (Estados Unidos)`

### Medidas DAX creadas

```dax
Total Sales     = SUM(superstore[Sales])
Total Profit    = SUM(superstore[Profit])
Profit Margin % = DIVIDE([Total Profit], [Total Sales])
Total Orders    = DISTINCTCOUNT(superstore[Order ID])
Total Customers = DISTINCTCOUNT(superstore[Customer ID])
Avg Ticket      = DIVIDE([Total Sales], [Total Orders])
Avg Shipping Days = AVERAGEX(superstore, DATEDIFF(superstore[Order Date], superstore[Ship Date], DAY))
Orders Per Customer = DIVIDE([Total Orders], [Total Customers])
```

### Columna calculada

```dax
Discount Range =
SWITCH(
    TRUE(),
    superstore[Discount] = 0,      "0%",
    superstore[Discount] <= 0.20,  "1-20%",
    superstore[Discount] <= 0.40,  "21-40%",
    "41%+"
)
```

### Páginas del dashboard

**Página 1 — Resumen General**
- KPIs: Ventas Totales, Ganancia Total, Margen %, Total Órdenes, Ticket Promedio
- Ventas por mes (gráfico de líneas)
- Ventas por categoría (barras)
- Mapa de ventas por estado
- Ventas por segmento (donut)
- Filtros: Año, Región, Segmento

**Página 2 — Productos y Rentabilidad**
- Ganancia por categoría
- Ganancia por subcategoría (colores divergentes — rojo para pérdidas)
- Impacto de descuentos en ganancia por rango
- Filtros: Año, Región, Segmento, Categoría

**Página 3 — Análisis de Clientes**
- Top 10 clientes por ventas
- Ventas por segmento
- Órdenes por método de envío
- Filtros: Año, Región, Segmento

**Página 4 — Logística y Envíos**
- Días promedio de envío por método
- KPI promedio general (3.96 días)
- Distribución de métodos de envío (donut)
- Filtros: Año, Región, Segmento, Método de Envío

> Los fondos de cada página están disponibles en la carpeta `backgrounds/`. Para aplicarlos: **Formato → Fondo del lienzo → Examinar → selecciona la imagen correspondiente**. Los fondos fueron diseñados en PowerPoint y exportados como JPG.

---

## 📸 Screenshots

![Resumen General](screenshots/overview.jpg)
![Productos y Rentabilidad](screenshots/productos_rentabilidad.jpg)
![Análisis de Clientes](screenshots/analisis_clientes.jpg)
![Logística y Envíos](screenshots/logistica_envios.jpg)

---

## 📌 Conclusión

Este proyecto demuestra un flujo completo de análisis de datos:
exploración en Excel → limpieza con Python → análisis en SQL → visualización en Power BI → comunicación de insights.

El hallazgo más impactante: **los descuentos altos no generan más ganancia, la destruyen**.
Una recomendación concreta sería establecer un tope de descuento del 20% y revisar la estrategia de precios en Furniture, especialmente en la región Central.

---

*Proyecto de portafolio · Dataset: Sample Superstore (Kaggle) · Stack: Excel, Python, MySQL, Power BI, GitHub*
