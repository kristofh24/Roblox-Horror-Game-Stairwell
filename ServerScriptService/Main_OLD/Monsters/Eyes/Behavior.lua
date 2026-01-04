-- @ScriptType: Script
local rs=game:GetService("RunService")

local light_detect=require(game.ReplicatedStorage.LightDetection)

local dead=false
local f_count=0

task.spawn(function()
	while true do
		task.wait(math.random(16,64))
		if dead then break end
		script.Parent.Laugh:Play()
	end
end)

local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
local filter={script.Parent}
for i,v in pairs(game.Players:GetPlayers()) do
	for a,b in pairs(v.Character:GetChildren()) do
		if (b:IsA("BasePart") or b:IsA("Accessory")) and b.Name~="HumanoidRootPart" then
			table.insert(filter,b)
		end
	end
end
params.FilterDescendantsInstances=filter

rs.Heartbeat:Connect(function()
	if dead then return end
	
	f_count+=1
	
	if f_count%4==0 then
		--no need to do this stuff 60 times a second
		
		--print(light_detect:GetLightLevelAtPoint(script.Parent.Position,false,false))
		
		if light_detect:GetLightLevelAtPoint(script.Parent.Position,false,false)>3 then
			dead=true
			script.Parent.Screech:Play()
			script.Parent.Whisper:Stop()
			script.Parent.Attachment:Destroy()
			
			script.Parent.Explode.Enabled=true
			task.wait(.1)
			script.Parent.Explode.Enabled=false
			
			task.wait(2.4)
			
			script.Parent:Destroy()
			
			return
		end
		
		for i,v in pairs(game.Players:GetPlayers()) do
			if v.Dead.Value then continue end
			if not v.Character then continue end
			
			local dir=(v.Character.HumanoidRootPart.Position-script.Parent.Position)
			if dir.Magnitude<=10 then
				local ray=workspace:Raycast(script.Parent.Position,dir,params)
				if ray and ray.Instance.Name=="HumanoidRootPart" and ray.Instance.Parent==v.Character then
					v.Character.Humanoid.Health-=20--=0
					game.ReplicatedStorage.Remote.Jumpscare:FireClient(v,"Eyes")
					
					dead=true
					script.Parent.Bite:Play()
					script.Parent.Scream:Play()
					script.Parent.Whisper:Stop()
					script.Parent.Attachment:Destroy()

					task.wait(2.5)

					script.Parent:Destroy()
				end
			end
		end
	end
end)