-- CASO DE USO NoSQL / HIBRIDO - MONGODB
-- Modulo: informacion adicional de productos con datos semiestructurados JSONB

-- En este modulo se usa JSONB para guardar informacion variable de los productos,
-- como ingredientes, alergenos, informacion nutricional, etiquetas y nivel de picante.
-- Estos datos no siempre tienen la misma estructura para todos los productos, por eso
-- conviene almacenarlos como datos semiestructurados.

-- 1. Agregar columna JSONB a la tabla PRODUCTO
ALTER TABLE PRODUCTO
ADD COLUMN datos_extra JSONB;

-- 2. Registrar informacion semiestructurada para algunos productos
UPDATE PRODUCTO
SET datos_extra = '{
  "ingredientes": ["pescado", "limon", "cebolla", "aji"],
  "alergenos": ["pescado"],
  "nutricion": {
    "calorias": 320,
    "proteinas": "28g"
  },
  "etiquetas": ["marino", "tradicional", "sin gluten"],
  "nivel_picante": "medio"
}'
WHERE nombre = 'Ceviche Clasico';

UPDATE PRODUCTO
SET datos_extra = '{
  "ingredientes": ["carne", "papa", "arroz", "cebolla", "tomate"],
  "alergenos": [],
  "nutricion": {
    "calorias": 680,
    "proteinas": "35g"
  },
  "etiquetas": ["criollo", "plato principal"],
  "nivel_picante": "bajo"
}'
WHERE nombre = 'Lomo Saltado';

UPDATE PRODUCTO
SET datos_extra = '{
  "ingredientes": ["leche", "chocolate", "harina", "huevo"],
  "alergenos": ["leche", "gluten", "huevo"],
  "nutricion": {
    "calorias": 410,
    "azucar": "32g"
  },
  "etiquetas": ["postre", "dulce"],
  "apto_vegetariano": true
}'
WHERE nombre = 'Torta de Chocolate';

-- 3. Crear indice GIN para mejorar busquedas dentro del JSONB
CREATE INDEX idx_producto_datos_extra
ON PRODUCTO USING GIN (datos_extra);

-- 4. Consultas de ejemplo sobre datos semiestructurados

-- Productos que tienen la etiqueta "sin gluten"
SELECT nombre, precio, datos_extra
FROM PRODUCTO
WHERE datos_extra -> 'etiquetas' ? 'sin gluten';

-- Productos que contienen pescado como alergeno
SELECT nombre, datos_extra -> 'alergenos' AS alergenos
FROM PRODUCTO
WHERE datos_extra -> 'alergenos' ? 'pescado';

-- Calorias registradas de cada producto con datos extra
SELECT
  nombre,
  datos_extra -> 'nutricion' ->> 'calorias' AS calorias
FROM PRODUCTO
WHERE datos_extra IS NOT NULL;

-- JUSTIFICACION
-- Este modulo es hibrido porque mantiene el modelo relacional para los datos
-- principales del restaurante, como productos, pedidos, clientes y mesas, pero
-- agrega JSONB para informacion flexible que puede cambiar entre productos.
--
-- La ventaja sobre un modelo totalmente relacional es que evita crear muchas
-- tablas adicionales para ingredientes, alergenos, etiquetas, nutricion y otros
-- atributos que no aplican igual para todos los productos. Con JSONB se puede
-- guardar esa informacion en una sola columna, consultarla e incluso indexarla
-- con GIN para mejorar el rendimiento de las busquedas.
