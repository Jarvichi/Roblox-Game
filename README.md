# Roblox Tag Game

A multi-round tag game for Roblox. One player is "It" each round — they must chase and tag others. Tagged players become the new "It". Survive without being It to earn points!

## Features

- Configurable number of rounds (default: 5 × 60 seconds)
- Random "It" selection at the start of each round
- Red highlight + speed boost on the "It" player
- Per-second survival scoring + round-survival bonus
- Live scoreboard, round timer, toast notifications
- Auto-reassigns "It" if that player leaves mid-round

## Installation

### Option A — Rojo (recommended)

1. **Install Rojo**
   - Download the [Rojo VS Code extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo) **or** the standalone CLI from [rojo.space](https://rojo.space/)
   - Install the [Rojo Roblox Studio plugin](https://www.roblox.com/library/13916111004/Rojo) from the Roblox marketplace

2. **Clone this repository**
   ```bash
   git clone https://github.com/Jarvichi/Roblox-Game.git
   cd Roblox-Game
   ```

3. **Start the Rojo dev server**
   ```bash
   rojo serve
   ```

4. **Connect from Roblox Studio**
   - Open Roblox Studio with your place file
   - Open the Rojo plugin panel and click **Connect**
   - The scripts will sync into the correct services automatically

### Option B — Manual copy

If you prefer not to use Rojo, copy the scripts directly into Roblox Studio:

| File | Where to place it in Studio |
|---|---|
| `src/ReplicatedStorage/GameConfig.lua` | `ReplicatedStorage` → new **ModuleScript** named `GameConfig` |
| `src/ServerScriptService/GameManager.server.lua` | `ServerScriptService` → new **Script** named `GameManager` |
| `src/StarterPlayerScripts/TagClient.client.lua` | `StarterPlayer > StarterPlayerScripts` → new **LocalScript** named `TagClient` |

Paste the contents of each file into the corresponding script in Studio.

## Configuration

Edit `src/ReplicatedStorage/GameConfig.lua` to tune the game:

| Setting | Default | Description |
|---|---|---|
| `ROUND_COUNT` | `5` | Number of rounds per game |
| `ROUND_DURATION` | `60` | Seconds per round |
| `INTERMISSION_DELAY` | `10` | Seconds between rounds |
| `MIN_PLAYERS` | `2` | Minimum players to start |
| `IT_WALK_SPEED` | `22` | Walk speed for the "It" player |
| `NORMAL_WALK_SPEED` | `16` | Walk speed for everyone else |
| `TAG_IMMUNITY` | `2` | Immunity seconds after being tagged |
| `POINTS_PER_SECOND` | `1` | Points earned each second while not It |
| `ROUND_SURVIVAL_BONUS` | `10` | Bonus points for never being It in a round |

## Project Structure

```
default.project.json                          # Rojo project config
src/
  ReplicatedStorage/
    GameConfig.lua                            # Shared tuning constants (ModuleScript)
  ServerScriptService/
    GameManager.server.lua                    # Game loop, rounds, tag logic (Script)
  StarterPlayerScripts/
    TagClient.client.lua                      # HUD and notifications (LocalScript)
```
