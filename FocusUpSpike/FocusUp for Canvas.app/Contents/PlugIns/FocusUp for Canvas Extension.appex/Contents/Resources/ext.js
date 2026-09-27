// One name for the extension API in every browser: Firefox exposes the
// promise-based `browser` namespace, Chrome/Edge/Brave expose `chrome`
// (promise-based in MV3). Everything else in the extension imports this
// instead of touching either global directly.
export const ext = globalThis.browser ?? globalThis.chrome;
