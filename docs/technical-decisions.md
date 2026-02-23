# Technical Decisions

Technical decisions for elm-dropbox-shared-app-state-demo — implementation details, infrastructure, and API integration.

## Decided

### Dropbox API scopes

App Folder type application. All scopes are restricted to `/Apps/<app_name>/` in the user's Dropbox. Required scopes:

- `files.content.read` — download `app-state.json`
- `files.content.write` — upload `app-state.json`

OAuth flow: implicit grant (`response_type=token`), token returned in URL fragment. Handled by `init.ts` on the JS side since elm-land controls `Browser.application`.

### Optimistic updates with conflict resolution

UI updates immediately. Writes use Dropbox rev-based conflict detection. On conflict: re-download server state, replay pending action queue on top, re-upload (up to 3 retries). Instant UI response is critical for chat UX.

### Deployment

GitHub Pages via GitHub Actions. Zero infrastructure cost. `404.html` redirects to the domain root. CI runs format-validate, tests, and elm-review before building. Requires Node 22.17.

## Open Questions

### App versioning

GitHub Pages caches assets at the CDN level. Clients on different networks can get different versions of the app at the same time. Embedding a version (git SHA or semver) into the bundle and displaying it in the UI would help with diagnostics. Open: how to inject the version at build time (Vite define, env variable, generated Elm module).

### Auth reliability

localStorage-based Dropbox token persistence needs observation across mobile browsers (Safari, Chrome) before inviting other users. Token expiration and refresh behavior under real usage is not yet validated.
