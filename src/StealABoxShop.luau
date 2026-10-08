--[[ STEAL A BOX - ROBUX SHOP SETUP (everything you sell, in one place)

  HOW TO SELL THESE FOR REAL
  1. Publish the game (File > Publish to Roblox) and set Game Settings > Security >
     "Enable Studio Access to API Services" ON (so saving works while you test).
  2. Open create.roblox.com > Creations > your experience > Monetization:
       - Passes:              make ONE pass for every entry in Shop.Passes below.
       - Developer Products:  make ONE product for every entry in Shop.Products below,
                              and one for every Speed Boost tier (Shop.SpeedBoostIds).
     Give each one the price you want (the `robux` number below is just what the shop shows
     before Roblox tells it the real price, so keep them the same).
  3. Copy each ID and paste it into `id = 0` below (replace the 0).

  While an ID is still 0:
    - in Roblox Studio the item is FREE, so you can test every purchase;
    - in a real server the button says "Soon" and nothing can be bought.

  Purchases are safe: every Developer Product receipt is remembered in the player's save,
  so a purchase is never given twice and never lost (Roblox retries until it's saved).
]]

local Shop = {}

-- GAME PASSES: bought once, kept forever
Shop.Passes = {
	{key = "VIP",        id = 0, robux = 249, name = "VIP",           icon = "crown",  color = Color3.fromRGB(255, 200, 40),
		desc = "+50% cash forever, the exclusive VIP Trail and a gold VIP sign on your base."},
	{key = "DoubleCash", id = 0, robux = 199, name = "2x Cash",       icon = "cash",   color = Color3.fromRGB(90, 220, 70),
		desc = "Every shopper pays you DOUBLE. Forever!"},
	{key = "FastUnbox",  id = 0, robux = 149, name = "Fast Unboxing", icon = "clock",  color = Color3.fromRGB(70, 170, 255),
		desc = "Your boxes open 2x faster."},
	{key = "Lucky",      id = 0, robux = 179, name = "Lucky Hands",   icon = "clover", color = Color3.fromRGB(80, 220, 120),
		desc = "Plain boxes you bring home get a free extra roll for a mutation."},
	{key = "BigBase",    id = 0, robux = 99,  name = "Bigger Base",   icon = "box",    color = Color3.fromRGB(255, 150, 60),
		desc = "Unbox 4 more boxes at the same time (10 instead of 6)."},
}

-- DEVELOPER PRODUCTS: can be bought again and again
--   kind "cash":       gives `minutes` worth of your income (never less than `base`)
--   kind "skip":       every box unboxing on your base is ready right away
--   kind "luckybox":   a guaranteed Rainbow box (1 in 5 is Galaxy!) from your best department
--   kind "serverluck": 2x mutation luck for EVERYONE in the server (see Config.ServerLuck)
Shop.Products = {
	{key = "CashS",  id = 0, robux = 25,  kind = "cash", name = "Pile of Cash",     minutes = 10,  base = 2500,   icon = "cash"},
	{key = "CashM",  id = 0, robux = 75,  kind = "cash", name = "Bag of Cash",      minutes = 45,  base = 15000,  icon = "bag"},
	{key = "CashL",  id = 0, robux = 199, kind = "cash", name = "Vault of Cash",    minutes = 180, base = 120000, icon = "coin"},
	{key = "CashXL", id = 0, robux = 499, kind = "cash", name = "Mountain of Cash", minutes = 720, base = 900000, icon = "star"},
	{key = "SkipUnbox",  id = 0, robux = 39,  kind = "skip",       name = "Instant Unbox", icon = "clock",
		desc = "Open every box on your base right now"},
	{key = "LuckyBox",   id = 0, robux = 99,  kind = "luckybox",   name = "Lucky Box",     icon = "gift",
		desc = "A guaranteed RAINBOW box (1 in 5 is GALAXY!) from your best department."},
	{key = "ServerLuck", id = 0, robux = 149, kind = "serverluck", name = "Server Luck",   icon = "clover",
		desc = "2x mutation luck for EVERYONE in the server for 15 minutes. Stacks!"},
}

-- SPEED BOOSTS (Config.SpeedBoosts): one Developer Product per tier, in order.
-- 2x = 3 Robux, 4x = 6, 8x = 12, 16x = 24, 32x = 48, 64x = 96, 128x = 192, 256x = 384, 512x = 768, 1024x = 1536
Shop.SpeedBoostIds = {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
}

------------------------------------------------------------------
-- helpers (used by the server and the shop window)
------------------------------------------------------------------
function Shop.GetPass(key)
	for _, p in ipairs(Shop.Passes) do if p.key == key then return p end end
	return nil
end
function Shop.GetProduct(key)
	for _, p in ipairs(Shop.Products) do if p.key == key then return p end end
	return nil
end
function Shop.PassById(id)
	if (id or 0) == 0 then return nil end
	for _, p in ipairs(Shop.Passes) do if p.id == id then return p end end
	return nil
end
-- cash a cash pack gives right now
function Shop.CashAmount(product, incomePerSec)
	return math.max(product.base or 0, math.floor((incomePerSec or 0) * 60 * (product.minutes or 0)))
end

return Shop
