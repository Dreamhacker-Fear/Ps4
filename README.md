# PS4 Dashboard

A Roblox PS4-inspired dashboard UI.

## Load

The public loader URL remains unchanged:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Dreamhacker-Fear/Ps4/refs/heads/main/ps4.lua"))()
```

## Included

- PS4-style dashboard interface and navigation
- Library, Store, Settings, browser, and on-screen keyboard
- Account/login flow backed by the existing Orbis client module
- Presence and server-authorized Owner Panel
- What's New interface (Discord posting is intentionally disabled in this client build)

## Security notes

- Discord webhook credentials must never be embedded in a client-side script. The webhook URLs from the reference source were removed; the News form remains visible but cannot post until a secure server-side endpoint is configured.
- Owner permissions are expected to be decided by the server, not by a client-side key or editable flag.
- Keep authentication secrets and service credentials on the server. Do not commit them to this repository.

## Dependencies

The login/authentication flow references `orbis_client.lua` in this repository. Keep that file available at the configured raw GitHub URL.

## Community

[Join the Discord](https://discord.gg/gfdjcFDVjf)

## Validation

This repository change is delivered on a feature branch first. Review and test it in Roblox before merging into `main`. GitHub Actions results, if configured for this repository, should be checked on the pull request.
