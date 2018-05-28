--rpc doesnt like being hotreloaded for some reason
--prob cause its made by a baguette lol
if discordrpc then return end

Msg("DiscordRPC loading: start\n")

local function load(path)
	include(path)
	print("\tLoaded: " .. path)
end

load("cashout/plugins/rpc/init.lua")
function discordrpc.LoadStates()
    discordrpc.Print("Loading states:")
    for _, fn in pairs(file.Find("lua/cashout/plugins/rpc/states/*.lua", "GAME")) do
        load("cashout/plugins/rpc/states/" .. fn)
    end
end
load("cashout/plugins/rpc/main.lua")

Msg("DiscordRPC loading: done!\n")