import { Pool } from "pg";

// A single shared connection pool. DATABASE_URL is the only thing that
// changes between local dev, CI, and a real deployment (e.g. AWS RDS) --
// nothing else in the app should know or care where Postgres lives.
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error(
    "DATABASE_URL is not set. Copy .env.example to .env and fill it in."
  );
}

export const pool = new Pool({ connectionString });

export async function closePool(): Promise<void> {
  await pool.end();
}
