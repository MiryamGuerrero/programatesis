from app.core.db import db_cursor

def check():
    with db_cursor() as cur:
        cur.execute("select column_name from information_schema.columns where table_schema = 'nutricion' and table_name = 'ingrediente_nutriente'")
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    check()
