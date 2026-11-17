# UI Build Prompt — read this before generating the dashboard

You are building the Kindle Home Assistant dashboard UI that replaces the
reference shell in `kindle-ui/html/`. Read `docs/UI.md` first — its hard
constraints (ES5, XMLHttpRequest, `#sleep` view, `config.js`, 90° CSS
rotation) are non-negotiable. This document tells you how to *design* for
black-and-white e-ink: how to fake gray, which visual languages work, and
how touch must behave on a display that refreshes slowly and retains
afterimages.

---

## 1. How to get shaded tones on a 1-bit black/white e-ink screen

The panel has no gray levels available to the browser — every pixel is
either pure black or pure white. Gray is an illusion you create with
**ink density**: the fraction of black pixels in a region. Use exactly one
of these techniques, chosen per element:

**Ordered dithering (Bayer matrix)** — the workhorse for backgrounds,
charts, and any large area that needs an even pseudo-gray. A 4×4 Bayer
threshold map decides which pixels in a cell go black. The result is a
regular pattern that reads as a stable tone. Precompute your patterns as
tiny repeating CSS `background-image` data-URIs (e.g. 4×4-pixel PNGs at
various densities) — never compute per-pixel in JS; the old WebKit will
crawl. Density steps: 0%, 12.5%, 25%, 37.5%, 50%, 62.5%, 75%, 87.5%, 100%
give you a reliable 9-tone "palette" that stays legible after the e-ink's
own rendering pass.

**Stippling (dot fields)** — irregular dot placement for organic areas:
sky, gradients, texture. Reads as hand-drawn; use sparingly and at low
density, because e-ink reproduces sparse small dots poorly (dots under
~2px can smear or vanish). Keep dots ≥2×2 px.

**Hatching / cross-hatching** — parallel or crossing 2–3 px lines for
medium tones inside illustrations (shadows on a house, a hillside). Line
spacing sets the tone; crossing at ~90° darkens one step. This is the most
e-ink-faithful gray: it survives ghosting better than scattered dots.

**Halftone** — dots that grow with density, like newspaper print. Good for
hero graphics (a large weather scene). Use a coarse screen (≥6px cell) so
dots stay round instead of dissolving.

**Solid ink** — pure black shapes and pure white cutouts. The strongest
tool you have: on e-ink, a solid black region has more visual weight than
any amount of mid-tone. Reserve solid black for the most important 10% of
the screen: active states, headlines, the current temperature.

Rules of thumb:
- Fewer tones, more contrast. A 3-tone design (white / 25% hatch / solid
  black) beats a 9-tone gradient soup on e-ink every time.
- Anti-aliasing and gradients do NOT survive: they render as muddy noise.
  Hard 1px-aliased edges are correct here, which inverts normal web-design
  instinct.
- Gray text is banned. Text is black on white, full stop. Fake-gray text
  (`#888`) becomes fuzzy ghost text. Hierarchy comes from size, weight,
  and solid-black vs. outlined boxes — not from toning text down.
- Thin gray rules become invisible; use solid black 2–3 px rules or none.

## 2. Artistic imagery that works on B/W e-ink

The styles that reproduce beautifully are the ones invented for
monochrome printing — lean into them:

- **Woodcut / linocut**: bold solid shapes, dramatic black/white
  contrast, coarse carving marks for texture. The single best fit for
  hero illustrations (weather scenes, house icons, room glyphs).
- **Engraving / etching**: fine parallel hatching, cross-hatched shadows,
  white lines cut out of black. Good for detailed icons at larger sizes;
  loses detail below ~64px.
- **Vintage newspaper / halftone print**: coarse dot screens, heavy
  serifs, rules between sections. A great overall aesthetic for a
  "morning paper" style dashboard — status read like headlines.
- **Technical blueprint / schematic** (inverted or not): 2px line-weight
  drawings, labeled callouts, dashed hidden lines. Ideal for floor-plan
  style room layouts where each room is a schematic area with devices.
- **Ink-drawn iconography**: single-weight 3px stroke icons, no fills
  except solid black for "on" states. Stroke weight ≥3 px — 1px strokes
  shimmer and ghost.
- Avoid entirely: photography, soft shadows, drop shadows, rounded
  glassy "app icon" style, emoji (they render as muddy gray blobs), and
  any icon set designed for color screens (Material outlined at 1.5px,
  Feather, etc. — too thin; redraw or thicken to 3px).

Weather is your best showcase: a linocut-style scene per condition —
sun as radiating solid wedges, rain as hatched diagonal sheets, fog as
horizontal stipple bands, snow as sparse dots. 12.5% hatch for the sky,
solid black ground line, white cutout details.

## 3. Designing touch interactions for e-ink

E-ink changes the touch contract in three ways: **refresh is slow**
(a full-screen flash takes ~800ms–1s; partial updates ~150–300ms),
**refresh is visible** (any repaint flashes), and **ghosting persists**
(previous frames linger as faint afterimages until a full refresh). Every
interaction decision follows from that:

**One tap = one repaint.** Never repaint on hover, drag, keypress, or
animation. There is no hover (no cursor anyway) — do not build any.
Drags and sliders are unusable; replace them with big ± steppers for
setpoints (tap steps 0.5°) and mode buttons. Every tap must produce an
immediately visible change or the user will tap again and double-fire.

**Feedback without spinners.** You cannot show a spinner (it would need
continuous repaints, which e-ink cannot do and ghosting makes ugly).
Instead: flip the button's visual state *optimistically at tap time* —
tapped button inverts (solid black ↔ solid white) in the same repaint
that acknowledges the touch — then reconcile with the real entity state
when the XHR returns. If the service call fails, invert back and show a
small solid-black "!" badge. Never leave a tap without visual
acknowledgment.

**Make state impossible to misread.** Active/on = solid black fill with
white text. Off = white fill, black 3px border. This inversion survives
ghosting better than any subtle treatment, and it doubles as the touch
acknowledgment. For toggles, an explicit filled/unfilled square glyph
(a checkbox-style " cartridge") next to the name reads unambiguously.

**Touch targets: minimum 64×64 px** on the panel (the panel is ~167 ppi
and touch digitizers on old Kindles are imprecise), with ≥16px gutters.
The screen is used standing, at arm's length, possibly at night.

**Minimize repaint area.** Repaint only the changed element's DOM node,
not the whole page (this is why the reference app re-renders per device).
A full-page re-render per tap is acceptable but noticeably flashier;
element-scoped updates are the polish. Every ~10–20 interactions, or on
any wake-from-sleep, do one full re-render — the browser's partial e-ink
updates accumulate ghosting, and a full render triggers the framework's
full refresh which clears it.

**Never animate.** No transitions, no fades, no progress bars, no
clock seconds. A ticking clock is only minutes (the reference app
updates the clock every 30s in-DOM, which is fine at that granularity).
CSS transitions must be globally disabled — even a color transition
causes the old WebKit to queue intermediate repaints.

**The sleep view is part of the interaction.** The `#sleep` padlock
screen is what the user stares at whenever the device is suspended and
frozen — make it a deliberate, attractive poster (large linocut padlock,
"press power to wake" in heavy type), not an error state. It must be
static and contain no live data, because it will be frozen for hours.

**Staleness must be visible.** The device may be showing a frozen image
from up to a minute ago (or hours, after deep sleep). Show a small
"last updated HH:MM" line in the top bar, refreshed with every real
data poll, and always re-fetch all entities on resume (the reference
app does this — keep it).

---

## Deliverable

Static files in `kindle-ui/html/` (or a build directory mounted there):
`index.html` + `config.js` + any number of precomputed pattern assets
(PNG data-URIs or separate files). No build step, no frameworks, no
fetch, no ES6. Keep the `#sleep` contract and `config.js` shape from
`docs/UI.md`. Iterate from a desktop browser at `http://<server>:8124`,
and visually verify with the browser's rendering disabled-antialiasing
or a 1-bit screenshot filter before judging tones.
