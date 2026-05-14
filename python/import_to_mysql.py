import pandas as pd
from sqlalchemy import create_engine

# Leer CSV original
df = pd.read_csv("superstore.csv", encoding="latin1")

# Limpiar nombres de columnas
df.columns = (
    df.columns
    .str.lower()
    .str.replace(" ", "_")
)

# Conectar a MySQL
# Cambia: usuario, contraseña, y nombre de base de datos
engine = create_engine("mysql+pymysql://root:214626977perro@localhost/superstoregod")

# Importar a MySQL
df.to_sql("superstore_clean", con=engine, if_exists="replace", index=False)

print(f"Importadas {len(df)} filas correctamente")