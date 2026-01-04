-- @ScriptType: ModuleScript
-- Client Framework
-- Handles everything client related, such as sprinting, flashlight, camera effects, post-processing, object interactions, and much more.

local Framework={}
Framework.__index=Framework

local funcs=require(game.ReplicatedStorage.Functions)
local light_detect=require(game.ReplicatedStorage.LightDetection)

function nearest_pos(p: Vector3,tbl: {[number]: Part}): Vector3
	local closest_p=Vector3.one*math.huge
	local closest_dist=math.huge
	
	for i,v in pairs(tbl) do
		if (p-v.Position).Magnitude<closest_dist then
			closest_p=v.Position
			closest_dist=(p-v.Position).Magnitude
		end
	end
	
	return closest_p
end

function get_key_down(key: Enum.KeyCode): boolean
	for i,v in pairs(game:GetService("UserInputService"):GetKeysPressed()) do
		if v.KeyCode==key then
			return true
		end
	end
	
	return false
end

function Framework.new()
	local self=setmetatable({},Framework)
	
	--game vars
	local COMPUTERS_LEFT=10 --not default value
	
	--local vars
	local tilt=0
	local tilt_move=0
	local tilt_peek=0
	
	local offset_x=0
	local offset_x_goal=0
	
	local bob_x=0
	local bob_y=0
	local bob_y_min=0
	local bob_x_angle=0
	local bob_y_angle=0
	
	local walk_spd=7
	local walk_spd_default=7
	local sprint_spd=12
	local crouch_spd=4
	
	local cam_fov=70--65
	local cam_fov_default=70--65
	local cam_offset=Vector3.new(0,.65,0)
	local cam_type="Custom"
	local cam_prev_shake=CFrame.new()
	local cam_target=nil
	local cam_calc_mods=true
	local cam_cf_no_transform=CFrame.new()
	local cam_prev_cf_no_transform=CFrame.new()
	
	local ms_pos_old=Vector2.new()
	
	local body_light=script.BodyLight
	local dust_part=script.DustPart
	
	local adrenaline_state=false
	local modal_state=false
	local inventory_state=false
	
	local cam_freeze=false
	
	local computer_obj=nil
	
	local examine_obj=nil
	local examine_origin=Vector2.new()
	
	local next_swell=math.floor(tick())+math.random(19,182)
	local next_amb9=math.floor(tick())+math.random(60,192)
	
	local next_ghost1=-1
	local next_ghost2=-1
	local next_ghost3=-1
	
	local ghost_snds={
		{9126214611,.5},{9126213993,.5},{9114572814,3}, --ghost 1 (whisper)
		{9126213993,.5},{9126213741,.5},
		--{9114571160,1.5},
		{9114038256,.5},{9114038441,.5}, --ghost 2 (scream)
		{9114569704,.65},{9114567790,.65},{9114569769,.65} --ghost 3 (woman scream)
	}
	
	local fast_sanity_regain=false
	
	local sink_input=false
	
	local frame_count=0
	
	local monster_active=false
	--vars
	self.game_state="intro" --can be: intro,alive,dead,spectating
	
	self.crouch_offset_y=0
	self.crouch_offset_y_goal=0
	
	self.in_locker=false
	self.in_locker_ptr=nil
	
	self.flashlight_light=game.ReplicatedStorage.Flashlight.Flashlight:Clone()
	self.flashlight_ring_l=game.ReplicatedStorage.Flashlight.RingL:Clone()
	self.flashlight_ring_m=game.ReplicatedStorage.Flashlight.RingM:Clone()
	self.flashlight_state=false
	self.flashlight_power=50 --dont start at 100
	self.flashlight_bypass_check=false
	
	self.sanity=100
	
	self.light_level_cache=1
	
	self.sprint_state=false
	self.sprint_charge=100
	self.sprint_cooldown=false
	self.crouch_state=false
	self.crouch_anim=nil
	
	self.dead=false
	
	self.item_highlight=script.ItemHighlight
	
	self.plr=game.Players.LocalPlayer
	self.cam=workspace.CurrentCamera
	self.ms=self.plr:GetMouse()
	
	self:UpdateCharVariables()
	self.cam.CameraSubject=self.hum
	
	self.cas=game:GetService("ContextActionService")
	self.uis=game:GetService("UserInputService")
	self.ts=game:GetService("TweenService")
	self.rs=game:GetService("RunService")
	
	self.gui=self.plr:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	
	self.inventory={"None","None","None","None"}
	
	self.alert=require(script.Alerts)
	self.alert.container=self.gui.Alerts
	
	--local functions
	local function sink_movement()
		self.cas:BindActionAtPriority("Sink_Movement",
			function()
				return Enum.ContextActionResult.Sink
			end,false,Enum.ContextActionPriority.High.Value,
			Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward
		)
	end
	
	local function unsink_movement()
		self.cas:UnbindAction("Sink_Movement")
	end
	
	local function set_freeze(state: boolean)
		cam_freeze=state
		cam_type=state and "Scriptable" or "Custom"
		cam_calc_mods=not state
		--[[if state then
			cam_freeze=true
			cam_type="Scriptable"
			cam_calc_mods=false
		else
			cam_freeze=false
			cam_type="Custom"
			cam_calc_mods=true
		end]]
	end
	
	local function use_item(slot)
		print("using item from slot"..tostring(slot))
		print(self.inventory[slot])

		if self.inventory[slot]=="Adrenaline" then
			if adrenaline_state==false then
				self.inventory[slot]="None"
				self.gui.Inventory["Slot"..tostring(slot)].Icon:ClearAllChildren()
				
				funcs.play_sound(1371567007,1)
				
				adrenaline_state=true
				walk_spd=walk_spd_default*2.5
				
				script.Heartbeat.Volume=.75
				script.Heartbeat.PlaybackSpeed=1.5
				script.Heartbeat.PitchShiftSoundEffect.Octave=.75
				script.Heartbeat:Play()
				
				local connection=self.rs.RenderStepped:Connect(function()
					cam_fov=funcs.lerp(cam_fov,cam_fov_default+15,.1)
					self.gui.ColorOverlay.ImageTransparency=funcs.lerp(self.gui.ColorOverlay.ImageTransparency,.65,.1)
					
					local mult=math.clamp(script.Heartbeat.PlaybackLoudness/1000,0,1)
					self.gui.ColorOverlay.Size=UDim2.fromScale(1.4-(.4*mult),1.4-(.4*mult))
				end)
				
				if self.hum.Health>=100 then
					self.gui.Stats.Effect.Position=UDim2.fromScale(.975,.715)
				else
					self.gui.Stats.Effect.Position=UDim2.fromScale(.975,.615)
				end
				self.gui.Stats.Effect.Visible=true
				local counter=0
				local counter_goal=100
				local t=.1
				while counter<counter_goal do
					counter+=1
					
					--self.gui.Stats.Effect.BarHolder.Bar.Size=UDim2.fromScale(1-counter/100,1)
					self.gui.Stats.Effect.Title.Text=tostring(math.floor((counter_goal-counter)*t*10)/10).."s"
					task.wait(t)
				end
				self.gui.Stats.Effect.Visible=false
				
				connection:Disconnect()
				script.Heartbeat:Stop()

				adrenaline_state=false
				walk_spd=walk_spd_default

				for i=0,100 do
					self.gui.ColorOverlay.ImageTransparency=funcs.lerp(self.gui.ColorOverlay.ImageTransparency,1,.1)
					cam_fov=funcs.lerp(cam_fov,cam_fov_default,.1)
					self.rs.RenderStepped:Wait()
				end
			else
				self.alert:QueueAlert("Not now.")
			end
		end
	end
	
	local function examinable_event(v)
		local old_cf=v.CFrame
		
		modal_state=true
		
		set_freeze(true)
		sink_movement()
		
		examine_obj=v
		
		self.ts:Create(
			v,
			TweenInfo.new(.35,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
			{CFrame=CFrame.lookAt((self.cam.CFrame*CFrame.new(0,0,-2.5)).Position,self.cam.CFrame.Position)}):Play()
		
		if v:FindFirstChild("PickupSnds") then
			local snds=v.PickupSnds:GetChildren()
			
			snds[math.random(1,#snds)]:Play()
		end
		
		repeat
			task.wait()
		until modal_state==false
		
		examine_obj=nil
		
		set_freeze(false)
		unsink_movement()
		self.ts:Create(
			v,
			TweenInfo.new(.35,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
			{CFrame=old_cf}):Play()
	end
	
	local function computer_event(v)
		print("viewing computer")

		set_freeze(true)

		local old_cam_cf=self.cam.CFrame
		self.ts:Create(
			self.cam,
			TweenInfo.new(.35,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
			{CFrame=CFrame.lookAt((v.Screen.CFrame*CFrame.new(0,0,-1.5)).Position,v.Position)}):Play()

		sink_movement()

		self.gui.Modal.Visible=true
		modal_state=true

		local screen=script.Screen:Clone()
		screen.Parent=v.Screen
		local comp=require(script.CompFunc).new(screen)
		comp:GenerateZone()

		funcs.play_sound(9119720940,1,nil,nil,"Real")

		repeat
			task.wait()
		until modal_state==false or comp.Finished==true

		game.ReplicatedStorage.Remote.ComputerInteract:FireServer(v,comp.Success)

		screen:Destroy()
		screen=nil

		comp:Destroy()
		comp=nil

		self.cam.CFrame=old_cam_cf

		set_freeze(false)
		
		self.gui.Modal.Visible=false

		unsink_movement()
	end
	
	local function electrical_box_event(v)
		print("viewing electrical box")
		
		v.ClickDetector.MaxActivationDistance=0
		
		v.Frame.Door.Door.CanCollide=false
		v.Frame.Door.Handle.CanCollide=false
		
		self.ts:Create(
			v.Frame.Hinge,
			TweenInfo.new(.8,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
			{CFrame=v.Frame.Hinge.Original.Value*CFrame.Angles(math.rad(110),0,0)}):Play()
		
		v.Open:Play()
		
		set_freeze(true)
		
		local old_cam_cf=self.cam.CFrame
		self.ts:Create(
			self.cam,
			TweenInfo.new(.35,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
			{CFrame=CFrame.lookAt((v.Frame.BackPanel.CFrame*CFrame.new(-2.5,0.3,0)).Position,v.Frame.BackPanel.Position)}):Play()

		sink_movement()

		modal_state=true
		--modal frame not needed for scriptable cam
		
		repeat
			self.gui.Cursor.BackgroundTransparency=.65
			task.wait()
		until modal_state==false or v.Activated.Value==true
		
		modal_state=false --in case other condition is met
		
		self.gui.Cursor.BackgroundTransparency=1
		
		v.Close:Play()
		
		self.ts:Create(
			v.Frame.Hinge,
			TweenInfo.new(.42,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
			{CFrame=v.Frame.Hinge.Original.Value}):Play()
		
		self.ts:Create(
			self.cam,
			TweenInfo.new(.35,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),
			{CFrame=old_cam_cf}):Play()
		
		task.wait(.35)
		
		set_freeze(false)

		unsink_movement()
		
		v.ClickDetector.MaxActivationDistance=7.5
	end
	
	local function bind_interactable_highlight(i_type,detector,par)
		if par==nil then par=detector.Parent end --i hate this
		
		local function on_event(state: number) --0 or 1
			if self.game_state~="alive" then return end
			
			self.ts:Create(
				self.gui.Cursor,
				TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
				{BackgroundTransparency=1-(.35*state)}
			):Play()
			
			self.item_highlight.Parent=(state==1 and par or script)
			self.item_highlight.Adornee=(state==1 and par or nil)
			--highlight.Enabled=(state==1 and true or false)
			
			if i_type=="Door" then
				local transparency=1
				
				if state==1 and par.Opened.Value==false and table.find(self.inventory,"Plank") and not par:FindFirstChild("BlockadePlank") then
					transparency=0
				end
				
				self.gui.Hint.Text="[Right Mouse Button] to blockade Door"
				self.ts:Create(
					self.gui.Hint,
					TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
					{TextTransparency=transparency}
				):Play()
			end
		end
		
		detector.MouseHoverEnter:Connect(function()
			on_event(1)
		end)
		detector.MouseHoverLeave:Connect(function()
			on_event(0)
		end)
		detector.Destroying:Connect(function()
			on_event(0)
		end)
	end
	
	local function bind_interactable(v: Instance)
		if string.sub(v.Name,1,5)=="_Door" and v:IsA("Model") then
			v.Door.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				if v.IsLocked.Value==true or v:FindFirstChild("Planks") or v:FindFirstChild("Blocked") then
					v.Door.LockedSnd:Play()
					v.Door.ClickDetector.MaxActivationDistance=0
					
					self.alert:QueueAlert("Locked.",nil,2)

					task.wait(1)

					v.Door.ClickDetector.MaxActivationDistance=7.5

					return
				end

				game.ReplicatedStorage.Remote.DoorInteract:FireServer(v)
			end)
			
			v.Door.ClickDetector.RightMouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				local slot=table.find(self.inventory,"Plank")
				if v.Opened.Value==false and slot and not v:FindFirstChild("BlockadePlank") then
					self.inventory[slot]="None"
					self.gui.Inventory["Slot"..tostring(slot)].Icon:ClearAllChildren()
					
					self.ts:Create(
						self.gui.Hint,
						TweenInfo.new(0.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
						{TextTransparency=1}
					):Play()
					
					game.ReplicatedStorage.Remote.BlockadeDoor:FireServer(v)
				end
			end)

			bind_interactable_highlight("Door",v.Door.ClickDetector,v)
		elseif string.sub(v.Name,1,5)=="_Vent" and v:IsA("UnionOperation") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.VentInteract:FireServer(v)
			end)

			bind_interactable_highlight("Vent",v.ClickDetector)
		elseif v.Name=="_ElectricalBox" and v:IsA("Model") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				if v.Activated.Value==true then
					v.ClickDetector.MaxActivationDistance=0
					self.alert:QueueAlert("No need.",nil,2)
					task.wait(1)
					v.ClickDetector.MaxActivationDistance=7.5
					
					return
				end
				
				electrical_box_event(v)
			end)

			bind_interactable_highlight("ElectricalBox",v.ClickDetector)
		elseif v.Name=="_Switch" and v:IsA("Part") then --temp maybe
			v.Parent.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.ElectricalSwitchInteract:FireServer(v.Parent)
			end)
			
			bind_interactable_highlight("ElectricalSwitch",v.Parent.ClickDetector)
		elseif v.Name=="_Locker" and v:IsA("Model") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.Locker:FireServer(true,v)
				
				v.ClickDetector.MaxActivationDistance=0
				
				self.in_locker_ptr=v
				self.flashlight_state=false
				game.ReplicatedStorage.Remote.UpdFlashlight:FireServer(false)
				
				cam_freeze=true
				cam_type="Scriptable"
				cam_calc_mods=false
				
				sink_movement()
				
				self.ts:Create(
					self.gui.Vignette,
					TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
					{ImageTransparency=.1,Size=UDim2.fromScale(1,1)}):Play()
				
				local done=false
				task.spawn(function()
					--door opening/closing
					task.wait(.05)
					self.ts:Create(
						v.LeftDoor.Hinge,
						TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
						{CFrame=v.LeftDoor.Hinge.CFrame*CFrame.Angles(0,-math.rad(68),0)}):Play()
					v.LeftDoor.Open:Play()
					task.wait(.1)
					self.ts:Create(
						v.RightDoor.Hinge,
						TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
						{CFrame=v.RightDoor.Hinge.CFrame*CFrame.Angles(0,math.rad(63),0)}):Play()
					v.RightDoor.Open:Play()
					task.wait(.05)
					
					task.wait(.3)
					self.ts:Create(
						v.LeftDoor.Hinge,
						TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
						{CFrame=v.LeftDoor.Hinge.CFrame*CFrame.Angles(0,math.rad(68),0)}):Play()
					v.Close:Play()
					task.wait(.1)
					self.ts:Create(
						v.RightDoor.Hinge,
						TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
						{CFrame=v.RightDoor.Hinge.CFrame*CFrame.Angles(0,-math.rad(63),0)}):Play()
					
					task.wait(.4)
					done=true
				end)
				
				--cam movements
				self.ts:Create(
					self.cam,
					TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
					{CFrame=CFrame.lookAt(self.cam.CFrame.Position,v.LeftDoor:GetPivot().Position)}):Play()
				task.wait(.1)
				self.ts:Create(
					self.cam,
					TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
					{CFrame=CFrame.lookAt(self.cam.CFrame.Position,v.RightDoor:GetPivot().Position)}):Play()
				task.wait(.1)
				self.ts:Create(
					self.cam,
					TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
					{CFrame=v.Cam.CFrame}):Play()
				
				repeat
					task.wait()
				until done==true
				self.in_locker=true
				self.root.CFrame=self.in_locker_ptr.In.CFrame
				
				script.Breathing:Play()
			end)
			
			bind_interactable_highlight("_Locker",v.ClickDetector)
		elseif string.sub(v.Name,1,9)=="_Computer" and v:IsA("MeshPart") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				if v.Activated.Value==true then
					v.ClickDetector.MaxActivationDistance=0
					self.alert:QueueAlert("Not working.",nil,2)
					task.wait(1)
					v.ClickDetector.MaxActivationDistance=7.5

					return
				end
				
				computer_event(v)
			end)

			bind_interactable_highlight("Computer",v.ClickDetector)
		elseif v:FindFirstChild("_Examinable") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				examinable_event(v)
			end)

			bind_interactable_highlight("Examinable",v.ClickDetector)
		elseif v:FindFirstChild("_Pickup") then
			--print("item",v.Name,v.Parent.Parent.Parent.Name)
			
			local click_detector=v:FindFirstChild("ClickDetector") --hmmmm
			if not click_detector then
				--click detector is parented to hitbox child
				click_detector=v.Hitbox.ClickDetector
			end
			
			click_detector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				if v._Pickup.Value=="Battery" then
					if self.flashlight_power<98 then
						self.flashlight_power=math.clamp(self.flashlight_power+10,0,100) --give diff amt?

						funcs.play_sound(4831091467,.5,nil,nil,"Real")
						
						self.item_highlight.Parent=script
						self.item_highlight.Adornee=nil
						
						game.ReplicatedStorage.Remote.DestroyItem:FireServer(v)
						v:Destroy() --to prevent further clicks if plr is lagging ig
					else
						self.alert:QueueAlert("No need.")
					end
				else
					self:AddItem(v,v._Pickup.Value)
				end
			end)

			bind_interactable_highlight("Pickup",click_detector,click_detector.Parent.Name=="Hitbox" and click_detector.Parent.Parent or nil)
		elseif string.sub(v.Name,1,6)=="_Plank" and v:IsA("Model") then
			if not v:FindFirstChild("ClickDetector") then return end

			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				local slot=table.find(self.inventory,"Plank")
				print(slot)

				if slot then
					self.inventory[slot]="None"
					self.gui.Inventory["Slot"..tostring(slot)].Icon:ClearAllChildren()

					game.ReplicatedStorage.Remote.PlacePlank:FireServer(v)
				else
					self.alert:QueueAlert("Need a plank...")
				end
			end)

			bind_interactable_highlight("Plank",v.ClickDetector)
		elseif v.Name=="Lock" and v:IsA("MeshPart") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				local id="Key"
				if v:FindFirstChild("KeyID") then
					id=v.KeyID.Value
				end
				local i=table.find(self.inventory,id)
				if i then
					self.inventory[i]="None"
					self.gui.Inventory["Slot"..tostring(i)].Icon:ClearAllChildren()
					
					game.ReplicatedStorage.Remote.UnlockDoor:FireServer(v)
				else
					if id=="Key" then
						self.alert:QueueAlert("Need a key...")
					else
						self.alert:QueueAlert("Need the right key...")
					end
				end
			end)
			
			bind_interactable_highlight("Lock",v.ClickDetector)
		elseif v.Name=="Drawer" and v:IsA("Model") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.DrawerInteract:FireServer(v)
			end)
			
			bind_interactable_highlight("Drawer",v.ClickDetector)
		elseif v.Name=="RemoveablePlank" and v:IsA("Model") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				local i=table.find(self.inventory,"Crowbar")
				if i then
					game.ReplicatedStorage.Remote.RemovePlank:FireServer(v)
				else
					self.alert:QueueAlert("Need something to remove it...")
				end
			end)

			bind_interactable_highlight("RemoveablePlank",v.ClickDetector)
		elseif v.Name=="Telephone" and v:IsA("MeshPart") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.TelephoneInteract:FireServer(v)
			end)
			
			bind_interactable_highlight("Telephone",v.ClickDetector)
		elseif v.Name=="_Bell" and v:IsA("Model") then
			v.ClickDetector.MouseClick:Connect(function()
				if self.game_state~="alive" then return end
				
				game.ReplicatedStorage.Remote.BellInteract:FireServer(v)
			end)
			
			bind_interactable_highlight("Bell",v.ClickDetector)
		end
	end
	
	--connections
	self.cas:BindActionAtPriority("Jump_Sink",function()
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value,Enum.PlayerActions.CharacterJump)
	
	self.cas:BindActionAtPriority("Forward_Actions",function(name,state,input)
		if state==Enum.UserInputState.Begin and self.in_locker then
			game.ReplicatedStorage.Remote.Locker:FireServer(false,self.in_locker_ptr)
			
			self.in_locker=false
			self.root.CFrame=self.in_locker_ptr.Out.CFrame
			
			script.Breathing:Stop()
			
			self.ts:Create(
				self.gui.Vignette,
				TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
				{ImageTransparency=1,Size=UDim2.fromScale(2,2)}):Play()
			
			task.spawn(function()
				--door opening/closing
				self.ts:Create(
					self.in_locker_ptr.LeftDoor.Hinge,
					TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
					{CFrame=self.in_locker_ptr.LeftDoor.Hinge.CFrame*CFrame.Angles(0,-math.rad(68),0)}):Play()
				self.ts:Create(
					self.in_locker_ptr.RightDoor.Hinge,
					TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
					{CFrame=self.in_locker_ptr.RightDoor.Hinge.CFrame*CFrame.Angles(0,math.rad(63),0)}):Play()
				self.in_locker_ptr.LeftDoor.Open:Play()
				task.wait(.05)

				task.wait(.4)
				self.ts:Create(
					self.in_locker_ptr.LeftDoor.Hinge,
					TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
					{CFrame=self.in_locker_ptr.LeftDoor.Hinge.CFrame*CFrame.Angles(0,math.rad(68),0)}):Play()
				self.in_locker_ptr.Close:Play()
				self.ts:Create(
					self.in_locker_ptr.RightDoor.Hinge,
					TweenInfo.new(.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
					{CFrame=self.in_locker_ptr.RightDoor.Hinge.CFrame*CFrame.Angles(0,-math.rad(63),0)}):Play()
				
				self.in_locker_ptr=nil
			end)

			--cam movements
			self.ts:Create(
				self.cam,
				TweenInfo.new(.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
				{CFrame=self.char.Head.CFrame*CFrame.new(cam_offset)*CFrame.new(0,-.3,.5)*CFrame.Angles(math.rad(-15),0,0)}):Play()
			task.wait(.35)
			
			self.in_locker_ptr.ClickDetector.MaxActivationDistance=5
			
			set_freeze(false)
			unsink_movement()
		end
	end,false,Enum.ContextActionPriority.High.Value+1,Enum.PlayerActions.CharacterForward)
	
	do --camera tilt bindings
		local tilt_amt=3

		self.cas:BindAction("CameraTilt_Left",function(name,state,input)
			if state==Enum.UserInputState.Begin then
				tilt_move+=math.rad(tilt_amt)
			elseif state==Enum.UserInputState.End then
				tilt_move-=math.rad(tilt_amt)
			end
		end,false,Enum.PlayerActions.CharacterLeft)

		self.cas:BindAction("CameraTilt_Right",function(name,state,input)
			if state==Enum.UserInputState.Begin then
				tilt_move-=math.rad(tilt_amt)
			elseif state==Enum.UserInputState.End then
				tilt_move+=math.rad(tilt_amt)
			end
		end,false,Enum.PlayerActions.CharacterRight)
	end
	
	self.rs:BindToRenderStep("Framework_Render",Enum.RenderPriority.Last.Value,function(dt)
		debug.profilebegin("Framework_Render")
		--how dt works: (number change wanted per second)*dt (e.g. -0.5*dt means sub .5 per second)
		frame_count+=1
		
		--mouse
		local ms_pos=self.uis:GetMouseLocation()
		
		self.gui.Cursor.Position=UDim2.new(0,ms_pos.X,0,ms_pos.Y)
		
		--spectate skip
		if self.game_state=="spectating" then
			--print("skipping whole framework_render")
			debug.profileend()
			
			return
		end
		
		--cam stuff (mainly view bobbing)
		if not cam_freeze then
			if self.hum.MoveDirection.Magnitude==0 then tilt_move=0 end
			local tilt_goal=tilt_peek+tilt_move+(-self.uis:GetMouseDelta().X*.01)
			
			tilt=funcs.lerp(tilt,tilt_goal,10*dt)
			--tilt=funcs.lerp(tilt,tilt_goal,.1)
			offset_x=funcs.lerp(offset_x,offset_x_goal,10*dt)
			self.crouch_offset_y=funcs.lerp(self.crouch_offset_y,self.crouch_offset_y_goal,7*dt) --its just different...
			
			local velo=Vector3.new(self.root.Velocity.X,0,self.root.Velocity.Z)
			
			local bob_spd=(self.sprint_state and .65 or .85)*walk_spd
			local bob_x_goal=.25*math.sin(tick()*bob_spd)*funcs.round(velo.Magnitude/self.hum.WalkSpeed)
			local bob_y_goal=(self.sprint_state and .4 or .3)*math.sin(tick()*bob_spd*2)*funcs.round(velo.Magnitude/self.hum.WalkSpeed)
			--local bob_x_angle_goal=.0025*math.sin(tick()*bob_spd)*funcs.round(self.root.Velocity.Magnitude/self.hum.WalkSpeed)
			--local bob_y_angle_goal=.00125*math.sin(tick()*bob_spd*2)*funcs.round(velo.Magnitude/self.hum.WalkSpeed)
			
			if self.crouch_state then
				bob_x_goal=.18*math.sin(tick()*bob_spd)*funcs.round(velo.Magnitude/self.hum.WalkSpeed)
				bob_y_goal=.125*math.sin(tick()*bob_spd*2)*funcs.round(velo.Magnitude/self.hum.WalkSpeed)
			end
			
			bob_x=funcs.lerp(bob_x,bob_x_goal,10*dt)
			bob_y=funcs.lerp(bob_y,bob_y_goal,10*dt)
			--bob_x_angle=funcs.lerp(bob_x_angle,bob_x_angle_goal,10*dt)
			--bob_y_angle=funcs.lerp(bob_y_angle,bob_y_angle_goal,10*dt)
		else
			bob_y_angle=0
			
			if self.in_locker then
				local mv_scale=150 --smaller = more movement allowed
				local ax=CFrame.Angles(0,math.rad(-(ms_pos.X-(self.cam.ViewportSize.X/2))/mv_scale),0)
				local ay=CFrame.Angles(math.rad(-(ms_pos.Y-(self.cam.ViewportSize.Y/2))/mv_scale),0,0)
				
				self.cam.CFrame=self.cam.CFrame:Lerp(
					((ax*(self.in_locker_ptr.Cam.CFrame-self.in_locker_ptr.Cam.CFrame.Position))+self.in_locker_ptr.Cam.CFrame.Position)*ay,7*dt)
			end
		end
		
		if not cam_calc_mods then
			offset_x=0
			self.crouch_offset_y=0
			bob_x=0
			bob_y=0
			bob_x_angle=0
			bob_y_angle=0
			tilt=0
		end
		
		self.cam.CameraType=cam_type
		self.cam.FieldOfView=cam_fov
		self.cam.CFrame=self.cam.CFrame
			*cam_prev_shake:Inverse()
			*CFrame.new(offset_x,0,0)
			*CFrame.new(self.cam.CFrame:VectorToObjectSpace(Vector3.new(0,self.crouch_offset_y,0)))
			*CFrame.new(bob_x,0,0)
			*CFrame.new(self.cam.CFrame:VectorToObjectSpace(Vector3.new(0,bob_y,0)))
			*CFrame.Angles(bob_y_angle,bob_x_angle,0)
			*CFrame.Angles(0,0,tilt)
		
		--useful for optimizations
		cam_cf_no_transform=self.cam.CFrame
			*CFrame.new(offset_x,0,0):Inverse()
			*CFrame.new(self.cam.CFrame:VectorToObjectSpace(Vector3.new(0,self.crouch_offset_y,0))):Inverse()
			*CFrame.new(bob_x,0,0):Inverse()
			*CFrame.new(self.cam.CFrame:VectorToObjectSpace(Vector3.new(0,bob_y,0))):Inverse()
			*CFrame.Angles(bob_y_angle,bob_x_angle,0):Inverse()
			*CFrame.Angles(0,0,tilt):Inverse()
		
		cam_prev_shake=CFrame.new() --reset it
		
		if cam_cf_no_transform~=cam_prev_cf_no_transform and frame_count%4==0 then
			game.ReplicatedStorage.Remote.UpdCam:FireServer(cam_cf_no_transform)
			game.ReplicatedStorage.Remote.UpdStats:FireServer(self.flashlight_power,self.sanity)
		end
		
		if cam_target then
			self.cam.CFrame=self.cam.CFrame:Lerp(CFrame.lookAt(self.cam.CFrame.Position,cam_target),.1)
		end
		
		if self.game_state=="dead" then --self.dead then
			self.cam.CameraType="Fixed"
		end
		
		if not self.crouch_state then
			if self.hum.MoveDirection.Magnitude>0 and self.sprint_state then
				cam_fov=funcs.lerp(cam_fov,cam_fov_default+7.5,5*dt) --7*dt
			else
				cam_fov=funcs.lerp(cam_fov,cam_fov_default,7*dt)
			end
		else
			cam_fov=funcs.lerp(cam_fov,cam_fov_default-10,7*dt)
		end
		
		--sprinting
		local min_c=30
		if self.sprint_state and self.hum.MoveDirection.Magnitude>0 then
			self.sprint_charge=math.clamp(self.sprint_charge-4*dt,0,100)
			if self.sprint_charge<=0 then
				self.sprint_state=false
				self.sprint_cooldown=true
				walk_spd=walk_spd_default
			end
		else
			self.sprint_charge=math.clamp(self.sprint_charge+3*dt,0,100) -- +2*dt ?
			if self.sprint_cooldown and self.sprint_charge>=min_c then--*1.5 then
				self.sprint_cooldown=false
			end
		end
		
		if self.sprint_charge<=min_c then
			script.Fatigue.Playing=true
			script.Fatigue.Volume=math.clamp(.2*(1-self.sprint_charge/min_c),0,.2)
			
			game.Lighting.Fatigue.Brightness=-.1*(1-self.sprint_charge/min_c)
			game.Lighting.Fatigue.Contrast=.4*(1-self.sprint_charge/min_c)
			game.Lighting.Fatigue.Saturation=-.2*(1-self.sprint_charge/min_c)
			game.Lighting.FatigueBlur.Size=8*(1-self.sprint_charge/min_c)
			
			game.SoundService.Real.EqualizerSoundEffect.HighGain=-7.5*(1-self.sprint_charge/min_c)
			game.SoundService.Real.EqualizerSoundEffect.MidGain=-7.5*(1-self.sprint_charge/min_c)
		else
			script.Fatigue.Playing=false
			
			game.Lighting.Fatigue.Brightness=0
			game.Lighting.Fatigue.Contrast=0
			game.Lighting.Fatigue.TintColor=Color3.fromRGB(255,255,255)
			game.Lighting.FatigueBlur.Size=0
			
			if self.game_state~="dead" then
				game.SoundService.Real.EqualizerSoundEffect.HighGain=0
				game.SoundService.Real.EqualizerSoundEffect.MidGain=0
			end
		end
		
		--footsteps
		if bob_y<bob_y_min and bob_y<0 then
			bob_y_min=bob_y
		elseif bob_y>bob_y_min and bob_y_min<0 and bob_y_min>-1 then
			--print("--> FOOTSTEP"," | ",bob_y," | ",bob_y_min)
			local vol_mult=1
			if self.crouch_state then vol_mult=.5 end
			
			if self.hum.FloorMaterial==Enum.Material.Concrete then
				funcs.play_sound(6190604276,.4*(self.crouch_state and 0 or 1),nil,nil,"Real",{0,.35})
			elseif self.hum.FloorMaterial==Enum.Material.Wood then
				funcs.play_sound(9058073414,.8*vol_mult,nil,nil,"Real",{0,.3})
			elseif self.hum.FloorMaterial==Enum.Material.Metal or self.hum.FloorMaterial==Enum.Material.DiamondPlate then
				funcs.play_sound(9083841139,.8*vol_mult,nil,nil,"Real",{0,.3})
			elseif self.hum.FloorMaterial==Enum.Material.Fabric or self.hum.FloorMaterial==Enum.Material.Carpet then
				funcs.play_sound(6240702531,.4*vol_mult,nil,nil,"Real")
			end
			
			bob_y_min=-1
		elseif bob_y>0 and bob_y_min==-1 then
			bob_y_min=0
		end
		
		--update lighting (flashlight components & body light)
		if cam_cf_no_transform~=cam_prev_cf_no_transform or self.flashlight_bypass_check then
			--print("calc flashlight stuff")
			self.flashlight_bypass_check=false
			
			if self.flashlight_light.Light1.Enabled==false and self.flashlight_state==true then
				self.flashlight_light.CFrame=self.cam.CFrame*CFrame.new(0,0,1)
				self.flashlight_ring_l.CFrame=self.flashlight_light.CFrame*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)
				self.flashlight_ring_m.CFrame=self.flashlight_light.CFrame*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)
			end
			
			if self.flashlight_light.Light1.Enabled then
				self.flashlight_light.CFrame=CFrame.new((self.cam.CFrame*CFrame.new(0,0,1)).Position)*self.flashlight_light.CFrame.Rotation
				
				local tween=self.ts:Create(
					self.flashlight_light,
					TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),
					{CFrame=self.cam.CFrame*CFrame.new(0,0,1)}
				)
				tween:Play()
				
				--self.flashlight_light.CFrame=self.flashlight_light.CFrame:Lerp(self.cam.CFrame*CFrame.new(0,0,1),.2)
				self.flashlight_ring_l.CFrame=self.flashlight_light.CFrame*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)
				self.flashlight_ring_m.CFrame=self.flashlight_light.CFrame*CFrame.new(0,0,-.185)*CFrame.Angles(math.rad(90),0,0)
			end
		end
		
		self.flashlight_light.Light1.Enabled=self.flashlight_state
		self.flashlight_light.Light2.Enabled=self.flashlight_state
		self.flashlight_light.Light3.Enabled=self.flashlight_state

		self.flashlight_light.Parent=self.flashlight_state and self.cam or script
		self.flashlight_ring_l.Parent=self.flashlight_state and self.cam or script
		self.flashlight_ring_m.Parent=self.flashlight_state and self.cam or script
		
		body_light.Parent=self.root
		
		--update flashlight power
		if self.flashlight_state==true then
			--.75?
			self.flashlight_power=math.clamp(self.flashlight_power-.65*dt,0,100)--roughly .005 per frame on 60fps

			if self.flashlight_power<=0 then
				self.flashlight_state=false
				funcs.play_sound(198914875,.65,nil,nil,"Real")
				
				game.ReplicatedStorage.Remote.UpdFlashlight:FireServer(false)
			end
		end
		
		--delete server's copy of own flashlight (if exists)
		if workspace.Flashlights:FindFirstChild(self.plr.Name) then
			if #workspace.Flashlights[self.plr.Name]:GetChildren() then
				workspace.Flashlights[self.plr.Name]:ClearAllChildren()
			end
		end
		
		--gui
		self.gui.Stats.Battery.Title.Visible=get_key_down(Enum.KeyCode.Tab)
		self.gui.Stats.Battery.Title.Text=tostring(math.floor(self.flashlight_power*10)/10).."%"
		self.gui.Stats.Battery.Charge.Size=UDim2.new(1,0,0,(self.gui.Stats.Battery.AbsoluteSize.Y-16)*(self.flashlight_power/100))
		self.gui.Stats.Battery.Charge.Image.Size=UDim2.new(1,0,0,self.gui.Stats.Battery.AbsoluteSize.Y)
		
		self.gui.Stats.Health.Visible=self.hum.Health<100
		self.gui.Stats.Health.Title.Text=math.floor(self.hum.Health)
		
		--self.gui.Stats.Sprint.Visible=self.sprint_state --> necessary?
		self.gui.Stats.Sprint.Visible=get_key_down(Enum.KeyCode.Tab)
		self.gui.Stats.Sprint.Title.Text=tostring(math.floor(self.sprint_charge)).."%"
		
		--sound
		if math.floor(tick())==next_swell then
			funcs.play_sound(9043336845,.35)
			next_swell+=math.random(19,182)
		end
		
		if math.floor(tick())==next_amb9 then
			funcs.play_sound(8110784761,.45,nil,nil,"Real")
			next_amb9+=math.random(60,192)
		end
		
		--update examine obj
		local ms_btns=self.uis:GetMouseButtonsPressed()
		local ms_1=false
		
		for i,v in pairs(ms_btns) do --better way to do this stuff?
			if v.UserInputType==Enum.UserInputType.MouseButton1 then
				ms_1=true
				
				break
			end
		end
		
		--update dust
		--[[dust_part.CFrame=self.root.CFrame
		dust_part.Parent=workspace]]
		
		--post processing
		game.Lighting.Blur.Enabled=true
		
		--[[self.char["Left Arm"].LocalTransparencyModifier=0
		self.char["Right Arm"].LocalTransparencyModifier=0
		self.char["Left Leg"].LocalTransparencyModifier=0
		self.char["Right Leg"].LocalTransparencyModifier=0]]
		
		if not cam_freeze and cam_calc_mods then --should fix electrical box viewing bug
			local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=cam_cf_no_transform:GetComponents()
			self.root.CFrame=CFrame.new(self.root.CFrame.Position.X,self.root.CFrame.Position.Y,self.root.CFrame.Position.Z,r00,0,0,0,r11,0,r20,0,r22)
			self.char.Head.CanCollide=false --YES!!!!!!!
		end
		
		--update humanoid
		self.hum.WalkSpeed=self.crouch_state and crouch_spd or walk_spd
		self.hum.AutoRotate=false
		self.hum.CameraOffset=cam_offset
		
		--update prev vals
		cam_prev_cf_no_transform=cam_cf_no_transform
		ms_pos_old=ms_pos --need?
		
		debug.profileend()
	end)
	
	self.uis.InputBegan:Connect(function(i,gp)
		if self.game_state~="alive" then return end
		
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			if examine_obj then
				examine_origin=self.uis:GetMouseLocation()
			end
		elseif i.UserInputType==Enum.UserInputType.MouseButton2 then
			modal_state=false
		end
		
		if i.KeyCode==Enum.KeyCode.F and not self.in_locker then
			if self.flashlight_power>0 then
				self.flashlight_state=not self.flashlight_state
				funcs.play_sound(198914875,.65,nil,nil,"Real")
				
				self.flashlight_bypass_check=true
				
				game.ReplicatedStorage.Remote.UpdFlashlight:FireServer(self.flashlight_state)
			else
				self.alert:QueueAlert("Need more batteries...")
			end
		elseif (i.KeyCode==Enum.KeyCode.LeftControl or i.KeyCode==Enum.KeyCode.C) and not self.sprint_state and not self.in_locker then --remove one later
			--toggle for now
			local can_crouch=true
			
			if (not self.crouch_state)==false then
				local params=RaycastParams.new()
				params.FilterType=Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances={self.char}
				local ray=workspace:Raycast(self.root.Position,Vector3.new(0,1.5,0),params) --hmm should cast be from root...?
				
				if ray then
					if ray.Instance.CanCollide then
						can_crouch=false
					end
				end
			end
			
			if can_crouch then
				self.crouch_state=not self.crouch_state
				self.crouch_offset_y_goal+=self.crouch_state and -1.75 or 1.75
				
				funcs.play_sound(6636232274,.5,nil,nil,"Real",{.05,.5})
				
				if self.crouch_state==true then
					self.crouch_anim=self.hum:LoadAnimation(script.Animations.Crouch_Idle)
					self.crouch_anim.Looped=true
					self.crouch_anim:Play()
					
					--cam_fov=cam_fov_default-10
				else
					self.crouch_anim:Stop()
					self.crouch_anim=nil
				end
			end
		elseif i.KeyCode==Enum.KeyCode.Tab then
			inventory_state=true
			
			self.gui.Inventory:TweenPosition(UDim2.fromScale(0,.975),"InOut","Quad",.2,true)
			self.gui.Alerts:TweenPosition(UDim2.fromScale(.5,.85),"InOut","Quad",.2,true)
		elseif i.KeyCode==Enum.KeyCode.One then
			use_item(1)
		elseif i.KeyCode==Enum.KeyCode.Two then
			use_item(2)
		elseif i.KeyCode==Enum.KeyCode.Three then
			use_item(3)
		elseif i.KeyCode==Enum.KeyCode.Four then
			use_item(4)
		elseif i.KeyCode==Enum.KeyCode.LeftShift and not self.crouch_state and not self.sprint_cooldown then
			--sprinting
			self.sprint_state=true
			walk_spd=sprint_spd
		end
		
		--experimental
		if i.KeyCode==Enum.KeyCode.Q then
			tilt_peek+=math.rad(20)
			offset_x_goal-=1.25
		elseif i.KeyCode==Enum.KeyCode.E then
			tilt_peek-=math.rad(20)
			offset_x_goal+=1.25
		end
	end)
	
	self.uis.InputEnded:Connect(function(i,gp)
		if self.game_state~="alive" then return end
		
		--[[if i.KeyCode==Enum.KeyCode.LeftControl or i.KeyCode==Enum.KeyCode.C then --remove one later
			crouch_state=true
			crouch_offset_y_goal+=2
		end]]
		
		if i.KeyCode==Enum.KeyCode.Tab then
			inventory_state=false

			self.gui.Inventory:TweenPosition(UDim2.fromScale(0,1.2),"InOut","Quad",.2,true)
			self.gui.Alerts:TweenPosition(UDim2.fromScale(.5,.95),"InOut","Quad",.2,true)
		elseif i.KeyCode==Enum.KeyCode.LeftShift and not self.crouch_state and self.sprint_state then
			self.sprint_state=false
			walk_spd=walk_spd_default
		end
		
		--experimental
		if i.KeyCode==Enum.KeyCode.Q then
			tilt_peek-=math.rad(20)
			offset_x_goal+=1.25
		elseif i.KeyCode==Enum.KeyCode.E then
			tilt_peek+=math.rad(20)
			offset_x_goal-=1.25
		end
	end)
	
	--remote/bindable connections
	script.Dialogue.Event:Connect(function(txt,t)
		self.alert:QueueAlert(txt,nil,t)
	end)
	
	game.ReplicatedStorage.Remote.Alert.OnClientEvent:Connect(function(txt,t)
		self.alert:QueueAlert(txt,nil,t)
	end)
	
	game.ReplicatedStorage.Remote.MonsterSpawn.OnClientEvent:Connect(function(id,monster)
		if id==1 then
			funcs.play_sound(9038131957,1)
			
			--[[script.Heartbeat.TimePosition=0
			script.Heartbeat.Volume=.25
			script.Heartbeat:Play()]]
			
			monster_active=true
			
			local connection
			connection=self.rs.RenderStepped:Connect(function()
				if monster==nil or monster.Parent==nil or not monster:FindFirstChild("HumanoidRootPart") then
					game.Lighting.Scary.Contrast=0
					game.Lighting.Scary.Saturation=0
					game.Lighting.Scary.TintColor=Color3.fromRGB(255,255,255)
					--cam_fov=(self.sprint_state and cam_fov_sprint or cam_fov_default)
					--cam_prev_shake=CFrame.new()
					script.Heartbeat:Stop()
					connection:Disconnect()
					monster_active=false
					return
				end
				
				if not adrenaline_state then
					local inverse_d_y=math.clamp(20/(1.5*math.abs(self.root.Position.Y-monster.HumanoidRootPart.Position.Y)),0,1)
					
					if not script.Heartbeat.Playing then script.Heartbeat.Playing=true end
					script.Heartbeat.Volume=math.clamp(.25+inverse_d_y,.25,1.25)
					script.Heartbeat.PlaybackSpeed=math.clamp(1+inverse_d_y,1,2)
					script.Heartbeat.PitchShiftSoundEffect.Octave=math.clamp(1-(.5*inverse_d_y),.5,1)
					
					game.Lighting.Scary.Contrast=.1*math.clamp(script.Heartbeat.PlaybackLoudness/1000,0,1)
					game.Lighting.Scary.Saturation=-.65*math.clamp(script.Heartbeat.PlaybackLoudness/1000,0,1)
					
					game.Lighting.Scary.TintColor=Color3.fromRGB(
						255-(95*math.clamp(inverse_d_y,0,1)),
						255-(205*math.clamp(inverse_d_y,0,1)),
						255-(205*math.clamp(inverse_d_y,0,1))
					)
					
					--cam_fov=cam_fov_default
					--cam_fov=(self.sprint_state and cam_fov_sprint or cam_fov_default)+3*math.clamp(script.Heartbeat.PlaybackLoudness/1000,0,1)
					
					local cam_shake_mult=inverse_d_y*.5
					
					cam_prev_shake=CFrame.Angles(
						math.rad(math.random(-2000,2000)/1000)*cam_shake_mult,
						math.rad(math.random(-2000,2000)/1000)*cam_shake_mult,
						math.rad(math.random(-2000,2000)/1000)*cam_shake_mult
					)
					
					self.cam.CFrame*=cam_prev_shake
				end
			end)
			
			--make cam look toward direction of monster spawn?
		elseif id==2 then
			local connection
			connection=self.rs.RenderStepped:Connect(function(dt)
				if monster==nil or monster.Parent==nil or not monster:FindFirstChild("HumanoidRootPart") then
					connection:Disconnect()
					return
				end
				
				local mpos,on_screen=self.cam:WorldToViewportPoint(monster.Head.Position)
				
				--maybe make it so it has to be sum like 100px<mpos.X<800px
				
				if (monster.Head.Position-self.cam.CFrame.Position).Magnitude>1024 then --??!?!?!
					return --solution for a problem that idk why it exists
				end
				
				if on_screen and mpos.Z>0 then --on screen and in front of cam (looking at)
					local params=RaycastParams.new()
					params.FilterType=Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances={self.char}
					local dir=monster.Head.Position-self.cam.CFrame.Position
					local ray=workspace:Blockcast(self.cam.CFrame,Vector3.new(.5,.5,.5),dir,params)
					--local ray=workspace:Raycast(self.cam.CFrame.Position,dir,params)
					
					if ray then
						if ray.Instance:IsDescendantOf(monster) then
							connection:Disconnect()
							
							if not adrenaline_state then --another benefit of the item
								self.root.Anchored=true --ugh
								funcs.play_sound(4896837434,1)
								
								cam_target=monster.Head.Position
								cam_calc_mods=false
								cam_type="Scriptable"
								
								task.wait(.15)
								
								for i=1,60 do
									cam_fov=funcs.lerp(cam_fov,30,.08)
									self.rs.RenderStepped:Wait()
								end
								
								task.wait(1.5)
								
								self.root.Anchored=false
								
								cam_target=nil
								cam_calc_mods=true
								cam_type="Custom"
								cam_fov=cam_fov_default
							end
						end
					end
				end
			end)
		end
	end)
	
	game.ReplicatedStorage.Remote.Jumpscare.OnClientEvent:Connect(function(_type)
		if _type=="Eyes" then
			self.sanity=math.clamp(self.sanity-5,0,100)
			
			self.gui.Eyes.Size=UDim2.fromScale(.25,.25)
			self.gui.Eyes.Visible=true
			self.gui.Eyes:TweenSize(UDim2.fromScale(1,1),"InOut","Quad",.065)
			task.wait(.75)
			self.gui.Eyes.Visible=false
		end
	end)
	
	--init
	self.plr.CameraMode=Enum.CameraMode.LockFirstPerson
	self.uis.MouseIconEnabled=false
	self.hum:SetStateEnabled(Enum.HumanoidStateType.Climbing,false)
	
	game.Lighting.Ambient=Color3.fromRGB(65,65,65) --90,90,90
	
	pcall(function() --seriously
		game.StarterGui:SetCore("ResetButtonCallback",false)
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,false)
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu,false)
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)
	end)
	
	sink_movement()
	self.gui.Modal.Visible=true
	self.gui.Keybinds.Visible=true
	
	self.gui.Intro.Visible=true
	do --if not self.rs:IsStudio() then --intro sequence
		self.gui.Intro.Slide1.Visible=true
		
		local cps=game:GetService("ContentProvider")
		local to_load={
			unpack(self.gui:GetDescendants()),
			unpack(workspace:GetDescendants()),
			unpack(game.ReplicatedStorage.Flashlight:GetDescendants()),
			unpack(script:GetDescendants())
		}
		local loaded=0
		
		for i,v in pairs(to_load) do
			cps:PreloadAsync({v})
			loaded+=1
			self.gui.Intro.Slide1.BarHolder.Bar.Size=UDim2.fromScale(loaded/#to_load,1)
		end
		task.wait(.2)
		self.gui.Intro.Slide1.Visible=false
		self.gui.Intro.FG.BackgroundTransparency=0
		self.gui.Intro.Slide2.Visible=true
		task.wait(1)
		self.ts:Create(
			self.gui.Intro.FG,
			TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
			{BackgroundTransparency=1}
		):Play()
		task.wait(.4)
		funcs.play_sound(860460765,1.5)
		task.wait(4.6)--tween_t+3
		self.ts:Create(
			self.gui.Intro.FG,
			TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
			{BackgroundTransparency=0}
		):Play()
		task.wait(3)
		self.gui.Intro.Slide2.Visible=false
		self.gui.Intro.Slide3.Visible=true
		self.ts:Create(
			self.gui.Intro.FG,
			TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
			{BackgroundTransparency=1}
		):Play()
		task.wait(2)
		funcs.play_sound(7973280792,1)
		task.wait(3)--tween_t+3
		self.ts:Create(
			self.gui.Intro.FG,
			TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
			{BackgroundTransparency=0}
		):Play()
		task.wait(2)
		self.gui.Intro.Slide3.Visible=false
		self.gui.Intro.FG.Visible=false
	end
	
	game.ReplicatedStorage.Remote.Loaded:FireServer()

	self.ts:Create(
		self.gui.Intro.BG,
		TweenInfo.new(2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
		{BackgroundTransparency=1}
	):Play()
	task.wait(2)
	
	self.gui.Intro.Visible=false
	
	--cont. init
	self.gui.Cursor.BackgroundTransparency=.65
	self.gui.Keybinds.Confirm.MouseButton1Click:Connect(function()
		funcs.play_sound(6324790483,.5)
		
		self.gui.Modal.Visible=false
		self.gui.Keybinds.Visible=false
		self.gui.Cursor.BackgroundTransparency=1
		
		unsink_movement()
		
		self.game_state="alive"
		
		task.wait(math.random(3,7))
		script.Parent.Ambiance:Play()
	end)
	
	--interactable stuff
	for i,v in pairs(workspace:GetDescendants()) do
		bind_interactable(v)
	end

	workspace.Map--[[.Cells]].DescendantAdded:Connect(function(v)
		task.wait(.1) --wait for all descendants to load in ig?

		if v.Parent==nil then return end

		bind_interactable(v)
	end)
	
	return self
end

function Framework:UpdateCharVariables()
	self.char=self.plr.Character
	self.hum=self.char:WaitForChild("Humanoid")
	self.root=self.char:WaitForChild("HumanoidRootPart")
	
	--define connections specific to these variables
	self.hum.StateChanged:Connect(function(old,new)
		if old==Enum.HumanoidStateType.Freefall then --no landed state --> more reliable like this
			if math.abs(self.root.AssemblyLinearVelocity.Y)>30 then
				self.hum.Health-=math.clamp(math.abs(self.root.AssemblyLinearVelocity.Y),1,math.huge)
				
				if self.hum.Health>0 then
					funcs.play_sound(5507830449,.75)
				end
				
				funcs.play_sound(8011805384,.5,nil,nil,"Real")
			end
		end
	end)
	
	self.hum.Died:Connect(function()
		self:OnDeath()
	end)
end

function Framework:AddItem(item,item_type)
	local empty_slot=table.find(self.inventory,"None")

	if empty_slot then
		if item_type=="Key" or item_type=="GoldenKey" or item_type=="SpecialKey" then
			funcs.play_sound(189777179,.5,nil,nil,"Real")
		else
			funcs.play_sound(4831091467,.5,nil,nil,"Real")
		end

		self.inventory[empty_slot]=item_type
		
		local item_clone=item:Clone() --items which can be picked up must be models
		item_clone.Parent=self.gui.Inventory["Slot"..tostring(empty_slot)].Icon
		item_clone:PivotTo(CFrame.identity)
		
		local item_cam=Instance.new("Camera")
		item_cam.Parent=self.gui.Inventory["Slot"..tostring(empty_slot)].Icon
		item_cam.CFrame=CFrame.lookAt(item_clone.Config.Offset.Value,item_clone.WorldPivot.Position)
			*CFrame.Angles(
				item_clone.Config.Rotation.Value.X,
				item_clone.Config.Rotation.Value.Y,
				item_clone.Config.Rotation.Value.Z)
		
		self.gui.Inventory["Slot"..tostring(empty_slot)].Icon.CurrentCamera=item_cam
		
		self.item_highlight.Parent=script
		self.item_highlight.Adornee=nil
		
		game.ReplicatedStorage.Remote.DestroyItem:FireServer(item)
		item:Destroy() --to prevent further clicks if plr is lagging ig
	else
		self.alert:QueueAlert("No room.")
	end
end

function Framework:OnDeath(depth)
	funcs.play_sound(5507830073,1)
	funcs.play_sound(172905796,1)
	
	self.game_state="dead"
	
	self.dead=true
	self.flashlight_state=false
	
	game.ReplicatedStorage.Remote.UpdFlashlight:FireServer(false)

	self.gui.Stats.Visible=false
	self.gui.Keybinds.Visible=false
	self.gui.DeathScreen.Timer.Visible=true
	self.gui.DeathScreen.Continue.Visible=false
	
	task.wait(2)
	
	for i=1,200 do
		game.Lighting.DeathBlur.Size=i/2
		game.Lighting.DeathCorrection.Brightness=-i/100
		game.SoundService.Real.EqualizerSoundEffect.HighGain=-35*(i/200)
		game.SoundService.Real.EqualizerSoundEffect.MidGain=-35*(i/200)

		self.rs.RenderStepped:Wait()
	end

	self.gui.DeathScreen.Visible=true
	self.gui.Cursor.BackgroundTransparency=.65
	
	local depth=math.abs(math.ceil(self.root.CFrame.Y/9))
	--self.gui.DeathScreen.Depth.Text="Depth: "..tostring(depth)..(depth~=1 and " floors (" or " floor (")..tostring(depth*12).." steps)"
	self.gui.DeathScreen.Depth.Text=tostring(depth)..(depth~=1 and " floors (" or " floor (")..tostring(depth*12).." steps)"
	
	game.Lighting.DeathBlur.Size=0
	game.Lighting.DeathCorrection.Brightness=0

	if self.crouch_state then
		self.crouch_offset_y_goal+=1.75

		self.crouch_anim:Stop()
		self.crouch_anim=nil

		self.crouch_state=false
	end
	
	local plr_icons={}
	task.spawn(function() --fetch thumbnail icons for all plrs
		for i,v in pairs(game.Players:GetPlayers()) do
			local icon=game.Players:GetUserThumbnailAsync(v.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
			plr_icons[v.Name]=icon
		end
	end)
	
	local timer=5
	repeat
		timer-=.1
		self.gui.DeathScreen.Timer.Text="("..tostring(math.ceil(math.clamp(timer,0,math.huge)))..")"
		task.wait(.1)
	until timer<=0
	
	self.gui.DeathScreen.Timer.Visible=false
	self.gui.DeathScreen.Continue.Visible=true
	
	local connection
	connection=self.gui.DeathScreen.Continue.MouseButton1Click:Connect(function()
		local function on_game_over()
			local plr_stats=game.ReplicatedStorage.Remote.ReqStats:InvokeServer()
			
			self.game_state=nil --HMMMMMMMMMM
			
			self.gui.DeathScreen.Visible=false
			self.gui.Spectate.Visible=false
			self.gui.GameEnd.Visible=true
			
			self.gui.Modal.Visible=true --ig
			
			local plrs=game.Players:GetPlayers()
			local cards=#plrs
			local divs=0
			print(cards)

			for i=1,cards do
				local c=script.StatCard:Clone()
				c.Name=tostring(i+divs).."_"..plrs[i].Name
				c.Parent=self.gui.GameEnd.Stats

				c["1_Icon"].Image=plr_icons[plrs[i].Name]
				c["2_User"].Text=plrs[i].Name
				local depth=plr_stats[plrs[i].Name] and plr_stats[plrs[i].Name].Depth or nil
				c["3_Depth"].Text=depth and (tostring(depth)..(depth~=1 and " floors" or " floor")) or "NAN"

				if i~=cards then
					divs+=1

					local d=script.StatDiv:Clone()
					d.Name=tostring(i+divs).."_Div"
					d.Parent=self.gui.GameEnd.Stats
				end
			end

			self.gui.GameEnd.Lobby.MouseButton1Click:Connect(function()
				self.gui.Teleport.Visible=true
				
				game.ReplicatedStorage.Remote.ReturnToLobby:FireServer()
			end)
		end
		
		local game_over=true
		for i,v in pairs(game.Players:GetPlayers()) do
			if v.Dead.Value==false then
				game_over=false
				break
			end
		end
		
		if game_over then
			on_game_over()
		else
			self.gui.DeathScreen.Visible=false
			self.gui.Spectate.Visible=true
			
			self.game_state="spectating"
			
			game.SoundService.Real.EqualizerSoundEffect.HighGain=0
			game.SoundService.Real.EqualizerSoundEffect.MidGain=0
			
			local targets={}
			local index=1
			for i,v in pairs(game.Players:GetPlayers()) do
				if v.Dead.Value==false then
					table.insert(targets,v)
				end
			end
			
			local upd
			upd=self.rs.RenderStepped:Connect(function()
				if #targets==0 then
					task.delay(2,on_game_over)
					upd:Disconnect()

					return
				end
				
				if targets[index].Dead.Value==true then
					table.remove(targets,index)
					
					if index>#targets then
						index=1
					end
				end
				
				if targets[index] then
					self.plr.CameraMode=Enum.CameraMode.Classic
					
					self.cam.CameraType=Enum.CameraType.Follow --?
					self.cam.CameraSubject=targets[index].Character.Humanoid
					
					self.gui.Spectate.Bottom.User.Text=targets[index].Name
					self.gui.Spectate.Stats.Health.Title.Text=math.floor(targets[index].Character.Humanoid.Health*10)/10
					self.gui.Spectate.Stats.Battery.Title.Text=tostring(math.floor(targets[index].Battery.Value*10)/10).."%"
					self.gui.Spectate.Stats.Sanity.Title.Text=tostring(math.floor(targets[index].Sanity.Value*10)/10).."%"
				end
			end)
			
			self.gui.Spectate.Bottom.Next.MouseButton1Click:Connect(function()
				index+=1
				if index>#targets then
					index=1
				end
			end)
			
			self.gui.Spectate.Bottom.Prev.MouseButton1Click:Connect(function()
				index-=1
				if index<1 then
					index=#targets
				end
			end)
			
			self.gui.Spectate.Top["1_Lobby"].MouseButton1Click:Connect(function()
				self.gui.Teleport.Visible=true
				
				game.ReplicatedStorage.Remote.ReturnToLobby:FireServer()
			end)
		end
	end)
	
	--[[
	task.wait(1)
	
	local depth=math.abs(math.ceil(self.root.CFrame.Y/9))
	self.gui.DeathScreen.Depth.Text="Depth: "..tostring(depth)..(depth~=1 and " floors (" or " floor (")..tostring(depth*12).." steps)"
	self.gui.DeathScreen.Depth.Visible=true

	task.wait(1)

	self.gui.DeathScreen.Respawn.Visible=true

	local respawnInput
	respawnInput=self.uis.InputBegan:Connect(function(i,gp)
		if i.KeyCode==Enum.KeyCode.Y then
			local req=game.ReplicatedStorage.Remote.Respawn:InvokeServer()

			if req==true then
				print("respawn approved by server",self.char:GetAttribute("Immune"))
				
				game.SoundService.Real.EqualizerSoundEffect.HighGain=0
				game.SoundService.Real.EqualizerSoundEffect.MidGain=0

				self:UpdateCharVariables()
				self.cam.CameraSubject=self.hum
				
				self.sanity=100
				
				self.dead=false

				self.gui.DeathScreen.Visible=false
				self.gui.Stats.Visible=true
				self.gui.Cursor.BackgroundTransparency=1

				respawnInput:Disconnect() --maybe disconnect even if req is false?
			end
		end
	end)]]
end

return Framework.new()