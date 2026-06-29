-- =====================================================================
--  RESTAURANTE - ESQUEMA DE BASE DE DATOS (PostgreSQL)
--  Rubrica cubierta en este archivo:
--    * Integridad y Constraints (2.0): CHECK, UNIQUE, NOT NULL,
--      integridad referencial con CASCADE y SET NULL.
--    * Base para CRUD Complejo, Reportes, Transacciones y NoSQL.
-- =====================================================================

-- Empezamos limpio (utiles para volver a correr la demo desde cero).
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedidos        CASCADE;
DROP TABLE IF EXISTS productos      CASCADE;
DROP TABLE IF EXISTS categorias     CASCADE;
DROP TABLE IF EXISTS clientes       CASCADE;
DROP TABLE IF EXISTS mesas          CASCADE;
DROP TABLE IF EXISTS empleados      CASCADE;

-- ---------------------------------------------------------------------
-- 1) CATEGORIAS  (ej: Entradas, Platos de fondo, Bebidas, Postres)
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL UNIQUE,        -- UNIQUE + NOT NULL
    descripcion TEXT
);

-- ---------------------------------------------------------------------
-- 2) CLIENTES
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id         SERIAL PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    email      VARCHAR(120) UNIQUE,                  -- UNIQUE (puede ser NULL)
    telefono   VARCHAR(20),
    creado_en  TIMESTAMP    NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 3) MESAS
-- ---------------------------------------------------------------------
CREATE TABLE mesas (
    id         SERIAL PRIMARY KEY,
    numero     INT NOT NULL UNIQUE,                  -- UNIQUE
    capacidad  INT NOT NULL CHECK (capacidad > 0),   -- CHECK
    ubicacion  VARCHAR(40) DEFAULT 'salon'
);

-- ---------------------------------------------------------------------
-- 4) EMPLEADOS (meseros, cocina, caja)
-- ---------------------------------------------------------------------
CREATE TABLE empleados (
    id      SERIAL PRIMARY KEY,
    nombre  VARCHAR(100) NOT NULL,
    rol     VARCHAR(20)  NOT NULL
            CHECK (rol IN ('mesero','cocina','caja','admin')),  -- CHECK por lista
    activo  BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------
-- 5) PRODUCTOS (carta del restaurante)
--    * Aqui vive la columna JSONB "atributos" del modulo hibrido NoSQL.
--    * categoria_id usa ON DELETE SET NULL: si se borra la categoria,
--      el producto NO se borra, solo queda sin categoria.
-- ---------------------------------------------------------------------
CREATE TABLE productos (
    id           SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL UNIQUE,                 -- UNIQUE para demo
    precio       NUMERIC(10,2) NOT NULL CHECK (precio > 0),    -- CHECK precio > 0
    stock        INT NOT NULL DEFAULT 0 CHECK (stock >= 0),    -- CHECK stock >= 0
    disponible   BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_id INT REFERENCES categorias(id) ON DELETE SET NULL,  -- SET NULL
    atributos    JSONB NOT NULL DEFAULT '{}'::jsonb            -- *** NoSQL / Hibrido ***
);

-- ---------------------------------------------------------------------
-- 6) PEDIDOS (cabecera de la venta)
--    * cliente/mesa/empleado usan ON DELETE SET NULL para no perder el
--      historico de ventas si se elimina un cliente o se da de baja una mesa.
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
    id          SERIAL PRIMARY KEY,
    cliente_id  INT REFERENCES clientes(id)  ON DELETE SET NULL,
    mesa_id     INT REFERENCES mesas(id)     ON DELETE SET NULL,
    empleado_id INT REFERENCES empleados(id) ON DELETE SET NULL,
    fecha       TIMESTAMP NOT NULL DEFAULT now(),
    estado      VARCHAR(15) NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','preparando','servido','pagado','cancelado')),
    total       NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

-- ---------------------------------------------------------------------
-- 7) DETALLE_PEDIDO (lineas de cada pedido)
--    * pedido_id usa ON DELETE CASCADE: si se borra el pedido, sus
--      lineas se borran automaticamente.
--    * producto_id usa ON DELETE RESTRICT: no deja borrar un producto
--      que ya fue vendido (protege el historico).
--    * subtotal es columna GENERADA (calculada por la BD).
-- ---------------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id              SERIAL PRIMARY KEY,
    pedido_id       INT NOT NULL REFERENCES pedidos(id)   ON DELETE CASCADE,
    producto_id     INT NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,
    cantidad        INT NOT NULL CHECK (cantidad > 0),            -- CHECK
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario > 0),
    subtotal        NUMERIC(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    UNIQUE (pedido_id, producto_id)                              -- UNIQUE compuesto
);
