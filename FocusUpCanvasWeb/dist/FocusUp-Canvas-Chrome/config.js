// Public Supabase project values -- the same ones already shipped
// inside the FocusUp iOS app (see BackendSecrets.swift there). The
// anon key is public by design: Row Level Security on the server is
// what actually protects the data, so there's nothing sensitive here,
// even though this file is committed.
export const SUPABASE_URL = "https://lpruhipiailgdjzgjdsc.supabase.co";
export const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxwcnVoaXBpYWlsZ2RqemdqZHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5MzU1NTksImV4cCI6MjEwNTUxMTU1OX0.utXlhHAfikrzbxl1GtEZFpYXLmIHJ5NJTW_1s4dVhkM";

// Sign in with Apple in the browser needs a one-time Apple Developer +
// Supabase setup (see README, "Sign in with Apple"). Until that's done
// the button would only lead to an error, so it stays hidden. Flip to
// true once Supabase's Apple provider lists the Services ID and the
// extension redirect URLs are allowlisted, then run build.py again.
export const APPLE_WEB_SIGNIN_ENABLED = true;
