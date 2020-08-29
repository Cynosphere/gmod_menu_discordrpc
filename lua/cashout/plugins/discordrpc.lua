pcall(require, "luamio")
if not io then return end
local struct = include("rpc/struct.lua")
local uuid = include("rpc/uuid.lua")
local json = include("rpc/json.lua")

if _G.DiscordRPC and _G.DiscordRPC._RPC then
    _G.DiscordRPC:Close()
end

local Tag = "DiscordRPC"
local DiscordRPC = {}

if not cookie.GetNumber("discordrpc_debug", 0) then
    cookie.Set("discordrpc_debug", 0)
end

DiscordRPC.StartTime = (os.time() - math.floor(SysTime())) * 1000

DiscordRPC.OPCodes = {
    OP_HANDSHAKE = 0,
    OP_FRAME = 1,
    OP_CLOSE = 2,
    OP_PING = 3,
    OP_PONG = 4
}

DiscordRPC.Assets = {
    ["darkrp"] = true,
    ["gmod"] = true,
    ["sandbox"] = true,
    ["sandbox_modded"] = true,
    ["noicon"] = true,
    ["terrortown"] = true
}

function DiscordRPC:Print(...)
    MsgC(Color(114, 137, 218), "[DiscordRPC] ")
    print(...)
end

function DiscordRPC:FindRPC()
    if system.IsWindows() then
        for i = 0, 3 do
            local f = io.open("\\\\?\\pipe\\discord-ipc-" .. i, "w")
            if f ~= nil then
                return f
            end
        end
    elseif system.IsLinux() then -- UNTESTED
        local path

        -- $XDG_RUNTIME_DIR or $TMPDIR or $TMP or $TEMP or /tmp
        local _XDG_RUNTIME_DIR = io.popen("echo $XDG_RUNTIME_DIR")
        local XDG_RUNTIME_DIR = _XDG_RUNTIME_DIR:read("*a"):Trim()
        _XDG_RUNTIME_DIR:close()

        local _TMPDIR = io.popen("echo $TMPDIR")
        local TMPDIR = _TMPDIR:read("*a"):Trim()
        _TMPDIR:close()

        local _TMP = io.popen("echo $TMP")
        local TMP = _TMP:read("*a"):Trim()
        _TMP:close()

        local _TEMP = io.popen("echo $TEMP")
        local TEMP = _TEMP:read("*a"):Trim()
        _TEMP:close()

        if XDG_RUNTIME_DIR ~= "" then
            path = XDG_RUNTIME_DIR
        elseif TMPDIR ~= "" then
            path = TMPDIR
        elseif TMP ~= "" then
            path = TMP
        elseif TEMP ~= "" then
            path = TEMP
        else
            path = "/tmp"
        end

        for i = 0, 3 do
            local f = io.open(path .. "/discord-ipc-" .. i, "w")
            if f ~= nil then
                return f
            end
        end
    elseif system.IsOSX() then
        self:Print("OSX unsupported at the moment")
    else
        assert("[DiscordRPC] No OS recognizable by GMod or detouring wrongly????")
    end
end

function DiscordRPC:Init()
    self:Print("Starting RPC interface")
    self._RPC = self:FindRPC()
    if not self._RPC then
        self:Print("No RPC found. Is Discord running?")
        return
    end
    self.PID = math.random(1000, 20000)

    self:SendData(json.encode({
        v = 1,
        client_id = "429721789304668170"
    }), self.OPCodes.OP_HANDSHAKE)

    timer.Simple(0.5, function()
        local act = self:NewActivity()
        act:SetLargeImage("gmod", "Cashout RPC Plugin")
        act:SetDetails("In Menus")
        act:SetStart(self.StartTime)
        self:SendData(act:Finalize())
    end)
end

function DiscordRPC:Close()
    self:Print("Shutting down RPC interface")
    self._RPC:close()
    self._RPC = nil
end

function DiscordRPC:SendData(data, op)
    if not self._RPC then
        self:Print("Trying to send data when not initialized?")

        return
    end

    op = op or self.OPCodes.OP_FRAME
    local header = struct.pack("<II", op, data:len())
    self._RPC:write(header)
    self._RPC:flush()
    self._RPC:write(data)
    self._RPC:flush()

    if tobool(cookie.GetNumber("discordrpc_debug", 0)) then
        self:Print("[DEBUG] Sending data:", op, data)
    end
end

function DiscordRPC:SendActivity(act)
    if not act then
        self:Print("No activity given")

        return
    end
end

function DiscordRPC:NewActivity()
    local act = {
        _data = {
            cmd = "SET_ACTIVITY",
            args = {
                pid = self.PID,
                activity = {
                    assets = {
                        large_image = self.Assets["gmod"]
                    }
                }
            },
            nonce = uuid()
        }
    }

    function act.SetDetails(s, str)
        if not str then
            return
        end

        s._data.args.activity.details = str
    end

    function act.SetState(s, str)
        if not str then
            return
        end

        s._data.args.activity.state = str
    end

    function act.SetStart(s, time)
        time = time or os.time() * 1000
        s._data.args.activity.timestamps = s._data.args.activity.timestamps or {}
        s._data.args.activity.timestamps.start = time
    end

    function act.SetEnd(s, time)
        time = time or os.time() * 1000
        s._data.args.activity.timestamps = s._data.args.activity.timestamps or {}
        s._data.args.activity.timestamps["end"] = time
    end

    function act.SetLargeImage(s, key, text)
        if not self.Assets[key] then
            return
        end

        s._data.args.activity.assets.large_image = key

        if text then
            s._data.args.activity.assets.large_text = text
        end
    end

    function act.SetSmallImage(s, key, text)
        if not self.Assets[key] then
            return
        end

        s._data.args.activity.assets.small_image = key

        if text then
            s._data.args.activity.assets.small_text = text
        end
    end

    function act.SetParty(s, cur, max)
        s._data.args.activity.party = {size = {cur, max}}
    end

    function act.Finalize(s)
        return json.encode(s._data)
    end

    return act
end

_G.DiscordRPC = DiscordRPC
DiscordRPC:Init()

concommand.Add("discordrpc_stop", function()
    if DiscordRPC._RPC then
        DiscordRPC:Close()
    else
        DiscordRPC:Print("Already stopped")
    end
end)

concommand.Add("discordrpc_restart", function()
    if DiscordRPC._RPC then
        DiscordRPC:Close()
    end

    DiscordRPC:Init()
end)

concommand.Add("discordrpc_toggledebug", function()
    local old = cookie.GetNumber("discordrpc_debug", 0)
    cookie.Set("discordrpc_debug", old == 0 and 1 or 0)
end)

--[[hook.Add("InGame",Tag,function(state)
    local act = DiscordRPC:NewActivity()
    act:SetLargeImage("gmod","Cashout RPC Plugin")
    act:SetDetails(state and "In Game" or "In Menus")
    act:SetStart()
    DiscordRPC:SendData(act:Finalize())
end)--]]
local NextRPC = CurTime() + 15
DiscordRPC.GameData = {}

hook.Add("Think", Tag, function()
    if not DiscordRPC._RPC then
        return
    end

    local GameData = DiscordRPC.GameData

    if GetLoadStatus() ~= nil then
        if NextRPC > CurTime() then
            return
        end

        if not g_ServerName or not g_MapName or not g_GameMode then
            return
        end

        if not GameData.Server or not GameData.Map or not GameData.Gamemode then
            GameData = {
                Server = g_ServerName,
                Map = g_MapName,
                Gamemode = g_GameMode
            }
        end

        local act = DiscordRPC:NewActivity()
        act:SetSmallImage("gmod", "Cashout RPC Plugin")
        act:SetLargeImage(DiscordRPC.Assets[GameData.Gamemode] and GameData.Gamemode or "noicon", "Gamemode: " .. GameData.Gamemode)
        act:SetDetails("Loading into " .. GameData.Map)
        act:SetState(GameData.Server)
        act:SetStart(DiscordRPC.StartTime)
        DiscordRPC:SendData(act:Finalize())
        NextRPC = CurTime() + 15
    elseif not GetLoadStatus() then
        if IsInGame() then
            if NextRPC > CurTime() then
                return
            end

            local act = DiscordRPC:NewActivity()
            act:SetSmallImage("gmod", "Cashout RPC Plugin")
            act:SetLargeImage(DiscordRPC.Assets[GameData.Gamemode] and GameData.Gamemode or "noicon", "Gamemode: " .. (GameData.GamemodeName and Format("%s (%s)", GameData.GamemodeName, GameData.Gamemode) or GameData.Gamemode))
            act:SetDetails(GameData.Server)
            act:SetState(GameData.Map)
            act:SetStart(DiscordRPC.StartTime)
            if GameData.PlayerCount and GameData.MaxPlayers then
                act:SetParty(GameData.PlayerCount, GameData.MaxPlayers)
            end

            DiscordRPC:SendData(act:Finalize())
            NextRPC = CurTime() + 15
        else
            if GameData then
                GameData = {}
            end

            if NextRPC > CurTime() then
                return
            end

            local act = DiscordRPC:NewActivity()
            act:SetLargeImage("gmod", "Cashout RPC Plugin")
            act:SetDetails("In Menus")
            act:SetStart(DiscordRPC.StartTime)
            DiscordRPC:SendData(act:Finalize())
            NextRPC = CurTime() + 15
        end
    end
end)

local clientside = [[
timer.Create("CashoutRPC", 1, 0, function()
    if proxi then
        local gm_name = GAMEMODE.Name
        proxi.RunOnMenu(Format([=[
            DiscordRPC.GameData.Server = %q
            DiscordRPC.GameData.PlayerCount = %d
            DiscordRPC.GameData.MaxPlayers = %d
            DiscordRPC.GameData.IP = %q
            DiscordRPC.GameData.Gamemode = %q
            DiscordRPC.GameData.Map = %q
            DiscordRPC.GameData.GamemodeName = %q
        ]=], GetHostName(), player.GetCount(), game.MaxPlayers(), game.GetIPAddress(), engine.ActiveGamemode(), game.GetMap(), gm_name))
    end
end)
]]

local first = true
hook.Add("RunOnClient", "CashoutRPC", function(name, src)
    if name:find("autorun/") and first then
        interstate.RunOnClient([[hook.Add("Initialize", "CashoutRPC", function()
        ]] .. clientside .. [[
        end)]])
        first = false
    end
end)
hook.Add("LuaStateClosed", "CashoutRPC", function(state)
    if state == 0 then
        first = true
    end
end)

if IsInGame() then
    interstate.RunOnClient(clientside)
end