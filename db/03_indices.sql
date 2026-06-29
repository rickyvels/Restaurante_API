-- =====================================================================
--  RESTAURANTE - INDICES (Optimizacion 3.0)
--  Cada indice esta justificado segun como se consulta la base.
--  En la demo: correr EXPLAIN ANALYZE antes y despues de crear el indice.
-- =====================================================================

-- 1) Las lineas de un pedido se buscan SIEMPRE por pedido_id
--    (al ver el detalle de un pedido y al calcular reportes con JOIN).
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_pedido
    ON detalle_pedido (pedido_id);

-- 2) Los reportes filtran/agrupan productos por categoria.
CREATE INDEX IF NOT EXISTS idx_productos_categoria
    ON productos (categoria_id);

-- 3) Los pedidos se listan y filtran por fecha (reportes por dia/rango).
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha
    ON pedidos (fecha);

-- 4) Se filtra mucho por estado del pedido (pendiente, pagado, etc.).
CREATE INDEX IF NOT EXISTS idx_pedidos_estado
    ON pedidos (estado);

-- 5) *** INDICE GIN sobre JSONB *** (clave para el modulo NoSQL):
--    permite buscar dentro de "atributos" (ej. productos veganos,
--    con cierto alergeno, etc.) de forma eficiente.
CREATE INDEX IF NOT EXISTS idx_productos_atributos_gin
    ON productos USING GIN (atributos);
