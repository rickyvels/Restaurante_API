// =====================================================================
//  Inicializa la base: crea tablas, carga datos y crea indices.
//  Uso:  npm run db:init
// =====================================================================
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./db');

async function run() {
  const archivos = ['01_schema.sql', '02_seed.sql', '03_indices.sql'];
  const client = await pool.connect();
  try {
    for (const f of archivos) {
      const sql = fs.readFileSync(path.join(__dirname, '..', 'db', f), 'utf8');
      process.stdout.write(`Ejecutando ${f} ... `);
      await client.query(sql);
      console.log('OK');
    }
    console.log('\nBase de datos lista.');
  } catch (e) {
    console.error('\nError inicializando la BD:', e.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}
run();
