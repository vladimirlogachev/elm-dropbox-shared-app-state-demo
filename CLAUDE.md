# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product Decisions

See [product-decisions.md](docs/product-decisions.md) — log of key product decisions. Consult before making product-level changes.

See [technical-decisions.md](docs/technical-decisions.md) — log of technical decisions (Dropbox API scopes, ID generation, parsing, deployment). Consult before making technical changes.

See [user-manual.md](public/user-manual.md) — user-facing documentation.

## Build & Dev Commands

- `npm start` — Generate elm-land files and start Vite dev server on `0.0.0.0:7000`
- `npm run build` — Generate elm-land files and production build to `/dist`
- `npm test` — Run tests
- `npm run review` — Run elm-review linter
- `npm run review-fix-all` — Auto-fix all elm-review errors
- `npm run format-validate` — Check elm-format compliance
- `npm run format-fix-all` — Auto-format all Elm files
- `npm run fix` — Auto-fix format + review, then build + test. **Run after finishing a feature.**
- `npm run check-and-build` — Full CI pipeline: build + format-validate + test + review

## Architecture

Elm SPA built with [elm-land](https://elm.land/) framework, [elm-ui](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/) for rendering, [elm-modular-grid](https://package.elm-lang.org/packages/vladimirlogachev/elm-modular-grid/latest/) for responsive layout, Dropbox cloud persistence via `avh4/elm-dropbox`. TypeScript is only used for bootstrap (`init.ts`).

### Data Model

`AppState` contains a flat list of `ChatRecord`s (`{ userAgent, message, timestamp }`). Stored as JSON in Dropbox at `/app-state.json` with schema `{ "chat": [...], "stateVersion": N }`. The `stateVersion` field is serialization metadata — it lives in the JSON encoder/decoder but not in the Elm record. No opaque types — direct record access.

`PendingAction` is a union type (`AddMessage ChatRecord`) representing semantic operations on state. Actions are first-class data — queued, replayed, and applied via `applyAction`. Reinitialize is handled separately (bypasses the action/optimistic-update system, directly uploads fresh state).

### Dropbox Integration (without `Dropbox.application`)

elm-land generates its own `Browser.application`, so we can't use `Dropbox.application`. Instead:

1. **`init.ts`** handles the OAuth callback in JS: parses `#access_token=...` from URL fragment (and `#error=...` for failures), stores as `{ "dropbox": "TOKEN" }` in localStorage before Elm init. Validates the stored token — rejects non-ASCII tokens (which would crash `setRequestHeader`) and malformed JSON. Preserves the pre-auth URL hash in `redirectAfterAuth` localStorage key — when a user visits a protected page without auth, the hash is saved before OAuth redirect and restored after callback, so the user lands on the page they originally requested.
2. **`Auth.elm`** (overrides `.elm-land/src/Auth.elm`) — centralized auth gate. `onPageLoad` checks `shared.auth`: if present, returns `Auth.Action.loadPageWithUser {}`; if absent, redirects to Dropbox OAuth via `Auth.Action.loadExternalUrl`. Protected pages (Chat, Settings) declare auth requirement by taking `Auth.User` as their first `page` parameter — elm-land automatically calls `Auth.onPageLoad` before initializing them.
3. **`Shared.elm`** decodes the stored auth from flags using `Dropbox.decodeUserAuth`, manages download/upload with optimistic updates and conflict resolution.
4. **API calls**: `Dropbox.download`/`Dropbox.upload` as Tasks via `Effect.sendCmd`.
5. **Auth persistence**: `init.ts` writes auth to localStorage at OAuth callback time. No Elm-side port is currently used.

### Optimistic Updates & Conflict Resolution

The core persistence pattern is optimistic updates with automatic conflict retry:

1. When a user sends a message, the UI updates immediately by applying a `PendingAction` to `storageContents`.
2. If no upload is in-flight, the action is applied to `verifiedContents` (last server-confirmed state) and uploaded using `Dropbox.Update rev` (revision-based write).
3. If an upload is already in-flight, the action is queued in `queuedActions`.
4. On upload success, `verifiedContents` advances, `fileRevision` is updated, and the next queued action starts.
5. On `Dropbox.Conflict`, the system re-downloads server state, re-applies all pending actions (in-flight + queued) on top of it, and re-uploads (up to 3 retries).
6. `Dropbox.Update rev` is used when `fileRevision` is known; `Dropbox.Overwrite` only when creating for the first time.

Key state separation: `storageContents` = what the UI sees (possibly ahead of server), `verifiedContents` = last server-confirmed state.

### Module Responsibilities

- **Shared.elm** — Dropbox OAuth flow, file I/O (`/app-state.json`), optimistic update orchestration, conflict resolution, window resize, grid layout config. Auto-initializes empty state when file not found or JSON invalid.
- **Shared/Model.elm** — Shared state: `GridLayout2.LayoutState`, `Maybe Dropbox.UserAuth`, `storageContents : RemoteData String AppState` (from `krisajenkins/remotedata`: NotAsked | Loading | Success | Failure), `verifiedContents` (last server-confirmed state), `fileRevision` (Dropbox rev for conflict detection), `inFlightActions`/`queuedActions` (pending action queues), `dropboxConflictRetryCount`, `userAgent`, `redirectUri`, `toasts`, `nextToastId`. Also defines `ToastType` (`SuccessToast | ErrorToast`) and `Toast` record.
- **Shared/Msg.elm** — Shared messages: `GotFileResponse`, `SaveRequested PendingAction`, `GotSaveResponse`, `GotConflictDownloadResponse`, `ReinitializeState`, `SignOut`, `AddToast ToastType String`, `DismissToast`, `GotNewWindowSize`.
- **Effect.elm** — Custom effect type for elm-land. Variants: `None | Batch | SendCmd | PushUrl | ReplaceUrl | LoadExternalUrl | SendSharedMsg`. Helpers: `saveData` (takes a `PendingAction`), `reinitializeState`, `signOut`, `addSuccessToast`, `addErrorToast`.
- **View.elm** — elm-ui based View wrapper (`{ title, attributes, element }`).
- **Auth.elm** — Centralized auth gate (overrides `.elm-land/src/Auth.elm`). `onPageLoad` checks `shared.auth` and either loads the page (`loadPageWithUser`) or redirects to Dropbox OAuth (`loadExternalUrl`). `viewCustomPage` shows "Loading..." fallback.
- **Pages/Home\_.elm** — Landing page. Heading + "Open app" button linking to `/chat`. Uses `LandingLayout`. Accessible without authentication.
- **Pages/Chat.elm** — Auth-protected (`Auth.User` param). Chat UI: message input + send button, message list. Sends `Effect.saveData (AddMessage record)` on message send. Used to verify multi-client state sync.
- **Pages/Help.elm** — Help page displaying user manual content.
- **Pages/Settings.elm** — Auth-protected (`Auth.User` param). Settings page with sign out and reinitialize app state buttons (reinitialize available in both `Success` and `Failure` states). Sends `Effect.signOut` and `Effect.reinitializeState`.
- **Markdown.elm** — Markdown-to-elm-ui renderer using `dillonkearns/elm-markdown`. Supports headings, paragraphs, code blocks, links, lists, blockquotes, images. Uses `TextStyle` and `Color` for styling.
- **Color.elm** — Color palette: `white`, `black`, `grey`, `light1` (green), `light2` (orange), `primaryBlue`, `greyDimmed1`, `greyDimmed3`, `black025`.
- **Layouts/AppLayout.elm** — App layout using `GridLayout2` responsive grid. Renders a 5px amber status bar at top when `inFlightActions` is non-empty. Shows navigation bar (Chat, Help, Settings) when authenticated. Renders toasts with color by type (green for success, red for error).
- **Layouts/LandingLayout.elm** — Minimal layout for landing page. Only `GridLayout2` responsive grid — no navigation bar, no status bar, no toasts. Uses `Never` as `Msg` type (fully stateless).
- **AppState.elm** — `AppState`, `ChatRecord`, `PendingAction(..)` (`AddMessage`), JSON encode/decode, `applyAction`, `listMessages`, `empty`.
- **TextStyle.elm** — Typography: `body`, `secondary` (system-ui, for chat), `contentBody`, `subheaderDesktop`, `header`, `subheader`, `codeBody` (Inter, for Markdown).
- **Utils.elm** — Helpers: `parseDevice`.

### Key Patterns

- **elm-land framework**: File-based routing (`src/Pages/`), layouts (`src/Layouts/`), generated Main.elm in `.elm-land/src/`. Routes: `/` (Home\_ — landing, public), `/chat` (Chat — messaging, auth-protected), `/help` (Help — user manual, public), `/settings` (Settings — sign out/reinitialize, auth-protected).
- **Auth protection**: Pages with `Auth.User` as first `page` parameter are auto-protected by elm-land. `Auth.onPageLoad` (in `src/Auth.elm`) runs before page init — checks `shared.auth` and either loads the page or redirects to Dropbox OAuth. `init.ts` preserves the target URL hash across the OAuth redirect via `redirectAfterAuth` localStorage key.
- **Hash routing**: Enabled via `elm-land.json` (`useHashRouting: true`) for GitHub Pages compatibility.
- **Page → Shared communication**: Pages dispatch `Effect.sendSharedMsg` (e.g., `Effect.saveData`, `Effect.reinitializeState`, `Effect.signOut`) to communicate with Shared state.
- **Responsive grid**: `GridLayout2` with mobile (360-720px, 6 cols) and desktop (1024-1440px, 12 cols) breakpoints.
- **Action-based saves**: Sending a message dispatches `Effect.saveData (AddMessage record)`. Shared applies the action optimistically, queues or uploads immediately depending on in-flight state.
- **PendingAction as first-class data**: Semantic operations (`AddMessage`) instead of full state blobs. Enables queue-and-replay for conflict resolution.
- **Visual save indicator**: Amber 5px bar at page top while uploads are in-flight.
- **Toast guidelines**: Visible state changes (e.g. adding a message) usually don't need toasts. Errors with no automatic retry need error toasts. Invisible state changes (e.g. reinitialize) need success toasts. Two toast types: `SuccessToast` (green) and `ErrorToast` (red), dispatched via `Effect.addSuccessToast` / `Effect.addErrorToast`.
- **Auto-initialization**: Missing or corrupt `app-state.json` is silently replaced with empty state.
- **No `onAnimationFrame`**: Do NOT use `Browser.Events.onAnimationFrame` as a polling hack to detect state transitions. Instead, trigger follow-up actions directly from the `update` function where the state transition happens. Pages that need data on load should check `shared` in their `init` function.

### Versioned State Decoders (CRITICAL)

`appStateDecoder` in `AppState.elm` uses `D.oneOf` with a list of versioned decoders (`appStateDecoderV1`, etc.). This ensures backward compatibility with data already stored in users' Dropbox.

**When changing `AppState` or `ChatRecord` structure:**

1. Bump `currentStateVersion` in `AppState.elm` to match the new schema version. This value is used at runtime to detect version mismatches — if a client receives state with a higher version from Dropbox, it shows a "refresh the page" toast instead of silently corrupting data. Always keep `currentStateVersion` in sync with the latest decoder version number.
2. Create a new versioned decoder (`appStateDecoderV2`, etc.) for the new schema. Each versioned decoder must check `stateVersion` matches its expected version (e.g., `v == 2`) and `D.fail` otherwise.
3. Add it to the **end** of the `D.oneOf` list in `appStateDecoder` (newest last — the current format is tried first, fallbacks follow).
4. In `tests/AppStateTest.elm`, add a `testStateV2` JSON string with an example of the new format.
5. Write tests that verify: (a) the new versioned decoder decodes `testStateV2`, (b) `appStateDecoder` decodes both `testStateV1` and `testStateV2`.
6. Never remove old versioned decoders — existing users have data in old formats.

### Linting (elm-review)

`elm-review` is configured in `review/` with 24 rules covering unused code, debug statements, performance, type safety, Elm Architecture patterns, and code style. Key config:

- **review/src/ReviewConfig.elm** — Rule configuration. Ignores `.elm-land/` generated code.
- **review/elm.json** — Elm dependencies for review rules.
- `NoImportingEverything` allows `Element` and `GridLayout2`.
- `NoUnused.Exports` ignores `src/View.elm` (elm-land requires specific exports).
- `NoUnoptimizedRecursion` ignores `src/Effect.elm`.
- Run `npm run review` to check, `npm run review-fix-all` to auto-fix.

### Deployment

GitHub Actions (`.github/workflows/gh-pages.yaml`) builds and deploys to GitHub Pages on push to `main`. Requires Node 22.17. `404.html` redirects to the domain root. CI runs format-validate, tests, and elm-review before building.
