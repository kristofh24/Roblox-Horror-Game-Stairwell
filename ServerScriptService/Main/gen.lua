-- @ScriptType: ModuleScript
-- Module used for map generation
-- Contains functions to both generate structure and then populate with items and runtime values

local tiles=workspace.Tiles

local wait_t=.05

-- // LOCAL FUNCTIONS \\ --

function extract_comp(t: Model,str: string,dest: Object)
	for i,v in pairs(t:GetChildren()) do
		if v.Name==str then
			v.Parent=dest
		end
	end
end

function gen_rooms(seed: number?,req_comps: number,max_depth: number?)
	local rand=Random.new(seed)
	local count=0

	local comps=req_comps

	local overlap_cont=Instance.new("Folder")
	overlap_cont.Parent=workspace
	overlap_cont.Name="Overlaps"

	script.Pivots:ClearAllChildren() --needed?

	--start room
	local start=tiles.Start:GetChildren()[rand:NextInteger(1,#tiles.Start:GetChildren())]:Clone()
	start.Parent=workspace.Map.MAP_TEST --for now
	start.Name="START"
	start:PivotTo(CFrame.new(0,125,0)) --temp position

	extract_comp(start,"PivotP",script.Pivots)
	extract_comp(start,"Overlap",overlap_cont)

	task.wait(wait_t)

	--tiles
	repeat
		--pivot points are where tiles connect
		local p=script.Pivots:GetChildren()[rand:NextInteger(1,#script.Pivots:GetChildren())]
		
		--prevent deadends from occuring too early on in map generation
		local deadend=count>5 and rand:NextInteger(1,100)<25 or false --25% chance for deadend?

		local tile
		local attempts=10 -- 10 attempts to place an appropriate room tile; give up after 10 attemps and move on
		while true do
			task.wait(wait_t) --hmm?

			attempts-=1
			if attempts<=0 then
				break
			end

			local f=deadend and tiles.Deadend or tiles.Generic
			if deadend and comps>0 then
				f=tiles.Computer
			end
			tile=f:GetChildren()[rand:NextInteger(1,#f:GetChildren())]:Clone()
			tile.Parent=workspace.Map.MAP_TEST --for now

			--choose pivot
			local pivots={}
			local c_overlaps={}
			for i,v in pairs(tile:GetChildren()) do
				if v.Name=="Overlap" then
					table.insert(c_overlaps,v)
				elseif v.Name=="PivotP" then
					table.insert(pivots,v)
				end
			end
			tile.PrimaryPart=pivots[rand:NextInteger(1,#pivots)]

			tile:PivotTo(p.CFrame*CFrame.Angles(0,math.rad(180),0))
			tile.PrimaryPart:Destroy()
			
			--check for overlaps --> if chosen tile creates an overlap, pick another one
			local overlaps=overlap_cont:GetChildren()
			local params=OverlapParams.new()
			params.FilterType=Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances={overlap_cont}
			params.MaxParts=5 --ig
			params.RespectCanCollide=false

			local collisions={}
			for i,v in pairs(c_overlaps) do
				local results=workspace:GetPartsInPart(v,params)
				for a,b in pairs(results) do
					table.insert(collisions,b)
				end
			end

			if #collisions>0 then
				--warn("OVERLAP") --?
				tile:Destroy()
				continue
			end

			break
		end
		if (attempts<=0) then
			--create a locked door? or block with a wall?
			p:Destroy()
			continue
		end

		--temp
		if deadend and comps>0 then print("COMP")
		elseif deadend then print("DEADEND") end

		if deadend and comps>0 then comps-=1 end

		extract_comp(tile,"PivotP",script.Pivots)
		extract_comp(tile,"Overlap",overlap_cont)

		local d=script.Door:Clone()
		d.Parent=tile
		d.Name="_Door"
		d:PivotTo(p.CFrame)

		p:Destroy()

		count+=1

		task.wait(wait_t)
	until #script.Pivots:GetChildren()==0 or (max_depth and count>=max_depth) --TEMP

	overlap_cont:Destroy()

	return count,req_comps-comps
end

function populate_map()
	for i,v in pairs(workspace.Map.MAP_TEST:GetDescendants()) do
		--update door and vent hinge and drawer and electrical box original vals --> used for animation consistency
		if v.Name=="Original" and v:IsA("CFrameValue") then
			if v.Parent:IsA("Model") then
				v.Value=v.Parent:GetPivot()
			else
				v.Value=v.Parent.CFrame
			end
		end
	end
end

-- // MODULE \\ --

local gen={}
gen.gen_map=function()
	local depth_reached,comps=0,0
	while true do --??
		local r=5
		depth_reached,comps=gen_rooms(nil,r,35)
		print("depth: ",depth_reached)
		print("comps: ",comps)
		if depth_reached>=20 and comps==r then -- keep retrying until requirements are reached
			break
		end
		
		workspace.Map.MAP_TEST:ClearAllChildren()
	end
	populate_map()
end
return gen