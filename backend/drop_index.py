import psycopg
import os
from dotenv import load_dotenv
from urllib.parse import urlparse, unquote

load_dotenv('.env')
dburl = os.getenv('DATABASE_URL')
parsed = urlparse(dburl)
pwd = unquote(parsed.password or '')

conn = psycopg.connect(
    host='db.gfjqdisitqkryzjlwdsc.supabase.co',
    port=6543,
    user='postgres',
    password=pwd,
    dbname='postgres',
    sslmode='require',
)

cur = conn.cursor()

# Drop index
cur.execute("DROP INDEX IF EXISTS dom_nutricion_catalogos.ux_variable_nutricional_codigo CASCADE")
print("✓ Index dropped")

# Analyze table
cur.execute("ANALYZE dom_nutricion_catalogos.variable_nutricional")
print("✓ Table analyzed")

conn.commit()
cur.close()
conn.close()
print("DONE")
