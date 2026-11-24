# Floor is Profit

One tower. Eight floors. The floor you are standing on pays you, then it drops. Jump straight up. Fall off and you lose only the cash from this round. Last players on the gold top floor split the jackpot.

This is a [Rojo](https://rojo.space/) project. The map is built by the server when you press Play. There is no lobby, inventory, or pet system.

## Sync into Roblox Studio

You need Rojo 7.4 or newer (this project uses `.luau` files) and the Rojo Studio plugin.

1. Install the Rojo CLI: [installation](https://rojo.space/docs/v7/getting-started/installation/).
2. Install the Rojo plugin in Roblox Studio (Plugin page, or `rojo plugin install`).
3. From this folder, start the sync server:

   ```
   rojo serve
   ```

   It listens on `localhost:34872`.
4. In Studio, open a Baseplate place (or an empty place). Open the Rojo plugin and connect to `localhost:34872`.
5. Press Play.

The server deletes the default baseplate on start so falling off the tower actually falls. Lifetime cash is the leaderboard **Cash** column (Tab). It lasts for the Studio session only. There is no DataStore.

## How to play

You spawn on the red floor. A few seconds later it pays everyone still standing on it, flashes, and drops. Jump straight up. You pass through the next floor, then land on it.

After that opening drop, each floor waits **30 seconds**, pays, warns you, then drops. The gold floor never drops. If you are still on it, you split the **$20,000** jackpot. If you fall before that, the leaderboard gives back only what you earned this round.

| Floor | Color | Pays |
| --- | --- | --- |
| 1 | Red | $500, then drops in about 7 seconds |
| 2 | Orange | $800 after a 30 second wait |
| 3 | Yellow | $1,200 |
| 4 | Green | $1,800 |
| 5 | Teal | $2,500 |
| 6 | Blue | $3,500 |
| 7 | Purple | $5,000 |
| 8 | Gold | Jackpot, split by whoever is still up |

Jump height is raised so a straight jump clears the next floor. You do not need to run sideways.

## Dev products

These are stubs. Nothing calls `MarketplaceService`.

The buttons on the right side of the screen grant the effect immediately. Chat works too. In the Studio command bar, set the bar to **Server** and call `_G.FloorIsProfit`.

| Effect | Button | Chat | What it does |
| --- | --- | --- | --- |
| Second Life | Second Life | `/life` or `/secondlife` | Your next fall puts you back on the current floor and keeps this round's cash. Stacks up to 5. Arm it before you fall. |
| 2x Next Floor | 2x Next Floor | `/double` or `/2x` | The next floor payout is doubled, then the charge is spent. It is not the jackpot. |
| Survivor trail | Survivor Trail | `/trail` | Toggles a gold ribbon while you are alive. |
| Skip the wait | Skip wait | `/skip` | Ends the current 30 second wait and pays immediately. Does nothing once the floor is already paying or dropping. |

Command bar:

```lua
_G.FloorIsProfit.Grant(game.Players:GetPlayers()[1], "SecondLife")
_G.FloorIsProfit.Grant(game.Players:GetPlayers()[1], "DoubleNext")
_G.FloorIsProfit.Grant(game.Players:GetPlayers()[1], "SurvivorTrail")
_G.FloorIsProfit.Skip()
```

`/help` prints the chat list on screen.

## Project layout

```
default.project.json
README.md
src/shared/Config.luau
src/server/init.server.luau
src/server/RoundLoop.luau
src/server/Tower.luau
src/server/Cash.luau
src/server/Products.luau
src/server/DevCommands.luau
src/server/Remotes.luau
src/client/init.client.luau
src/client/RoundUI.luau
src/client/CashPopup.luau
src/client/ProductButtons.luau
```

`src/server` syncs as a Script under ServerScriptService. `src/client` syncs as a LocalScript under StarterPlayerScripts. `src/shared` syncs into ReplicatedStorage.

## Timing

Floor 1 is short on purpose: about 3.5 seconds, then the payout, a jump warning, then the drop. Spawn, cash, the fall, and the jump should all happen within the first 20 seconds of Play, after the character appears.

Floors 2–7 wait 30 seconds, pay everyone still on that floor, warn for about 3 seconds, then drop. Use **Skip wait** if you want to reach the jackpot without standing through every cycle.

## What still needs Studio

This environment cannot launch Roblox Studio, so none of the following has been played:

- Rojo plugin connect, then Play, with the character landing on the red floor.
- The straight-up jump. The next floor is a thin pad that ignores you until your feet are above it. Confirm you land on it instead of bouncing off the underside or falling through.
- The cash popup, the Tab leaderboard, and losing only this round's cash when you miss the jump.
- Second Life, 2x Next Floor, and the survivor trail, from the buttons and from chat.
- Two players splitting the jackpot.
- Builtin sounds (`electronicpingshort`, `button`, `uuhhh`, `victory`). If one of those paths is missing, that moment is silent. The round still runs.
