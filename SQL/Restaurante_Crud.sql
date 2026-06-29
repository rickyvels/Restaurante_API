
--Pagos
INSERT INTO PAGO (monto, metodo, fcha_pago, estado, id_pedido) 
VALUES (15000, 'tarjeta debito', CURRENT_DATE, 'pendiente', 5);

INSERT INTO FACTURA (numero, fecha_emision, monto_total, id_pago) 
VALUES ('FAC-001', CURRENT_DATE, 15000, LASTVAL());

UPDATE PEDIDO SET estado = 'Pagado' WHERE id_pedido = 5;

UPDATE PAGO SET estado = 'completado' WHERE id_pedido = 5;

--Compra a proveedor
INSERT INTO COMPRA (fecha, total, estado, id_scrsal, id_prvdor)
VALUES (CURRENT_DATE, 0, 'recibido', 1, 1);

INSERT INTO DETALLE_COMPRA (cantidad, subtotal, precio_unitario, id_producto, id_compra)
VALUES (36, 36*800, 800, 10, LASTVAL());

UPDATE PRODUCTO
SET stock = stock + 36
WHERE id_producto = 10;

UPDATE COMPRA
SET total = (
  SELECT SUM(subtotal)
  FROM DETALLE_COMPRA
  WHERE id_compra = LASTVAL()
) 
WHERE id_compra = LASTVAL();
