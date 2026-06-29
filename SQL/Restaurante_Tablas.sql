--1
  CREATE TABLE CLIENTE (
	id_cliente SERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL,
	apellido VARCHAR(50) NOT NULL,
	email VARCHAR(100) UNIQUE NOT NULL,
	dni VARCHAR(20) UNIQUE NOT NULL,
	telefono VARCHAR(20),
	fecha_registro DATE DEFAULT CURRENT_TIMESTAMP
  );

--2
  CREATE TABLE MESA (
	id_mesa SERIAL PRIMARY KEY,
    id_scrsal INT NOT NULL,
    numero INTEGER NOT NULL,
    capacidad INTEGER NOT NULL,
    estado VARCHAR(20) DEFAULT 'Disponible',
    CONSTRAINT fk_mesa_sucursal
        FOREIGN KEY (id_scrsal)
        REFERENCES SUCURSAL(id_scrsal)
  );

--3
  CREATE TABLE PEDIDO (
	id_pedido SERIAL PRIMARY KEY,
    id_cliente INT NOT NULL,          
    id_empleado INT NOT NULL,          
    id_mesa INT NOT NULL,              
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(30) DEFAULT 'Pendiente',
    total NUMERIC(10,2),
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES CLIENTE(id_cliente),
    CONSTRAINT fk_pedido_empleado
        FOREIGN KEY (id_empleado)
        REFERENCES EMPLEADO(id_empleado),
    CONSTRAINT fk_pedido_mesa
        FOREIGN KEY (id_mesa)
        REFERENCES MESA(id_mesa)
  );

--4
  CREATE TABLE DETALLE_PEDIDO (
	id_detalle SERIAL PRIMARY KEY,
    id_pedido INT NOT NULL,            
    id_producto INT NOT NULL,          
    cantidad NUMERIC(8,0) NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,
    subtotal NUMERIC(12,2),
    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES PEDIDO(id_pedido),
    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (id_producto)
        REFERENCES PRODUCTO(id_producto)
  );

--5
CREATE TABLE PRODUCTO (
	id_producto SERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL,
	descripcion VARCHAR(50),
	precio DECIMAL(10,2) NOT NULL,
	stock INT NOT NULL,
	id_categoria INT NOT NULL,

	CONSTRAINT fk_id_categoria
		FOREIGN KEY (id_categoria)
		REFERENCES CATEGORIA(id_categoria)
		ON DELETE SET NULL
  );

--6
CREATE TABLE CATEGORIA (
	id_categoria SERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL,
	descripcion VARCHAR(50)
  );

--7
  CREATE TABLE EMPLEADO (
	id_empleado SERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL,
	apellido VARCHAR(50) NOT NULL,
	dni VARCHAR(9) UNIQUE,
	email VARCHAR(50) UNIQUE,
	telefono VARCHAR(12),
	rol VARCHAR(50) NOT NULL CHECK (rol IN ('Mesero', 'Cocinero', 'Gerente', 'Cajero')),
	turno VARCHAR(50) NOT NULL CHECK (turno IN ('Mañana', 'Tarde', 'Noche')),
	id_scrsal INT NOT NULL,

	CONSTRAINT fk_empldo_id_scrsal
		FOREIGN KEY (id_scrsal)
		REFERENCES SUCURSAL(id_scrsal)
	  	ON DELETE SET NULL
  );

--8
  CREATE TABLE PROVEEDOR (
	id_prvdor SERIAL PRIMARY KEY,
	nombre VARCHAR(50) NOT NULL,
	ruc VARCHAR(20) NOT NULL,
	telefono VARCHAR(12),
	email VARCHAR(50) UNIQUE,
	id_scrsal INT NOT NULL,

	CONSTRAINT fk_id_scrsal
		FOREIGN KEY (id_scrsal)
		REFERENCES SUCURSAL(id_scrsal)
  );

--9
  CREATE TABLE COMPRA (
	id_compra SERIAL PRIMARY KEY,
  	fecha DATE NOT NULL,
  	total DECIMAL(10,2) NOT NULL CHECK(total >= 0),
  	estado VARCHAR(100) NOT NULL CHECK(estado IN('pendiente', 'recibido', 'cancelado', 'parcialmente recibido', 'devuelto')),
  	id_scrsal INT NOT NULL,
  	id_prvdor INT,
  
  	CONSTRAINT fk_id_scrsal
		FOREIGN KEY (id_scrsal)
  		REFERENCES SUCURSAL(id_scrsal)
		ON DELETE CASCADE,
  	CONSTRAINT fk_id_prvdor
		FOREIGN KEY (id_prvdor)
  		REFERENCES PROVEEDOR(id_prvdor)
		ON DELETE SET NULL
  );

--10
  CREATE TABLE DETALLE_COMPRA (
	id_dtlle_compra SERIAL PRIMARY KEY,
  	cantidad DECIMAL(10,2) NOT NULL CHECK(cantidad >=0),
	subtotal DECIMAL(10,2) NOT NULL CHECK(subtotal >= 0),
	precio_unitario DECIMAL(10,2) NOT NULL CHECK(precio_unitario >= 0),
	id_producto INT NOT NULL,
	id_compra INT NOT NULL,
	  	
	CONSTRAINT fk_id_producto
		FOREIGN KEY (id_producto)
		REFERENCES PRODUCTO(id_producto)
		ON DELETE CASCADE,
	CONSTRAINT fk_id_compra
	  	FOREIGN KEY (id_compra)
	  	REFERENCES COMPRA(id_compra)
		ON DELETE CASCADE
  );

--11
  CREATE TABLE PAGO (
	id_pago SERIAL PRIMARY KEY,
  	monto DECIMAL(10,2) NOT NULL CHECK(monto > 0),
  	metodo VARCHAR(100) NOT NULL CHECK (metodo IN ('efectivo', 'tarjeta debito', 'tarjeta credito', 'billetera digital', 'transferencia')),
  	fcha_pago DATE NOT NULL,
  	estado VARCHAR(100) NOT NULL CHECK(estado IN('pendiente', 'completado', 'cancelado', 'reembolsado')),
  	id_pedido INT NOT NULL,
  
  	CONSTRAINT fk_id_pedido
		FOREIGN KEY (id_pedido)
  		REFERENCES PEDIDO(id_pedido)
		ON DELETE CASCADE
  );

--12
  CREATE TABLE FACTURA (
	id_factura SERIAL PRIMARY KEY,
  	numero VARCHAR(50) NOT NULL UNIQUE,
  	fecha_emision DATE NOT NULL,
  	monto_total DECIMAL(10,2) NOT NULL CHECK(monto_total >= 0),
  	id_pago INT NOT NULL,
  
  	CONSTRAINT fk_id_pago
		FOREIGN KEY (id_pago)
  		REFERENCES PAGO(id_pago)
  );
CREATE TABLE RESERVA (
    id_reserva SERIAL PRIMARY KEY,
    fecha_reserva DATE NOT NULL,
    hora TIME NOT NULL,
    num_personas INTEGER NOT NULL,
    estado VARCHAR(30) DEFAULT 'Pendiente',
    id_cliente INT NOT NULL,
    id_mesa INT NOT NULL,
    id_scrsal INT NOT NULL,

    CONSTRAINT fk_reserva_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES CLIENTE(id_cliente),
    CONSTRAINT fk_reserva_mesa
        FOREIGN KEY (id_mesa)
        REFERENCES MESA(id_mesa),
    CONSTRAINT fk_reserva_sucursal
        FOREIGN KEY (id_scrsal)
        REFERENCES SUCURSAL(id_scrsal)
);

--14
CREATE TABLE PROMOCION (
    id_promocion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descuento_pct DECIMAL(5,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    id_scrsal INT,

    CONSTRAINT fk_promocion_sucursal
        FOREIGN KEY (id_scrsal)
        REFERENCES SUCURSAL(id_scrsal)
);

--15
CREATE TABLE SUCURSAL (
    id_scrsal SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(150) NOT NULL,
    ciudad VARCHAR(50) NOT NULL,
    telefono VARCHAR(20)
);
