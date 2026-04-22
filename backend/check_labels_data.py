from app.core.db import db_cursor

def test_labels():
    sql = "SELECT count(*) FROM nutricion.etiqueta_nutricional"
    with db_cursor() as cur:
        cur.execute(sql)
        count = cur.fetchone()[0]
        print(f"Total etiquetas en DB: {count}")
        
        if count > 0:
            cur.execute("SELECT nombre_visible FROM nutricion.etiqueta_nutricional LIMIT 5")
            rows = cur.fetchall()
            print("Primeras 5 etiquetas:")
            for r in rows:
                print(f"- {r[0]}")
        else:
            print("ADVERTENCIA: La tabla de etiquetas está vacía.")

if __name__ == "__main__":
    try:
        test_labels()
    except Exception as e:
        print(f"Error consultando DB: {e}")
