import { Router } from "express";
import { z } from "zod";
import { pool } from "../db/pool";
import { requireAuth, type AuthedRequest } from "../middleware/requireAuth";
import { pickNextActiveTask } from "../utils/activeTask";
import { toTaskDTO, type TaskRow } from "../types";

async function getAllTasks(userId: string): Promise<TaskRow[]> {
  const { rows } = await pool.query<TaskRow>(
    "SELECT * FROM tasks WHERE user_id = $1 ORDER BY created_at ASC",
    [userId]
  );
  return rows;
}

// Clears any currently-active task for this user and marks `taskId`
// (or none) as active instead. Wrapped so the "only one active task"
// invariant (enforced by the partial unique index in schema.sql) is
// never violated mid-request.
async function setActiveTask(userId: string, taskId: string | null): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      "UPDATE tasks SET is_active = false WHERE user_id = $1 AND is_active",
      [userId]
    );
    if (taskId) {
      await client.query(
        "UPDATE tasks SET is_active = true WHERE id = $1 AND user_id = $2",
        [taskId, userId]
      );
    }
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

// Same rule as the iOS app (TaskStore.advanceActiveTask): only
// auto-pick when nothing is currently active. An in-progress task,
// manually overridden or not, stays put until it's completed.
async function autoAdvanceIfNeeded(userId: string): Promise<void> {
  const tasks = await getAllTasks(userId);
  if (tasks.some((t) => t.is_active)) return;
  const next = pickNextActiveTask(tasks);
  if (next) await setActiveTask(userId, next.id);
}

export function tasksRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  router.get("/", async (req: AuthedRequest, res) => {
    const tasks = await getAllTasks(req.userId!);
    res.json({ tasks: tasks.map(toTaskDTO) });
  });

  const createSchema = z.object({
    title: z.string().trim().min(1).max(500),
    dueDate: z.string().date().nullish(),
  });

  router.post("/", async (req: AuthedRequest, res) => {
    const parsed = createSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }

    const { rows } = await pool.query<TaskRow>(
      `INSERT INTO tasks (user_id, title, due_date)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [req.userId, parsed.data.title, parsed.data.dueDate ?? null]
    );

    // Only auto-pick if nothing else is active yet -- adding a task
    // due sooner never bumps an in-progress one.
    await autoAdvanceIfNeeded(req.userId!);

    const { rows: fresh } = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1",
      [rows[0]!.id]
    );
    res.status(201).json({ task: toTaskDTO(fresh[0]!) });
  });

  const updateSchema = z.object({
    title: z.string().trim().min(1).max(500).optional(),
    dueDate: z.string().date().nullish(),
    isCompleted: z.boolean().optional(),
  });

  router.patch("/:id", async (req: AuthedRequest, res) => {
    const parsed = updateSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }

    const existing = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1 AND user_id = $2",
      [req.params.id, req.userId]
    );
    const before = existing.rows[0];
    if (!before) {
      res.status(404).json({ error: "Task not found" });
      return;
    }

    const next = {
      title: parsed.data.title ?? before.title,
      dueDate: parsed.data.dueDate !== undefined ? parsed.data.dueDate : before.due_date,
      isCompleted: parsed.data.isCompleted ?? before.is_completed,
    };

    await pool.query(
      `UPDATE tasks SET title = $1, due_date = $2, is_completed = $3, updated_at = now()
       WHERE id = $4`,
      [next.title, next.dueDate, next.isCompleted, before.id]
    );

    // Just finished the currently-active task -> auto-advance, same
    // rule as the shield's "I finished it" on the iOS side.
    if (next.isCompleted && before.is_active) {
      await setActiveTask(req.userId!, null);
      await autoAdvanceIfNeeded(req.userId!);
    }

    const { rows: fresh } = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1",
      [before.id]
    );
    res.json({ task: toTaskDTO(fresh[0]!) });
  });

  // Manual override -- always wins immediately, stays active until
  // completed, exactly like "Set Active" in the iOS Tasks tab.
  router.post("/:id/activate", async (req: AuthedRequest, res) => {
    const existing = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1 AND user_id = $2",
      [req.params.id, req.userId]
    );
    if (existing.rows.length === 0) {
      res.status(404).json({ error: "Task not found" });
      return;
    }

    await setActiveTask(req.userId!, req.params.id!);
    const { rows: fresh } = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1",
      [req.params.id]
    );
    res.json({ task: toTaskDTO(fresh[0]!) });
  });

  router.delete("/:id", async (req: AuthedRequest, res) => {
    const existing = await pool.query<TaskRow>(
      "SELECT * FROM tasks WHERE id = $1 AND user_id = $2",
      [req.params.id, req.userId]
    );
    const task = existing.rows[0];
    if (!task) {
      res.status(404).json({ error: "Task not found" });
      return;
    }

    await pool.query("DELETE FROM tasks WHERE id = $1", [task.id]);

    if (task.is_active) {
      await autoAdvanceIfNeeded(req.userId!);
    }

    res.status(204).send();
  });

  return router;
}
