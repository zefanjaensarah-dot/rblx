# Smoke tests

These run the game's real scripts in a small fake Roblox engine built on [Lune](https://lune-org.github.io/docs). Every instance is a real Lune instance, so a misspelled property or a wrong value type fails the test.

From this folder:

```
lune run test_server.luau ../../StealABox_v5.rbxl
lune run test_client.luau ../../StealABox_v5.rbxl
```

- `test_server.luau` builds the map and runs the server with one player:
  - steal, carry and place a box (including the anti-teleport check), and the guardian chase and fling
  - unbox, shoppers paying, codes, daily rewards and trails
  - every pass and product (as Studio test purchases), plus real receipts: granted exactly once, unknown products refused
  - Index area rewards (locked until complete, claimed once), saving on leave, rejoining with offline earnings, and the session lock
- `test_client.luau` builds the map and runs the client UI. It sends server events, plays the effects, opens every window and tab, and presses every button.

Both print `... SMOKE TEST PASSED` or list what failed. They can't check how things look; test in Studio for that.
