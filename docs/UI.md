# UI contract and replacing the reference UI

The served web root (`kindle-ui/html/`) is plain static files bind-mounted
into nginx. The reference UI (`index.html` + `config.js`) can be replaced
entirely — including by a UI generated in opencode with figcraft — as long
as the replacement respects the constraints below.

## Hard constraints (old Kindle WebKit)

- **ES5 only** — no `let`/`const`, arrow functions, template literals,
  modules, `fetch`, or Promises. `XMLHttpRequest` only.
- Table or absolute layouts; flexbox and grid are unreliable on
  2012-era WebKit.
- Rotation: the panel is portrait; the app rotates itself 90° with a
  CSS `-webkit-transform` to render a landscape dashboard.
- Pure black on white, big touch targets (~48px+), thick lines.
  Anti-aliased grayscale and subtle colors render poorly on e-ink.
- Keep DOM small and re-render on change — every repaint is a visible
  e-ink flash. Partial-screen updates are not controllable from the
  browser; fewer repaints = better UX.

## Behavioral contract (the device scripts depend on these)

1. **`#sleep` hash view**: when `location.hash === '#sleep'`, render a
   static "asleep" screen (padlock). The on-device idle logic and the
   suspend cycle freeze whatever is on screen; this contract makes the
   frozen image honest about its state.
2. **Self-idle**: after `CONFIG.idleSeconds` without a touch, navigate
   to `#sleep`. Any touch returns to the dashboard and refreshes data.
3. **API access**: read state from `/api/states/<entity>`, call services
   via `POST /api/services/<domain>/<service>`. The proxy attaches
   auth; the UI never handles tokens.
4. **Configuration from `config.js`**: rooms, devices, panel size,
   location. Keep this file as the single source of user config so the
   helper scripts keep working.

## Replacing the UI

A figcraft-generated UI should output into `kindle-ui/html/` (or change
the bind mount in `docker-compose.yml` to its own build directory).
Design guidance for the generator lives in
**[UI-DESIGN-PROMPT.md](UI-DESIGN-PROMPT.md)** (e-ink shading techniques,
B/W art styles, touch-interaction rules).
Iterate from a desktop browser at `http://<server-ip>:8124` first — it is
much faster than the e-ink refresh cycle. Keep `config.js` as-is or
extend it; keep the `#sleep` contract.
