-- Migración de Provincia a Cantón y Parroquia (Contexto Chimborazo)

BEGIN;

-- 1. Renombrar tabla provincia a canton
ALTER TABLE usuarios.provincia RENAME TO canton;
ALTER TABLE usuarios.canton RENAME CONSTRAINT provincia_pkey TO canton_pkey;

-- 2. Limpiar datos antiguos de la tabla (eran provincias de todo el país)
TRUNCATE TABLE usuarios.canton CASCADE;

-- 3. Crear tabla parroquia
CREATE TABLE usuarios.parroquia (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    id_canton INTEGER NOT NULL REFERENCES usuarios.canton(id) ON DELETE CASCADE
);

-- 4. Actualizar tabla paciente
-- Renombrar id_provincia a id_canton
ALTER TABLE usuarios.paciente RENAME COLUMN id_provincia TO id_canton;
-- Agregar id_parroquia
ALTER TABLE usuarios.paciente ADD COLUMN id_parroquia INTEGER REFERENCES usuarios.parroquia(id);

-- 5. Insertar Cantones de Chimborazo
INSERT INTO usuarios.canton (id, nombre) VALUES 
(1, 'RIOBAMBA'),
(2, 'ALAUSI'),
(3, 'COLTA'),
(4, 'CHAMBO'),
(5, 'CHUNCHI'),
(6, 'GUAMOTE'),
(7, 'GUANO'),
(8, 'PALLATANGA'),
(9, 'PENIPE'),
(10, 'CUMANDA');

-- Ajustar el secuencial de canton si es necesario (ya que insertamos IDs fijos)
SELECT setval(pg_get_serial_sequence('usuarios.canton', 'id'), 10);

-- 6. Insertar Parroquias
-- Riobamba (id_canton = 1)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('LIZARZABURU', 1), ('MALDONADO', 1), ('VELASCO', 1), ('VELOZ', 1), ('YARUQUÍES', 1), 
('RIOBAMBA', 1), ('CACHA', 1), ('CALPI', 1), ('CUBIJÍES', 1), ('FLORES', 1), 
('LICÁN', 1), ('LICTO', 1), ('PUNGALÁ', 1), ('PUNÍN', 1), ('QUIMIAG', 1), 
('SAN JUAN', 1), ('SAN LUIS', 1);

-- Alausí (id_canton = 2)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('ALAUSÍ', 2), ('ACHUPALLAS', 2), ('CUMANDÁ', 2), ('GUASUNTOS', 2), ('HUIGRA', 2), 
('MULTITUD', 2), ('PISTISHÍ', 2), ('PUMALLACTA', 2), ('SEVILLA', 2), 
('SIBAMBE', 2), ('TIXÁN', 2);

-- Colta (id_canton = 3)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('CAJABAMBA', 3), ('SICALPA', 3), ('VILLA LA UNIÓN', 3), ('CAÑI', 3), 
('COLUMBE', 3), ('JUAN DE VELASCO', 3), ('SANTIAGO DE QUITO', 3);

-- Chambo (id_canton = 4)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('CHAMBO', 4);

-- Chunchi (id_canton = 5)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('CHUNCHI', 5), ('CAPZOL', 5), ('COMPUD', 5), ('GONZOL', 5), ('LLAGOS', 5);

-- Guamote (id_canton = 6)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('GUAMOTE', 6), ('CEBADAS', 6), ('PALMIRA', 6);

-- Guano (id_canton = 7)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('EL ROSARIO', 7), ('LA MATRIZ', 7), ('GUANO', 7), ('GUANANDO', 7), 
('ILAPO', 7), ('LA PROVIDENCIA', 7), ('SAN ANDRÉS', 7), 
('SAN GERARDO DE PACAICAGUÁN', 7), ('SAN ISIDRO DE PATULÚ', 7), 
('SAN JOSÉ DEL CHAZO', 7), ('SANTA FÉ DE GALÁN', 7), ('VALPARAÍSO', 7);

-- Pallatanga (id_canton = 8)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('PALLATANGA', 8);

-- Penipe (id_canton = 9)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('PENIPE', 9), ('EL ALTAR', 9), ('MATUS', 9), ('PUELA', 9), 
('SAN ANTONIO DE BAYUSHIG', 9), ('LA CANDELARIA', 9), ('BILBAO', 9);

-- Cumandá (id_canton = 10)
INSERT INTO usuarios.parroquia (nombre, id_canton) VALUES 
('CUMANDÁ', 10);

-- 7. Manejar datos existentes (si los hay)
-- Asignar un cantón por defecto (ej. Riobamba = 1) a los pacientes que tenían provincia
UPDATE usuarios.paciente SET id_canton = 1 WHERE id_canton IS NOT NULL;

COMMIT;
