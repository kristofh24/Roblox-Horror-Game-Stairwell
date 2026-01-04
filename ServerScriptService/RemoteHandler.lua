-- @ScriptType: Script
local ts=game:GetService("TweenService")

local plr_flashlight_data={}

game.ReplicatedStorage.Remote.DoorInteract.OnServerEvent:Connect(function(plr,v)
	--v.Parent.Modified.Value=true
	--v.Parent.Modified.LastModifiedBy.Value="Door"
	
	v.Opened.Value=not v.Opened.Value
	v.Door.ClickDetector.MaxActivationDistance=0
	
	local spd=.8
	local dir=Enum.EasingDirection.InOut
	local goal={}
	if v.Opened.Value then
		--open
		dir=Enum.EasingDirection.Out

		local primary_pos=plr.Character.HumanoidRootPart.CFrame.Position
		if v:FindFirstChild("BlockadePlank") then
			primary_pos=v.BlockadePlank.BlockadePlank.CFrame.Position
		end
		local door_pos=v.Door.CFrame.Position

		if (door_pos-primary_pos).Unit:Dot(v.Door.CFrame.LookVector)>0 then
			--in front
			goal.CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(-90),0)
		else
			--in back
			goal.CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(90),0)
		end

		v.Door.Open:Play()
	else
		--close
		--dir=Enum.EasingDirection.In
		goal.CFrame=v.Hinge.Original.Value

		v.Door.Close:Play()
	end

	ts:Create(v.Hinge,TweenInfo.new(spd,Enum.EasingStyle.Quart,dir),goal):Play()

	task.wait(spd)

	v.Door.ClickDetector.MaxActivationDistance=7.5
end)

game.ReplicatedStorage.Remote.VentInteract.OnServerEvent:Connect(function(plr,v)
	v.Parent.Modified.Value=true
	v.Parent.Modified.LastModifiedBy.Value="Vent"

	v.Opened.Value=not v.Opened.Value
	v.ClickDetector.MaxActivationDistance=0
	v.CanCollide=false

	local spd=.8
	local dir=Enum.EasingDirection.InOut
	local goal={}
	if v.Opened.Value then
		--open
		dir=Enum.EasingDirection.Out

		local plr_pos=plr.Character.HumanoidRootPart.CFrame.Position
		local vent_pos=v.CFrame.Position

		if (vent_pos-plr_pos).Unit:Dot(v.CFrame.RightVector)>0 then --using right vector because vents look vector is not good
			--in front
			goal.CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(78),0)
		else
			--in back
			goal.CFrame=v.Hinge.Original.Value*CFrame.Angles(0,math.rad(-78),0)
		end

		v.Open:Play()
	else
		--close
		spd=.42
		dir=Enum.EasingDirection.In
		goal.CFrame=v.Hinge.Original.Value

		v.Close:Play()
	end

	ts:Create(v.Hinge,TweenInfo.new(spd,Enum.EasingStyle.Quart,dir),goal):Play()
	
	task.wait(spd)

	v.ClickDetector.MaxActivationDistance=7.5
	
	if not v.Opened.Value then
		v.CanCollide=true
	end
end)

game.ReplicatedStorage.Remote.ElectricalDoorInteract.OnServerEvent:Connect(function(plr,v)
	--* v is model
	--[[v.Parent.Modified.Value=true
	v.Parent.Modified.LastModifiedBy.Value="ElectricalBox"]]

	v.Door.Opened.Value=not v.Door.Opened.Value
	v.Door.ClickDetector.MaxActivationDistance=0
	v.Door.Door.CanCollide=false
	v.Door.Handle.CanCollide=false

	local spd=.8
	local dir=Enum.EasingDirection.InOut
	local style=Enum.EasingStyle.Quart
	local goal={}
	if v.Door.Opened.Value then
		--open
		dir=Enum.EasingDirection.Out
		goal.CFrame=v.Hinge.Original.Value*CFrame.Angles(math.rad(110),0,0)

		v.Door.Open:Play()
	else
		--close
		spd=.42
		dir=Enum.EasingDirection.In
		style=Enum.EasingStyle.Quad
		goal.CFrame=v.Hinge.Original.Value

		v.Door.Close:Play()
	end

	ts:Create(v.Hinge,TweenInfo.new(spd,style,dir),goal):Play()

	task.wait(spd)

	v.Door.ClickDetector.MaxActivationDistance=7.5
	v.Door.Door.CanCollide=true
	v.Door.Handle.CanCollide=true
end)

game.ReplicatedStorage.Remote.ElectricalSwitchInteract.OnServerEvent:Connect(function(plr,v)
	v.State.Value=not v.State.Value
	v.ClickDetector.MaxActivationDistance=0

	local spd=.08
	local dir=Enum.EasingDirection.InOut
	local style=Enum.EasingStyle.Circular
	local goal={}
	if v.State.Value then
		--to right
		goal.CFrame=v._Switch.CFrame*CFrame.new(.25,0,0)
	else
		--to left
		goal.CFrame=v._Switch.CFrame*CFrame.new(-.25,0,0)
	end
	
	v.Frame.Switch:Play()

	ts:Create(v._Switch,TweenInfo.new(spd,style,dir),goal):Play()

	task.wait(spd)

	v.ClickDetector.MaxActivationDistance=7.5
end)

game.ReplicatedStorage.Remote.PlacePlank.OnServerEvent:Connect(function(plr,spot)
	spot.Plank.Transparency=0
	spot.Plank.CanCollide=true
	spot.Plank.Place:Play()
	
	spot.ClickDetector:Destroy()
	spot.HighlightBugFixer:Destroy()
	
	spot.Parent.Modified.Value=true
end)

game.ReplicatedStorage.Remote.BlockadeDoor.OnServerEvent:Connect(function(plr,door)
	local plank=script.BlockadePlank:Clone()
	plank.Parent=door
	
	if (door.Door.Position-plr.Character.HumanoidRootPart.Position).Unit:Dot(door.Door.CFrame.LookVector)>0 then
		--in front
		plank:PivotTo(door.Door.CFrame*CFrame.new(0,0,.419)*CFrame.Angles(math.rad(90),math.rad(math.random(-15,15)),0))
	else
		--in back
		plank:PivotTo(door.Door.CFrame*CFrame.new(0,0,-.419)*CFrame.Angles(math.rad(-90),math.rad(math.random(-15,15)),0))
	end
	
	plank.BlockadePlank.Place:Play()
end)

game.ReplicatedStorage.Remote.UnlockDoor.OnServerEvent:Connect(function(plr,lock)
	lock.Parent.Modified.Value=true
	
	lock.ClickDetector.MaxActivationDistance=0
	lock.Unlock:Play()
	task.wait(1.8)
	lock.Door.Value.IsLocked.Value=false
	lock.Anchored=false
end)

game.ReplicatedStorage.Remote.RemovePlank.OnServerEvent:Connect(function(plr,plank)
	local cell
	for i,v in pairs(workspace.Map.Cells:GetChildren()) do
		if plank:IsAncestorOf(v) then
			cell=v
			break
		end
	end
	if cell then
		cell.Modified.Value=true
		cell.Modified.LastModifiedBy.Value="Plank"
	end
	
	plank.ClickDetector:Destroy()
	plank.Break:Play()
	for i,v in pairs(plank:GetChildren()) do
		if v.Name=="Door" or v.Name=="Break" then continue end
		
		--if v.Name=="Nail" then
			--v:Destroy()
		--elseif v.Name=="BlockadePlank" then
			v.Anchored=false
		--end
	end
	plank.Door.Value.Planks.Value-=1
	if plank.Door.Value.Planks.Value<=0 then
		plank.Door.Value.Planks:Destroy()
	end
	plank.Door:Destroy()
	
	game:GetService("Debris"):AddItem(plank,10)
end)

game.ReplicatedStorage.Remote.DrawerInteract.OnServerEvent:Connect(function(plr,v)
	local cell
	for a,b in pairs(workspace.Map.Cells:GetChildren()) do
		if v:IsAncestorOf(b) then
			cell=b
			break
		end
	end
	if cell then
		cell.Modified.Value=true
		cell.Modified.LastModifiedBy.Value="Drawer"
	end
	
	v.Opened.Value=not v.Opened.Value
	v.ClickDetector.MaxActivationDistance=0
	if v.Opened.Value then v.Open:Play() else v.Close:Play() end
	
	--hate this god awful chunk of code
	local cf_val=Instance.new("CFrameValue")
	cf_val.Value=v:GetPivot()
	local tween=ts:Create(
		cf_val,
		TweenInfo.new(.33,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),
		{Value=v.Opened.Value==true and v.Original.Value*CFrame.new(0,0,-1.35) or v.Original.Value}
	)
	tween:Play()
	repeat
		v:PivotTo(cf_val.Value)
		game:GetService("RunService").Heartbeat:Wait()
	until tween.PlaybackState==Enum.PlaybackState.Completed or tween.PlaybackState==Enum.PlaybackState.Cancelled

	v.ClickDetector.MaxActivationDistance=7.5
end)

game.ReplicatedStorage.Remote.TelephoneInteract.OnServerEvent:Connect(function(plr,v)
	v.ClickDetector.MaxActivationDistance=0
	
	v.Grab:Play()
	task.wait(.5)
	for i=1,math.random(3,5) do
		v.Ring:Play()
		task.wait(2)
	end
	
	if math.random(1,1000)<=10 then --1%
		--pickup
		v.Pickup:Play()
		task.wait(12.5)
	else
		v.Fail:Play()
		task.wait(8.5)
		v.Drop:Play()
		task.wait(.5)
	end
	
	v.ClickDetector.MaxActivationDistance=7.5
end)

game.ReplicatedStorage.Remote.BellInteract.OnServerEvent:Connect(function(plr,v)
	v.ClickDetector.MaxActivationDistance=0
	
	v.Ring:Play()
	task.wait(.5)
	
	v.ClickDetector.MaxActivationDistance=7.5
end)

game.ReplicatedStorage.Remote.UpdFlashlight.OnServerEvent:Connect(function(plr,state)
	if not plr_flashlight_data[plr.Name] then
		plr_flashlight_data[plr.Name]={state} -- {state,cf,light,ring1,ring2}
	end

	plr_flashlight_data[plr.Name][1]=state
	
	if not workspace.Flashlights:FindFirstChild(plr.Name) then
		local f=Instance.new("Folder")
		f.Name=plr.Name
		f.Parent=workspace.Flashlights
	end
	
	plr_flashlight_data[plr.Name][3].Parent=state==true and workspace.Flashlights[plr.Name] or script.Parent
	plr_flashlight_data[plr.Name][4].Parent=state==true and workspace.Flashlights[plr.Name] or script.Parent
	plr_flashlight_data[plr.Name][5].Parent=state==true and workspace.Flashlights[plr.Name] or script.Parent
end)

game.ReplicatedStorage.Remote.UpdCam.OnServerEvent:Connect(function(plr,cf)
	if not plr_flashlight_data[plr.Name] then
		plr_flashlight_data[plr.Name]={false,cf} -- {state,cf,light,ring1,ring2}
	end
	
	if not plr_flashlight_data[plr.Name][3] then
		plr_flashlight_data[plr.Name][3]=game.ReplicatedStorage.Flashlight.Flashlight:Clone()
		plr_flashlight_data[plr.Name][4]=game.ReplicatedStorage.Flashlight.RingM:Clone()
		plr_flashlight_data[plr.Name][5]=game.ReplicatedStorage.Flashlight.RingL:Clone()
	end
	
	if plr_flashlight_data[plr.Name][1] then
		plr_flashlight_data[plr.Name][2]=cf*CFrame.new(0,0,-1)
		
		if not workspace.Flashlights:FindFirstChild(plr.Name) then
			local f=Instance.new("Folder")
			f.Name=plr.Name
			f.Parent=workspace.Flashlights
		end
		
		plr_flashlight_data[plr.Name][3].Parent=workspace.Flashlights[plr.Name]
		plr_flashlight_data[plr.Name][4].Parent=workspace.Flashlights[plr.Name]
		plr_flashlight_data[plr.Name][5].Parent=workspace.Flashlights[plr.Name]
		
		ts:Create(
			plr_flashlight_data[plr.Name][3],
			TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
			{CFrame=cf*CFrame.new(0,0,-1)}
		):Play()
		
		ts:Create(
			plr_flashlight_data[plr.Name][4],
			TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
			{CFrame=cf*CFrame.new(0,0,-1)*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)}
		):Play()
		
		ts:Create(
			plr_flashlight_data[plr.Name][5],
			TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
			{CFrame=cf*CFrame.new(0,0,-1)*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)}
		):Play()
	elseif not plr_flashlight_data[plr.Name][1] and plr_flashlight_data[plr.Name][3].Parent==workspace then
		plr_flashlight_data[plr.Name][3].Parent=script.Parent
		plr_flashlight_data[plr.Name][4].Parent=script.Parent
		plr_flashlight_data[plr.Name][5].Parent=script.Parent
	end
end)

game.ReplicatedStorage.Remote.DestroyItem.OnServerEvent:Connect(function(plr,item) --idk about this; potential security risks
	if item:FindFirstChild("_Pickup") then --only destroy valid items
		print("item valid --> destroying")
		
		item:Destroy()
		
		for i,v in pairs(workspace.Map.Cells:GetChildren()) do
			if item:IsDescendantOf(v) then
				v.Modified.Value=true
				v.Parent.Modified.LastModifiedBy.Value="Item"
				
				break
			end
		end
	end
end)

game.ReplicatedStorage.Remote.Locker.OnServerEvent:Connect(function(plr,entering,locker)
	if entering then
		locker.ClickDetector.MaxActivationDistance=0
	else
		locker.ClickDetector.MaxActivationDistance=5
	end
end)

script.ReqFlashlightState.OnInvoke=function(plr_name)
	if not plr_flashlight_data[plr_name] then
		return false
	end
	
	return plr_flashlight_data[plr_name][1]
end