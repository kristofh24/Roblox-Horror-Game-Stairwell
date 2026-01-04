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

local seed=math.random(999999999)
print(seed)

local active_cells={
	--format: {cell: number, model_path: Model}
}

local max_cell_height=-1
local max_cell_dist=5

local displacements={
	--format: [cell#]={displacement,rotation}
	[0]={Vector3.new(),Vector3.new()}
}

local items={
	["Battery"]=75,
	["Adrenaline"]=20,
	--["SanityJuice"]=32.5,
	["Key"]=5
}

local eyes_cd=0

local cry_part=script.CryingSound
local next_cry=math.floor(tick())+math.random(21,46)--+21

local next_spawn=math.floor(tick())+math.random(65,181)

local secret_room=-math.random(5,45)

function calcCellDisplacement(num: number): {Vector3}
	local r
	
	if displacements[math.abs(num)] then
		r=displacements[math.abs(num)]
	else
		local displacement_index=0
		for i,v in displacements do
			if math.abs(num)>i and i>displacement_index then
				displacement_index=i

				--print("cell:",math.abs(num),"cell_d_i:",i,"d_i:",displacement_index)
			end
		end
		r=displacements[displacement_index]
	end
	
	return r
end

function populateCell(num: number)
	local f_start_time=tick() --debugging
	
	local tiles=game.ServerStorage.Tiles:GetChildren()
	local rand=Random.new(seed+num)

	local tile
	local passed_overlap_test=false
	local failed_once=false
	local attempts=25
	repeat
		attempts-=1
		
		tile=tiles[rand:NextInteger(1,#tiles)]:Clone()
		--[[if num==secret_room then
			tile=game.ServerStorage.SpecialTiles.Piano:Clone()
		elseif num==-49 then --trust
			tile=game.ServerStorage.SpecialTiles.Elevator:Clone()
		end]]
		tile.Parent=workspace.Map.Cells
		tile.Name=tostring(num)
		
		--calc displacement and place tile
		local displacement=calcCellDisplacement(num)
		
		tile:PivotTo(CFrame.new(displacement[1].X,displacement[1].Y+num*18,displacement[1].Z)*CFrame.Angles(0,math.rad(displacement[2].Y),0))
		
		if tile:FindFirstChild("Overlap") then
			local c_overlaps={}
			for i,v in pairs(tile:GetChildren()) do
				if v.Name=="Overlap" then table.insert(c_overlaps,v) end
			end
			local overlaps=game.ServerStorage.Overlaps:GetChildren()
			local params=OverlapParams.new()
			params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances={}
			params.MaxParts=5 --ig
			params.RespectCanCollide=false
			
			for i,v in pairs(overlaps) do
				v.Parent=workspace
				params:AddToFilter(v)
			end

			local collisions={}
			for i,v in pairs(c_overlaps) do
				local results=workspace:GetPartsInPart(v,params)
				for a,b in pairs(results) do
					table.insert(collisions,b)
				end
			end
			
			for i,v in pairs(overlaps) do
				v.Parent=game.ServerStorage.Overlaps
			end
			
			if #collisions>0 then
				warn("OVERLAP "..tostring(num))
				--[[for i,v in pairs(collisions) do
					v.Name="OVERLAP"..tostring(num)
					v.Parent=workspace
					v.Transparency=.65
				end
				local v=tile.Overlap
				v.Name="OVERLAP"
				v.Parent=workspace
				v.Transparency=.65]]
				tile:Destroy()
				
				failed_once=true
				
				continue
			end
			
			for i,v in pairs(c_overlaps) do
				v.Name=tostring(num)
				v.Parent=game.ServerStorage.Overlaps
			end
		end
		
		table.insert(active_cells,{num,tile})
		
		passed_overlap_test=true
	until passed_overlap_test or attempts<=0
	if failed_once then
		tile.Modified.Value=true --ugh (prevents cell from potentially being diff when loaded again)
	end
	if attempts<=0 then
		warn("oh crap --> room population failed")
		return
	end
	
	--floor signs
	for i,v in pairs(tile:GetChildren()) do
		if string.sub(v.Name,1,8)=="FloorNum" then
			if num~=-49 then
				--decide if sign will be spawned or not
				--local modulus=2
				--[[if rand:NextInteger(1,100)<52 then--%modulus~=0 then
					v:Destroy()
					continue
				end]]
			end
			
			local n=tonumber(string.sub(v.Name,9))
			v.Gui.Num.Text="L"..tostring(2*num-(n-1))
		end
	end
	
	--check if tile displaces column
	if tile:FindFirstChild("Displacement") then
		if not displacements[math.abs(num)] then
			--print(num,",",num*18,",",tile.Displacement.Position.Y,",",tile.Displacement.Position.Y-num*18)
			
			displacements[math.abs(num)]={
				Vector3.new(tile.Displacement.Position.X,tile.Displacement.Position.Y-num*18,tile.Displacement.Position.Z),
				tile.Displacement.Orientation
			}
		end
		
		tile.Modified.Value=true --need? (yes for now)
		tile.Modified.LastModifiedBy.Value="Displacement"
	end
	
	--choose variation
	if tile:FindFirstChild("VARS") then
		local vars=tile.VARS:GetChildren()
		local var=vars[rand:NextInteger(1,#vars)]--vars[math.random(1,#vars)]
		
		for i,v in pairs(var:GetChildren()) do
			if v:IsA("Folder") and tile:FindFirstChild(v.Name) then
				for a,b in pairs(v:GetChildren()) do
					b.Parent=tile[v.Name]
				end
				continue
			end
			
			v.Parent=tile
		end

		tile.VARS:Destroy()
	end
	
	local random_cats={}
	for i,v in pairs(tile:GetDescendants()) do
		--special randoms
		if v:FindFirstChild("_Random") then
			if not random_cats[v._Random.Value] then random_cats[v._Random.Value]={} end

			table.insert(random_cats[v._Random.Value],v)
		end
		
		--update door and vent hinge and drawer and electrical box original vals
		if v.Name=="Original" and v:IsA("CFrameValue") then
			if v.Parent:IsA("Model") then
				v.Value=v.Parent:GetPivot()
			else
				v.Value=v.Parent.CFrame
			end
		end
	end
	
	--(special) random items
	for i,v in pairs(random_cats) do
		local chosen=v[math.random(1,#v)]

		for a,b in pairs(v) do
			if b~=chosen then
				b:Destroy()
				v[a]=nil
			end
		end

		random_cats[i]=nil
	end
	
	--spawn lights
	if tile:FindFirstChild("Lights") then
		for i,v in pairs(tile.Lights:GetChildren()) do
			if rand:NextInteger(1,100)<=30 then --70% chance to spawn
				--dont spawn --> delete
				v:Destroy()
			else
				--decide whether to give it buzzing sound or not
				local chance=30
				rand=Random.new((seed+num)/i-1) --hmm

				if rand:NextInteger(1,100)>=chance then
					if v.Light:FindFirstChild("Buzzing") then
						v.Light.Buzzing:Destroy()
					end
				end
			end
		end
	end
	
	--spawn items
	if tile:FindFirstChild("Items") then
		local item_p=35--60
		for _,v in pairs(tile.Items:GetChildren()) do
			if rand:NextInteger(1,100)<=item_p then --spawn an item
				local item
				
				if not v:FindFirstChild("Plank") then
					item=script.Items[funcs.random_weighted(items,rand)]:Clone()
				else
					item=script.Items.Plank:Clone()
				end
				
				item.Parent=v:FindFirstChild("Drawer") and v.Drawer.Value or v.Parent
				local pos=v.CFrame*CFrame.new(item.OFFSET.Value)
				if not v:FindFirstChild("Plank") then
					pos=pos
						*CFrame.new(
							funcs.random_real(-.5*v.Size.X+.25,.5*v.Size.X-.25,100,rand),
							0,
							funcs.random_real(-.5*v.Size.Z+.25,.5*v.Size.Z-.25,100,rand))
						*CFrame.Angles(0,funcs.random_real(-180,180,100,rand),0)
				end
				item:PivotTo(pos)
				item.OFFSET:Destroy()
				
				item_p*=.7
			end
			
			v:Destroy()
		end
	end
	
	--spawn eyes
	if tile:FindFirstChild("Eyes") then --no need for using rand var
		if eyes_cd>0 then eyes_cd-=1 end
		if math.random(100)<=45 and eyes_cd<=0 then
			--[[for i,v in pairs(tile.Eyes:GetChildren()) do
				if light_detect:GetLightLevelAtPoint(v.Position,false,true)>.25 then
					v:Destroy()
				end
			end]]
			
			if #tile.Eyes:GetChildren()>0 then
				local spawns=tile.Eyes:GetChildren()
				local cf
				local success
				
				repeat
					local i=math.random(1,#spawns)
					local chosen_spawn=spawns[i]
					
					local attempts=20
					repeat
						cf=chosen_spawn.CFrame
							*CFrame.new(
								funcs.random_real(-.5*chosen_spawn.Size.X+1,.5*chosen_spawn.Size.X-1),
								funcs.random_real(0,.5*chosen_spawn.Size.Y-1),
								funcs.random_real(-.5*chosen_spawn.Size.Z+1,.5*chosen_spawn.Size.Z-1)
							)
						attempts-=1
					until light_detect:GetLightLevelAtPoint(cf.Position,false,true)<=.15 or attempts<=0
					if attempts<=0 then
						table.remove(spawns,i)
						if #spawns==0 then
							break
						end
					else
						success=true
						--break
					end
				until success
				
				if success then
					local monster=script.Monsters.Eyes:Clone()
					monster.CFrame=cf
					monster.Name="M_Eyes"
					monster.Parent=tile
					monster.Behavior.Enabled=true
					
					eyes_cd=2
				end
			end
		end
		
		tile.Eyes:Destroy()
	end
	
	--spawn monster2 (counts as a modification)
	--[[for i,v in pairs(tile:GetChildren()) do
		if v.Name=="_MSpawn" then
			local modulus=11
			
			if math.random(1,100)%modulus==0 then
				--spawn
				tile.Modified.Value=true --dont reload tile --> prevents monster from spawning in this tile again
				tile.Modified.LastModifiedBy.Value="Monster2"
				
				local monster=script.Monsters.Monster2:Clone()
				monster:PivotTo(v.CFrame)
				monster.Parent=tile
				monster.Behavior.Enabled=true
				
				local connection
				connection=monster.Destroying:Connect(function()
					connection:Disconnect()
					
					if tile.Modified.LastModifiedBy.Value=="Monster2" then
						tile.Modified.Value=false
					end
				end)
				
				game.ReplicatedStorage.Remote.MonsterSpawn:FireAllClients(2,monster)
				
				break --> one monster spawn per tile
			end
		end
	end]]
	
	--piano logic (make piano room rare secret room?)
	if tile:FindFirstChild("Piano") then
		local connection
		connection=tile.Piano.Hitbox.Touched:Connect(function(p)
			if game.Players:GetPlayerFromCharacter(p.Parent) then
				tile.Piano.Music:Play()

				tile.Modified.Value=true
				tile.Modified.LastModifiedBy.Value="Piano"

				connection:Disconnect()
			end
		end)
	end
	
	--floor 100 (elevator) custom population
	--[[if num==-49 then
		local has_code=false --determines whether inputting correct code will do anything
		
		--generate switch code
		local n_rand=Random.new()
		
		--order: white,yellow,green,black,red,blue
		local code=tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))
		local switch_start
		
		repeat
			switch_start=tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))..tostring(n_rand:NextInteger(0,1))
		until code~=switch_start
		print(code)
		print(switch_start)
		
		for i=1,string.len(switch_start) do
			tile._ElectricalBox.Switches[tostring(i)].State.Value=string.sub(switch_start,i,i)=="1" and true or false
			tile._ElectricalBox.Switches[tostring(i)]._Switch.CFrame*=CFrame.new(-.25*(1-tonumber(string.sub(switch_start,i,i))),0,0)
		end
		
		local connections={}
		for i,v in pairs(tile._ElectricalBox.Switches:GetChildren()) do
			table.insert(connections,v.State:GetPropertyChangedSignal("Value"):Connect(function()
				if not has_code then return end
				
				local c_code=""
				for a=1,#tile._ElectricalBox.Switches:GetChildren() do
					c_code..=(tile._ElectricalBox.Switches[tostring(a)].State.Value==true and "1" or "0")
				end
				print(c_code)
				print(code)
				if c_code==code then
					tile._ElectricalBox.Activated.Value=true
					tile._ElectricalBox.PowerOn:Play()
					tile._Computer.Activated.Value=false
					
					for a,b in pairs(connections) do
						b:Disconnect()
					end
					connections=nil
				end
			end))
		end
		
		--make code paper display correct code
		local paper
		for i,v in pairs(tile:GetDescendants()) do
			if v.Name=="Code_Paper" then
				paper=v
				break
			end
		end
		
		for i=1,string.len(code) do
			if string.sub(code,i,i)=="1" then
				paper.SurfaceGui[tostring(i)].Image="http://www.roblox.com/asset/?id=17060778559"
				paper.SurfaceGui[tostring(i)].ImageRectOffset=Vector2.new(250*n_rand:NextInteger(0,1),0)
			else
				paper.SurfaceGui[tostring(i)].Image="http://www.roblox.com/asset/?id=17060782190"
				paper.SurfaceGui[tostring(i)].ImageRectOffset=Vector2.new(250*n_rand:NextInteger(0,1),0)
			end
		end
		
		paper.ClickDetector.MouseClick:Connect(function()
			has_code=true
		end)
		
		tile.Modified.Value=true --i mean, its inevitable
	end]]
	
	local f_end_time=tick()
	print("DEBUG --> populateCell execute time: "..tostring(math.floor((f_end_time-f_start_time)*100000)/100).."ms")
end

rs.Heartbeat:Connect(function()
	--[[cry_part.CFrame=char.HumanoidRootPart.CFrame*CFrame.new(0,-100,0)
	cry_part.Parent=workspace
	
	if math.floor(tick())==next_cry then
		print("cry")
		
		cry_part.Sound:Play()
		next_cry+=math.random(29,144)
	end]] 
	
	--[[if math.floor(tick())==next_spawn then --make monster be able to spawn below and run up also?
		print("spawning monster")
		
		if #plrs>0 then
			local chosen_plr=plrs[math.random(1,#plrs)]
			
			local plr_cell=math.ceil(chosen_plr.Character.HumanoidRootPart.CFrame.Y/18)
			local spawn_cell=math.clamp(plr_cell+4,-math.huge,max_cell_height+1)
			local dest_cell=plr_cell-4 --no need for clamp right?
			
			--print("plr:",plr_cell,"spawn:",spawn_cell,"dest:",dest_cell)
			
			local monster=script.Monsters.Monster1:Clone()
			monster:PivotTo(CFrame.new(spawn_cell~=0 and workspace.Map.Cells[tostring(spawn_cell)].Pathfinding["1"].Position or workspace.Map.StartingArea.Pathfinding["1"].Position))
			monster.Parent=workspace
			monster.Behavior.Start.Value=spawn_cell
			monster.Behavior.End.Value=dest_cell
			monster.Behavior.Enabled=true
			monster.HumanoidRootPart.Run:Play()
			monster.HumanoidRootPart.Aura:Play()
			
			game.ReplicatedStorage.Remote.MonsterSpawn:FireAllClients(1,monster)
		end
		
		next_spawn+=math.random(62,181) --experiment w/ these vals later
	end]]
	
	--chunk loading and unloading
	for i,v in pairs(active_cells) do
		local in_range=false
		
		for a,b in pairs(plrs) do
			if not b.Character then continue end
			
			local plr_cell=math.clamp(math.ceil(b.Character.HumanoidRootPart.CFrame.Y/18),-math.huge,max_cell_height)
			
			if math.abs(v[1]-plr_cell)<=max_cell_dist then
				in_range=true
				
				break
			end
		end
		
		if in_range==false and v[2].Modified.Value==false then
			for a,b in pairs(game.ServerStorage.Overlaps:GetChildren()) do
				if b.Name==v[2].Name then
					b:Destroy()
				end
			end
			
			v[2]:Destroy()
			
			table.remove(active_cells,i)
		end
	end
	
	for _,v in pairs(plrs) do
		if not v.Character then continue end
		
		local plr_cell=math.clamp(math.ceil(v.Character.HumanoidRootPart.CFrame.Y/18),-math.huge,max_cell_height)
		
		for i=max_cell_dist,-max_cell_dist,-1 do
			local cell_num=plr_cell+i
			local is_cell_filled=false
			
			for a,b in pairs(active_cells) do
				if b[1]==cell_num then
					is_cell_filled=true
					
					break
				end
			end
			
			if is_cell_filled==false and cell_num<=max_cell_height then
				populateCell(cell_num)
			end
		end
	end
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

game.ReplicatedStorage.Remote.Loaded.OnServerEvent:Connect(function(plr)
	--[[if not table.find(plrs,plr) and not table.find(plrs_dead,plr) then
		table.insert(plrs,plr)
		plr_stats[plr.Name]={
			["Depth"]=0
		}
		
		plr.Character.HumanoidRootPart.CFrame=workspace.Map.StartingArea.Spawn.CFrame*CFrame.new(0,3.4,0)
	end]]
end)

script.KillPlayer.Event:Connect(function(plr)
	--game.ReplicatedStorage.Remote.Killed:FireClient(plr,math.abs(math.ceil(plr.Character.HumanoidRootPart.CFrame.Y/9)))
	
	plr.Character.Humanoid.Health=0
end)

script.ReqPlrs.OnInvoke=function()
	return plrs
end

game.ReplicatedStorage.Remote.Respawn.OnServerInvoke=function(plr)
	--change this up probably
	
	if #plrs>0 then
		local chosen_plr=plrs[math.random(1,#plrs)]
		--local plr_cell=math.clamp(math.ceil(chosen_plr.Character.HumanoidRootPart.CFrame.Y/18),-math.huge,max_cell_height+1)
		
		--print(plr_cell," | ",workspace.Map.StartingArea.Spawn.CFrame*CFrame.new(0,3.4+(-18*plr_cell),0))
		
		--plr.Character.HumanoidRootPart.CFrame=workspace.Map.StartingArea.Spawn.CFrame*CFrame.new(0,4+(-18*plr_cell),0)
		plr.Character.HumanoidRootPart.CFrame=chosen_plr.Character.HumanoidRootPart.CFrame
	else
		plr.Character.HumanoidRootPart.CFrame=workspace.Map.StartingArea.Spawn.CFrame*CFrame.new(0,3.4,0) --should work fine
	end
	
	local i=table.find(plrs_dead,plr)
	table.remove(plrs_dead,i)
	table.insert(plrs,plr)
	
	plr.Dead.Value=false
	
	return true
end

game.ReplicatedStorage.Remote.ComputerInteract.OnServerEvent:Connect(function(plr,comp,success)
	if comp.Activated.Value==true then return end

	if success then
		comp.Activated.Value=true
		comp.Parent.Modified.Value=true

		if comp:FindFirstChild("Event") then
			comp.Event.Enabled=true
		end
	else
		--play a loud sound and attract monster
		comp.ClickDetector.MaxActivationDistance=0
		comp.Screen.Color=Color3.fromRGB(255,0,0)
		comp.Alarm:Play()

		--attract monster
		print("spawning monster (comp)")

		local cell=tonumber(comp.Parent.Name)
		local spawn_cell=math.clamp(cell+4,-math.huge,max_cell_height+1)

		local monster=script.Monsters.Monster1:Clone()
		monster:PivotTo(CFrame.new(spawn_cell~=0 and workspace.Map.Cells[tostring(spawn_cell)].Pathfinding["1"].Position or workspace.Map.StartingArea.Pathfinding["1"].Position))
		monster.Parent=workspace
		monster.Behavior.Start.Value=spawn_cell
		monster.Behavior.End.Value=cell
		monster.Behavior.Computer.Value=true
		monster.Behavior.Enabled=true
		monster.HumanoidRootPart.Run:Play()
		monster.HumanoidRootPart.Aura:Play()

		game.ReplicatedStorage.Remote.MonsterSpawn:FireAllClients(1,monster)

		next_spawn+=math.random(62,181) --experiment w/ these vals later

		--[[task.wait(12) --maybe?

		comp.ClickDetector.MaxActivationDistance=7.5
		comp.Screen.Color=Color3.fromRGB(0,0,0)
		comp.Alarm:Stop()]]
	end
end)

game.ReplicatedStorage.Remote.ReturnToLobby.OnServerEvent:Connect(function(plr)
	local i1=table.find(plrs,plr)
	local i2=table.find(plrs_dead,plr)
	
	if i1 then
		table.remove(plrs,i1)
	end
	if i2 then
		table.remove(plrs_dead,i2)
	end
	
	pcall(function()
		game:GetService("TeleportService"):TeleportAsync(15987463030,{plr})
	end)
end)

game.ReplicatedStorage.Remote.ReqStats.OnServerInvoke=function(plr)
	return plr_stats
end

game.ReplicatedStorage.Remote.UpdStats.OnServerEvent:Connect(function(plr,battery,sanity)
	plr.Battery.Value=battery
	plr.Sanity.Value=sanity
end)

--game.Lighting.Ambient=Color3.fromRGB(72,72,72)
--game.Lighting.FogEnd=40