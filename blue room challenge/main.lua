local mod = RegisterMod('Blue Room Challenge', 1)
local json = require('json')
local game = Game()

mod.blueRoomIndex = nil
mod.onGameStartHasRun = false
mod.curseOfBlueRooms = 'Curse of Blue Rooms!'
mod.curseOfBlueRooms2 = 'Curse of Blue Rooms!!'
mod.curseOfPitchBlack = 'Curse of Pitch Black!'
-- 1 << x is the same as 2 ^ x except that the first returns an integer and the second returns a float
mod.flagCurseOfBlueRooms = 1 << Isaac.GetCurseIdByName(mod.curseOfBlueRooms) - 1
mod.flagCurseOfBlueRooms2 = 1 << Isaac.GetCurseIdByName(mod.curseOfBlueRooms2) - 1
mod.flagCurseOfPitchBlack = 1 << Isaac.GetCurseIdByName(mod.curseOfPitchBlack) - 1
mod.rng = RNG()

mod.difficulty = {
  [Difficulty.DIFFICULTY_NORMAL] = 'normal',
  [Difficulty.DIFFICULTY_HARD] = 'hard',
  [Difficulty.DIFFICULTY_GREED] = 'greed',
  [Difficulty.DIFFICULTY_GREEDIER] = 'greedier'
}

mod.state = {}
mod.state.blueRooms = {}                    -- clear state for blue rooms
mod.state.leaveDoor = DoorSlot.NO_DOOR_SLOT -- bug fix: the game doesn't remember LeaveDoor on continue
mod.state.stageSeed = nil
mod.state.probabilityBlueRooms =  { normal = 3, hard = 20, greed = 0, greedier = 0 }
mod.state.probabilityBlueRooms2 = { normal = 0, hard = 3,  greed = 0, greedier = 0 }
mod.state.probabilityPitchBlack = { normal = 0, hard = 3,  greed = 0, greedier = 0 }
mod.state.overrideCurses = false
mod.state.enableCursesForChallenges = false

function mod:onGameStart(isContinue)
  local level = game:GetLevel()
  local seeds = game:GetSeeds()
  local stageSeed = seeds:GetStageSeed(level:GetStage())
  mod.state.stageSeed = stageSeed
  mod:seedRng()
  
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if math.type(state.stageSeed) == 'integer' then
        -- quick check to see if this is the same run being continued
        if state.stageSeed == stageSeed then
          if type(state.blueRooms) == 'table' then
            mod.state.blueRooms = state.blueRooms
          end
          if math.type(state.leaveDoor) == 'integer' and state.leaveDoor > DoorSlot.NO_DOOR_SLOT and state.leaveDoor < DoorSlot.NUM_DOOR_SLOTS then
            mod.state.leaveDoor = state.leaveDoor
          end
        end
      end
      for _, probability in ipairs({ 'probabilityBlueRooms', 'probabilityBlueRooms2', 'probabilityPitchBlack' }) do
        if type(state[probability]) == 'table' then
          for _, difficulty in ipairs({ 'normal', 'hard', 'greed', 'greedier' }) do
            if math.type(state[probability][difficulty]) == 'integer' and state[probability][difficulty] >= 0 and state[probability][difficulty] <= 100 then
              mod.state[probability][difficulty] = state[probability][difficulty]
            end
          end
        end
      end
      if type(state.overrideCurses) == 'boolean' then
        mod.state.overrideCurses = state.overrideCurses
      end
      if type(state.enableCursesForChallenges) == 'boolean' then
        mod.state.enableCursesForChallenges = state.enableCursesForChallenges
      end
    end
    
    if not isContinue then
      mod:clearBlueRooms()
      mod.state.leaveDoor = level.LeaveDoor
    end
  end
  
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms | mod.flagCurseOfBlueRooms2) or mod:isChallenge() then
    if mod:isBlueRoom(level:GetCurrentRoomDesc()) then
      mod:setBlueRoomIndex()
      mod:setBlueRoomState()
    end
  end
  
  if mod:isChallenge() then
    if not isContinue then -- spawn random boss pool item and book on start
      local itemPool = game:GetItemPool()
      local collectible = itemPool:GetCollectible(ItemPoolType.POOL_BOSS, false, Random(), CollectibleType.COLLECTIBLE_NULL)
      Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, collectible, Vector(280, 280), Vector(0,0), nil) -- game:Spawn
      
      local book = mod:isDarkChallenge() and CollectibleType.COLLECTIBLE_SATANIC_BIBLE or CollectibleType.COLLECTIBLE_BOOK_OF_REVELATIONS
      Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, book, Vector(360, 280), Vector(0,0), nil)
    end
  end
  
  mod.onGameStartHasRun = true
end

function mod:onGameExit()
  mod:SaveData(json.encode(mod.state))
end

function mod:onCurseEval(curses)
  if mod:isChallenge() then
    local flag = mod:isCursedChallenge() and mod.flagCurseOfBlueRooms2 or mod.flagCurseOfBlueRooms
    if mod:isDarkChallenge() then
      flag = flag | mod.flagCurseOfPitchBlack
    end
    
    return curses | flag
  end
  
  if Isaac.GetChallenge() ~= Challenge.CHALLENGE_NULL and not mod.state.enableCursesForChallenges then
    return curses
  end
  
  if curses == LevelCurse.CURSE_NONE or mod.state.overrideCurses then
    if mod.rng:RandomInt(100) < mod.state.probabilityBlueRooms[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfBlueRooms
    elseif mod.rng:RandomInt(100) < mod.state.probabilityBlueRooms2[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfBlueRooms2
    elseif mod.rng:RandomInt(100) < mod.state.probabilityPitchBlack[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfPitchBlack
    end
  end
  
  return curses
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
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms2) or mod:isCursedChallenge() then
    local level = game:GetLevel()
    local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1) -- writeable
    
    if mod:isBlueRoom(roomDesc) then
      roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_CURSED_MIST
    end
  end
end

function mod:onNewRoom()
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1)
  
  mod.state.leaveDoor = level.LeaveDoor
  
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms | mod.flagCurseOfBlueRooms2) or mod:isChallenge() then
    -- this needs to happen in onGameStart the first time (which happens after onNewRoom)
    if mod.onGameStartHasRun then
      if mod:isBlueRoom(roomDesc) then
        mod:setBlueRoomIndex() -- calculate this once
        mod:setBlueRoomState()
      end
    end
    
    -- set blue room redirect on surrounding rooms
    -- this only works if we're on the grid, otherwise the other end of the blue room might not have a door
    if roomDesc.GridIndex >= 0 and not mod:isMinesEscapeSequence() then
      mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc))
    end
  end
  
  if mod:hasAnyCurse(mod.flagCurseOfPitchBlack) or mod:isDarkChallenge() then
    roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
  end
end

function mod:onUpdate()
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms | mod.flagCurseOfBlueRooms2) or mod:isChallenge() then
    local level = game:GetLevel()
    local roomDesc = level:GetCurrentRoomDesc() -- read-only
    
    if mod:isBlueRoom(roomDesc) then
      mod:setBlueRoomState()
    end
    
    -- this is here because red rooms could be created at any time
    if roomDesc.GridIndex >= 0 and not mod:isMinesEscapeSequence() then
      mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc))
    end
  end
end

function mod:isBlueRoom(roomDesc)
  return roomDesc.Data.Type == RoomType.ROOM_BLUE and roomDesc.GridIndex == GridRooms.ROOM_BLUE_ROOM_IDX
end

function mod:setBlueRoomRedirects(indexes)
  local level = game:GetLevel()
  
  for _, gridIdx in pairs(indexes) do
    if gridIdx >= 0 then
      local roomDesc = level:GetRoomByIdx(gridIdx, -1) -- doc says this always returns an object, check GridIndex
      
      if roomDesc.GridIndex >= 0 then
        if not mod:isBlueRoomClear(mod:mergeIndexes(level:GetCurrentRoomDesc().ListIndex, roomDesc.ListIndex)) then
          roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_BLUE_REDIRECT -- game is responsible for removing this flag
        end
      end
    end
  end
end

function mod:setBlueRoomIndex()
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetPreviousRoomIndex(), -1)
  local gridIdx = mod:getSurroundingGridIndexes(roomDesc)[mod.state.leaveDoor] -- index for room we would have gone to
  
  mod.blueRoomIndex = mod:mergeIndexes(roomDesc.ListIndex, level:GetRoomByIdx(gridIdx, -1).ListIndex)
end

function mod:setBlueRoomState()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  mod.state.blueRooms[mod.blueRoomIndex] = roomDesc.Clear
end

function mod:isBlueRoomClear(index)
  return mod.state.blueRooms[index]
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

function mod:mergeIndexes(index1, index2)
  local low, high
  if index1 < index2 then
    low = index1
    high = index2
  else
    low = index2
    high = index1
  end
  return low .. '-' .. high
end

function mod:seedRng()
  repeat
    local rand = Random()  -- 0 to 2^32
    if rand > 0 then       -- if this is 0, it causes a crash later on
      mod.rng:SetSeed(rand, 1)
    end
  until(rand > 0)
end

function mod:isMinesEscapeSequence()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local roomDesc = level:GetCurrentRoomDesc()
  
  return stage == LevelStage.STAGE2_2 and (stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B) and mod:getDimension(roomDesc) == 1
end

function mod:getDimension(roomDesc)
  local level = game:GetLevel()
  local ptrHash = GetPtrHash(roomDesc)
  
  -- 0: main dimension
  -- 1: secondary dimension, used by downpour mirror dimension and mines escape sequence
  -- 2: death certificate dimension
  for i = 0, 2 do
    if ptrHash == GetPtrHash(level:GetRoomByIdx(roomDesc.SafeGridIndex, i)) then
      return i
    end
  end
  return -1
end

function mod:hasAnyCurse(curse)
  local level = game:GetLevel()
  local curses = level:GetCurses()
  
  return mod:hasAnyFlag(curses, curse)
end

function mod:hasAnyFlag(flags, flag)
  return flags & flag ~= 0
end

function mod:isChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

function mod:isCursedChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

function mod:isDarkChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)')
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  ModConfigMenu.AddSetting(
    mod.Name,
    'Curses',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.overrideCurses
      end,
      Display = function()
        return (mod.state.overrideCurses and 'Override' or 'Respect') .. ' curses'
      end,
      OnChange = function(b)
        mod.state.overrideCurses = b
      end,
      Info = { 'The game may have already set a curse', 'Should we respect it or potentially override it?' }
    }
  )
  ModConfigMenu.AddSetting(
    mod.Name,
    'Curses',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.enableCursesForChallenges
      end,
      Display = function()
        return (mod.state.enableCursesForChallenges and 'Enable' or 'Disable') .. ' these curses for challenges'
      end,
      OnChange = function(b)
        mod.state.enableCursesForChallenges = b
      end,
      Info = { 'Can other challenges potentially get the curses listed below?' }
    }
  )
  ModConfigMenu.AddSpace(mod.Name, 'Curses')
  for i, probability in ipairs({ 'probabilityBlueRooms', 'probabilityBlueRooms2', 'probabilityPitchBlack' }) do
    if i == 1 then
      ModConfigMenu.AddTitle(mod.Name, 'Curses', mod.curseOfBlueRooms)
    elseif i == 2 then
      ModConfigMenu.AddTitle(mod.Name, 'Curses', mod.curseOfBlueRooms2)
    else -- 3
      ModConfigMenu.AddTitle(mod.Name, 'Curses', mod.curseOfPitchBlack)
    end
    for _, difficulty in ipairs({ 'normal', 'hard', 'greed', 'greedier' }) do
      ModConfigMenu.AddSetting(
        mod.Name,
        'Curses',
        {
          Type = ModConfigMenu.OptionType.NUMBER,
          CurrentSetting = function()
            return mod.state[probability][difficulty]
          end,
          Minimum = 0,
          Maximum = 100,
          Display = function()
            return difficulty .. ': ' .. mod.state[probability][difficulty] .. '%'
          end,
          OnChange = function(n)
            mod.state[probability][difficulty] = n
          end,
          Info = { 'The curses here are evaluated in order' }
        }
      )
    end
    if i ~= 3 then
      ModConfigMenu.AddSpace(mod.Name, 'Curses')
    end
  end
end
-- end ModConfigMenu --

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, mod.onCurseEval)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.onNewLevel)
mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.onPreNewRoom) -- fires 0-n times per new room, 1-n for blue rooms
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)

if ModConfigMenu then
  mod:setupModConfigMenu()
end