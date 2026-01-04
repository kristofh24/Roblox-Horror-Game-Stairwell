-- @ScriptType: ModuleScript
-- Calculates an arbitrary light value at a given point
-- Designed to be fast and efficient while being precise enough to fit the needs of the game

local LightDetection={}
LightDetection.__index=LightDetection

-- DEBUG VARIABLES --
local exec_times={}
---------------------

local function get_light_cf(light)
	local cf=CFrame.identity
	local par=light.Parent
	
	if par then
		if par:IsA("Attachment") then
			cf=par.WorldCFrame
		elseif par:IsA("BasePart") then
			cf=par.CFrame
		end
	end
	
	return cf
end

function LightDetection.new()
	local self=setmetatable({},LightDetection)
	
	self.lights={}
	self.raycast_include={workspace.Map}
	
	for i,v in pairs(workspace:GetDescendants()) do
		if v:IsA("Light") then
			table.insert(self.lights,v)
		end
	end
	
	workspace.DescendantAdded:Connect(function(v)
		if v:IsA("Light") then
			table.insert(self.lights,v)
		end
	end)
	
	workspace.DescendantRemoving:Connect(function(v)
		if v:IsA("Light") then
			local i=table.find(self.lights,v)
			if i then
				table.remove(self.lights,i)
			end
		end
	end)
	
	return self
end

function LightDetection:GetLightLevelAtPoint(p: Vector3,ignore_angle: boolean,ignore_flashlight: boolean?)
	--local DEBUG_t_start=tick()
	if ignore_flashlight==nil then ignore_flashlight=true end --true by default
	
	local lvl=0
	
	for i,v in pairs(self.lights) do
		local l_cf=get_light_cf(v)
		local l_dist=(p-l_cf.Position).Magnitude
		
		if (ignore_flashlight and v.Parent.Name=="Flashlight") or v.Enabled==false then
			continue
		end
		
		if game:GetService("RunService"):IsClient() and v.Parent.Name=="Flashlight" and v.Parent.Parent.Name=="Camera" then
			continue
		end
		
		if l_dist<=v.Range then
			local params=RaycastParams.new()
			params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances=self.raycast_include
			local ray=workspace:Raycast(p,l_cf.Position-p,params)
			
			if not ray then
				if not ignore_angle and (v:IsA("SpotLight") or v:IsA("SurfaceLight")) then
					local vec=l_cf.LookVector
					
					if v.Face==Enum.NormalId.Bottom then vec=-l_cf.UpVector
					elseif v.Face==Enum.NormalId.Top then vec=l_cf.UpVector
					elseif v.Face==Enum.NormalId.Front then vec=l_cf.LookVector
					elseif v.Face==Enum.NormalId.Back then vec=-l_cf.LookVector
					elseif v.Face==Enum.NormalId.Left then vec=-l_cf.RightVector
					elseif v.Face==Enum.NormalId.Right then vec=l_cf.RightVector
					end
					
					--print("dot product:",(l_pos-p).Unit:Dot(Vector3.new(0,-1,0)))
					--print("angle:",180-math.deg(math.acos((l_cf.Position-p).Unit:Dot(Vector3.new(0,-1,0)))))
					--[[if 180-math.deg(math.acos((l_cf.Position-p).Unit:Dot(-l_cf.UpVector)))<=v.Angle/2 then
						--print("GREEEN LIGHT")
						lvl+=v.Brightness*((v.Range-l_dist)/v.Range)
					end]]
					
					if 180-math.deg(math.acos((l_cf.Position-p).Unit:Dot(vec)))<=v.Angle/2 then
						lvl+=v.Brightness*((v.Range-l_dist)/v.Range)
					end
				else
					lvl+=v.Brightness*((v.Range-l_dist)/v.Range)
				end
			end
		end
	end
	
	--[[if d then
		local DEBUG_t_end=tick()
		table.insert(exec_times,math.floor((DEBUG_t_end-DEBUG_t_start)*100000)/100) --ms
		if #exec_times>30 then
			repeat
				table.remove(exec_times,1)
			until #exec_times==30
		end
		
		local DEBUG_t_avg=0
		for i,v in pairs(exec_times) do
			DEBUG_t_avg+=v
		end
		DEBUG_t_avg/=#exec_times
		DEBUG_t_avg=math.floor(DEBUG_t_avg*100)/100
		--print("DEBUG: LightDetection:GetLightLevelAtPoint execute time: "..tostring(DEBUG_t).."ms")
		
		return lvl,DEBUG_t_avg
	end]]
		
	return lvl
end

return LightDetection.new()