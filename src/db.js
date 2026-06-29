// =====================================================================
//  Conexion a PostgreSQL.
//  Usa la variable DATABASE_URL del archivo .env.
//  Funciona igual con PostgreSQL LOCAL o con SUPABASE: solo se cambia
//  la cadena de conexion en .env, el codigo NO cambia.
// =====================================================================
require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  // Supabase exige SSL. En local no. Se activa solo si la URL lo pide.
  ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes('supabase')
    ? { rejectUnauthorized: false }
    : false,
});

module.exports = { pool };
