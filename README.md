# Orbis PS4 Dashboard

A Roblox/Luau dashboard styled after the PlayStation 4 interface, with an Orbis authentication backend powered by a Cloudflare Worker and Durable Objects.

> **Important:** This is a dashboard running in Roblox. It does not sign in to PlayStation Network, change the real PS4 system user, or switch console accounts. The saved profiles in this project are Roblox account identities used by the dashboard's own authentication flow.

## Community

Join the project's Discord server: [https://discord.gg/gfdjcFDVjf](https://discord.gg/gfdjcFDVjf)

## Release and readable source

- `ps4.lua` is the release entry point, and the existing loadstring URL remains unchanged.
- The readable dashboard source is preserved at `source/ps4.lua`; both files currently contain the same readable code while this startup fix is being verified.
- Obfuscation can be restored after the corrected release has been tested in the Roblox runtime; it only makes casual reading harder and is not encryption.

## Project files

- `ps4.lua` — refreshed PS4-style dashboard UI from Use_this.lua, including Home, ScriptBlox Store, Library, browser, Settings, themes, profile picker, and Owner panel.
- `orbis_client.lua` — client-side requests and locally saved authentication sessions.
- `orbis-auth-worker.js` — Cloudflare Worker API, passcode verification, session validation, and server-side Owner/Premium controls.
- `wrangler.jsonc` — Cloudflare Worker and Durable Object configuration.

## Refreshed dashboard UI

The feature/owner-system branch now uses the UI from the separate Dreamhacker-Fear/What-Claude-gave-me repository's Use_this.lua, adapted to the existing Orbis Worker rather than copied blindly. The root ps4.lua and readable source/ps4.lua are kept byte-for-byte identical.

The refreshed interface includes the PS4-style Home, ScriptBlox Store, Library, browser, Settings, themes, notifications, profile picker, and Owner panel. The Owner panel uses the supported account-list and Premium endpoints. Recently active is calculated from the last-seen timestamp; it is not a live presence signal. Script Friends endpoints and Discord News posting are disabled/pending server-side support.

The stable main branch and the existing loadstring are unchanged. The refreshed version is only on feature/owner-system until the pull request is reviewed and merged.

## Current profile behavior

- Regular users can save up to **5 Roblox profiles** in the dashboard.
- The configured Owner Roblox user can save more profiles.
- The profile picker is a horizontal, swipeable carousel: Create Account starts centered when available, saved profiles sit to its right, and the card nearest the center is enlarged to appear in the foreground. Only the centered card can be activated.
- Swipe horizontally to bring another profile into the center; the nearest card snaps into place when the swipe ends. Tap it to sign in.
- Each profile authenticates against its Roblox User ID and has its own server-issued session.
- The Hub display name can be renamed without changing the Roblox account username.
- Tapping the Hub profile/avatar area reopens the profile picker.

Profiles and session tokens are stored locally by the client where the executor provides file APIs. The server still validates sessions; a locally stored token alone does not grant access.

## Authentication flow

1. The account owner requests a passcode using the configured Discord `/psn` command.
2. The dashboard submits the passcode and Roblox User ID to the Worker.
3. The Worker checks the required Roblox profile ownership proof before issuing a session.
4. Later sign-ins validate the saved session with the Worker. Expired sessions require a fresh passcode.

Do not share passcodes, session tokens, Discord bot tokens, signing secrets, or the Discord public key.

## Cloudflare Worker setup

The production API used by `orbis_client.lua` is `https://ps4.lucaebraeuer.workers.dev` (Cloudflare Worker script name: `ps4`). The `wrangler.jsonc` file currently names a separate script, `orbis-auth`; running `npx wrangler deploy` with that config does **not** deploy to the production `ps4` script. Do not change the production script name or Durable Object binding casually: the live `AUTH` namespace contains existing login/session data.

The production `ps4` Worker was updated on 2026-10-31 to the Owner-enabled code from `feature/owner-system` (version 31, deployed to 100% of traffic). The existing `AUTH` Durable Object namespace and secret bindings were preserved. This deployment updates the shared authentication backend, so the client still needs an end-to-end Roblox login and Owner-panel test.

For a separate development deployment, install Wrangler, authenticate with the intended Cloudflare account, configure the required secrets (`DISCORD_PUBLIC_KEY`, `DISCORD_BOT_TOKEN`, and `SIGNING_SECRET`) without committing their values, and verify the target script and Durable Object namespace before deploying. Keep the production Worker URL in `orbis_client.lua` pointed at the intended deployment.

The `/setup` route is disabled by default in the Worker. Only enable it temporarily when re-registering the Discord command, then disable it again.

## Owner and Premium features

- The refreshed Owner panel lists accounts that have signed in to this Worker, resolves Roblox usernames for display, and marks accounts recently seen within five minutes as recently active (not guaranteed live-online presence).
- The Owner can grant or revoke Premium for registered accounts; the Owner account itself is always Premium.
- Owner account listing, Premium changes, and visit logging use the existing /owner/* Worker routes.
- Owner actions are recorded in Durable Object storage and retained for up to 30 days.
- Owner access is checked server-side using the session token and configured Owner Roblox User ID (`8407673016`). A client-side flag alone does not grant Owner access.

## Validation and release notes

- This repository contains Roblox/Luau client code and a JavaScript Cloudflare Worker.
- GitHub Actions checks are only available when workflows are configured and triggered. A missing workflow run is not a passing build.
- A successful JavaScript syntax check does not prove the Luau UI works in the Roblox runtime.
- Cloudflare preview builds are not a substitute for a live Durable Object runtime test. The Owner-enabled Worker is deployed to production `ps4`, but successful syntax/deployment checks do not prove that Roblox login and every Owner action work end to end.
- The refreshed client does not contain the old Discord webhook URLs. News posting is disabled until secure server-side webhook handling is configured.
- The Script Friends view is a UI placeholder for now; the current Worker does not implement friend search/request endpoints. Roblox Friends and local party display are separate UI views.
- The refreshed Store fetches public ScriptBlox catalogue data. Its script runner executes downloaded Lua code, so only use code you understand and trust; the built-in string scan is not a security guarantee.
- Owner UI references are forward-declared before callbacks use them, so Lua resolves them to the intended local controls and cache.
- The feature-branch dashboard loads its matching orbis_client.lua, including the Owner API methods and a compatibility response for the refreshed UI. The client source URL is pinned to feature/owner-system while the refresh is tested.
- Owner API requests are forwarded to their matching Durable Object routes; they are not treated as ordinary session checks.
- The Worker validates the Owner session and configured Roblox User ID on every Owner-only operation.
- Before merging the client changes, test profile creation, profile switching, passcode login, session resume, and Owner-only endpoints in Roblox. If any production login flow fails, roll back the Worker to the previous deployment version while investigating.
- Changes on `feature/owner-system` are proposed through [PR #2](https://github.com/Dreamhacker-Fear/Ps4/pull/2). The default `main` branch is not changed until that pull request is merged.

## Cloudflare preview build note

Both `main` and `feature/owner-system` Wrangler configurations include the `PSN_USERS` entry under `previews.kv_namespaces`, using the preview namespace ID requested by the Cloudflare build log. This is preview-only; the feature branch Worker continues to use the `AUTH` Durable Object for its current authentication flow. The preview mapping does not change the production Worker deployment or the Roblox loadstring.
