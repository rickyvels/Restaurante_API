-- =====================================================================
--  RESTAURANTE - DATOS DE EJEMPLO (seed)
--  Carga datos realistas para que la demo en vivo tenga contenido.
-- =====================================================================

-- Categorias
INSERT INTO categorias (nombre, descripcion) VALUES
 ('Entradas',         'Para empezar'),
 ('Platos de Fondo',  'Platos principales'),
 ('Bebidas',          'Frias y calientes'),
 ('Postres',          'Dulces de la casa');

-- Empleados
INSERT INTO empleados (nombre, rol) VALUES
 ('Ana Quispe',     'mesero'),
 ('Luis Mamani',    'cocina'),
 ('Rosa Huaman',    'caja'),
 ('Carlos Flores',  'admin');

-- Mesas
INSERT INTO mesas (numero, capacidad, ubicacion) VALUES
 (1, 4, 'salon'),
 (2, 2, 'salon'),
 (3, 6, 'terraza'),
 (4, 4, 'terraza');

-- Clientes
INSERT INTO clientes (nombre, email, telefono) VALUES
 ('Maria Lopez',  'maria@correo.com',  '987654321'),
 ('Jose Ramirez', 'jose@correo.com',   '912345678'),
 ('Sin nombre',    NULL,                NULL);

-- Productos (con atributos JSONB: cada plato tiene info semi-estructurada
-- distinta -> por eso conviene JSONB en vez de muchas columnas o tablas EAV)
INSERT INTO productos (nombre, precio, stock, categoria_id, atributos) VALUES
 ('Lomo Saltado',      32.00, 50, 2,
   '{"vegano": false, "picante": 2, "alergenos": ["gluten"], "ingredientes": ["carne","cebolla","papa","arroz"], "calorias": 780}'),
 ('Aji de Gallina',    28.00, 40, 2,
   '{"vegano": false, "picante": 1, "alergenos": ["gluten","lacteos"], "ingredientes": ["gallina","aji","pan"], "calorias": 650}'),
 ('Ensalada Vegana',   22.00, 30, 1,
   '{"vegano": true, "picante": 0, "alergenos": [], "ingredientes": ["lechuga","palta","tomate"], "calorias": 210}'),
 ('Causa Limeña',      18.00, 25, 1,
   '{"vegano": false, "picante": 1, "alergenos": ["huevo"], "ingredientes": ["papa","pollo","palta"], "calorias": 380}'),
 ('Chicha Morada',      8.00, 100, 3,
   '{"vegano": true, "picante": 0, "alergenos": [], "tamano": "500ml", "azucar": "media"}'),
 ('Inca Kola',          6.00, 120, 3,
   '{"vegano": true, "alergenos": [], "tamano": "500ml", "gaseosa": true}'),
 ('Suspiro Limeño',    14.00, 20, 4,
   '{"vegano": false, "alergenos": ["lacteos","huevo"], "ingredientes": ["leche","huevo","oporto"], "calorias": 450}'),
 ('Picarones',         12.00, 35, 4,
   '{"vegano": true, "picante": 0, "alergenos": ["gluten"], "ingredientes": ["zapallo","camote","miel"], "calorias": 520}');

-- Un par de pedidos historicos para que el reporte tenga datos
INSERT INTO pedidos (cliente_id, mesa_id, empleado_id, estado, total) VALUES
 (1, 1, 1, 'pagado', 0),
 (2, 3, 1, 'pagado', 0);

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
 (1, 1, 2, 32.00),
 (1, 5, 2, 8.00),
 (2, 2, 1, 28.00),
 (2, 6, 3, 6.00),
 (2, 8, 2, 12.00);

-- Recalculamos el total de cada pedido a partir de sus lineas
UPDATE pedidos p
SET total = sub.suma
FROM (SELECT pedido_id, SUM(subtotal) AS suma FROM detalle_pedido GROUP BY pedido_id) sub
WHERE p.id = sub.pedido_id;
