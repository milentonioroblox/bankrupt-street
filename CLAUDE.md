# Bankrupt Street: notes for Claude

A Roblox game built with Roblox Studio, Rojo, ForgeGUI (UI/art/audio generation) and Claude Code.

## Layout

| Path | Goes to in Studio |
|---|---|
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/ui` | `ReplicatedStorage.UI` (ForgeGUI-generated UI modules) |
| `assets/` | Source art/audio from ForgeGUI before upload |
| `docs/GDD.md` | Game design document (source of truth) |

Server code lives in `src/server/Services/*` modules and client code in `src/client/Controllers/*`. Each module can expose `:Init()` and `:Start()`.

## Setup (Windows)

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then run `aftman install` in this folder.
2. Install the Rojo plugin in Studio, run `rojo serve`, and click **Connect** in the plugin.
3. Connect Claude Code to Studio:
   ```
   claude mcp add --transport stdio Roblox_Studio -- "cmd.exe" "/c" "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"
   ```
4. ForgeGUI MCP is used for UI, images, 3D models, music and SFX.

## Conventions
- Luau with `--!strict`. Format with StyLua, lint with Selene.
- Put balance numbers in `src/shared/Config`, never hard-code them.
- Never trust the client: all currency changes happen on the server.
- Edit code in `src/`, not in Studio, or Rojo will overwrite it.
