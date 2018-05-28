if not discordrpc then ErrorNoHalt("DiscordRPC: missing???") return end

discordrpc.state = "default" -- This is the default state when you first load in.


hook.Add("Think", "discordrpc_init", function()
    hook.Run("httpLoaded")
    hook.Remove("Think", "discordrpc_init")
end)

hook.Add("httpLoaded", "discordrpc_init", function()
	discordrpc.Print("HTTP loaded, trying to init")
	discordrpc.Init(function(succ, err)
		if succ then
			discordrpc.LoadStates()
			if discordrpc.state then
				local state = discordrpc.states[discordrpc.state]
				if state.Init then
					state:Init()
				end
			end
		else
			discordrpc.Print(succ, err)
		end
	end)
end)