# PS4 Dashboard

A Roblox Lua dashboard with a PlayStation 4-inspired interface.

## Current interface

- Deep-blue wallpaper with subtle animated wave and glow layers
- Compact PS4-style system rail and Home marker
- Horizontal application tile row with a clear selected state
- Crisp tile outlines and a blue selection strip
- Native Roblox UI elements; no external HTML, CSS, or JavaScript runtime is required

## Project layout

- `ps4.lua` — dashboard UI and client-side interface
- `orbis_client.lua` — authentication client module
- `orbis-auth-worker.js` — authentication worker
- `wrangler.jsonc` — Cloudflare Worker configuration

## Design reference

The visual direction was adapted from **[d4v1-sudo/Ps4-UI](https://github.com/d4v1-sudo/Ps4-UI)**, a browser-based PS4 interface recreation by d4v1-sudo. This repository does not embed that project's HTML, CSS, JavaScript, fonts, sounds, or game artwork. The Roblox interface changes are rebuilt with native Roblox UI primitives.

Reference project license: [MIT License](https://github.com/d4v1-sudo/Ps4-UI/blob/master/LICENSE).

## Notes

- The existing project entry point and loader URL are intentionally unchanged by the visual adaptation.
- The adaptation is on the `feature/ps4-ui-reference-adaptation` branch so the `main` branch remains untouched while it is reviewed.
- This repository is an independent project and is not affiliated with or endorsed by Sony Interactive Entertainment or PlayStation.
