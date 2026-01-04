-- @ScriptType: ModuleScript
local Computer={}
Computer.__index=Computer

function Computer.new(comp)
	local self=setmetatable({},Computer)
	
	local function flash(array,t,c1,c2)
		for i,v in pairs(array) do
			local prop={}

			if v:IsA("Frame") then
				if v.BackgroundTransparency~=1 then
					v.BackgroundColor3=c1
					prop={BackgroundColor3=c2}
				end
			elseif v:IsA("TextLabel") then
				if v.TextTransparency~=1 then
					v.TextColor3=c1
					prop={TextColor3=c2}
				end
			elseif v:IsA("UIStroke") then
				v.Color=c1
				prop={Color=c2}
			end

			game:GetService("TweenService"):Create(v,TweenInfo.new(t,Enum.EasingStyle.Circular,Enum.EasingDirection.Out),prop):Play()
		end
	end
	
	self.Computer=comp
	
	self.Completed=0
	self.Required=math.random(3,6)
	
	self.TimeLeft=self.Required*3
	self.ZonePos=UDim2.new()
	self.ZoneSize=UDim2.new()
	
	self.TrackerSpeed=.9--.015
	
	self.Finished=false
	self.Success=false
	
	local tracker_pos=UDim2.fromScale(.1,.5)
	local tracker_pos_min=.1
	local tracker_pos_max=.5+(self.Computer.Frame.Bar.Size.X.Scale/2)
	local tracker_dir=1 --> -1 or 1
	
	self.Update=game:GetService("RunService").RenderStepped:Connect(function(dt)
		--tracker_pos=UDim2.fromScale(tracker_pos.X.Scale+(self.TrackerSpeed*tracker_dir),.5)
		tracker_pos=UDim2.fromScale(tracker_pos.X.Scale+((self.TrackerSpeed*tracker_dir)*dt),.5)
		
		if tracker_pos.X.Scale>=tracker_pos_max or tracker_pos.X.Scale<=tracker_pos_min then
			tracker_dir*=-1
		end
		
		self.Computer.Frame.Tracker.Position=tracker_pos
		self.TimeLeft-=dt
		
		local t=tostring(math.floor(self.TimeLeft*10)/10)
		
		if string.len(t)==1 then
			t="0"..t..".0"
		end
		
		if string.find(t,".",1,true)==2 then
			t="0"..t
		elseif string.find(t,".",1,true)==1 then
			t="00"..t
		elseif string.find(t,".",1,true)==nil then
			t=t..".0"
		end
		
		self.Computer.Frame.Info.Text="Time Left: "..t.."s<br/>Left: "..tostring(self.Required-self.Completed)
		
		if self.TimeLeft<=0 then
			print("times up")
			self.Finished=true
		end
	end)
	
	self.Input=game:GetService("UserInputService").InputBegan:Connect(function(i,gp)
		if i.KeyCode==Enum.KeyCode.Space then
			local tracker_x=self.Computer.Frame.Tracker.AbsolutePosition.X
			local zone_x_min=self.Computer.Frame.Bar.Zone.AbsolutePosition.X-5 --5 px for padding
			local zone_x_max=self.Computer.Frame.Bar.Zone.AbsolutePosition.X+self.Computer.Frame.Bar.Zone.AbsoluteSize.X
			
			--[[local frame=Instance.new("Frame")
			frame.AnchorPoint=Vector2.new(0,.5)
			frame.Size=UDim2.new(0,1,1,0)
			frame.BackgroundColor3=Color3.fromRGB(255,0,0)
			frame.Parent=self.Computer.Frame
			frame.Position=UDim2.fromOffset(tracker_x,0)
			game:GetService("Debris"):AddItem(frame,3)]]
			
			if tracker_x>=zone_x_min and tracker_x<=zone_x_max then
				require(game.ReplicatedStorage.Functions).play_sound(6098419898,.5,nil,nil,"Real")
				flash(self.Computer.Frame:GetDescendants(),.4,Color3.fromRGB(150,255,150),Color3.fromRGB(255,255,255))
				
				self.Completed+=1
				
				--self.TrackerSpeed+=.001 --experimental
				
				if self.Completed==self.Required then
					--wow
					print("finished")
					self.Finished=true
					self.Success=true
				end
				
				self:GenerateZone()
			else
				require(game.ReplicatedStorage.Functions).play_sound(550209561,1,nil,nil,"Real")
				flash(self.Computer.Frame:GetDescendants(),.4,Color3.fromRGB(255,0,0),Color3.fromRGB(255,255,255))
				
				self.TimeLeft-=2 --change?
			end
			
			--self.Update:Disconnect()
		end
	end)
	
	return self
end

function Computer:GenerateZone()
	self.ZonePos=UDim2.fromScale(math.random(75,825)/1000,0)
	self.ZoneSize=UDim2.fromScale(math.clamp(math.random(75,175)/1000,0,.925-self.ZonePos.X.Scale),1)
	
	self.Computer.Frame.Bar.Zone.Position=self.ZonePos
	self.Computer.Frame.Bar.Zone.Size=self.ZoneSize
end

function Computer:Destroy()
	--disconnect connections and stuff
	self.Update:Disconnect()
	self.Input:Disconnect()
end

return Computer --hmm