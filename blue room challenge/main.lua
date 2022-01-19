local mod = RegisterMod('Blue Room Challenge', 1)
local json = require('json')
local game = Game()

mod.blueRoomIndex = -1

mod.state = {}
mod.state.blueRooms = {} -- clear state for blue rooms
mod.state.stageSeed = nil

function mod:onGameStart(isContinue)
  local level = game:GetLevel()
  local seeds = game:GetSeeds()
  local stageSeed = seeds:GetStageSeed(level:GetStage())
  mod.state.stageSeed = stageSeed
  
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if math.type(state.stageSeed) == 'integer' and type(state.blueRooms) == 'table' then
        -- quick check to see if this is the same run being continued
        if state.stageSeed == stageSeed then
          mod.state.blueRooms = state.blueRooms
        end
      end
    end
    
    if not isContinue then
      mod:clearBlueRooms()
    end
  end
  
  if not mod:isChallenge() then
    return
  end
  
  -- spawn random boss pool item and book on start
  if not isContinue then
    local itemPool = game:GetItemPool()
    local collectible = itemPool:GetCollectible(ItemPoolType.POOL_BOSS, false, Random(), CollectibleType.COLLECTIBLE_NULL)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, collectible, Vector(280, 280), Vector(0,0), nil) -- game:Spawn
    
    local book = mod:isDarkChallenge() and CollectibleType.COLLECTIBLE_SATANIC_BIBLE or CollectibleType.COLLECTIBLE_BOOK_OF_REVELATIONS
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, book, Vector(360, 280), Vector(0,0), nil)
  end
end

function mod:onGameExit()
  mod:SaveData(json.encode(mod.state))
end

function mod:onNewLevel()
  local level = game:GetLevel()
  local seeds = game:GetSeeds()
  local stageSeed = seeds:GetStageSeed(level:GetStage())
  mod.state.stageSeed = stageSeed
  mod:clearBlueRooms()
end

-- onNewRoom doesn't enable FLAG_CURSED_MIST quickly enough
function mod:onPreNewRoom()
  if not mod:isCursedChallenge() then
    return
  end
  
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1) -- writeable
  
  -- if blue room
  if roomDesc.Data.Type == RoomType.ROOM_BLUE and roomDesc.GridIndex == GridRooms.ROOM_BLUE_ROOM_IDX then
    roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_CURSED_MIST
  end
end

function mod:onNewRoom()
  if not mod:isChallenge() then
    return
  end
  
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1)
  
  if roomDesc.Data.Type == RoomType.ROOM_BLUE and roomDesc.GridIndex == GridRooms.ROOM_BLUE_ROOM_IDX then
    mod.blueRoomIndex = mod:getBlueRoomIndex() -- calculate this once
    mod.state.blueRooms[mod.blueRoomIndex] = roomDesc.Clear
  end
  
  -- set blue room redirect on surrounding rooms
  -- this only works if we're on the grid, otherwise the other end of the blue room might not have a door
  if roomDesc.GridIndex >= 0 then
    mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc))
  end
  
  if not mod:isDarkChallenge() then
    return
  end
  
  roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
end

function mod:onUpdate()
  if not mod:isChallenge() then
    return
  end
  
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc() -- read-only
  
  if roomDesc.Data.Type == RoomType.ROOM_BLUE and roomDesc.GridIndex == GridRooms.ROOM_BLUE_ROOM_IDX then
    mod.state.blueRooms[mod.blueRoomIndex] = roomDesc.Clear
  end
  
  -- this is here because red rooms could be created at any time
  if roomDesc.GridIndex >= 0 then
    mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc))
  end
end

function mod:getBlueRoomIndex()
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetPreviousRoomIndex(), -1)
  local gridIdx = mod:getSurroundingGridIndexes(roomDesc)[level.LeaveDoor] -- index for room we would have gone to
  return mod:mergeIndexes(roomDesc.ListIndex, level:GetRoomByIdx(gridIdx, -1).ListIndex)
end

function mod:setBlueRoomRedirects(indexes)
  local level = game:GetLevel()
  
  for _, gridIdx in pairs(indexes) do
    if gridIdx >= 0 then
      local roomDesc = level:GetRoomByIdx(gridIdx, -1) -- doc says this always returns an object, check GridIndex
      
      if roomDesc.GridIndex >= 0 then
        if not mod.state.blueRooms[mod:mergeIndexes(level:GetCurrentRoomDesc().ListIndex, roomDesc.ListIndex)] then
          roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_BLUE_REDIRECT -- game is responsible for removing this flag
        end
      end
    end
  end
end

function mod:clearBlueRooms()
  for key, _ in pairs(mod.state.blueRooms) do
    mod.state.blueRooms[key] = nil
  end
end

function mod:getSurroundingGridIndexes(roomDesc)
  local indexes = {}
  local shape = roomDesc.Data.Shape
  
  if shape == RoomShape.ROOMSHAPE_1x1 then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13
  elseif shape == RoomShape.ROOMSHAPE_IH then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1
  elseif shape == RoomShape.ROOMSHAPE_IV then
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13
  elseif shape == RoomShape.ROOMSHAPE_1x2 then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13 - 1
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_IIV then
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
  elseif shape == RoomShape.ROOMSHAPE_2x1 then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13
    indexes[DoorSlot.UP1] = roomDesc.GridIndex - 13 + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_IIH then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
  elseif shape == RoomShape.ROOMSHAPE_2x2 then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13 - 1
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1 + 1
    indexes[DoorSlot.UP1] = roomDesc.GridIndex - 13 + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_LTL then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13 - 1
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1 + 1
    indexes[DoorSlot.UP1] = roomDesc.GridIndex - 13 + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_LTR then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13 - 1
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1 + 1
    indexes[DoorSlot.UP1] = roomDesc.GridIndex + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_LBL then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1 + 1
    indexes[DoorSlot.UP1] = roomDesc.GridIndex - 13 + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 13 + 1
  elseif shape == RoomShape.ROOMSHAPE_LBR then
    indexes[DoorSlot.LEFT0] = roomDesc.GridIndex - 1
    indexes[DoorSlot.RIGHT0] = roomDesc.GridIndex + 1 + 1
    indexes[DoorSlot.UP0] = roomDesc.GridIndex - 13
    indexes[DoorSlot.DOWN0] = roomDesc.GridIndex + 13 + 13
    indexes[DoorSlot.LEFT1] = roomDesc.GridIndex + 13 - 1
    indexes[DoorSlot.RIGHT1] = roomDesc.GridIndex + 13 + 1
    indexes[DoorSlot.UP1] = roomDesc.GridIndex - 13 + 1
    indexes[DoorSlot.DOWN1] = roomDesc.GridIndex + 13 + 1
  end
  
  return indexes
end

function mod:mergeIndexes(i1, i2)
  local low, high
  if i1 < i2 then
    low = i1
    high = i2
  else
    low = i2
    high = i1
  end
  return low .. '-' .. high
end

function mod:isChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

function mod:isDarkChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

function mod:isCursedChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.onNewLevel)
mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.onPreNewRoom) -- fires 0-n times per new room, 1-n for blue rooms
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)