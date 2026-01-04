-- @ScriptType: ModuleScript
local Functions={}

Functions.round=function(n: number): number
	return math.floor(n+.5)
end

Functions.lerp=function(a: number,b: number,c: number): number
	return a+(b-a)*c
end

Functions.play_sound=function(id: number,vol: number?,spd: number?,name: string?,group: string?,region: {number}?)
	local snd=Instance.new("Sound")
	snd.Name=name or "GENERATED_SFX"
	snd.SoundId="rbxassetid://"..tostring(id)
	snd.TimePosition=0 --necessary??
	snd.Volume=vol or 0.5
	snd.PlaybackSpeed=spd or 1
	snd.SoundGroup=group and game.SoundService[group] or nil
	snd.Parent=script

	if region then
		snd.PlaybackRegionsEnabled=true
		snd.PlaybackRegion=NumberRange.new(unpack(region))
	end

	snd:Play()

	game:GetService("Debris"):AddItem(snd,8) --cleanup (maybe change delay time?)
end

Functions.shuffle=function(arr: {}) --func, tbl, userdata passed by reference; str, num, bool passed by value
	local j,temp
	for i=#arr,1,-1 do
		j=math.random(i)
		temp=arr[i]
		arr[i]=arr[j]
		arr[j]=temp
	end
end

Functions.random_real=function(a: number,b: number,f: number?,rand: Random?): number
	if not f then f=1000 end
	if not rand then rand=Random.new() end
	return rand:NextInteger(a*f,b*f)/f
end

Functions.random_weighted=function(arr: {[any]: number},rand: Random?): any
	if not rand then rand=Random.new() end
	
	local ind
	
	local s=0
	for _,v in pairs(arr) do s+=v end
	local n=rand:NextInteger(1,s)-1 --sub 1 to include 0, exclude s
	local t=0
	for i,v in pairs(arr) do
		t+=v
		if t>n then
			ind=i
			break
		end
	end
	
	return ind
end

--ew
Functions.renderRay=function(origin,destination,color,width,height)
	local dist=(origin-destination).Magnitude

	local p=Instance.new("Part")
	p.Anchored=true
	p.CanCollide=false
	p.Color=color or Color3.fromRGB(255,0,0)
	p.Material=Enum.Material.Neon
	p.Size=Vector3.new(width or .1,height or .1,dist)
	p.CFrame=CFrame.lookAt(origin,destination)*CFrame.new(0,0,-(dist/2))
	p.Parent=workspace

	return p
end

return Functions