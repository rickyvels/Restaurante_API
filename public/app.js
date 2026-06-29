/* =====================================================================
   Restaurante — logica del panel (vanilla JS, sin framework)
   ===================================================================== */
const $  = (s) => document.querySelector(s);
const $$ = (s) => Array.from(document.querySelectorAll(s));
const api = (url, opts) => fetch(url, opts).then(r => r.json().then(d => ({ ok: r.ok, d })));
const soles = (n) => 'S/ ' + Number(n).toFixed(2);

let editandoId = null;     // id del producto en edicion
let carrito = [];          // items del pedido en construccion
let cacheProductos = [];   // para precios en el carrito

/* ---------- Consola SQL (elemento firma) ---------- */
const KEYWORDS = ['SELECT','FROM','WHERE','INSERT INTO','VALUES','UPDATE','SET','DELETE','RETURNING',
  'JOIN','LEFT JOIN','INNER JOIN','ON','GROUP BY','HAVING','ORDER BY','BEGIN','COMMIT','ROLLBACK',
  'AND','OR','IN','AS','COUNT','SUM','DISTINCT','COALESCE','FOR UPDATE','EXPLAIN','ANALYZE','BUFFERS',
  'CREATE INDEX','USING','GIN','DESC','ASC','NOT','jsonb','json_agg','json_build_object'];

function resaltar(sql){
  let html = sql.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  html = html.replace(/(--[^\n]*)/g, '<span class="c">$1</span>');          // comentarios
  html = html.replace(/'([^']*)'/g, '<span class="s">\'$1\'</span>');        // strings
  html = html.replace(/\$(\d+)/g, '<span class="n">$$$1</span>');            // $1, $2
  KEYWORDS.sort((a,b)=>b.length-a.length).forEach(k=>{
    html = html.replace(new RegExp('\\b('+k.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+')\\b','g'),
      '<span class="k">$1</span>');
  });
  return html;
}
function mostrarSQL(sql, ctx, params){
  const out = $('#sql-out');
  out.classList.remove('empty');
  out.innerHTML = resaltar(sql || '');
  $('#sql-ctx').textContent = ctx || 'consulta';
  $('#sql-params').textContent = (params && params.length)
    ? 'Parámetros: ' + JSON.stringify(params) : '';
  $('#sqlbar').classList.remove('collapsed');
}
$('#sqlbar-hd').addEventListener('click', () => {
  const bar = $('#sqlbar');
  bar.classList.toggle('collapsed');
  $('#sql-toggle').textContent = bar.classList.contains('collapsed') ? '▴ mostrar' : '▾ ocultar';
});

/* ---------- Avisos ---------- */
function aviso(sel, tipo, msg){
  const n = $(sel);
  n.className = 'notice show ' + tipo;
  n.textContent = (tipo === 'ok' ? '✓ ' : '✕ ') + msg;
  setTimeout(() => n.classList.remove('show'), 6000);
}

/* ---------- Navegacion ---------- */
$('#nav').addEventListener('click', (e) => {
  const b = e.target.closest('button'); if (!b) return;
  $$('.nav button').forEach(x => x.classList.remove('active'));
  $$('.page').forEach(x => x.classList.remove('active'));
  b.classList.add('active');
  $('#page-' + b.dataset.page).classList.add('active');
});

/* =====================================================================
   1) CRUD PRODUCTOS
   ===================================================================== */
async function cargarCategorias(){
  const { d } = await api('/api/categorias');
  const opts = '<option value="">— sin categoría —</option>' +
    d.data.map(c => `<option value="${c.id}">${c.nombre}</option>`).join('');
  $('#p-categoria').innerHTML = opts;
}

async function cargarProductos(){
  const { d } = await api('/api/productos');
  cacheProductos = d.data;
  mostrarSQL(d._sql, 'CRUD · SELECT (lista de platos)');
  const tb = $('#tabla-productos tbody');
  tb.innerHTML = d.data.map(p => `
    <tr>
      <td class="mono">${p.id}</td>
      <td><b>${p.nombre}</b></td>
      <td>${p.categoria ? `<span class="tag gray">${p.categoria}</span>` : '<span class="tag gray">—</span>'}</td>
      <td class="right mono">${soles(p.precio)}</td>
      <td class="right mono">${p.stock}</td>
      <td><div class="jsonbox">${JSON.stringify(p.atributos)}</div></td>
      <td><div class="row-actions">
        <button class="btn ghost sm" onclick='editar(${p.id})'>Editar</button>
        <button class="btn danger sm" onclick='borrar(${p.id})'>Eliminar</button>
      </div></td>
    </tr>`).join('');
}

$('#btn-guardar').addEventListener('click', async () => {
  const body = {
    nombre: $('#p-nombre').value.trim(),
    precio: parseFloat($('#p-precio').value),
    stock: parseInt($('#p-stock').value || '0', 10),
    categoria_id: $('#p-categoria').value || null,
    atributos: { vegano: $('#p-vegano').value === 'true', picante: parseInt($('#p-picante').value || '0', 10) },
    disponible: true,
  };
  const url = editandoId ? `/api/productos/${editandoId}` : '/api/productos';
  const method = editandoId ? 'PUT' : 'POST';
  const { ok, d } = await api(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  mostrarSQL(d._sql, editandoId ? 'CRUD · UPDATE' : 'CRUD · INSERT', d._params);
  if (ok) {
    aviso('#crud-notice', 'ok', editandoId ? 'Plato actualizado.' : `Plato “${d.data.nombre}” creado (id ${d.data.id}).`);
    cancelarEdicion();
    cargarProductos();
  } else {
    aviso('#crud-notice', 'err', d.error);
  }
});

window.editar = (id) => {
  const p = cacheProductos.find(x => x.id === id); if (!p) return;
  editandoId = id;
  $('#p-nombre').value = p.nombre; $('#p-precio').value = p.precio;
  $('#p-stock').value = p.stock; $('#p-categoria').value = p.categoria_id || '';
  $('#p-vegano').value = String(!!(p.atributos && p.atributos.vegano));
  $('#p-picante').value = (p.atributos && p.atributos.picante) || 0;
  $('#form-titulo').innerHTML = `Editando: ${p.nombre} <span class="pill">UPDATE</span>`;
  $('#btn-guardar').textContent = 'Guardar cambios';
  $('#btn-cancelar').style.display = '';
  window.scrollTo({ top: 0, behavior: 'smooth' });
};
function cancelarEdicion(){
  editandoId = null;
  ['p-nombre','p-precio'].forEach(i => $('#'+i).value = '');
  $('#p-stock').value = 20; $('#p-picante').value = 0; $('#p-vegano').value = 'false';
  $('#form-titulo').innerHTML = 'Nuevo plato <span class="pill">INSERT</span>';
  $('#btn-guardar').textContent = 'Guardar plato';
  $('#btn-cancelar').style.display = 'none';
}
$('#btn-cancelar').addEventListener('click', cancelarEdicion);

window.borrar = async (id) => {
  if (!confirm('¿Eliminar este plato?')) return;
  const { ok, d } = await api(`/api/productos/${id}`, { method: 'DELETE' });
  mostrarSQL(d._sql, 'CRUD · DELETE', d._params);
  if (ok) { aviso('#crud-notice', 'ok', `Plato “${d.data.nombre}” eliminado.`); cargarProductos(); }
  else aviso('#crud-notice', 'err', d.error);
};

/* =====================================================================
   2) VENTA / TRANSACCION
   ===================================================================== */
async function cargarCatalogosVenta(){
  const [cl, me, em] = await Promise.all([api('/api/clientes'), api('/api/mesas'), api('/api/empleados')]);
  $('#v-cliente').innerHTML  = '<option value="">— sin cliente —</option>' + cl.d.data.map(c=>`<option value="${c.id}">${c.nombre}</option>`).join('');
  $('#v-mesa').innerHTML     = '<option value="">— sin mesa —</option>' + me.d.data.map(m=>`<option value="${m.id}">Mesa ${m.numero} (cap. ${m.capacidad})</option>`).join('');
  $('#v-empleado').innerHTML = '<option value="">— sin mesero —</option>' + em.d.data.map(e=>`<option value="${e.id}">${e.nombre} (${e.rol})</option>`).join('');
}
function refrescarProdSelect(){
  $('#v-prod').innerHTML = cacheProductos.map(p=>`<option value="${p.id}">${p.nombre} — ${soles(p.precio)} (stock ${p.stock})</option>`).join('');
}
$('#btn-add-item').addEventListener('click', () => {
  const id = parseInt($('#v-prod').value, 10);
  const cant = parseInt($('#v-cant').value || '1', 10);
  const p = cacheProductos.find(x => x.id === id); if (!p) return;
  const ex = carrito.find(i => i.producto_id === id);
  if (ex) ex.cantidad += cant; else carrito.push({ producto_id: id, nombre: p.nombre, precio: Number(p.precio), cantidad: cant });
  renderCarrito();
});
function renderCarrito(){
  const tb = $('#tabla-carrito tbody');
  tb.innerHTML = carrito.map((i, idx) => `
    <tr><td>${i.nombre}</td><td class="right mono">${i.cantidad}</td>
    <td class="right mono">${soles(i.precio)}</td><td class="right mono">${soles(i.precio*i.cantidad)}</td>
    <td class="right"><button class="btn danger sm" onclick="quitarItem(${idx})">×</button></td></tr>`).join('');
  const total = carrito.reduce((s,i)=>s+i.precio*i.cantidad,0);
  $('#carrito-total').textContent = soles(total);
  $('#btn-registrar').disabled = carrito.length === 0;
}
window.quitarItem = (idx) => { carrito.splice(idx,1); renderCarrito(); };

$('#btn-registrar').addEventListener('click', async () => {
  const body = {
    cliente_id: $('#v-cliente').value || null,
    mesa_id: $('#v-mesa').value || null,
    empleado_id: $('#v-empleado').value || null,
    items: carrito.map(i => ({ producto_id: i.producto_id, cantidad: i.cantidad })),
  };
  const { ok, d } = await api('/api/pedidos', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
  mostrarSQL(d._sql, ok ? 'Transacción · COMMIT' : 'Transacción · ROLLBACK');
  if (ok) {
    aviso('#venta-notice', 'ok', `Venta registrada. Pedido #${d.data.id}, total ${soles(d.data.total)}.`);
    carrito = []; renderCarrito();
    await cargarProductos(); refrescarProdSelect();   // stock actualizado
    cargarPedidos();
  } else {
    aviso('#venta-notice', 'err', d.error);
  }
});

async function cargarPedidos(){
  const { d } = await api('/api/pedidos');
  $('#tabla-pedidos tbody').innerHTML = d.data.map(p => `
    <tr><td class="mono">${p.id}</td><td>${p.cliente||'—'}</td><td>${p.mesa?('Mesa '+p.mesa):'—'}</td>
    <td>${p.mesero||'—'}</td><td><span class="tag green">${p.estado}</span></td>
    <td class="right mono">${soles(p.total)}</td></tr>`).join('');
}

/* =====================================================================
   3) REPORTE
   ===================================================================== */
$('#btn-reporte').addEventListener('click', async () => {
  const min = $('#r-min').value || 0;
  const { d } = await api(`/api/reportes/ventas-por-categoria?min=${min}`);
  mostrarSQL(d._sql, 'Reporte · GROUP BY / HAVING (JOIN 4 tablas)', d._params);
  $('#tabla-reporte tbody').innerHTML = d.data.length
    ? d.data.map(r => `<tr><td><b>${r.categoria}</b></td><td class="right mono">${r.num_pedidos}</td>
        <td class="right mono">${r.unidades_vendidas}</td><td class="right mono">${soles(r.ingresos)}</td></tr>`).join('')
    : '<tr><td colspan="4" style="color:var(--ink-soft)">Ninguna categoría supera ese mínimo.</td></tr>';
});
$$('[data-fmt]').forEach(b => b.addEventListener('click', () => {
  const min = $('#r-min').value || 0;
  window.location = `/api/reportes/ventas-por-categoria?min=${min}&formato=${b.dataset.fmt}`;
}));

/* =====================================================================
   4) NOSQL / JSONB
   ===================================================================== */
function renderNosql(d){
  mostrarSQL(d._sql, 'NoSQL · JSONB', d._params);
  $('#tabla-nosql tbody').innerHTML = d.data.length
    ? d.data.map(p => `<tr><td class="mono">${p.id}</td><td><b>${p.nombre}</b></td>
        <td class="right mono">${p.precio?soles(p.precio):'—'}</td>
        <td><div class="jsonbox">${p.atributos?JSON.stringify(p.atributos):''}</div></td></tr>`).join('')
    : '<tr><td colspan="4" style="color:var(--ink-soft)">Sin resultados.</td></tr>';
}
$('#btn-nosql').addEventListener('click', async () => {
  const clave = $('#nq-clave').value, valor = $('#nq-valor').value;
  const { d } = await api(`/api/nosql/buscar?clave=${encodeURIComponent(clave)}&valor=${encodeURIComponent(valor)}`);
  renderNosql(d);
});
$('#btn-alerg').addEventListener('click', async () => {
  const a = $('#nq-alerg').value;
  const { d } = await api(`/api/nosql/alergeno?alergeno=${encodeURIComponent(a)}`);
  renderNosql(d);
});

/* =====================================================================
   5) OPTIMIZACION
   ===================================================================== */
$('#btn-indices').addEventListener('click', async () => {
  const { d } = await api('/api/optimizacion/indices');
  mostrarSQL(d._sql, 'Optimización · pg_indexes');
  $('#indices-wrap').style.display = '';
  $('#tabla-indices tbody').innerHTML = d.data.map(i => `
    <tr><td class="mono">${i.tablename}</td><td class="mono">${i.indexname}</td>
    <td class="mono" style="font-size:11px">${i.indexdef}</td></tr>`).join('');
});
$('#btn-explain').addEventListener('click', async () => {
  const { d } = await api('/api/optimizacion/explain');
  mostrarSQL(d._sql, 'Optimización · EXPLAIN ANALYZE');
  $('#explain-out').style.display = '';
  $('#explain-out').textContent = d.data;
});

/* ---------- Arranque ---------- */
(async function init(){
  await cargarCategorias();
  await cargarProductos();
  refrescarProdSelect();
  await cargarCatalogosVenta();
  await cargarPedidos();
})();
