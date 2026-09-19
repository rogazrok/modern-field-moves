-- Instance-local navigation; native map art, names and player marker remain.
return function(mod)
  return function(map, generation)
    if mod.options:get("map_cursor") == "classic" then return end
    local entries = {}
    if generation == 1 then
      if map.mode ~= "grid" then return end -- old caches without coordinates
      for _, loc in ipairs(map.allLocs or map.locs) do entries[#entries+1] = loc end
    else
      local last, first = map:cursorLimits()
      for _, loc in pairs((map.landmarks or {}).landmarks or {}) do
        if loc.index and loc.index >= first and loc.index <= last then entries[#entries+1] = loc end
      end
      table.sort(entries, function(a,b) return a.index < b.index end)
    end
    local valid = {}
    for _, loc in ipairs(entries) do
      if type(loc.x)=="number" and type(loc.y)=="number" then valid[#valid+1]=loc end
    end
    if #valid==0 then return end
    local initial = generation==1 and map.locs[map.sel] or map:mapLandmark()
    if not initial or not initial.x or not initial.y then initial=valid[1] end
    local step = generation==1 and 1 or 4
    local cursor = { x=initial.x, y=initial.y, name="" }
    map.freeCursor=cursor
    local function resolve()
      map.hoverLocation=nil
      for _, loc in ipairs(valid) do
        -- Only real engine anchors identify places. Never assign blank sea
        -- or guess long route extents from the nearest town.
        if math.abs(loc.x-cursor.x)<=step/2 and math.abs(loc.y-cursor.y)<=step/2 then
          map.hoverLocation=loc;break
        end
      end
      cursor.name=map.hoverLocation and map.hoverLocation.name or ""
      cursor.index=map.hoverLocation and map.hoverLocation.index or -1
    end
    if generation==1 then
      map.locs[0]=cursor;map.sel=0
    else
      map.mapLandmark=function()return cursor end
      map.mapCursorIndex=function()return cursor.index end
    end
    resolve()
    map.moveFreeCursor=function(self,input)
      local dx,dy=0,0
      local direction, pressed
      for _,key in ipairs({"left","right","up","down"}) do
        if input:wasPressed(key) then direction=key;pressed=true;break end
        if not direction and input.isDown and input:isDown(key) then direction=key end
      end
      if not direction then self.cursorHeld=nil;self.cursorTicks=0;return false end
      if pressed or self.cursorHeld~=direction then
        self.cursorHeld=direction;self.cursorTicks=0
      else
        self.cursorTicks=(self.cursorTicks or 0)+1
        if self.cursorTicks<15 or (self.cursorTicks-15)%4~=0 then return true end
      end
      if direction=="left" then dx=-step
      elseif direction=="right" then dx=step
      elseif direction=="up" then dy=-step
      elseif direction=="down" then dy=step end
      if dx==0 and dy==0 then return false end
      local minX,maxX,minY,maxY=0,15,0,15
      if generation==2 then
        minX,maxX,minY,maxY=8,152,24,136
        for _,loc in ipairs(valid)do
          minX=math.min(minX,loc.x);maxX=math.max(maxX,loc.x)
          minY=math.min(minY,loc.y);maxY=math.max(maxY,loc.y)
        end
      end
      cursor.x=math.max(minX,math.min(maxX,cursor.x+dx))
      cursor.y=math.max(minY,math.min(maxY,cursor.y+dy))
      resolve()
      return true
    end
  end
end
