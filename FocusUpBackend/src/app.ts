import cors from "cors";
import express, { type Express } from "express";
import { authRouter } from "./routes/auth";
import { healthRouter } from "./routes/health";
import { tasksRouter } from "./routes/tasks";

// Split from index.ts so tests (and anything else) can import a
// ready-to-use Express app without also binding a port -- see
// src/__tests__/health.test.ts.
export function createApp(appleBundleId: string): Express {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.use("/health", healthRouter());
  app.use("/auth", authRouter(appleBundleId));
  app.use("/tasks", tasksRouter());

  app.use((_req, res) => {
    res.status(404).json({ error: "Not found" });
  });

  return app;
}
