import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../app";

const app = createApp("com.scottgray.FocusUpSpike.test");

async function signUpAndLogIn(email = "scotty@example.com") {
  const res = await request(app).post("/auth/signup").send({
    email,
    password: "hunter2hunter2",
    displayName: "Scotty",
  });
  expect(res.status).toBe(201);
  return res.body.sessionToken as string;
}

describe("auth", () => {
  it("signs up, then logs in with the same credentials", async () => {
    await request(app)
      .post("/auth/signup")
      .send({ email: "a@example.com", password: "hunter2hunter2" })
      .expect(201);

    const login = await request(app)
      .post("/auth/login")
      .send({ email: "a@example.com", password: "hunter2hunter2" });
    expect(login.status).toBe(200);
    expect(login.body.sessionToken).toBeTruthy();
  });

  it("rejects a wrong password without revealing whether the account exists", async () => {
    const res = await request(app)
      .post("/auth/login")
      .send({ email: "nobody@example.com", password: "wrongwrongwrong" });
    expect(res.status).toBe(401);
  });

  it("refuses a garbage Apple identity token", async () => {
    const res = await request(app)
      .post("/auth/apple")
      .send({ identityToken: "not-a-real-jwt" });
    expect(res.status).toBe(401);
  });

  it("rejects task requests with no session token", async () => {
    await request(app).get("/tasks").expect(401);
  });
});

describe("tasks", () => {
  let token: string;

  beforeEach(async () => {
    token = await signUpAndLogIn();
  });

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

  it("auto-activates the first task added", async () => {
    const res = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Apply to 3 internships" });
    expect(res.status).toBe(201);
    expect(res.body.task.isActive).toBe(true);
  });

  it("keeps the active task active even when a sooner-due task is added", async () => {
    const first = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Later task", dueDate: "2026-12-01" });
    const activeId = first.body.task.id;

    await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Due sooner", dueDate: "2026-09-19" });

    const list = await request(app).get("/tasks").set(auth(token));
    const active = list.body.tasks.find((t: { id: string }) => t.id === activeId);
    expect(active.isActive).toBe(true);
  });

  it("auto-advances to the next task by due date when the active one is completed", async () => {
    const first = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "First", dueDate: "2026-09-19" });
    const second = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Second", dueDate: "2026-09-25" });

    await request(app)
      .patch(`/tasks/${first.body.task.id}`)
      .set(auth(token))
      .send({ isCompleted: true })
      .expect(200);

    const list = await request(app).get("/tasks").set(auth(token));
    const secondNow = list.body.tasks.find(
      (t: { id: string }) => t.id === second.body.task.id
    );
    expect(secondNow.isActive).toBe(true);
  });

  it("lets a manual override win immediately, then resumes auto-pick after it's done", async () => {
    const soon = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Due soon", dueDate: "2026-09-19" });
    const chosen = await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Overridden pick", dueDate: "2026-12-01" });

    await request(app)
      .post(`/tasks/${chosen.body.task.id}/activate`)
      .set(auth(token))
      .expect(200);

    let list = await request(app).get("/tasks").set(auth(token));
    let active = list.body.tasks.find((t: { isActive: boolean }) => t.isActive);
    expect(active.id).toBe(chosen.body.task.id);

    await request(app)
      .patch(`/tasks/${chosen.body.task.id}`)
      .set(auth(token))
      .send({ isCompleted: true });

    list = await request(app).get("/tasks").set(auth(token));
    active = list.body.tasks.find((t: { isActive: boolean }) => t.isActive);
    expect(active.id).toBe(soon.body.task.id);
  });

  it("scopes tasks to the authenticated user only", async () => {
    const otherToken = await signUpAndLogIn("other@example.com");
    await request(app)
      .post("/tasks")
      .set(auth(token))
      .send({ title: "Scotty's task" });

    const othersList = await request(app).get("/tasks").set(auth(otherToken));
    expect(othersList.body.tasks).toHaveLength(0);
  });
});
