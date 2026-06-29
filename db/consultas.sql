-- =====================================================================
--  CONSULTAS.SQL  -  Catalogo de TODAS las consultas que usa la pagina.
--
--  Aqui esta, una por una, cada consulta SQL y EN QUE PARTE de la web /
--  de la API se ejecuta. Es la "chuleta" para la demo en vivo: cuando
--  la profesora pregunte "que query corre aqui?", esta es la respuesta.
--
--  OJO: en la pagina web, cada vez que haces clic, la "Consola SQL"
--  (panel oscuro de abajo) muestra exactamente esta misma consulta.
-- =====================================================================


-- #####################################################################
-- # BLOQUE 1  -  CRUD de PRODUCTOS  (constraints CHECK/UNIQUE/NOT NULL)
-- # Pantalla:  "1. CRUD + Constraints"
-- # Rubrica:   Integridad y Constraints (2.0)
-- #####################################################################

-- [GET /api/productos]  -> al abrir la pantalla, llena la tabla.
-- (JOIN productos + categorias para mostrar el nombre de la categoria)
SELECT p.id, p.nombre, p.precio, p.stock, p.disponible,
       c.nombre AS categoria, p.categoria_id, p.atributos
FROM productos p
LEFT JOIN categorias c ON c.id = p.categoria_id
ORDER BY p.id;

-- [POST /api/productos]  -> boton "Crear producto".
-- Aqui se DISPARAN las restricciones: CHECK (precio>0, stock>=0),
-- UNIQUE (nombre), NOT NULL (nombre). Probar a propósito un precio
-- negativo o un nombre repetido para ver el error controlado.
INSERT INTO productos (nombre, precio, stock, categoria_id, atributos)
VALUES ($1, $2, $3, $4, $5::jsonb)
RETURNING *;

-- [PUT /api/productos/:id]  -> boton "Editar" de una fila.
UPDATE productos
SET nombre = $1, precio = $2, stock = $3, categoria_id = $4, disponible = $5
WHERE id = $6
RETURNING *;

-- [DELETE /api/productos/:id]  -> boton "Eliminar" de una fila.
DELETE FROM productos WHERE id = $1 RETURNING id, nombre;


-- #####################################################################
-- # BLOQUE 2  -  PEDIDO = CRUD COMPLEJO (3 tablas) + TRANSACCION ACID
-- # Pantalla:  "2. Pedido (Transaccion)"
-- # Rubrica:   Operaciones CRUD Complejas (4.0) + Gestion de Transacciones (1.0)
-- #
-- # Un solo pedido toca 3 tablas: pedidos, detalle_pedido y productos
-- # (descuenta stock). Todo va dentro de BEGIN ... COMMIT, y si un
-- # producto no tiene stock suficiente se hace ROLLBACK (no se guarda nada).
-- #####################################################################

-- [POST /api/pedidos]  -> boton "Confirmar pedido".
BEGIN;

  -- (a) cabecera del pedido
  INSERT INTO pedidos (cliente_id, mesa_id, empleado_id, estado, total)
  VALUES ($1, $2, $3, 'pendiente', 0)
  RETURNING id;

  -- (b) por cada producto del carrito: se bloquea la fila (FOR UPDATE),
  --     se valida stock, se inserta el detalle y se descuenta stock.
  SELECT nombre, precio, stock FROM productos WHERE id = $1 FOR UPDATE;

  INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
  VALUES ($1, $2, $3, $4);

  UPDATE productos SET stock = stock - $1 WHERE id = $2;

  -- (c) recalcular el total del pedido sumando el detalle
  UPDATE pedidos
  SET total = (SELECT COALESCE(SUM(subtotal),0)
               FROM detalle_pedido WHERE pedido_id = $1)
  WHERE id = $1;

COMMIT;
-- Si algo falla (ej. stock insuficiente):  ROLLBACK;  -- se revierte TODO

-- [GET /api/pedidos]  -> lista de pedidos (JOIN de 4 tablas).
SELECT p.id, p.fecha, p.estado, p.total,
       cl.nombre AS cliente, m.numero AS mesa, e.nombre AS mesero
FROM pedidos p
LEFT JOIN clientes  cl ON cl.id = p.cliente_id
LEFT JOIN mesas     m  ON m.id  = p.mesa_id
LEFT JOIN empleados e  ON e.id  = p.empleado_id
ORDER BY p.id DESC;


-- #####################################################################
-- # BLOQUE 3  -  REPORTE  GROUP BY / HAVING + JOIN de 4 tablas + EXPORT
-- # Pantalla:  "3. Reportes"
-- # Rubrica:   Reportes y Exportacion (2.0)
-- #
-- # Botones: "Ver JSON", "Descargar CSV", "Descargar Excel".
-- # El parametro $1 es el "minimo de ingresos" del filtro HAVING.
-- #####################################################################

-- [GET /api/reportes/ventas-por-categoria?min=...&formato=json|csv|excel]
SELECT c.nombre                AS categoria,
       COUNT(DISTINCT p.id)    AS num_pedidos,
       SUM(d.cantidad)         AS unidades_vendidas,
       SUM(d.subtotal)         AS ingresos
FROM pedidos p
JOIN detalle_pedido d ON d.pedido_id = p.id
JOIN productos     pr ON pr.id = d.producto_id
JOIN categorias    c  ON c.id = pr.categoria_id
WHERE p.estado IN ('pagado','servido')
GROUP BY c.nombre
HAVING SUM(d.subtotal) > $1
ORDER BY ingresos DESC;


-- #####################################################################
-- # BLOQUE 4  -  MODULO HIBRIDO NoSQL  (JSONB en productos.atributos)
-- # Pantalla:  "4. NoSQL / JSONB"
-- # Rubrica:   Caso de Uso NoSQL / Hibrido (2.5)
-- #
-- # La columna productos.atributos es JSONB: guarda datos que cambian
-- # de un producto a otro (vegano, picante, calorias, alergenos[],
-- # ingredientes[]) sin tener que crear una columna o tabla por cada uno.
-- # Tabla afectada: SOLO productos (columna atributos).
-- #####################################################################

-- [GET /api/nosql/buscar?clave=vegano&valor=true]  -> "contiene" (@>)
SELECT id, nombre, precio, atributos
FROM productos
WHERE atributos @> $1::jsonb;     -- ej:  {"vegano": true}

-- [GET /api/nosql/alergeno?alergeno=mani]  -> busca dentro del arreglo JSON
SELECT id, nombre
FROM productos
WHERE atributos -> 'alergenos' @> $1::jsonb;   -- ej:  ["mani"]


-- #####################################################################
-- # BLOQUE 5  -  OPTIMIZACION / INDICES  (EXPLAIN antes y despues)
-- # Pantalla:  "5. Optimizacion"
-- # Rubrica:   Optimizacion (Indices) (3.0)
-- #####################################################################

-- [GET /api/optimizacion/indices]  -> lista todos los indices creados.
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- [GET /api/optimizacion/explain]  -> plan de ejecucion del reporte.
-- Para la evidencia "antes y despues": correr este EXPLAIN, luego borrar
-- el indice GIN (ver db/03_indices.sql), volver a correrlo, y comparar.
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.nombre, COUNT(DISTINCT p.id), SUM(d.cantidad), SUM(d.subtotal)
FROM pedidos p
JOIN detalle_pedido d ON d.pedido_id = p.id
JOIN productos     pr ON pr.id = d.producto_id
JOIN categorias    c  ON c.id = pr.categoria_id
WHERE p.estado IN ('pagado','servido')
GROUP BY c.nombre
HAVING SUM(d.subtotal) > 0
ORDER BY 4 DESC;

-- Demostracion "antes y despues" del indice GIN sobre el JSONB:
--   1) EXPLAIN ANALYZE SELECT * FROM productos WHERE atributos @> '{"vegano":true}';
--   2) DROP INDEX idx_productos_atributos;   -- quitar el indice
--   3) repetir el EXPLAIN  (ahora hace Seq Scan, mas lento)
--   4) CREATE INDEX idx_productos_atributos ON productos USING GIN (atributos);
--   5) repetir el EXPLAIN  (vuelve a usar el indice / Bitmap Index Scan)
