import bcrypt from "bcryptjs";
import { Router } from "express";
import { z } from "zod";
import { pool } from "../db/pool";
import { verifyAppleIdentityToken } from "../auth/appleVerify";
import { issueSessionToken } from "../auth/session";
import { toAuthUserDTO, type UserRow } from "../types";

const BCRYPT_ROUNDS = 12;

export function authRouter(appleBundleId: string): Router {
  const router = Router();

  // Real Sign in with Apple: verifies the identity token the iOS app
  // got from AuthenticationServices, then finds-or-creates the user
  // by Apple's stable "sub" claim.
  const appleSchema = z.object({
    identityToken: z.string().min(1),
    displayName: z.string().trim().min(1).max(200).optional(),
  });

  router.post("/apple", async (req, res) => {
    const parsed = appleSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }

    let identity;
    try {
      identity = await verifyAppleIdentityToken(
        parsed.data.identityToken,
        appleBundleId
      );
    } catch (err) {
      res.status(401).json({ error: "Could not verify Apple identity token" });
      return;
    }

    const { rows } = await pool.query<UserRow>(
      `INSERT INTO users (apple_sub, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (apple_sub) DO UPDATE
         SET email = COALESCE(users.email, EXCLUDED.email)
       RETURNING *`,
      [identity.sub, identity.email, parsed.data.displayName ?? null]
    );

    const user = rows[0]!;
    res.json({
      user: toAuthUserDTO(user),
      sessionToken: issueSessionToken({ userId: user.id }),
    });
  });

  // UI-only placeholder today on the iOS side (AuthView has the form
  // but doesn't call anything) -- this is real, working email/password
  // auth on the server, ready for whenever that gets wired up.
  const credentialsSchema = z.object({
    email: z.string().trim().toLowerCase().email(),
    password: z.string().min(8).max(200),
    displayName: z.string().trim().min(1).max(200).optional(),
  });

  router.post("/signup", async (req, res) => {
    const parsed = credentialsSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }
    const { email, password, displayName } = parsed.data;

    const existing = await pool.query<UserRow>(
      "SELECT * FROM users WHERE email = $1",
      [email]
    );
    if (existing.rows.length > 0) {
      res.status(409).json({ error: "An account with that email already exists" });
      return;
    }

    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const { rows } = await pool.query<UserRow>(
      `INSERT INTO users (email, password_hash, display_name)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [email, passwordHash, displayName ?? null]
    );

    const user = rows[0]!;
    res.status(201).json({
      user: toAuthUserDTO(user),
      sessionToken: issueSessionToken({ userId: user.id }),
    });
  });

  router.post("/login", async (req, res) => {
    const parsed = credentialsSchema
      .pick({ email: true, password: true })
      .safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: parsed.error.flatten() });
      return;
    }
    const { email, password } = parsed.data;

    const { rows } = await pool.query<UserRow>(
      "SELECT * FROM users WHERE email = $1",
      [email]
    );
    const user = rows[0];
    const hash = user?.password_hash;

    // Always hash, even when the user isn't found -- avoids leaking
    // account existence through response-time differences.
    const ok = await bcrypt.compare(password, hash ?? "$2a$12$invalidsaltinvalidsaltin");
    if (!user || !hash || !ok) {
      res.status(401).json({ error: "Invalid email or password" });
      return;
    }

    res.json({
      user: toAuthUserDTO(user),
      sessionToken: issueSessionToken({ userId: user.id }),
    });
  });

  return router;
}
