# PS4 Dashboard

A PlayStation 4–inspired Roblox dashboard with an Orbis passcode login, saved sessions, social features, and a Cloudflare authentication backend.

## Quick start

Use this exact loader in your supported Roblox environment:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Dreamhacker-Fear/Ps4/main/ps4.lua"))()
```

The loader URL is intended to stay stable. The dashboard code it downloads is `ps4.lua` on the `main` branch.

## What's included

- **PS4-style dashboard UI** with pages, tiles, settings, themes, notifications, and sound effects.
- **Orbis login** using a one-time 4-digit passcode.
- **Saved sessions** so a valid login can be reused on later launches.
- **Roblox account ownership check** using a temporary phrase in the Roblox profile About section.
- **Social features** for presence, friend search, friend requests, and friend management.
- **Owner user list** protected by a server-side Roblox user ID check.
- **Responsive sizing** that reads the current Roblox viewport and adjusts the dashboard when the screen size changes.

## Files

| File | Purpose |
|---|---|
| `ps4.lua` | Main dashboard loaded by the quick-start loader. |
| `orbis_client.lua` | Client-side Orbis login and authenticated API requests. |
| `orbis-auth-worker.js` | Cloudflare Worker handling Discord interactions and authentication API routes. |
| `wrangler.jsonc` | Cloudflare Worker configuration, including the Durable Object binding and migration. |

## Orbis login flow

1. In the configured Discord server, run `/psn` to request a passcode.
2. The passcode is **4 digits**, expires after 24 hours, and can only be used once.
3. The response may include a temporary verification phrase. Add that phrase to the **About** section of the Roblox profile you want to link.
4. Enter the passcode in the dashboard. The Worker checks the profile phrase before creating a session.
5. The client saves the session token locally and checks it again on later launches. A session expires after 24 hours.

Do not share passcodes, session files, or authentication tokens.

## Backend routes

All routes are served by the configured Cloudflare Worker.

| Method | Route | Purpose |
|---|---|---|
| GET | `/` | Basic Worker health response. |
| POST | `/verify` | Exchange a 4-digit passcode for a session. |
| POST | `/session` | Validate a saved session. |
| POST | `/presence` | Update online presence and retrieve social status. |
| POST | `/friends/search` | Search users known to the dashboard. |
| POST | `/friends/request` | Send a friend request. |
| POST | `/friends/respond` | Accept or decline an incoming request. |
| POST | `/friends/remove` | Remove a friend. |
| POST | `/admin/users` | Retrieve the owner-only user list. |
| POST | `/` or `/interactions` | Receive verified Discord interactions, including `/psn`. |

Authenticated social routes require a valid session token. The owner-only check is enforced by the Worker, not just by the dashboard UI.

## Cloudflare configuration

The Worker uses a Durable Object binding named `AUTH` for authentication and social data. The included `wrangler.jsonc` declares the `AuthState` class and its initial SQLite Durable Object migration.

The Worker expects these Cloudflare secrets to be configured in the deployment environment:

- `DISCORD_PUBLIC_KEY`
- `DISCORD_BOT_TOKEN`
- `SIGNING_SECRET`

Keep secret values private. Never commit tokens, private keys, or account credentials to this repository.

The optional `/setup` route is disabled by default (`SETUP_ENABLED = false`). Do not enable it unless you intentionally need to register the Discord command again and understand the deployment change.

## Compatibility notes

- The client uses POST requests and needs an environment that provides a supported request function (`request`, `http_request`, `syn.request`, or a compatible equivalent).
- Local session persistence uses file functions when available. If they are unavailable, the client can still run but cannot persist sessions to a file.
- The dashboard adapts to the Roblox camera viewport; actual appearance can vary by device and environment, so test layout changes in Roblox before merging or deploying.
- The profile ownership check depends on Roblox's user profile API being reachable.

## Project status

This repository contains the dashboard and its authentication integration. Review changes and test them in your own environment before using them. Updating source files in GitHub does **not** deploy the Cloudflare Worker automatically.

Premium purchasing or Robux payments are not implemented in this version.
