import { createRemoteJWKSet, jwtVerify } from "jose";

// Apple's public keys for verifying Sign in with Apple identity
// tokens. jose caches and auto-refreshes this internally, so we only
// create it once per process.
const APPLE_JWKS = createRemoteJWKSet(
  new URL("https://appleid.apple.com/auth/keys")
);

export interface AppleIdentity {
  sub: string; // Apple's stable per-user, per-app identifier
  email: string | null;
}

/**
 * Verifies a Sign in with Apple identity token (a signed JWT the iOS
 * app gets back from AuthenticationServices) against Apple's public
 * keys, and checks it was actually issued for THIS app and by Apple.
 *
 * NOT yet exercised against a real device-issued token -- the iOS
 * app's AuthManager/AuthView currently only handle Sign in with Apple
 * locally and never send the token anywhere. Wiring that up is the
 * next step before this path can be trusted end to end.
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  expectedAudience: string
): Promise<AppleIdentity> {
  const { payload } = await jwtVerify(identityToken, APPLE_JWKS, {
    issuer: "https://appleid.apple.com",
    audience: expectedAudience,
  });

  if (typeof payload.sub !== "string") {
    throw new Error("Apple identity token missing 'sub' claim");
  }

  const email = typeof payload.email === "string" ? payload.email : null;
  return { sub: payload.sub, email };
}
