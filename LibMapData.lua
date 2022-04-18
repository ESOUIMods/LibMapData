local libName, libVersion = "LibMapData", 100
local lib = {}
local internal = {}
_G["LibMapData"] = lib
_G["LibMapData_Internal"] = internal

local GPS = LibGPS3

lib.mapNames = {}
lib.mapNamesLookup = {}
lib.zoneNames = {}
lib.zoneNamesLookup = {}
lib.textureNames = {}
lib.textureNamesLookup = {}
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
lib.currentFloor = nil
lib.numFloors = nil

lib.pseudoMapIndex = nil

lib.MAPINDEX_MIN = 1
lib.MAPINDEX_MAX = 45
lib.MAX_NUM_MAPIDS = 2192
lib.MAX_NUM_ZONEINDEXES = 881
lib.MAX_NUM_ZONEIDS = 1345
-- max zoneId 1345 using valid zoneIndex

-----
--- API functions
-----
-- /script d(LibMapData:GetMapIdByTileTexture("blackwood/arpenial3_base_0"))
-- /script d(GetMapTileTextureForMapId(1490, 1))
function lib:GetMapIdByTileTexture(tileTexture)
  if lib.textureNamesLookup[tileTexture] then return lib.textureNamesLookup[tileTexture] end
end

function lib:GetMapIdByMapName(mapName)
  if lib.mapNamesLookup[mapName] then return lib.mapNamesLookup[mapName] end
end

function lib:ReturnSingleIndex(indexTable)
  if not indexTable then
    internal:dm("Warn", "ReturnSingleIndex Failed, no indexes found or table is nil")
    return
  end
  if NonContiguousCount(indexTable) == 1 then return indexTable[1]
  elseif NonContiguousCount(indexTable) > 1 then
    internal:dm("Warn", "ReturnSingleIndex Failed, multiple indexes found")
    return
  end
end

-----
--- Utility functions
-----

function internal:SetPlayerLocation()
  local originalMap = GetMapTileTexture()
  if SetMapToPlayerLocation() == SET_MAP_RESULT_FAILED then
    internal:dm("Warn", "SetMapToPlayerLocation Failed")
  end
  if GetMapTileTexture() ~= originalMap then
    CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
  end
  -- SET_MAP_RESULT_CURRENT_MAP_UNCHANGED
end

function internal:UpdateMapInfo()
  local zoneIndex = GetCurrentMapZoneIndex()
  local mapIndex = GetCurrentMapIndex()
  local mapId = GetCurrentMapId()
  local zoneId = GetZoneId(zoneIndex)
  local currentFloor, numFloors = GetMapFloorInfo()

  lib.zoneIndex = zoneIndex
  lib.mapIndex = mapIndex
  lib.mapId = mapId
  lib.zoneId = zoneId
  if numFloors > 0 then lib.currentFloor = currentFloor else lib.currentFloor = nil end

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
  internal:dm("Debug", "OnZoneChanged")
  internal:SetPlayerLocation()
  internal:UpdateMapInfo()
end
EVENT_MANAGER:RegisterForEvent(libName .. "_zone_changed", EVENT_ZONE_CHANGED, OnZoneChanged)

local function OnPlayerActivated(eventCode, initial)
  if not initial then
    internal:SetPlayerLocation()
    internal:UpdateMapInfo()
  end
end
EVENT_MANAGER:RegisterForEvent(libName .. "_activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-----
--- Check for multiple MapNames with different IDs
-----

function internal:ContainsIndex(indexTable, indexToFind)
  if not indexToFind then return true end
  local foundId = false
  for mapName, indexes in pairs(indexTable) do
    -- internal:dm("Debug", mapName)
    for _, index in pairs(indexes) do
      -- internal:dm("Debug", index)
      if index == indexToFind then
        foundId = true
      end
    end
  end
  return foundId
end

function internal:TableContainsIndex(indexTable, indexToFind)
  if not indexToFind then return true end
  local foundId = false
  for _, index in pairs(indexTable) do
    -- internal:dm("Debug", index)
    if index == indexToFind then
      foundId = true
    end
  end
  return foundId
end
-----
--- MapNames
-----

local function BuildMapNames()
  local maxMapId = nil
  local mapName
  for i = 1, lib.MAX_NUM_MAPIDS do
    mapName = GetMapNameById(i)
    if mapName ~= "" then
      lib.mapNames[i] = mapName
      if maxMapId == nil or maxMapId < i then maxMapId = i end
    end
  end
end

--[[ this lookup builds a table for each map name containing all the
different mapIds of the same map name. ]]--
local function BuildMapNamesLookup()
  local built_table = {}

  for var1, var2 in pairs(lib.mapNames) do
    if built_table[var2] == nil then built_table[var2] = {} end
    if internal:ContainsIndex(built_table, var1) then
      -- internal:dm("Debug", "Var 1 is in ids")
    else
      -- internal:dm("Debug", "Var 1 is not in ids")
      table.insert(built_table[var2], var1)
    end
  end
  lib.mapNamesLookup = built_table
  lib.mapNames = { } -- clear because you can use the API GetMapNameById(mapId)
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
  lib.zoneNames = { } -- clear because you can use the API GetZoneNameByIndex(zoneIndex)
end

-----
--- Texture Names
-----

local function BuildMapTextureNames()
  local textureName = nil
  local mapTexture
  for i = 1, lib.MAX_NUM_MAPIDS do
    textureName = GetMapTileTextureForMapId(i)
    if textureName ~= "" then
      mapTexture = string.lower(textureName)
      mapTexture = mapTexture:gsub("^.*/maps/", "")
      mapTexture = mapTexture:gsub("%.dds$", "")
      lib.textureNames[i] = mapTexture
    end
  end
end

local function BuildMapTextureNamesLookup()
  local built_table = {}

  for var1, var2 in pairs(lib.textureNames) do
    if built_table[var2] == nil then built_table[var2] = {} end
    if internal:ContainsIndex(built_table, var1) then
      -- internal:dm("Debug", "Var 1 is in ids")
    else
      -- internal:dm("Debug", "Var 1 is not in ids")
      table.insert(built_table[var2], var1)
    end
  end
  lib.textureNamesLookup = built_table
  lib.textureNames = { } -- clear because you can use the API GetMapTileTextureForMapId(mapId, tileIndex)
end

local function GetPlayerPos()
  internal:dm("Debug", "-----")
  internal:dm("Debug", "GetPlayerPos")
  internal:SetPlayerLocation()
  internal:UpdateMapInfo()

  local x, y = GetMapPlayerPosition("player")
  local xpos, ypos = GPS:LocalToGlobal(x, y)
  local zone_id, worldX, worldY, worldZ = GetUnitWorldPosition("player")

  internal:dm("Debug", lib.mapTexture)
  if lib.zoneName then internal:dm("Debug", "zoneName: " .. lib.zoneName) end
  if lib.mapName then internal:dm("Debug", "mapName: " .. lib.mapName) end
  if subzoneName then internal:dm("Debug", "***subzoneName: " .. lib.subzoneName) end

  if lib.zoneId then internal:dm("Debug", "ZoneId: " .. lib.zoneId) end
  if lib.mapIndex then internal:dm("Debug", "MapIndex: " .. lib.mapIndex) end
  if lib.mapId then internal:dm("Debug", "mapId: " .. lib.mapId) end
  if lib.zoneIndex then internal:dm("Debug", "zoneIndex: " .. lib.zoneIndex) end
  internal:dm("Debug", "isDungeon: " .. tostring(lib.isDungeon))
  internal:dm("Debug", "isMainZone: " .. tostring(lib.isMainZone))
  internal:dm("Debug", "isSubzone: " .. tostring(lib.isSubzone))
  internal:dm("Debug", "isWorld: " .. tostring(lib.isWorld))
  if lib.currentFloor then
    local floorString = string.format("currentFloor: %d of %d", lib.currentFloor, lib.numFloors)
    internal:dm("Debug", floorString)
  end
  internal:dm("Debug", "X: " .. x)
  internal:dm("Debug", "Y: " .. y)
  internal:dm("Debug", "GPS X: " .. xpos)
  internal:dm("Debug", "GPS Y: " .. ypos)
  internal:dm("Debug", "worldX: " .. worldX)
  internal:dm("Debug", "worldY: " .. worldY)
  internal:dm("Debug", "worldZ: " .. worldZ)

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

    SLASH_COMMANDS["/lmdupdate"] = function() internal:UpdateMapInfo() end -- used

    internal:SetPlayerLocation()
    internal:UpdateMapInfo()
    BuildMapNames()
    BuildMapNamesLookup()
    BuildZoneNames()
    BuildZoneNamesLookup()
    BuildMapTextureNames()
    BuildMapTextureNamesLookup()
  end
end
EVENT_MANAGER:RegisterForEvent(libName .. "_onload", EVENT_ADD_ON_LOADED, OnAddOnLoaded)

CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
  internal:UpdateMapInfo()
end)

WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
  if newState == SCENE_SHOWING then
    internal:UpdateMapInfo()
  elseif newState == SCENE_HIDDEN then
    internal:SetPlayerLocation()
    internal:UpdateMapInfo()
  end
end)

if LibDebugLogger then
  local logger = LibDebugLogger.Create(libName)
  lib.logger = logger
end

local function create_log(log_type, log_content)
  if not DebugLogViewer and log_type == "Info" then
    CHAT_ROUTER:AddSystemMessage(log_content)
    return
  end
  if not LibDebugLogger then return end
  if log_type == "Debug" then
    lib.logger:Debug(log_content)
  end
  if log_type == "Info" then
    lib.logger:Info(log_content)
  end
  if log_type == "Verbose" then
    lib.logger:Verbose(log_content)
  end
  if log_type == "Warn" then
    lib.logger:Warn(log_content)
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

function internal:dm(log_type, ...)
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if (type(value) == "table") then
      emit_table(log_type, value)
    else
      emit_message(log_type, tostring(value))
    end
  end
end
