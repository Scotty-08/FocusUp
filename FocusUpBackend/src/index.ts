import "dotenv/config";
import { createApp } from "./app";

const PORT = Number(process.env.PORT ?? 3000);
// Bundle ID of the FocusUpSpike iOS target -- Apple identity tokens are
// only valid for the app that requested them, so this must match
// FocusUpSpike's bundle identifier in Xcode exactly.
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID ?? "com.scottgray.FocusUpSpike";

const app = createApp(APPLE_BUNDLE_ID);

app.listen(PORT, () => {
  console.log(`FocusUp backend listening on http://localhost:${PORT}`);
});
