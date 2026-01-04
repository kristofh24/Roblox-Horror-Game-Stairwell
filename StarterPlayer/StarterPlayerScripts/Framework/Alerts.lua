-- @ScriptType: ModuleScript
local Alerts={}
Alerts.__index=Alerts

local rs=game:GetService("RunService")

function Alerts.new()
	local self=setmetatable({},Alerts)
	
	self.container=nil
	
	self.cur_alert=nil --maybe make them local vars only
	self.queue={}
	
	rs.RenderStepped:Connect(function()
		if self.queue[1]~=self.cur_alert and self.queue[1]~=nil then
			--show next alert in queue
			self.cur_alert=self.queue[1]
			
			local alert=script.Alert:Clone()
			alert.Text=self.cur_alert[1]
			alert.TextColor3=self.cur_alert[2]
			alert.Parent=self.container
			
			--[[for i=0,string.len(self.cur_alert[1]) do
				alert.MaxVisibleGraphemes=i
				task.wait()
			end]]
			
			task.wait(self.cur_alert[3])
			
			alert:Destroy()
			
			table.remove(self.queue,1)
		end
	end)
	
	return self
end

function Alerts:QueueAlert(txt: string,col: Color3?,t: number?)
	table.insert(self.queue,{txt,col or Color3.fromRGB(255,255,255),t or 3})
end

return Alerts.new()