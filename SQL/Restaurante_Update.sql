UPDATE SUCURSAL 
SET nombre='Sucursal Habanas',direccion='Av.Bellavista 432'
WHERE ciudad='Arequipa';

UPDATE PEDIDO
SET id_empleado= 2, id_mesa= 4, estado='Pendiente', total=150
WHERE id_cliente=4;

UPDATE PROVEEDOR
SET nombre='Tyler', ruc='20552103816', telefono='598005744', email='Tlr_937@gmail.com'
WHERE id_scrsal='4';
