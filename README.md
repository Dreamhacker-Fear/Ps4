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

- `ps4.lua` — dashboard interface, profile picker, account switching within the dashboard, and Owner panel UI.
- `orbis_client.lua` — client-side requests and locally saved authentication sessions.
- `orbis-auth-worker.js` — Cloudflare Worker API, passcode verification, session validation, and server-side Owner/Premium controls.
- `wrangler.jsonc` — Cloudflare Worker and Durable Object configuration.

## Current profile behavior

- Regular users can save up to **5 Roblox profiles** in the dashboard.
- The configured Owner Roblox user can save more profiles.
- The profile picker is a horizontal, swipeable carousel: Create Account starts centered when available, saved profiles sit to its left, and the card nearest the center is enlarged to appear in the foreground.
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

The Worker uses the Durable Object binding and migration declared in `wrangler.jsonc`. The Owner feature branch has its own Cloudflare Workers Builds preview trigger; preview URLs are enabled so testing the feature branch does not replace the live Worker.

1. Install Wrangler and authenticate with the Cloudflare account that owns the Worker.
2. Set the required secrets using Wrangler (never commit secret values):
   - `DISCORD_PUBLIC_KEY`
   - `DISCORD_BOT_TOKEN`
   - `SIGNING_SECRET`
3. Deploy from the project directory:

   ```sh
   npx wrangler deploy
   ```

4. Confirm the deployed Worker responds at its root endpoint with its online message.
5. Keep the Worker URL in `orbis_client.lua` pointed at the intended deployment.

The `/setup` route is disabled by default in the Worker. Only enable it temporarily when re-registering the Discord command, then disable it again.

## Owner and Premium features

- The Owner panel lists accounts that have signed in to this Worker, with Roblox usernames resolved for display.
- The Owner can grant or revoke Premium for registered accounts; the Owner account itself is always Premium.
- Owner actions are recorded in Durable Object storage and retained for up to 30 days.
- Owner access is checked server-side using the session token and configured Owner Roblox User ID (`8407673016`). A client-side flag alone does not grant Owner access.

## Validation and release notes

- This repository contains Roblox/Luau client code and a JavaScript Cloudflare Worker.
- GitHub Actions checks are only available when workflows are configured and triggered. A missing workflow run is not a passing build.
- A successful JavaScript syntax check does not prove the Luau UI works in the Roblox runtime.
- Cloudflare currently does not create active Preview URLs for Workers that use Durable Objects. The feature-branch `wrangler preview` build can validate the deployment command, but it is not a live runtime test; the Owner API and Durable Object changes are not deployed to the production Worker by this branch workflow.
- The public client source contains Discord webhook URLs for the News form. Treat those URLs as exposed: rotate them in Discord and move replacements into Worker secrets before relying on those submissions.
- Owner UI references are forward-declared before callbacks use them, so Lua resolves them to the intended local controls and cache.
- The feature-branch dashboard loads its matching `orbis_client.lua`, including the Owner API methods.
- Owner API requests are forwarded to their matching Durable Object routes; they are not treated as ordinary session checks.
- The Worker validates the Owner session and configured Roblox User ID on every Owner-only operation.
- Test profile creation, profile switching, passcode login, session resume, and Owner-only endpoints in a non-production test environment before merging or deploying.
- Changes on `feature/owner-system` are proposed through [PR #2](https://github.com/Dreamhacker-Fear/Ps4/pull/2). The default `main` branch is not changed until that pull request is merged.
