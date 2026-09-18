import type { NextFunction, Request, Response } from "express";
import { verifySessionToken } from "../auth/session";

export interface AuthedRequest extends Request {
  userId?: string;
}

export function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction
): void {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }

  try {
    const { userId } = verifySessionToken(header.slice("Bearer ".length));
    req.userId = userId;
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired session token" });
  }
}
