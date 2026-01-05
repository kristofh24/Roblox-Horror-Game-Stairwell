-- @ScriptType: Script
local ts=game:GetService("TweenService")
local rs=game:GetService("RunService")

local light_detect=require(game.ReplicatedStorage.LightDetection)

--[[Instance.new("Folder").Parent=workspace
function visualize(pos,name)
	local p=Instance.new("Part")
	p.Shape=Enum.PartType.Ball
	p.Size=Vector3.new(1,1,1)
	p.Material=Enum.Material.Neon
	p.Color=Color3.fromRGB(255,0,0)
	p.Anchored=true
	p.CanCollide=false
	p.Position=pos
	p.Name=name or "Part"
	p.Parent=workspace.Folder
end]]

local sp=script.Start.Value~=0 and workspace.Map.Cells[tostring(script.Start.Value)].Pathfinding["1"] or workspace.Map.StartingArea.Pathfinding["1"]
local ep=workspace.Map.Cells[tostring(script.End.Value)].Pathfinding["1"]

local waypoints={}
local nextWaypoint=1

for a=script.Start.Value,script.End.Value,-1 do
	local cell
	if a~=0 then
		cell=workspace.Map.Cells[tostring(a)]
	else
		cell=workspace.Map.StartingArea
	end
	
	if tonumber(cell.Name)==script.End.Value and script.Computer.Value==true then
		for b=1,#cell.Pathfinding.Computer:GetChildren() do
			local p=false
			if cell.Pathfinding.Computer[tostring(b)]:FindFirstChild("Plank") then p=true end
			table.insert(waypoints,{["Position"]=cell.Pathfinding.Computer[tostring(b)].Position,["Cell"]=cell,["Terminate"]=false,["Plank"]=p}) --no terminating waypoints?
		end
		
		continue
	end
	
	local num=#cell.Pathfinding:GetChildren()
	if cell.Pathfinding:FindFirstChild("Computer") then num-=1 end
	
	for b=1,num do
		local t=false
		if cell.Pathfinding[tostring(b)]:FindFirstChild("Terminate") then t=true end
		local p=false
		if cell.Pathfinding[tostring(b)]:FindFirstChild("Plank") then p=true end
		table.insert(waypoints,{["Position"]=cell.Pathfinding[tostring(b)].Position,["Cell"]=cell,["Terminate"]=t,["Plank"]=p})
	end
end

--[[for i,v in pairs(waypoints) do
	visualize(v)
end]]

script.Parent.HumanoidRootPart:SetNetworkOwner(nil)

--get all doors (and connect descendant added) (WAY BETTER FOR PERFORMANCE LIKE THIS)
local doors={}
local opened_doors={}
for i,v in pairs(workspace.Map.Cells:GetDescendants()) do
	if string.sub(v.Name,1,5)=="_Door" and v:IsA("Model") then
		table.insert(doors,v)
	end
end

local child_added=workspace.Map.Cells.DescendantAdded:Connect(function(v) --has to be descendant
	if string.sub(v.Name,1,5)=="_Door" and v:IsA("Model") then
		table.insert(doors,v)
	end
end)

local plrs=game.ServerScriptService.Main.ReqPlrs:Invoke() --change perhaps (if plr respawns while monster is spawned, what happens?)
local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
local filter={script.Parent}
for i,v in pairs(opened_doors) do table.insert(filter,v) end
for i,v in pairs(plrs) do
	for a,b in pairs(v.Character:GetChildren()) do
		if (b:IsA("BasePart") or b:IsA("Accessory")) and b.Name~="HumanoidRootPart" then
			table.insert(filter,b)
		end
	end
end
params.FilterDescendantsInstances=filter

local heartbeat=rs.Heartbeat:Connect(function()
	--[[local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	local filter={script.Parent}
	for i,v in pairs(opened_doors) do table.insert(filter,v) end
	for i,v in pairs(plrs) do
		
	end
	params.FilterDescendantsInstances=filter]]
	--params.RespectCanCollide=true
	
	--plr detection
	for i,v in pairs(plrs) do --somehow ignore dead plrs
		local dir=v.Character.HumanoidRootPart.Position-script.Parent.HumanoidRootPart.Position
		--local ray=workspace:Blockcast(CFrame.lookAt(script.Parent.HumanoidRootPart.Position,v.Character.HumanoidRootPart.Position),Vector3.new(1,1,1),dir,params)
		local ray=workspace:Raycast(script.Parent.HumanoidRootPart.Position,dir,params)
		
		if ray then
			--if ray.Instance:IsDescendantOf(v.Character) and ray.Distance<=24 then --play around with distance value
			if ray.Instance.Name=="HumanoidRootPart" and ray.Instance.Parent==v.Character and ray.Distance<=18 then
				--require(game.ReplicatedStorage.Functions).renderRay(script.Parent.HumanoidRootPart.Position,ray.Position,nil,1,1)
				--print(require(game.ReplicatedStorage.LightDetection):GetLightLevelAtPoint(v.Character.HumanoidRootPart.Position,false,false))
				local light_level=light_detect:GetLightLevelAtPoint(v.Character.HumanoidRootPart.Position,false,false)
				local light_state=game.ServerScriptService.RemoteHandler.ReqFlashlightState:Invoke(v.Character.Name)
				light_level+=light_state and 1 or 0
				--print(light_level)
				if light_level>.25 or ray.Distance<=8 then
					v.DiedTo.Value="Monster1"
					if script.Computer.Value==true then v.DiedTo.Value="Monster1Computer" end --hmmm
					v.Character.Humanoid.Health=0
					
					table.remove(plrs,i)
				end
			end
		end
	end
	
	--door slamming
	for i,v in pairs(doors) do
		if not v.Parent then
			table.remove(doors,i)
			continue
		end
		
		local dir=v.Door.Position-script.Parent.HumanoidRootPart.Position
		local ray=workspace:Blockcast(script.Parent.HumanoidRootPart.CFrame,Vector3.new(1,1,1),dir,params)
		
		if ray then
			if ray.Instance:IsDescendantOf(v) and ray.Distance<=12 then --play around w/ distance value
				if v.IsLocked.Value==true then continue end
				if v.Opened.Value==true then continue end
				if v:FindFirstChild("BlockadePlank") then
					--if v.BlockadePlank.BlockadePlank.Cracked.Transparency==1 then
						--v.BlockadePlank.BlockadePlank.Cracked.Transparency=.4
						continue
					--end
				end
				
				table.remove(doors,i)
				table.insert(opened_doors,v)
				table.insert(filter,v) --yessir
				params.FilterDescendantsInstances=filter
				
				local d=dir.Unit:Dot(v.Door.CFrame.LookVector)>0 and -1 or 1
				
				v.Opened.Value=true
				v.Door.Slam:Play()
				ts:Create(
					v.Hinge,
					TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
					{CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(120*d),0)}
				):Play()

				task.wait(.16)
				
				local r2=56
				if tonumber(v.Parent.Name)==script.End.Value then r2=100 end
				
				ts:Create(
					v.Hinge,
					TweenInfo.new(2.2,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
					{CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(r2*d),0)}
				):Play()
			end
		end
	end
end)

if #waypoints==0 then
	print("no waypoints --> destroying")
	
	heartbeat:Disconnect()
	child_added:Disconnect()
	script.Parent:Destroy()
end

local blocked_door=nil
local at_blocked_door=false
local at_blocked_door_bypass=false
script.Parent.Humanoid:MoveTo(waypoints[nextWaypoint].Position)
script.Parent.Humanoid.MoveToFinished:Connect(function(reached)
	if at_blocked_door then
		script.Parent.HumanoidRootPart.Banging:Play()
		task.wait(.2)
		script.Parent.HumanoidRootPart.Run:Stop()
		task.wait(.6)
		if at_blocked_door_bypass then
			blocked_door.BlockadePlank.BlockadePlank.Break:Play()
			for i,v in pairs(blocked_door.BlockadePlank:GetChildren()) do
				--if v.Name=="Nail" then
					--v:Destroy()
				--elseif v.Name=="BlockadePlank" then
					v.Anchored=false
				--end
			end
			game:GetService("Debris"):AddItem(blocked_door.BlockadePlank,10) --change?
			blocked_door.BlockadePlank.Name="plank_debris" --allows monster to slam door open
			script.Parent.Humanoid:MoveTo(waypoints[nextWaypoint].Position)
			blocked_door=nil
			at_blocked_door=false
			at_blocked_door_bypass=false
			
			script.Parent.HumanoidRootPart.Run:Play()
		else
			task.wait(.2)
			if blocked_door:FindFirstChild("BlockadePlank") then blocked_door.BlockadePlank.BlockadePlank.Cracked.Transparency=.4 end
			task.wait(.3)
			if script.Computer.Value then script.Parent.HumanoidRootPart.Roar:Play() end
			task.wait(1.3)
		end
	end
	
	local terminate=false
	if waypoints[nextWaypoint].Terminate then terminate=true end
	if waypoints[nextWaypoint].Plank and waypoints[nextWaypoint].Cell:FindFirstChild("_Plank") then
		if waypoints[nextWaypoint].Cell._Plank.Plank.Transparency~=0 then
			print("no plank placed --> teleport to next waypoint")
			
			nextWaypoint+=1
			script.Parent.HumanoidRootPart.CFrame=CFrame.new(waypoints[nextWaypoint].Position)
			--terminate=true
		end
	end
	
	if reached and nextWaypoint<#waypoints and not terminate and not at_blocked_door then
		nextWaypoint+=1
		
		local params=RaycastParams.new()
		params.FilterType=Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances={script.Parent}
		local dir=waypoints[nextWaypoint].Position-waypoints[nextWaypoint-1].Position
		local ray=workspace:Raycast(waypoints[nextWaypoint-1].Position,dir,params)
		
		if ray then
			if ray.Instance.Parent.Name=="_Door" and (ray.Instance.Parent:FindFirstChild("BlockadePlank") or ray.Instance.Parent.IsLocked.Value) then
				blocked_door=ray.Instance.Parent
				at_blocked_door=true
				script.Parent.Humanoid:MoveTo(ray.Position+ray.Normal)
				
				if blocked_door:FindFirstChild("BlockadePlank") then
					if blocked_door.BlockadePlank.BlockadePlank.Cracked.Transparency<1 then
						at_blocked_door_bypass=true
					end
				end
				
				return
			end
		end
		
		script.Parent.Humanoid:MoveTo(waypoints[nextWaypoint].Position)
	else--if (reached and nextWaypoint>=#waypoints) or not reached or terminate then --destroy if path failed (for now)
		--path finished --> destroy?
		print("destroying monster")
		
		if script.Computer.Value==true then
			if nextWaypoint>=#waypoints and not terminate and not at_blocked_door then
				--wait a little, then run backward
				script.Parent.HumanoidRootPart.Run:Stop()
				task.wait(3)
				script.Parent.HumanoidRootPart.Run:Play()
			end
			
			--run backward
			local comp=workspace.Map.Cells[tostring(script.End.Value)]._Computer
			comp.ClickDetector.MaxActivationDistance=7.5
			comp.Screen.Color=Color3.fromRGB(0,0,0)
			comp.Alarm:Stop()
			
			local n_waypoints={}
			local t_waypoints={}
			print(nextWaypoint)
			for i,v in pairs(waypoints) do
				if i>nextWaypoint then continue end
				t_waypoints[i]=v
			end
			print(#waypoints,#t_waypoints)
			for i,v in pairs(t_waypoints) do
				n_waypoints[#t_waypoints-(i-1)]=v
			end
			
			waypoints=n_waypoints
			nextWaypoint=1 --or 2?
			
			script.Parent.Humanoid:MoveTo(waypoints[nextWaypoint].Position)
			script.Computer.Value=false --to prevent monster from looping back again
			
			return
		end
		
		heartbeat:Disconnect()
		child_added:Disconnect()
		script.Parent:Destroy()
	end
end)