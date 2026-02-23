# Product Decisions

Product decisions for elm-dropbox-shared-app-state-demo — both settled and open.

## Decided

### Mission

A demo application showing how to implement shared app state via Dropbox in an Elm SPA. Multiple clients can read and write to the same JSON file in Dropbox, with optimistic updates and automatic conflict resolution.

### Storage: Dropbox

Cloud persistence via Dropbox API instead of a custom backend. Dropbox enables deploying as a static site on GitHub Pages with zero server infrastructure.

### Platform: browser only

No native app planned. Mobile browser is sufficient.

### Unknown routes redirect to landing

Unknown hash routes (e.g. `/#/anything`) redirect to the landing page (`/#/`) instead of showing "Page not found". No reason to strand users on a dead-end 404 — the app has a small route surface, so an unknown route is almost certainly a typo or stale link.

### Chat feature

Used to verify multi-client state sync correctness. Messages are sent from different clients and synchronized via Dropbox shared state.
