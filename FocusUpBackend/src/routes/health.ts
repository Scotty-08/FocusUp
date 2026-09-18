import { Router } from "express";
import { pool } from "../db/pool";

export function healthRouter(): Router {
  const router = Router();

  router.get("/", async (_req, res) => {
    try {
      await pool.query("SELECT 1");
      res.json({ status: "ok", db: "reachable" });
    } catch {
      res.status(503).json({ status: "degraded", db: "unreachable" });
    }
  });

  return router;
}
