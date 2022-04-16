local libName, libVersion = "LibMapData", 100
local lib = {}
_G["LibMapData"] = lib

local GPS = LibGPS3

lib.mapNames = {}
lib.mapNamesLookup = {}
lib.zoneNames = {}
lib.zoneNamesLookup = {}
lib.zoneIndex = nil
lib.mapIndex = nil
lib.mapId = nil
lib.zoneId = nil
lib.mapTexture = nil
lib.isMainZone = nil
lib.isSubzone = nil
lib.isWorld = nil
lib.isDungeon = nil
lib.zoneName = nil
lib.mapName = nil
lib.subzoneName = nil

lib.pseudoMapIndex = nil

lib.MAPINDEX_MIN = 1
lib.MAPINDEX_MAX = 45
lib.MAX_NUM_MAPIDS = 2192
lib.MAX_NUM_ZONEINDEXES = 881
lib.MAX_NUM_ZONEIDS = 1345
-- max zoneId 1345 using valid zoneIndex
--[[
function lib.on_map_zone_changed()
  internal.dm("Debug", "[5] on_map_zone_changed")

  internal.dm("Debug", "[5] Updating last_mapid and current_mapid")
  lib.last_mapid = lib.current_mapid
  lib.last_zone = lib.current_zone
  lib.current_mapid = GetCurrentMapId()
  lib.current_zone = LMP:GetZoneAndSubzone(true, false, true)

  if not lib.last_mapid then
    internal.dm("Debug", "[5] LMP did not set the last_mapid properly")
  end
  if not lib.last_zone then
    internal.dm("Debug", "[5] LMP did not set the last_zone properly")
  end
  if not lib.current_mapid then
    internal.dm("Debug", "[5] LMP did not set the current_mapid properly")
  end
  if not lib.current_zone then
    internal.dm("Debug", "[5] LMP did not set the current_zone properly")
  end

  local temp = string.format("[5] Last Mapid: %s", lib.last_mapid) or "[5] NA"
  internal.dm("Debug", temp)
  local temp = string.format("[5] Last Zone: %s", lib.last_zone) or "[5] NA"
  internal.dm("Debug", temp)
  local temp = string.format("[5] Current Mapid: %s", lib.current_mapid) or "[5] NA"
  internal.dm("Debug", temp)
  local temp = string.format("[5] Current Zone: %s", lib.current_zone) or "[5] NA"
  internal.dm("Debug", temp)
  lib.check_map_state()
end
]]--
local function UpdateMapInfo()
  local zoneIndex = GetCurrentMapZoneIndex()
  local mapIndex = GetCurrentMapIndex()
  local mapId = GetCurrentMapId()
  local zoneId = GetZoneId(zoneIndex)

  lib.zoneIndex = GetCurrentMapZoneIndex()
  lib.mapIndex = GetCurrentMapIndex()
  lib.mapId = GetCurrentMapId()
  lib.zoneId = GetZoneId(zoneIndex)

  local mapTextureByMapId = GetMapTileTextureForMapId(mapId, 1)
  local mapTexture = string.lower(mapTextureByMapId)
  mapTexture = mapTexture:gsub("^.*/maps/", "")
  mapTexture = mapTexture:gsub("%.dds$", "")
  lib.mapTexture = mapTexture

  local name, mapType, mapContentType, zoneIndex, description = GetMapInfoById(mapId)
  lib.isMainZone = mapType == MAPTYPE_ZONE
  lib.isSubzone = mapType == MAPTYPE_SUBZONE
  lib.isWorld = mapType == MAPTYPE_WORLD
  lib.isDungeon = mapContentType == MAP_CONTENT_DUNGEON

  local zoneName = GetZoneNameByIndex(zoneIndex)
  local mapName = GetMapNameById(mapId)
  if not zoneName then zoneName = "[Empty String]" end
  if not mapName then mapName = "[Empty String]" end
  lib.zoneName = zoneName
  lib.mapName = mapName
  local subzoneName = GetPlayerActiveSubzoneName()
  if subzoneName == "" then subzoneName = nil end
  lib.subzoneName = subzoneName
end

local function OnZoneChanged(eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
  UpdateMapInfo()
end
EVENT_MANAGER:RegisterForEvent(libName .. "_zone_changed", EVENT_ZONE_CHANGED, OnZoneChanged)

local function OnPlayerActivated(eventCode, initial)
  if not initial then UpdateMapInfo() end
end
EVENT_MANAGER:RegisterForEvent(libName .. "_activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-----
--- MapNames
-----

local function BuildMapNames()
  local maxMapId = nil
  for i = 1, lib.MAX_NUM_MAPIDS do
    local name, mapType, mapContentType, zoneIndex, description = GetMapInfoById(i)
    if name ~= "" then
      lib.mapNames[i] = name
      if maxMapId == nil or maxMapId < i then maxMapId = i end
    end
  end
end

local function BuildMapNamesLookup()
  local built_table = {}

  for var1, var2 in pairs(lib.mapNames) do
    if built_table[var2] == nil then built_table[var2] = {} end
    built_table[var2] = var1
  end
  lib.mapNamesLookup = built_table
end

-----
--- ZoneNames
-----

local function BuildZoneNames()
  local maxZoneIndex = nil
  local maxZoneId = nil
  local zoneId = nil
  for i = 1, lib.MAX_NUM_ZONEINDEXES do
    local zoneName = GetZoneNameByIndex(i)
    if zoneName ~= "" then
      zoneId = GetZoneId(i)
      lib.zoneNames[i] = zoneName
      if maxZoneIndex == nil or maxZoneIndex < i then maxZoneIndex = i end
      if maxZoneId == nil or maxZoneId < zoneId then maxZoneId = zoneId end
    end
  end
end

local function BuildZoneNamesLookup()
  local built_table = {}

  for var1, var2 in pairs(lib.zoneNames) do
    if built_table[var2] == nil then built_table[var2] = {} end
    built_table[var2] = var1
  end
  lib.zoneNamesLookup = built_table
end

local function GetPlayerPos()
  -- Get location info and format coordinates
  LibMapData:dm("Debug", "-----")
  LibMapData:dm("Debug", "GetPlayerPos")

  local x, y = GetMapPlayerPosition("player")
  local xpos, ypos = GPS:LocalToGlobal(x, y)
  local zone_id, worldX, worldY, worldZ = GetUnitWorldPosition("player")

  LibMapData:dm("Debug", lib.mapTexture)
  if lib.zoneName then LibMapData:dm("Debug", "zoneName: " .. lib.zoneName) end
  if lib.mapName then LibMapData:dm("Debug", "mapName: " .. lib.mapName) end
  if subzoneName then LibMapData:dm("Debug", "***subzoneName: " .. lib.subzoneName) end

  if lib.zoneId then LibMapData:dm("Debug", "ZoneId: " .. lib.zoneId) end
  if lib.mapIndex then LibMapData:dm("Debug", "MapIndex: " .. lib.mapIndex) end
  if lib.mapId then LibMapData:dm("Debug", "mapId: " .. lib.mapId) end
  if lib.zoneIndex then LibMapData:dm("Debug", "zoneIndex: " .. lib.zoneIndex) end
  LibMapData:dm("Debug", "isDungeon: " .. tostring(lib.isDungeon))
  LibMapData:dm("Debug", "isMainZone: " .. tostring(lib.isMainZone))
  LibMapData:dm("Debug", "isSubzone: " .. tostring(lib.isSubzone))
  LibMapData:dm("Debug", "isWorld: " .. tostring(lib.isWorld))
  LibMapData:dm("Debug", "X: " .. x)
  LibMapData:dm("Debug", "Y: " .. y)
  LibMapData:dm("Debug", "GPS X: " .. xpos)
  LibMapData:dm("Debug", "GPS Y: " .. ypos)
  LibMapData:dm("Debug", "worldX: " .. worldX)
  LibMapData:dm("Debug", "worldY: " .. worldY)
  LibMapData:dm("Debug", "worldZ: " .. worldZ)

  --local distance = zo_round(GPS:GetLocalDistanceInMeters(0.62716490030289, 0.56329780817032, 0.62702748199203, 0.61508411169052))
  --d(distance)

  --local distance = zo_round(GPS:GetLocalDistanceInMeters(0.62716490030289, 0.56329780817032, 0.63227427005768, 0.70292204618454))
  --d(distance)

  --local distance = zo_round(GPS:GetLocalDistanceInMeters(0.6324172616, 0.7026107907, 0.63227427005768, 0.70292204618454))
  --d(distance)
  --local distance = zo_round(GPS:GetLocalDistanceInMeters(0.6500588655, 0.6869461536, 0.63227427005768, 0.70292204618454))
  --d(distance)

  --local distance = zo_round(GPS:GetLocalDistanceInMeters(0.6388558745, 0.5947756767, 0.63227427005768, 0.70292204618454))
  --d(distance)
end

local function OnAddOnLoaded(eventCode, addonName)
  if addonName == libName then
    EVENT_MANAGER:UnregisterForEvent(libName .. "_onload", EVENT_ADD_ON_LOADED)

    SLASH_COMMANDS["/lmdgetpos"] = function() GetPlayerPos() end -- used

    UpdateMapInfo()
    BuildMapNames()
    BuildMapNamesLookup()
    BuildZoneNames()
    BuildZoneNamesLookup()
  end
end
EVENT_MANAGER:RegisterForEvent(libName .. "_onload", EVENT_ADD_ON_LOADED, OnAddOnLoaded)

CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
  UpdateMapInfo()
end)

WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
  if newState == SCENE_SHOWING then
    UpdateMapInfo()
  elseif newState == SCENE_HIDDEN then
    UpdateMapInfo()
  end
end)

if LibDebugLogger then
  local logger = LibDebugLogger.Create(libName)
  LibMapData.logger = logger
end

local function create_log(log_type, log_content)
  if not DebugLogViewer and log_type == "Info" then
    CHAT_ROUTER:AddSystemMessage(log_content)
    return
  end
  if not LibDebugLogger then return end
  if log_type == "Debug" then
    LibMapData.logger:Debug(log_content)
  end
  if log_type == "Info" then
    LibMapData.logger:Info(log_content)
  end
  if log_type == "Verbose" then
    LibMapData.logger:Verbose(log_content)
  end
  if log_type == "Warn" then
    LibMapData.logger:Warn(log_content)
  end
end

local function emit_message(log_type, text)
  if (text == "") then
    text = "[Empty String]"
  end
  create_log(log_type, text)
end

local function emit_table(log_type, t, indent, table_history)
  indent = indent or "."
  table_history = table_history or {}

  for k, v in pairs(t) do
    local vType = type(v)

    emit_message(log_type, indent .. "(" .. vType .. "): " .. tostring(k) .. " = " .. tostring(v))

    if (vType == "table") then
      if (table_history[v]) then
        emit_message(log_type, indent .. "Avoiding cycle on table...")
      else
        table_history[v] = true
        emit_table(log_type, v, indent .. "  ", table_history)
      end
    end
  end
end

function LibMapData:dm(log_type, ...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if (type(value) == "table") then
      emit_table(log_type, value)
    else
      emit_message(log_type, tostring(value))
    end
  end
end
