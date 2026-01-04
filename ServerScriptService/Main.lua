-- @ScriptType: Script
local plrs={}
local plrs_dead={}

local plr_stats={
	--[[
	["name"]={
		Depth: number
	}
	--]]
}

local rs=game:GetService("RunService")
local funcs=require(game.ReplicatedStorage.Functions)
local light_detect=require(game.ReplicatedStorage.LightDetection)

local items={
	["Battery"]=75,
	["Adrenaline"]=20,
	--["SanityJuice"]=32.5,
	["Key"]=5
}

rs.Heartbeat:Connect(function()
	--empty for now
end)

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		char.Humanoid.BreakJointsOnDeath=false
		char.Humanoid.Died:Connect(function()
			plr_stats[plr.Name].Depth=math.abs(math.ceil(char.HumanoidRootPart.CFrame.Y/9))

			plr.Dead.Value=true

			--ragdoll stuff
			for i,v in pairs(char:GetDescendants()) do
				if v.Name=="Neck" then continue end --should improve pov of plr
				if v:IsA("Motor6D") then
					local a0,a1=Instance.new("Attachment"),Instance.new("Attachment")
					a0.CFrame=v.C0
					a1.CFrame=v.C1
					a0.Parent=v.Part0
					a1.Parent=v.Part1

					v.Part0.CanCollide=true
					v.Part1.CanCollide=true

					local b=Instance.new("BallSocketConstraint")
					b.Attachment0=a0
					b.Attachment1=a1
					b.Parent=v.Part0

					v:Destroy()
				end
			end
			char.HumanoidRootPart.CanCollide=false

			--on death stuff
			local connection
			connection=plr.CharacterAdded:Connect(function()
				print("char respawned (fully) --> teleport to dead plr zone")

				local i=table.find(plrs,plr)
				table.remove(plrs,i)
				table.insert(plrs_dead,plr)

				connection:Disconnect()
			end)
		end)
	end)

	local diedto=Instance.new("StringValue")
	diedto.Name="DiedTo"
	diedto.Parent=plr

	local dead=Instance.new("BoolValue")
	dead.Name="Dead"
	dead.Parent=plr

	local battery=Instance.new("NumberValue")
	battery.Name="Battery"
	battery.Parent=plr
	battery.Value=50
	local sanity=Instance.new("NumberValue")
	sanity.Name="Sanity"
	sanity.Parent=plr
	sanity.Value=100

	plr.CharacterAdded:Wait() --double wait w/ 1 sec below

	task.wait(1) --give loading time ig

	table.insert(plrs,plr)
	plr_stats[plr.Name]={
		["Depth"]=0
	}

	plr.Character.HumanoidRootPart.CFrame=workspace.Map.StartingArea.Spawn.CFrame*CFrame.new(0,3.4,0)
end)

game.ReplicatedStorage.Remote.UpdStats.OnServerEvent:Connect(function(plr,battery,sanity)
	plr.Battery.Value=battery
	plr.Sanity.Value=sanity
end)

--init
require(script.gen).gen_map()

print("map gen finished")

for i,v in pairs(game.Players:GetPlayers()) do
	v.Character.HumanoidRootPart.CFrame=workspace.Map.MAP_TEST.START.Spawn.CFrame*CFrame.new(0,3.4,0)
end