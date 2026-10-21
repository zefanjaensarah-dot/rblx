--[[ STEAL A BOX - error reporter (Studio only)
Collects every server error and puts the last few in ReplicatedStorage, so the client can show
them on screen while you test in Studio (no digging in the Output window). Does nothing in live games. ]]
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local recent = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind ~= Enum.MessageType.MessageError then return end
	table.insert(recent, "[SERVER] " .. string.sub(tostring(message), 1, 300))
	while #recent > 6 do table.remove(recent, 1) end
	ReplicatedStorage:SetAttribute("StudioServerErrors", table.concat(recent, "\n"))
end)
