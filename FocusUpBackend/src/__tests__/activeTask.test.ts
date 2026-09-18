import { describe, expect, it } from "vitest";
import { pickNextActiveTask } from "../utils/activeTask";
import type { TaskRow } from "../types";

function task(overrides: Partial<TaskRow>): TaskRow {
  return {
    id: "id",
    user_id: "user",
    title: "task",
    is_completed: false,
    due_date: null,
    is_active: false,
    created_at: new Date(),
    updated_at: new Date(),
    ...overrides,
  };
}

describe("pickNextActiveTask", () => {
  it("returns null when there is nothing incomplete", () => {
    expect(pickNextActiveTask([])).toBeNull();
    expect(pickNextActiveTask([task({ id: "a", is_completed: true })])).toBeNull();
  });

  it("prefers a dated task over an undated one, regardless of order", () => {
    const undated = task({ id: "a", created_at: new Date("2026-01-01") });
    const dated = task({ id: "b", due_date: "2026-12-31" });
    expect(pickNextActiveTask([undated, dated])?.id).toBe("b");
  });

  it("picks the earliest due date among dated tasks", () => {
    const later = task({ id: "a", due_date: "2026-10-05" });
    const sooner = task({ id: "b", due_date: "2026-09-20" });
    expect(pickNextActiveTask([later, sooner])?.id).toBe("b");
  });

  it("ignores completed tasks entirely", () => {
    const done = task({ id: "a", due_date: "2026-09-18", is_completed: true });
    const pending = task({ id: "b", due_date: "2026-10-01" });
    expect(pickNextActiveTask([done, pending])?.id).toBe("b");
  });

  it("breaks same-day ties by picking one of the tied tasks (never a third)", () => {
    const a = task({ id: "a", due_date: "2026-09-20" });
    const b = task({ id: "b", due_date: "2026-09-20" });
    const other = task({ id: "c", due_date: "2026-10-01" });
    const picks = new Set<string>();
    for (let i = 0; i < 50; i++) {
      picks.add(pickNextActiveTask([a, b, other])!.id);
    }
    expect(picks.has("c")).toBe(false);
    expect([...picks].every((id) => id === "a" || id === "b")).toBe(true);
  });

  it("falls back to creation order when nothing has a due date", () => {
    const second = task({ id: "a", created_at: new Date("2026-02-01") });
    const first = task({ id: "b", created_at: new Date("2026-01-01") });
    expect(pickNextActiveTask([second, first])?.id).toBe("b");
  });
});
