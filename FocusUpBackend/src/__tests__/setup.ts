import { readFileSync } from "node:fs";
import { join } from "node:path";
import "dotenv/config";
import { afterAll, afterEach, beforeAll } from "vitest";
import { pool, closePool } from "../db/pool";

beforeAll(async () => {
  const schema = readFileSync(join(__dirname, "../db/schema.sql"), "utf8");
  await pool.query(schema);
});

// Truncate (not drop) between tests -- keeps every test isolated
// without paying to re-run the schema each time.
afterEach(async () => {
  await pool.query("TRUNCATE TABLE tasks, users RESTART IDENTITY CASCADE");
});

afterAll(async () => {
  await closePool();
});
