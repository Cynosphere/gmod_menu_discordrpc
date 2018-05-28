if not discordrpc then ErrorNoHalt("DiscordRPC: missing???") return end

local default = discordrpc.states.default or {}
default.assets = default.assets or {
	large_image = {
		gmod           = true,
		darkrp         = true,
		sandbox        = true,
		sandbox_modded = true,
		moddedbox      = true,
	},
	small_image = {
		gmod_small = true,
	}
}
local presences = {
    mainmenu = {},
    ingame = {}
}
local gameStart = os.time()

function presences.mainmenu:GetActivity()
	return {
		--details = "In main menu.",
		state = "In main menu.",
		timestamps = {
			start = gameStart
		},
		assets = {
			large_image = "gmod",
			large_text = "Powered by Cashout"
		},
	}
end

function presences.ingame:GetActivity()
	return {
		details = GetLoadStatus() and "Loading into a game..." or "In game.",
        state = GetLoadStatus() and (_G.co_loadinfo.name and _G.co_loadinfo.name or "Server name unknown.") or (IsInGame() and _G.co_loadinfo.name or "Server name unknown."),
		timestamps = {
			start = gameStart
		},
		assets = {
			small_image = "gmod_small",
			small_text = ("Map: %s"):format(_G.co_loadinfo.map),
			large_image = default.assets.large_image[_G.co_loadinfo.gm] and _G.co_loadinfo.gm or "gmod",
			large_text = _G.co_loadinfo.gm and (_G.co_loadinfo.gm == "moddedbox" and "The Cyn Hole" or (_G.co_loadinfo.gm == "sandbox_modded" and "Meta Construct" or "Gamemode: ".._G.co_loadinfo.gm) or "Gamemode Unknown")
		},
	}
end

for _, presence in next, presences do -- let's do that currently, until I'm less lazy to actually add other game info to the presence
	if not presence.GetActivity then
		presence.GetActivity = function()
			return fallback:GetActivity()
		end
	end
end

-- actual state
function default:Init()
	local activeGamemode = (IsInGame() or GetLoadStatus()) and presences.ingame or presences.mainmenu

	discordrpc.clientID = "429721789304668170"

	if activeGamemode.Init then
		activeGamemode:Init()
	end

	TimerPanel = vgui.Create("EditablePanel", GetOverlayPanel())
	TimerPanel:SetPos(0,0)
	TimerPanel:SetSize(1,1)
	local nextRPC = CurTime()+15
	TimerPanel.Think = function()
		if CurTime() > nextRPC then
			discordrpc.SetActivity(self:GetActivity(), discordrpc.Print)
			nextRPC = CurTime()+15
		end
	end

end
function default:GetActivity()
	local activeGamemode = (IsInGame() or GetLoadStatus()) and presences.ingame or presences.mainmenu

	local activity = activeGamemode:GetActivity()
	if not activity.assets then
		activity.assets = {}
	end

	return activity
end

discordrpc.states.default = default