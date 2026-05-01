-- =============================================================================
-- REESTRUCTURACIÓN DE SUBGRUPOS ALIMENTARIOS
-- Propósito: Cada subgrupo es homogéneo en alergenos/intolerancias
-- Si un paciente es alérgico a un subgrupo → TODOS sus ingredientes se bloquean
-- =============================================================================

BEGIN;

-- =============================================================================
-- GRUPO 1: CEREALES
-- Problema actual: Gluten y sin-gluten mezclados en mismos subgrupos
-- =============================================================================

-- Nuevo: Subgrupo "Cereales con gluten" (trigo, centeno, cebada, avena)
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Cereales con gluten (trigo, centeno, cebada, avena)');

-- Nuevo: Subgrupo "Cereales sin gluten" (arroz, maíz, quinoa)
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Cereales sin gluten (arroz, maíz, quinoa, mijo)');

-- Nuevo: Subgrupo "Panes con gluten"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Panes con gluten');

-- Nuevo: Subgrupo "Panes sin gluten"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Panes sin gluten');

-- Nuevo: Subgrupo "Pastas con gluten"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Pastas con gluten');

-- Nuevo: Subgrupo "Pastas sin gluten"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Pastas sin gluten');

-- Nuevo: Subgrupo "Cereales de desayuno"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (1, 'Cereales de desayuno');

-- Reclasificar ingredientes de CEREALES
-- Granos y harinas con gluten (IDs: 7-centeno, 6-cebada, 5-avena, 12-harina trigo, 13-harina trigo integral, 10-harina centeno, 19-sémola trigo)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Cereales con gluten (trigo, centeno, cebada, avena)'
) WHERE id IN (5, 6, 7, 10, 12, 13, 19);

-- Granos y harinas sin gluten (IDs: 2-arroz, 3-arroz rápido, 4-arroz integral, 8-fécula maíz, 9-harina arroz, 11-harina maíz, 14-méchica, 15-maíz lata, 16-maíz mazorca, 17-maíz hervido, 18-quinoa)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Cereales sin gluten (arroz, maíz, quinoa, mijo)'
) WHERE id IN (2, 3, 4, 8, 9, 11, 14, 15, 16, 17, 18);

-- Panes con gluten (IDs: 20-31, 35-38) - todos menos pan sin gluten
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Panes con gluten'
) WHERE id IN (20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 35, 36, 37, 38);

-- Pan sin gluten (ID: 34)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Panes sin gluten'
) WHERE id IN (34);

-- Pastas con gluten (IDs: 39-cuscús, 40-pasta, 41-pasta al huevo, 42-pasta colores, 43-pasta fresca, 44-pasta integral, 45-pasta carne, 46-pasta queso)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Pastas con gluten'
) WHERE id IN (39, 40, 41, 42, 43, 44, 45, 46);

-- Cereales de desayuno (ID: 1-Malta)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Cereales de desayuno'
) WHERE id = 1;

-- Datos de prueba / temporales - mover a un subgrupo de prueba
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 1 AND nombre = 'Cereales sin gluten (arroz, maíz, quinoa, mijo)'
) WHERE id IN (807, 808);


-- =============================================================================
-- GRUPO 2: LEGUMBRES
-- Problema actual: Soja mezclada con otras legumbres, lentejas en "derivados"
-- =============================================================================

-- Nuevo: "Soja y derivados de soja" (alergeno principal)
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (2, 'Soja y derivados de soja');

-- Nuevo: "Legumbres secas (no soja)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (2, 'Legumbres secas (no soja)');

-- Nuevo: "Legumbres en conserva (no soja)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (2, 'Legumbres en conserva (no soja)');

-- Nuevo: "Análogos vegetales (soja)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (2, 'Análogos vegetales de soja (hamburguesa, salchicha)');

-- Reclasificar: Soja y derivados puros (IDs: 68-soja, 48-bebida soja, 47-batido fermentado soja, 49-brote soja, 50-fideos soja, 52-harina soja, 53-lecitina soja, 56-tempeh)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 2 AND nombre = 'Soja y derivados de soja'
) WHERE id IN (47, 48, 49, 50, 52, 53, 56, 68);

-- Análogos vegetales de soja (IDs: 51-hamburguesa vegetal, 55-salchicha vegetal)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 2 AND nombre = 'Análogos vegetales de soja (hamburguesa, salchicha)'
) WHERE id IN (51, 55);

-- Legumbres secas sin soja (IDs: 61-altramuz, 62-garbanzo, 63-haba seca, 64-harina algarrobo, 65-judía blanca, 66-judía pinta, 67-lenteja, 54-lentejas)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 2 AND nombre = 'Legumbres secas (no soja)'
) WHERE id IN (54, 61, 62, 63, 64, 65, 66, 67);

-- Legumbres en conserva sin soja (IDs: 57-garbanzo, 58-judía blanca, 59-judía pinta, 60-lenteja)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 2 AND nombre = 'Legumbres en conserva (no soja)'
) WHERE id IN (57, 58, 59, 60);


-- =============================================================================
-- GRUPO 3: VERDURAS Y HORTALIZAS
-- Estructura actual: BIEN (no son alergenos principales, subdivisión por formato es lógica)
-- No se requieren cambios
-- =============================================================================


-- =============================================================================
-- GRUPO 4: FRUTAS
-- Problema: "Crema de almendras" y "Crema de cacahuete" en "Derivados de frutas"
-- (no son derivados de fruta, son derivados de frutos secos)
-- =============================================================================

-- Nuevo: "Derivados de frutos secos" (cremas de almendra, cacahuete)
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (4, 'Derivados de frutos secos (cremas, mantequillas)');

-- Mover crema de almendras (ID: 130) y crema de cacahuete (ID: 131)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 4 AND nombre = 'Derivados de frutos secos (cremas, mantequillas)'
) WHERE id IN (130, 131);


-- =============================================================================
-- GRUPO 5: LÁCTEOS Y DERIVADOS
-- Problema: Lácteos animales con lactosa mezclados con sin-lactosa y yogur de soja
-- =============================================================================

-- Nuevo: "Leches animales (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Leches animales (con lactosa)');

-- Nuevo: "Leches animales sin lactosa"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Leches animales sin lactosa');

-- Nuevo: "Natas y cremas de leche (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Natas y cremas de leche (con lactosa)');

-- Nuevo: "Yogures animales (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Yogures animales (con lactosa)');

-- Nuevo: "Yogures animales sin lactosa"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Yogures animales sin lactosa');

-- Nuevo: "Yogures vegetales (sin lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Yogures vegetales (sin lactosa)');

-- Nuevo: "Leches fermentadas animales (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Leches fermentadas animales (con lactosa)');

-- Nuevo: "Quesos frescos (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Quesos frescos (con lactosa)');

-- Nuevo: "Quesos semicurados (bajos en lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Quesos semicurados (bajos en lactosa)');

-- Nuevo: "Quesos curados (trazas de lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Quesos curados (trazas de lactosa)');

-- Nuevo: "Quesos procesados (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (5, 'Quesos procesados y en lonchas (con lactosa)');

-- Reclasificar LECHE
-- Leches animales con lactosa (IDs: 206-concentrada, 207-condensada, 208-condensada desnatada, 209-cabra, 210-oveja, 211-vaca desnatada, 212-vaca entera, 213-vaca semidesnatada, 215-polvo desnatada, 216-polvo entera, 217-polvo semidesnatada, 219-evaporada)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Leches animales (con lactosa)'
) WHERE id IN (206, 207, 208, 209, 210, 211, 212, 213, 215, 216, 217, 219);

-- Leches sin lactosa (IDs: 214-desnatada sin lactosa, 218-entera sin lactosa, 220-semidesnatada sin lactosa)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Leches animales sin lactosa'
) WHERE id IN (214, 218, 220);

-- Natas (ID: 221)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Natas y cremas de leche (con lactosa)'
) WHERE id = 221;

-- Yogures animales con lactosa (IDs: 241-254, 256)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Yogures animales (con lactosa)'
) WHERE id IN (241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 256);

-- Yogur sin lactosa (ID: 255)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Yogures animales sin lactosa'
) WHERE id = 255;

-- Yogur de soja (ID: 240) → Yogures vegetales
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Yogures vegetales (sin lactosa)'
) WHERE id = 240;

-- Kéfir (ID: 239) → Leche fermentada animal
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Leches fermentadas animales (con lactosa)'
) WHERE id = 239;

-- Quesos frescos (con lactosa): Fresco Cremoso Kiosko(230), Fresco Siberia(231), Mozzarella(233), Mozzarella Florap(234), Mozzarella Kiosko(235), quark descremado(238), Criollo Cremosísimo(225)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Quesos frescos (con lactosa)'
) WHERE id IN (225, 230, 231, 233, 234, 235, 238);

-- Quesos semicurados (bajos en lactosa): Cabra semicurado(227), Cabra tierno(228)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Quesos semicurados (bajos en lactosa)'
) WHERE id IN (227, 228);

-- Quesos curados (trazas): Cabra curado(226), Parmesano(236), Amasado Don Queso(222), Manaba(232)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Quesos curados (trazas de lactosa)'
) WHERE id IN (222, 226, 232, 236);

-- Quesos procesados: Azul(223), Cheddar(224), en lonchas(229)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 5 AND nombre = 'Quesos procesados y en lonchas (con lactosa)'
) WHERE id IN (223, 224, 229);


-- =============================================================================
-- GRUPO 6: HUEVOS Y DERIVADOS
-- Estructura actual: BIEN (todos son huevo, alergeno homogéneo)
-- No se requieren cambios
-- =============================================================================


-- =============================================================================
-- GRUPO 7: CARNES Y DERIVADOS
-- Problema: Embutidos mezclan puros (jamón serrano) con gluten (salchichas, chistorra, longaniza)
-- =============================================================================

-- Nuevo: "Embutidos curados (sin gluten)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (7, 'Embutidos curados (sin gluten)');

-- Nuevo: "Embutidos frescos y cocidos (pueden contener gluten)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (7, 'Embutidos frescos y cocidos (pueden contener gluten)');

-- Embutidos curados sin gluten: Jamón cocido(293), Jamón cocido enlatado(294), Jamón ibérico(295), Jamón serrano(296), Lomo embuchado(297), Salchichón(304), Salami(302)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 7 AND nombre = 'Embutidos curados (sin gluten)'
) WHERE id IN (293, 294, 295, 296, 297, 302, 304);

-- Embutidos frescos/cocidos con posible gluten: Butifarra(288), Chistorra(290), Chopped(291), Chorizo(292), Longaniza(298), Morcilla(299), Mortadela(300), Pechuga pavo embutido(301), Salchicha fresca(303), Cabeza de cerdo(289)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 7 AND nombre = 'Embutidos frescos y cocidos (pueden contener gluten)'
) WHERE id IN (288, 289, 290, 291, 292, 298, 299, 300, 301, 303);


-- =============================================================================
-- GRUPO 8: PESCADOS Y DERIVADOS
-- Estructura actual: BIEN (mariscos ya separados de pescado)
-- No se requieren cambios
-- =============================================================================


-- =============================================================================
-- GRUPO 9: ACEITES Y GRASAS
-- Problema: Mantequilla (lácteo) mezclada con margarina (vegetal)
-- =============================================================================

-- Nuevo: "Mantequillas (lácteo, con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (9, 'Mantequillas (lácteo, con lactosa)');

-- Nuevo: "Margarinas y grasas vegetales"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (9, 'Margarinas y grasas vegetales');

-- Nuevo: "Otras grasas animales"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (9, 'Otras grasas animales');

-- Mantequillas (IDs: 423, 424, 425)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 9 AND nombre = 'Mantequillas (lácteo, con lactosa)'
) WHERE id IN (423, 424, 425);

-- Margarinas (IDs: 426-431)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 9 AND nombre = 'Margarinas y grasas vegetales'
) WHERE id IN (426, 427, 428, 429, 430, 431);

-- Otras grasas animales (IDs: 432-manteca cacao, 433-manteca cerdo)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 9 AND nombre = 'Otras grasas animales'
) WHERE id IN (432, 433);


-- =============================================================================
-- GRUPO 10: CONDIMENTOS Y SALSAS
-- Problema: Salsa de soja (alergeno soja) mezclada con salsas comunes
-- Salsas con lácteos (béchamel, carbonara, cesar, queso, holandesa) mezcladas con salsas sin lácteo
-- =============================================================================

-- Nuevo: "Salsas con lácteos (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (10, 'Salsas con lácteos (con lactosa)');

-- Nuevo: "Salsas sin lácteos"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (10, 'Salsas sin lácteos');

-- Nuevo: "Salsa de soja y derivados de soja"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (10, 'Salsa de soja y derivados de soja');

-- Salsas con lácteos: Alioli(475 - puede llevar huevo), Bechamel(484), Carbonara(487), Cesar(488), Queso(489), Holandesa(491)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 10 AND nombre = 'Salsas con lácteos (con lactosa)'
) WHERE id IN (475, 484, 487, 488, 489, 491);

-- Salsas sin lácteos: Gelatina(476), Kétchup(477), Mayonesa(478), Mayonesa ligera(479), Mostaza(480), Agridulce(481), Curry(482), Barbacoa(483), Brava(486), Boloñesa(485), Inglesa(492)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 10 AND nombre = 'Salsas sin lácteos'
) WHERE id IN (476, 477, 478, 479, 480, 481, 482, 483, 485, 486, 492);

-- Salsa de soja (ID: 490)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 10 AND nombre = 'Salsa de soja y derivados de soja'
) WHERE id = 490;


-- =============================================================================
-- GRUPO 11: AZÚCARES, DULCES Y PASTELERÍA
-- Problema: Productos con lácteo y sin lácteo mezclados; con gluten y sin gluten mezclados
-- =============================================================================

-- Nuevo: "Chocolates con leche (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (11, 'Chocolates con leche (con lactosa)');

-- Nuevo: "Chocolates sin leche (sin lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (11, 'Chocolates sin leche (sin lactosa)');

-- Nuevo: "Dulces con lácteos (con lactosa)"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (11, 'Dulces con lácteos (con lactosa)');

-- Nuevo: "Dulces sin lácteos"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (11, 'Dulces sin lácteos');

-- Nuevo: "Galletas con gluten"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (11, 'Galletas con gluten');

-- Chocolates con leche: Chocolate con leche(504), Chocolate con leche y almendra(505), Chocolate blanco(503), Crema de cacao y avellanas(508 - Nutella lleva leche)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 11 AND nombre = 'Chocolates con leche (con lactosa)'
) WHERE id IN (503, 504, 505, 508);

-- Chocolates sin leche: Cacao polvo 0 azúcar(500), Cacao polvo azucarado(501), Cacao polvo bajo calorías(502), Chocolate puro(507), Chocolate en polvo a la taza(506)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 11 AND nombre = 'Chocolates sin leche (sin lactosa)'
) WHERE id IN (500, 501, 502, 506, 507);

-- Dulces con lácteos: Dulce de leche(510), Merengue(512 - lleva clara de huevo pero no lácteo... mejor sin lácteos)
-- Merengue lleva clara de huevo, no lácteo → va a sin lácteos
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 11 AND nombre = 'Dulces con lácteos (con lactosa)'
) WHERE id IN (510);

-- Dulces sin lácteos: Cacahuete chocolate(509), Mazapán(511), Merengue(512)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 11 AND nombre = 'Dulces sin lácteos'
) WHERE id IN (509, 511, 512);

-- Galletas con gluten: Todas las galletas son con gluten (IDs: 513-518)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 11 AND nombre = 'Galletas con gluten'
) WHERE id IN (513, 514, 515, 516, 517, 518);


-- =============================================================================
-- GRUPO 12: APERITIVOS
-- Estructura actual: solo 1 ingrediente
-- No se requieren cambios
-- =============================================================================


-- =============================================================================
-- GRUPO 13: BEBIDAS
-- Problema: Bebidas vegetales mezcladas con agua y sodas en "Otras bebidas no alcohólicas"
-- =============================================================================

-- Nuevo: "Bebidas vegetales de frutos secos"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (13, 'Bebidas vegetales de frutos secos (almendras)');

-- Nuevo: "Bebidas vegetales de cereales"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (13, 'Bebidas vegetales de cereales (avena, arroz)');

-- Nuevo: "Bebidas vegetales de otros"
INSERT INTO nutricion.subgrupo_alimentario (id_grupo_alimentario, nombre)
VALUES (13, 'Bebidas vegetales de otros (coco, chufa/horchata, alpiste)');

-- Bebida de almendras (ID: 552)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 13 AND nombre = 'Bebidas vegetales de frutos secos (almendras)'
) WHERE id = 552;

-- Bebida de avena(554), Leche de arroz(556)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 13 AND nombre = 'Bebidas vegetales de cereales (avena, arroz)'
) WHERE id IN (554, 556);

-- Leche de coco(557), Agua de coco(551), Horchata(555), Bebida de alpiste(553)
UPDATE nutricion.ingrediente SET id_subgrupo_alimentario = (
    SELECT id FROM nutricion.subgrupo_alimentario WHERE id_grupo_alimentario = 13 AND nombre = 'Bebidas vegetales de otros (coco, chufa/horchata, alpiste)'
) WHERE id IN (551, 553, 555, 557);


COMMIT;

-- =============================================================================
-- VERIFICACIÓN: Ver cuántos ingredientes quedaron sin subgrupo asignado
-- =============================================================================
-- SELECT i.id, i.nombre, s.nombre as subgrupo_actual, g.nombre as grupo_actual
-- FROM nutricion.ingrediente i
-- JOIN nutricion.subgrupo_alimentario s ON s.id = i.id_subgrupo_alimentario
-- JOIN nutricion.grupo_alimentario g ON g.id = s.id_grupo_alimentario
-- WHERE g.id IN (1, 2, 4, 5, 7, 9, 10, 11, 13)
-- ORDER BY g.nombre, s.nombre, i.nombre;

-- =============================================================================
-- VERIFICACIÓN: Subgrupos que quedaron vacíos (se pueden eliminar)
-- =============================================================================
-- SELECT s.id, s.nombre, g.nombre as grupo,
--        (SELECT COUNT(*) FROM nutricion.ingrediente i WHERE i.id_subgrupo_alimentario = s.id) as ingredientes
-- FROM nutricion.subgrupo_alimentario s
-- JOIN nutricion.grupo_alimentario g ON g.id = s.id_grupo_alimentario
-- WHERE g.id IN (1, 2, 4, 5, 7, 9, 10, 11, 13)
-- ORDER BY g.nombre, s.nombre;
