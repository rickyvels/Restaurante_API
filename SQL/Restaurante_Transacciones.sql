-- TRANSACCIÓN REGISTRAR PEDIDO  (4 TABLAS)


BEGIN;

INSERT INTO PEDIDO (id_cliente, id_empleado, id_mesa, estado, total)
VALUES (1, 2, 3, 'Pendiente', 50.00);

INSERT INTO DETALLE_PEDIDO (id_pedido, id_producto, cantidad, precio_unitario, subtotal)
VALUES (1, 10, 2, 25.00, 50.00);

UPDATE PRODUCTO SET stock = stock - 2 WHERE id_producto = 10;

UPDATE MESA SET estado = 'Ocupada' WHERE id_mesa = 3;

COMMIT;

-- TRANSACCIÓN REGISTRAR PAGO (4 TABLAS)


BEGIN;

INSERT INTO PAGO (monto, metodo, fcha_pago, estado, id_pedido)
VALUES (15000, 'tarjeta debito', CURRENT_DATE, 'completado', 5);

INSERT INTO FACTURA (numero, fecha_emision, monto_total, id_pago)
VALUES ('FAC-001', CURRENT_DATE, 15000, 1);

UPDATE PEDIDO SET estado = 'Pagado' WHERE id_pedido = 5;

COMMIT;
