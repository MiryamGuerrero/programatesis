from app.core.db import db_cursor

def check():
    with db_cursor() as cur:
        cur.execute("select id, nombre from nutricion.grupo_alimentario order by id")
        for row in cur.fetchall(): print(row)

if __name__ == "__main__":
    check()
