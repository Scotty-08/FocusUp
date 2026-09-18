import { readFileSync } from "node:fs";
import { join } from "node:path";
import "dotenv/config";
import { pool, closePool } from "./pool";

// Deliberately simple -- one idempotent schema.sql, no migration
// framework. Fine at this size; a real migration tool (e.g.
// node-pg-migrate) is the obvious next step once the schema needs to
// evolve without being able to just re-run the whole file.
async function migrate(): Promise<void> {
  const schemaPath = join(__dirname, "schema.sql");
  const schema = readFileSync(schemaPath, "utf8");
  await pool.query(schema);
  console.log("Schema applied.");
}

migrate()
  .catch((err) => {
    console.error("Migration failed:", err);
    process.exitCode = 1;
  })
  .finally(() => {
    void closePool();
  });
