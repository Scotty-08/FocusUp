import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is not set. Copy .env.example to .env and fill it in.");
}

const SESSION_TTL = "30d";

export interface SessionPayload {
  userId: string;
}

// The app's OWN session token, issued after either sign-in path
// succeeds (Apple or the placeholder email/password flow). The iOS
// app would store this and send it as a Bearer token on every
// /tasks request -- separate from Apple's identity token, which is
// only used once, at sign-in, to prove who the user is.
export function issueSessionToken(payload: SessionPayload): string {
  return jwt.sign(payload, JWT_SECRET!, { expiresIn: SESSION_TTL });
}

export function verifySessionToken(token: string): SessionPayload {
  const decoded = jwt.verify(token, JWT_SECRET!);
  if (typeof decoded === "string" || !("userId" in decoded)) {
    throw new Error("Malformed session token");
  }
  return { userId: (decoded as SessionPayload).userId };
}
