import type { TaskRow } from "../types";

/**
 * Picks which incomplete task should be active, mirroring the exact
 * rule used on the iOS side (TaskStore.autoPickNextTask in the
 * FocusUpSpike app, see TaskStore.swift):
 *
 *   1. A task with a due date always beats one without.
 *   2. Among dated tasks, earliest due date wins.
 *   3. Tasks due on the same calendar day are tied and one is picked
 *      at random -- there's no other signal to break the tie with.
 *   4. Undated tasks are least urgent: only picked once every dated
 *      task is done, and in creation order among themselves.
 *
 * Keeping this identical to the client logic matters -- if the
 * server and the (currently offline-first) iOS app ever disagree on
 * which task is "active", the block screen and the account would
 * show different things.
 */
export function pickNextActiveTask(tasks: TaskRow[]): TaskRow | null {
  const incomplete = tasks.filter((t) => !t.is_completed);
  if (incomplete.length === 0) return null;

  const dated = incomplete.filter((t) => t.due_date !== null);
  if (dated.length > 0) {
    const earliestDay = dated.reduce(
      (min, t) => (t.due_date! < min ? t.due_date! : min),
      dated[0]!.due_date!
    );
    const tied = dated.filter((t) => t.due_date === earliestDay);
    return tied[Math.floor(Math.random() * tied.length)]!;
  }

  const byCreatedAt = [...incomplete].sort(
    (a, b) => a.created_at.getTime() - b.created_at.getTime()
  );
  return byCreatedAt[0]!;
}
