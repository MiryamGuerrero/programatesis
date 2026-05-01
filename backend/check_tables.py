import psycopg2, os
from dotenv import load_dotenv
load_dotenv()

conn = psycopg2.connect(os.getenv("DATABASE_URL"))
cur = conn.cursor()

# Check control_paciente table columns
cur.execute("""
    SELECT column_name FROM information_schema.columns 
    WHERE table_schema = 'clinico' AND table_name = 'control_paciente' 
    ORDER BY ordinal_position
""")
print("=== CONTROL_PACIENTE COLUMNS ===")
for r in cur.fetchall():
    print(f"  {r[0]}")

# Check paciente table columns
cur.execute("""
    SELECT column_name FROM information_schema.columns 
    WHERE table_schema = 'usuarios' AND table_name = 'paciente' 
    ORDER BY ordinal_position
""")
print("\n=== PACIENTE COLUMNS ===")
for r in cur.fetchall():
    print(f"  {r[0]}")

conn.close()
