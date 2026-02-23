// @ts-ignore
import { Elm } from "./.elm-land/src/Main.elm";

// @ts-ignore
if (process.env.NODE_ENV === "development") {
  const ElmDebugTransform = await import("elm-debug-transformer");

  ElmDebugTransform.register({});
}

const authStateKey = "authState";
const redirectKey = "redirectAfterAuth";

// Handle Dropbox OAuth callback before Elm init.
// Dropbox redirects with #access_token=TOKEN&token_type=bearer&...
// Must intercept before elm-land parses the hash for routing.
const hash = window.location.hash;
if (hash.includes("access_token=")) {
  const params = new URLSearchParams(hash.substring(1));
  const accessToken = params.get("access_token");
  if (accessToken) {
    localStorage.setItem(authStateKey, JSON.stringify({ dropbox: accessToken }));
  }
  // Redirect to the page the user was trying to reach before OAuth, or root
  const redirectTarget = localStorage.getItem(redirectKey) || "#/";
  localStorage.removeItem(redirectKey);
  history.replaceState(null, "", window.location.pathname + redirectTarget);
} else if (hash.includes("error=")) {
  // Dropbox returned an auth error
  const params = new URLSearchParams(hash.substring(1));
  console.error("[Dropbox Auth Error]", params.get("error"), params.get("error_description"));
  localStorage.removeItem(redirectKey);
  history.replaceState(null, "", window.location.pathname + "#/");
} else if (!localStorage.getItem(authStateKey)) {
  // No auth token — save current hash so we can return here after OAuth
  const currentHash = window.location.hash;
  if (currentHash && currentHash !== "#/" && currentHash !== "#") {
    localStorage.setItem(redirectKey, currentHash);
  }
}

// Validate that stored auth contains a token safe for HTTP headers.
// Non-ASCII tokens crash setRequestHeader at runtime (Elm can't catch this).
function isValidAuthState(raw: string | null): boolean {
  if (!raw) return false;
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed?.dropbox !== "string") return false;
    return /^[\x20-\x7E]+$/.test(parsed.dropbox);
  } catch {
    return false;
  }
}

const rootNode = document.querySelector("#app") as HTMLDivElement;
const storedAuthState = localStorage.getItem(authStateKey);

if (storedAuthState && !isValidAuthState(storedAuthState)) {
  localStorage.removeItem(authStateKey);
}

const validatedAuthState = isValidAuthState(storedAuthState) ? storedAuthState : null;

declare const __BUILD_VERSION__: string;

const app = Elm.Main.init({
  flags: {
    initialAuthState: validatedAuthState ? JSON.parse(validatedAuthState) : null,
    userAgent: navigator.userAgent,
    redirectUri: window.location.origin + window.location.pathname,
    windowSize: {
      height: window.innerHeight,
      width: window.innerWidth,
    },
    buildVersion: __BUILD_VERSION__,
  },
  node: rootNode,
});

// Guard: port only exists in compiled output if Elm code actually uses it
app.ports?.storeAuthState?.subscribe((val: any) => {
  if (val === null) {
    localStorage.removeItem(authStateKey);
  } else {
    localStorage.setItem(authStateKey, JSON.stringify(val));
  }
});

