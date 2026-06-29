// =====================================================================
//  RESTAURANTE - API (Express + PostgreSQL)
//  Cada endpoint devuelve el SQL que ejecuto (campo "_sql") para que en
//  la demo se vea exactamente que consulta corrio.
//
//  MAPA RUBRICA -> ENDPOINT:
//   * CRUD simple + constraints  -> /api/productos (GET/POST/PUT/DELETE)
//   * CRUD complejo 3+ tablas + Transaccion ACID -> POST /api/pedidos
//   * Reporte GROUP BY/HAVING + JOIN + export -> /api/reportes/ventas-por-categoria
//   * NoSQL / JSONB             -> /api/nosql/*
//   * Optimizacion / EXPLAIN    -> /api/optimizacion/*
// =====================================================================
require('dotenv').config();
const express = require('express');
const path = require('path');
const ExcelJS = require('exceljs');
const { pool } = require('./db');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

// ---------------------------------------------------------------------
//  Helper: traduce errores de constraints de PostgreSQL a mensajes claros.
// ---------------------------------------------------------------------
function explicarError(err) {
  switch (err.code) {
    case '23505': return `Violacion de UNIQUE: ya existe un registro con ese valor (${err.constraint}).`;
    case '23514': return `Violacion de CHECK: el valor no cumple la regla (${err.constraint}).`;
    case '23502': return `Violacion de NOT NULL: el campo "${err.column}" es obligatorio.`;
    case '23503': return `Violacion de llave foranea: el registro relacionado no existe o no se puede borrar (${err.constraint}).`;
    default:      return err.message;
  }
}

// =====================================================================
//  CATALOGOS (para los <select> del formulario de pedidos)
// =====================================================================
app.get('/api/categorias', async (_req, res) => {
  const sql = 'SELECT id, nombre FROM categorias ORDER BY nombre';
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql, data: rows });
});
app.get('/api/clientes', async (_req, res) => {
  const sql = 'SELECT id, nombre, email FROM clientes ORDER BY nombre';
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql, data: rows });
});
app.get('/api/mesas', async (_req, res) => {
  const sql = 'SELECT id, numero, capacidad FROM mesas ORDER BY numero';
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql, data: rows });
});
app.get('/api/empleados', async (_req, res) => {
  const sql = "SELECT id, nombre, rol FROM empleados WHERE activo = TRUE ORDER BY nombre";
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql, data: rows });
});

// =====================================================================
//  1) CRUD PRODUCTOS  (demostrar CHECK / UNIQUE / NOT NULL en vivo)
// =====================================================================

// Listar
app.get('/api/productos', async (_req, res) => {
  const sql = `
SELECT p.id, p.nombre, p.precio, p.stock, p.disponible,
       c.nombre AS categoria, p.categoria_id, p.atributos
FROM productos p
LEFT JOIN categorias c ON c.id = p.categoria_id
ORDER BY p.id`;
  try {
    const { rows } = await pool.query(sql);
    res.json({ _sql: sql.trim(), data: rows });
  } catch (e) {
    res.status(500).json({ _sql: sql.trim(), error: explicarError(e) });
  }
});

// Crear  (aqui se prueban CHECK precio>0, stock>=0 y UNIQUE nombre)
app.post('/api/productos', async (req, res) => {
  const { nombre, precio, stock, categoria_id, atributos } = req.body;
  const sql = `
INSERT INTO productos (nombre, precio, stock, categoria_id, atributos)
VALUES ($1, $2, $3, $4, $5::jsonb)
RETURNING *`;
  const params = [nombre, precio, stock ?? 0, categoria_id || null, JSON.stringify(atributos || {})];
  try {
    const { rows } = await pool.query(sql, params);
    res.status(201).json({ _sql: sql.trim(), _params: params, data: rows[0] });
  } catch (e) {
    res.status(400).json({ _sql: sql.trim(), _params: params, error: explicarError(e) });
  }
});

// Editar
app.put('/api/productos/:id', async (req, res) => {
  const { nombre, precio, stock, categoria_id, disponible } = req.body;
  const sql = `
UPDATE productos
SET nombre = $1, precio = $2, stock = $3, categoria_id = $4, disponible = $5
WHERE id = $6
RETURNING *`;
  const params = [nombre, precio, stock, categoria_id || null, disponible, req.params.id];
  try {
    const { rows } = await pool.query(sql, params);
    if (rows.length === 0) return res.status(404).json({ error: 'No existe el producto.' });
    res.json({ _sql: sql.trim(), _params: params, data: rows[0] });
  } catch (e) {
    res.status(400).json({ _sql: sql.trim(), _params: params, error: explicarError(e) });
  }
});

// Eliminar
app.delete('/api/productos/:id', async (req, res) => {
  const sql = 'DELETE FROM productos WHERE id = $1 RETURNING id, nombre';
  try {
    const { rows } = await pool.query(sql, [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'No existe el producto.' });
    res.json({ _sql: sql, _params: [req.params.id], data: rows[0] });
  } catch (e) {
    res.status(400).json({ _sql: sql, error: explicarError(e) });
  }
});

// =====================================================================
//  2) CRUD COMPLEJO + TRANSACCION ACID
//     Crear un pedido toca 3 tablas: pedidos + detalle_pedido + productos
//     (descuenta stock). Todo dentro de BEGIN ... COMMIT / ROLLBACK.
// =====================================================================
app.post('/api/pedidos', async (req, res) => {
  const { cliente_id, mesa_id, empleado_id, items } = req.body; // items: [{producto_id, cantidad}]
  if (!Array.isArray(items) || items.length === 0)
    return res.status(400).json({ error: 'Debe enviar al menos un item.' });

  const pasos = []; // guardamos el SQL de cada paso para mostrarlo
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    pasos.push('BEGIN;');

    // 1) Cabecera del pedido
    const insPedido = `INSERT INTO pedidos (cliente_id, mesa_id, empleado_id, estado, total)
                       VALUES ($1, $2, $3, 'pendiente', 0) RETURNING id`;
    const ped = await client.query(insPedido, [cliente_id || null, mesa_id || null, empleado_id || null]);
    const pedidoId = ped.rows[0].id;
    pasos.push(`-- cabecera\nINSERT INTO pedidos (...) VALUES (${cliente_id||'NULL'}, ${mesa_id||'NULL'}, ${empleado_id||'NULL'}, 'pendiente', 0);`);

    // 2) Por cada item: validar stock, insertar detalle, descontar stock
    for (const it of items) {
      const prod = await client.query('SELECT nombre, precio, stock FROM productos WHERE id = $1 FOR UPDATE', [it.producto_id]);
      if (prod.rows.length === 0) throw { code: 'CUSTOM', message: `Producto ${it.producto_id} no existe.` };
      const p = prod.rows[0];
      if (p.stock < it.cantidad)
        throw { code: 'CUSTOM', message: `Stock insuficiente de "${p.nombre}" (hay ${p.stock}, pediste ${it.cantidad}). Se hace ROLLBACK.` };

      await client.query(
        `INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
         VALUES ($1, $2, $3, $4)`,
        [pedidoId, it.producto_id, it.cantidad, p.precio]
      );
      pasos.push(`-- linea\nINSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES (${pedidoId}, ${it.producto_id}, ${it.cantidad}, ${p.precio});`);

      await client.query('UPDATE productos SET stock = stock - $1 WHERE id = $2', [it.cantidad, it.producto_id]);
      pasos.push(`-- descontar stock\nUPDATE productos SET stock = stock - ${it.cantidad} WHERE id = ${it.producto_id};`);
    }

    // 3) Recalcular total del pedido desde el detalle
    await client.query(
      `UPDATE pedidos SET total = (SELECT COALESCE(SUM(subtotal),0) FROM detalle_pedido WHERE pedido_id = $1) WHERE id = $1`,
      [pedidoId]
    );
    pasos.push(`-- total\nUPDATE pedidos SET total = (SELECT SUM(subtotal) FROM detalle_pedido WHERE pedido_id = ${pedidoId}) WHERE id = ${pedidoId};`);

    await client.query('COMMIT');
    pasos.push('COMMIT;');

    const final = await client.query(
      `SELECT p.id, p.total, p.estado,
              json_agg(json_build_object('producto', pr.nombre, 'cantidad', d.cantidad, 'subtotal', d.subtotal)) AS items
       FROM pedidos p
       JOIN detalle_pedido d ON d.pedido_id = p.id
       JOIN productos pr ON pr.id = d.producto_id
       WHERE p.id = $1 GROUP BY p.id`, [pedidoId]);

    res.status(201).json({ _sql: pasos.join('\n'), data: final.rows[0] });
  } catch (e) {
    await client.query('ROLLBACK');
    pasos.push('ROLLBACK;  -- se revierte TODO');
    res.status(400).json({ _sql: pasos.join('\n'), error: e.message || explicarError(e) });
  } finally {
    client.release();
  }
});

// Listar pedidos (con JOIN a cliente, mesa, empleado)
app.get('/api/pedidos', async (_req, res) => {
  const sql = `
SELECT p.id, p.fecha, p.estado, p.total,
       cl.nombre AS cliente, m.numero AS mesa, e.nombre AS mesero
FROM pedidos p
LEFT JOIN clientes  cl ON cl.id = p.cliente_id
LEFT JOIN mesas     m  ON m.id  = p.mesa_id
LEFT JOIN empleados e  ON e.id  = p.empleado_id
ORDER BY p.id DESC`;
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql.trim(), data: rows });
});

// =====================================================================
//  3) REPORTE: GROUP BY / HAVING + JOIN de 4 tablas + EXPORTACION
//     formato = json (default) | csv | excel
// =====================================================================
const SQL_REPORTE = `
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
ORDER BY ingresos DESC`;

app.get('/api/reportes/ventas-por-categoria', async (req, res) => {
  const minimo = Number(req.query.min ?? 0);
  const formato = (req.query.formato || 'json').toLowerCase();
  let rows;
  try {
    const r = await pool.query(SQL_REPORTE, [minimo]);
    rows = r.rows;
  } catch (e) {
    return res.status(500).json({ _sql: SQL_REPORTE.trim(), error: explicarError(e) });
  }

  if (formato === 'json')
    return res.json({ _sql: SQL_REPORTE.trim(), _params: [minimo], data: rows });

  if (formato === 'csv') {
    const cab = ['categoria', 'num_pedidos', 'unidades_vendidas', 'ingresos'];
    const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
    const csv = [cab.join(',')]
      .concat(rows.map(r => cab.map(k => esc(r[k])).join(',')))
      .join('\n');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="reporte_ventas.csv"');
    return res.send('\ufeff' + csv); // BOM para que Excel abra bien los acentos
  }

  if (formato === 'excel') {
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('Ventas');
    ws.columns = [
      { header: 'Categoria', key: 'categoria', width: 22 },
      { header: 'N. Pedidos', key: 'num_pedidos', width: 14 },
      { header: 'Unidades', key: 'unidades_vendidas', width: 14 },
      { header: 'Ingresos', key: 'ingresos', width: 14 },
    ];
    ws.getRow(1).font = { bold: true };
    rows.forEach(r => ws.addRow(r));
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename="reporte_ventas.xlsx"');
    await wb.xlsx.write(res);
    return res.end();
  }

  res.status(400).json({ error: 'Formato no soportado. Use json, csv o excel.' });
});

// =====================================================================
//  4) MODULO NoSQL / HIBRIDO (JSONB sobre productos.atributos)
// =====================================================================

// Buscar por igualdad dentro del JSON  (ej: vegano=true)
app.get('/api/nosql/buscar', async (req, res) => {
  const { clave, valor } = req.query;
  const sql = `SELECT id, nombre, precio, atributos
               FROM productos
               WHERE atributos @> $1::jsonb`;
  // valor puede ser true/false/numero/texto -> lo normalizamos a JSON
  let valJson;
  if (valor === 'true' || valor === 'false') valJson = `{"${clave}": ${valor}}`;
  else if (!isNaN(Number(valor)))            valJson = `{"${clave}": ${Number(valor)}}`;
  else                                        valJson = `{"${clave}": "${valor}"}`;
  try {
    const { rows } = await pool.query(sql, [valJson]);
    res.json({ _sql: sql.trim(), _params: [valJson], _explica: 'Tabla afectada: productos (columna JSONB atributos). Operador @> = "contiene".', data: rows });
  } catch (e) {
    res.status(400).json({ _sql: sql.trim(), error: explicarError(e) });
  }
});

// Buscar por alergeno dentro del arreglo JSON
app.get('/api/nosql/alergeno', async (req, res) => {
  const { alergeno } = req.query;
  const sql = `SELECT id, nombre FROM productos
               WHERE atributos -> 'alergenos' @> $1::jsonb`;
  const param = JSON.stringify([alergeno]);
  try {
    const { rows } = await pool.query(sql, [param]);
    res.json({ _sql: sql.trim(), _params: [param], _explica: 'Busca dentro del arreglo JSON "alergenos" de la tabla productos.', data: rows });
  } catch (e) {
    res.status(400).json({ _sql: sql.trim(), error: explicarError(e) });
  }
});

// =====================================================================
//  5) OPTIMIZACION / EXPLAIN
// =====================================================================
app.get('/api/optimizacion/explain', async (_req, res) => {
  const sql = `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
${SQL_REPORTE.replace('$1', '0')}`;
  try {
    const { rows } = await pool.query(sql);
    res.json({ _sql: sql.trim(), data: rows.map(r => r['QUERY PLAN']).join('\n') });
  } catch (e) {
    res.status(500).json({ _sql: sql.trim(), error: explicarError(e) });
  }
});

app.get('/api/optimizacion/indices', async (_req, res) => {
  const sql = `SELECT indexname, tablename, indexdef
               FROM pg_indexes
               WHERE schemaname = 'public'
               ORDER BY tablename, indexname`;
  const { rows } = await pool.query(sql);
  res.json({ _sql: sql.trim(), data: rows });
});

// ---------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n  Restaurante API + Web corriendo en  http://localhost:${PORT}\n`);
});
