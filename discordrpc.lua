require("luamio")
local struct = include("rpc/struct.lua")
local uuid = include("rpc/uuid.lua")

if _G.DiscordRPC and _G.DiscordRPC._RPC then _G.DiscordRPC:Close() end

local Tag = "DiscordRPC"
local DiscordRPC = {}

if not cookie.GetNumber("discordrpc_debug",0) then
    cookie.Set("discordrpc_debug",0)
end

DiscordRPC.StartTime = os.time()*1000

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
}

function DiscordRPC:Print(...)
    MsgC(Color(114,137,218),"[DiscordRPC] ") print(...)
end

function DiscordRPC:Init()
    self:Print("starting rpc")
    self._RPC = io.open("\\\\?\\pipe\\discord-ipc-0","w")
    self.PID = math.random(1000,20000)
    self:SendData(util.TableToJSON({
        v=1,
        client_id="429721789304668170"
    }),self.OPCodes.OP_HANDSHAKE)
    timer.Simple(0.5,function()
        local act = self:NewActivity()
        act:SetLargeImage("gmod","Cashout RPC Plugin")
        act:SetDetails("In Menus")
        act:SetStart(self.StartTime)
        self:SendData(act:Finalize())
    end)
end

function DiscordRPC:Close()
    self:Print("shutting down rpc")
    self._RPC:close()
    self._RPC = nil
end

function DiscordRPC:SendData(data,op)
    if not self._RPC then
        self:Print("trying to send data when not initialized")
        return
    end

    op = op or self.OPCodes.OP_FRAME

	local header = struct.pack("<II",op,data:len())
	self._RPC:write(header)
	self._RPC:flush()
	self._RPC:write(data)
	self._RPC:flush()

    if tobool(cookie.GetNumber("discordrpc_debug",0)) then
        self:Print("sending data",op,data)
    end
end

function DiscordRPC:SendActivity(act)
    if not act then
        self:Print("no activity given")
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

    function act.SetDetails(s,str)
        if not str then return end
        s._data.args.activity.details = str
    end
    function act.SetState(s,str)
        if not str then return end
        s._data.args.activity.state = str
    end
    function act.SetStart(s,time)
        time = time or os.time()*1000
        s._data.args.activity.timestamps = s._data.args.activity.timestamps or {}
        s._data.args.activity.timestamps.start = time
    end
    function act.SetEnd(s,time)
        time = time or os.time()*1000
        s._data.args.activity.timestamps = s._data.args.activity.timestamps or {}
        s._data.args.activity.timestamps["end"] = time
    end
    function act.SetLargeImage(s,key,text)
        if not self.Assets[key] then return end

        s._data.args.activity.assets.large_image = key
        if text then
            s._data.args.activity.assets.large_text = text
        end
    end
    function act.SetSmallImage(s,key,text)
        if not self.Assets[key] then return end

        s._data.args.activity.assets.small_image = key
        if text then
            s._data.args.activity.assets.small_text = text
        end
    end
    function act.Finalize(s)
        return util.TableToJSON(s._data)
    end

    return act
end

_G.DiscordRPC = DiscordRPC
DiscordRPC:Init()

concommand.Add("discordrpc_stop",function()
    if DiscordRPC._RPC then
        DiscordRPC:Close()
    else
        DiscordRPC:Print("already stopped")
    end
end)

concommand.Add("discordrpc_restart",function()
    if DiscordRPC._RPC then
        DiscordRPC:Close()
    end
    DiscordRPC:Init()
end)

concommand.Add("discordrpc_toggledebug",function()
    local old = cookie.GetNumber("discordrpc_debug",0)
    cookie.Set("discordrpc_debug",old == 0 and 1 or 0)
end)

--[[hook.Add("InGame",Tag,function(state)
    local act = DiscordRPC:NewActivity()
    act:SetLargeImage("gmod","Cashout RPC Plugin")
    act:SetDetails(state and "In Game" or "In Menus")
    act:SetStart()
    DiscordRPC:SendData(act:Finalize())
end)--]]

local NextRPC = CurTime()+15
local IsLoading = false
local GameData
hook.Add("Think",Tag,function()
    if not DiscordRPC._RPC then return end
    if GetLoadStatus() ~= nil then
        if NextRPC > CurTime() then return end
        if not g_ServerName or not g_MapName or not g_GameMode then return end
        if not GameData then
            GameData = {
                Server = g_ServerName,
                Map = g_MapName,
                Gamemode = g_GameMode,
            }
        end

        local act = DiscordRPC:NewActivity()
        act:SetSmallImage("gmod","Cashout RPC Plugin")
        act:SetLargeImage(DiscordRPC.Assets[GameData.Gamemode] and GameData.Gamemode or "noicon","Gamemode: "..GameData.Gamemode)
        act:SetDetails("Loading into "..GameData.Map)
        act:SetState(GameData.Server)
        act:SetStart(DiscordRPC.StartTime)
        DiscordRPC:SendData(act:Finalize())

        NextRPC = CurTime()+15
    elseif not GetLoadStatus() then
        if IsInGame() then
            if NextRPC > CurTime() then return end
            if not g_ServerName or not g_MapName or not GameData.Gamemode then return end
            if not GameData then return end

            local act = DiscordRPC:NewActivity()
            act:SetSmallImage("gmod","Cashout RPC Plugin")
            act:SetLargeImage(DiscordRPC.Assets[GameData.Gamemode] and GameData.Gamemode or "noicon","Gamemode: "..GameData.Gamemode)
            act:SetDetails("Playing on "..GameData.Map)
            act:SetState(GameData.Server)
            act:SetStart(DiscordRPC.StartTime)
            DiscordRPC:SendData(act:Finalize())

            NextRPC = CurTime()+15
        else
            if GameData then
                GameData = nil
            end
            if NextRPC > CurTime() then return end

            local act = DiscordRPC:NewActivity()
            act:SetLargeImage("gmod","Cashout RPC Plugin")
            act:SetDetails("In Menus")
            act:SetStart(DiscordRPC.StartTime)
            DiscordRPC:SendData(act:Finalize())

            NextRPC = CurTime()+15
        end
    end
end)