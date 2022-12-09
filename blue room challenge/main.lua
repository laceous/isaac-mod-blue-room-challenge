local mod = RegisterMod('Blue Room Challenge', 1)
local json = require('json')
local game = Game()

mod.blueRoomIndex = nil
mod.frameCount = 0
mod.onGameStartHasRun = false
mod.hadCurseOfBlueRooms = false
mod.curseOfBlueRooms = 'Curse of Blue Rooms!'
mod.curseOfBlueRooms2 = 'Curse of Blue Rooms!!'
mod.curseOfPitchBlack = 'Curse of Pitch Black!'
-- 1 << x is the same as 2 ^ x except that the first returns an integer and the second returns a float
mod.flagCurseOfBlueRooms = 1 << (Isaac.GetCurseIdByName(mod.curseOfBlueRooms) - 1)
mod.flagCurseOfBlueRooms2 = 1 << (Isaac.GetCurseIdByName(mod.curseOfBlueRooms2) - 1)
mod.flagCurseOfPitchBlack = 1 << (Isaac.GetCurseIdByName(mod.curseOfPitchBlack) - 1)
mod.rngShiftIndex = 35

mod.difficulty = {
  [Difficulty.DIFFICULTY_NORMAL] = 'normal',
  [Difficulty.DIFFICULTY_HARD] = 'hard',
  [Difficulty.DIFFICULTY_GREED] = 'greed',
  [Difficulty.DIFFICULTY_GREEDIER] = 'greedier'
}

mod.state = {}
mod.state.stageSeeds = {}                   -- per stage
mod.state.blueRooms = {}                    -- per stage/type (clear state for blue rooms)
mod.state.pitchBlackRooms = {}              -- per stage/type (which rooms we set pitch black on)
mod.state.leaveDoor = DoorSlot.NO_DOOR_SLOT -- bug fix: the game doesn't remember LeaveDoor on continue
mod.state.probabilityBlueRooms  = { normal = 3, hard = 20, greed = 0, greedier = 0 }
mod.state.probabilityBlueRooms2 = { normal = 0, hard = 3,  greed = 0, greedier = 0 }
mod.state.probabilityPitchBlack = { normal = 0, hard = 3,  greed = 0, greedier = 0 }
mod.state.overrideCurses = false
mod.state.enableCursesForChallenges = false

function mod:onGameStart(isContinue)
  local level = game:GetLevel()
  local stage = level:GetStage()
  local seeds = game:GetSeeds()
  local stageSeed = seeds:GetStageSeed(stage)
  mod:setStageSeed(stageSeed)
  mod:clearBlueRooms(false)
  mod:clearPitchBlackRooms(false)
  
  mod:loadData(isContinue, stageSeed)
  
  if not isContinue and mod:isChallenge() then -- spawn random boss pool item and book on start
    local itemPool = game:GetItemPool()
    local collectible = itemPool:GetCollectible(ItemPoolType.POOL_BOSS, false, Random(), CollectibleType.COLLECTIBLE_NULL)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, collectible, Vector(280, 280), Vector(0,0), nil) -- game:Spawn
    
    local book = mod:isDarkChallenge() and CollectibleType.COLLECTIBLE_SATANIC_BIBLE or CollectibleType.COLLECTIBLE_BOOK_OF_REVELATIONS
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, book, Vector(360, 280), Vector(0,0), nil)
  end
  
  mod.onGameStartHasRun = true
  mod:onNewRoom()
end

function mod:loadData(isContinue, stageSeed)
  local level = game:GetLevel()
  local stage = level:GetStage()
  
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if isContinue and type(state.stageSeeds) == 'table' then
        -- quick check to see if this is the same run being continued
        if state.stageSeeds[tostring(stage)] == stageSeed then
          for key, value in pairs(state.stageSeeds) do
            if type(key) == 'string' and math.type(value) == 'integer' then
              mod.state.stageSeeds[key] = value
            end
          end
          if type(state.blueRooms) == 'table' then
            for key, value in pairs(state.blueRooms) do
              if type(key) == 'string' and type(value) == 'table' then
                mod.state.blueRooms[key] = {}
                for k, v in pairs(value) do
                  if type(k) == 'string' and type(v) == 'boolean' then
                    mod.state.blueRooms[key][k] = v
                  end
                end
              end
            end
          end
          if type(state.pitchBlackRooms) == 'table' then
            for key, value in pairs(state.pitchBlackRooms) do
              if type(key) == 'string' and type(value) == 'table' then
                mod.state.pitchBlackRooms[key] = {}
                for k, v in pairs(value) do
                  if type(k) == 'string' and type(v) == 'boolean' then
                    mod.state.pitchBlackRooms[key][k] = v
                  end
                end
              end
            end
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
  end
end

function mod:onGameExit(shouldSave)
  if shouldSave then
    mod:SaveData(json.encode(mod.state))
    mod:clearStageSeeds()
    mod:clearBlueRooms(true)
    mod:clearPitchBlackRooms(true)
    mod.state.leaveDoor = DoorSlot.NO_DOOR_SLOT
  else
    mod:clearStageSeeds()
    mod:clearBlueRooms(true)
    mod:clearPitchBlackRooms(true)
    mod.state.leaveDoor = DoorSlot.NO_DOOR_SLOT
    mod:SaveData(json.encode(mod.state))
  end
  
  mod.blueRoomIndex = nil
  mod.frameCount = 0
  mod.onGameStartHasRun = false
  mod.hadCurseOfBlueRooms = false
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
    local level = game:GetLevel()
    local stage = level:GetStage()
    local seeds = game:GetSeeds()
    local stageSeed = seeds:GetStageSeed(stage)
    local rng = RNG()
    rng:SetSeed(stageSeed, mod.rngShiftIndex)
    
    if rng:RandomInt(100) < mod.state.probabilityBlueRooms[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfBlueRooms
    elseif rng:RandomInt(100) < mod.state.probabilityBlueRooms2[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfBlueRooms2
    elseif rng:RandomInt(100) < mod.state.probabilityPitchBlack[mod.difficulty[game.Difficulty]] then
      return mod.flagCurseOfPitchBlack
    end
  end
  
  return curses
end

-- onNewRoom doesn't enable FLAG_CURSED_MIST quickly enough
function mod:onPreNewRoom()
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms2) or mod:isCursedChallenge() then
    local level = game:GetLevel()
    local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1) -- writeable
    local stage = level:GetStage()
    
    if mod:isBlueRoom(roomDesc) or (mod:isCursedChallenge() and (mod:isBlueWoom(roomDesc) or stage == LevelStage.STAGE4_3)) then
      roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_CURSED_MIST
    end
  end
end

function mod:onNewRoom()
  -- the game runs in this order: onNewRoom -> onNewLevel -> onGameStart
  -- that order causes issues here so keep a boolean for onGameStart and a different check for isNewLevel
  if not mod.onGameStartHasRun then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc() -- read-only
  
  if mod:isNewLevel() then
    local seeds = game:GetSeeds()
    local stageSeed = seeds:GetStageSeed(level:GetStage())
    mod:setStageSeed(stageSeed)
    mod:clearBlueRooms(false)
    mod:clearPitchBlackRooms(false)
  end
  
  mod:doBlueRoomLogic(true, true)
  mod:doPitchBlackLogic(true)
  
  if mod:isHushChallenge() then
    if mod:isMomsHeart() and room:IsClear() then
      room:TrySpawnBlueWombDoor(false, true, true)
    elseif mod:isBlueWoom(roomDesc) then
      Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, room:GetCenterPos(), true) -- room:SpawnGridEntity
    end
  end
end

function mod:onUpdate()
  -- this is here because red rooms could be created at any time
  mod:doBlueRoomLogic(false, false)
  mod:doPitchBlackLogic(false)
  mod.frameCount = game:GetFrameCount()
end

-- filtered to PICKUP_TROPHY
function mod:onPickupInit(pickup)
  local room = game:GetRoom()
  
  if mod:isHushChallenge() and mod:isMomsHeart() then
    pickup:Remove() -- remove the trophy
    room:TrySpawnBlueWombDoor(true, true, true)
  end
end

function mod:isRewind()
  return game:GetFrameCount() < mod.frameCount
end

function mod:doBlueRoomLogic(setLeaveDoor, setBlueRoomIndex)
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1)
  
  if mod:hasAnyCurse(mod.flagCurseOfBlueRooms | mod.flagCurseOfBlueRooms2) or mod:isChallenge() then
    mod.hadCurseOfBlueRooms = true
    
    if mod:isBlueRoom(roomDesc) then
      if setLeaveDoor then
        if not mod:isRewind() then              -- LeaveDoor is wrong when rewinding
          mod.state.leaveDoor = level.LeaveDoor -- we want the value that was set when we first walked into the blue room, this will sync up with level:GetPreviousRoomIndex
        end
      end
      if setBlueRoomIndex then
        mod:setBlueRoomIndex() -- calculate this once
      end
      mod:setBlueRoomState()
    else
      if mod.blueRoomIndex and mod:isRewind() then -- if rewinding due to glowing hour glass
        mod:setBlueRoomState(false)                -- then set the previous blue room state to false
      end
      mod.blueRoomIndex = nil
    end
    
    -- set blue room redirect on surrounding rooms
    -- this only works if we're on the grid, otherwise the other end of the blue room might not have a door
    if roomDesc.GridIndex >= 0 and not mod:isMinesEscapeSequence() then
      mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc))
    end
  elseif mod.hadCurseOfBlueRooms then -- remove curse condition from game state
    mod.hadCurseOfBlueRooms = false   -- we only need to do this for the current room
    
    if mod:isBlueRoom(roomDesc) and mod:hasAnyFlag(roomDesc.Flags, RoomDescriptor.FLAG_CURSED_MIST) then
      roomDesc.Flags = roomDesc.Flags & ~RoomDescriptor.FLAG_CURSED_MIST
    end
    
    if roomDesc.GridIndex >= 0 and not mod:isMinesEscapeSequence() then
      mod:setBlueRoomRedirects(mod:getSurroundingGridIndexes(roomDesc), true)
    end
  end
end

function mod:doPitchBlackLogic(setFlag)
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetCurrentRoomIndex(), -1)
  
  if mod:hasAnyCurse(mod.flagCurseOfPitchBlack) or mod:isDarkChallenge() then
    if setFlag and not mod:hasAnyFlag(roomDesc.Flags, RoomDescriptor.FLAG_PITCH_BLACK) then -- some rooms set this by default
      mod:setPitchBlackRoomState(true)
      roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_PITCH_BLACK
    end
  else
    local pitchBlackRoomState = mod:getPitchBlackRoomState() -- remove curse condition from game state
    if pitchBlackRoomState == true or (pitchBlackRoomState == false and mod:hasAnyFlag(roomDesc.Flags, RoomDescriptor.FLAG_PITCH_BLACK)) then -- 3 states: true  = we set it
      mod:setPitchBlackRoomState(false)                                                                                                       --           false = we set & unset it, but could be reset by glowing hour glass
      roomDesc.Flags = roomDesc.Flags & ~RoomDescriptor.FLAG_PITCH_BLACK                                                                      --           nil   = we didn't set it
    end
  end
end

function mod:isBlueRoom(roomDesc)
  return roomDesc.Data.Type == RoomType.ROOM_BLUE and roomDesc.GridIndex == GridRooms.ROOM_BLUE_ROOM_IDX
end

function mod:isBlueWoom(roomDesc)
  return roomDesc.GridIndex == GridRooms.ROOM_BLUE_WOOM_IDX
end

function mod:setBlueRoomRedirects(indexes, forceRemoveFlag)
  local level = game:GetLevel()
  
  for _, gridIdx in pairs(indexes) do
    if gridIdx >= 0 then
      local roomDesc = level:GetRoomByIdx(gridIdx, -1) -- doc says this always returns an object, check GridIndex
      
      if roomDesc.GridIndex >= 0 then
        if forceRemoveFlag or mod:isBlueRoomClear(mod:mergeIndexes(level:GetCurrentRoomDesc().ListIndex, roomDesc.ListIndex)) then
          roomDesc.Flags = roomDesc.Flags & ~RoomDescriptor.FLAG_BLUE_REDIRECT
        else
          roomDesc.Flags = roomDesc.Flags | RoomDescriptor.FLAG_BLUE_REDIRECT
        end
      end
    end
  end
end

function mod:setBlueRoomIndex()
  local level = game:GetLevel()
  local roomDesc = level:GetRoomByIdx(level:GetPreviousRoomIndex(), -1)
  local gridIdx = mod:getSurroundingGridIndexes(roomDesc)[mod.state.leaveDoor] -- index for room we would have gone to
  
  if gridIdx and gridIdx >= 0 then
    mod.blueRoomIndex = mod:mergeIndexes(roomDesc.ListIndex, level:GetRoomByIdx(gridIdx, -1).ListIndex)
  else
    mod.blueRoomIndex = nil
  end
end

function mod:setBlueRoomState(override)
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  local stageIndex = mod:getStageIndex()
  if type(mod.state.blueRooms[stageIndex]) ~= 'table' then
    mod.state.blueRooms[stageIndex] = {}
  end
  
  if mod.blueRoomIndex then
    if type(override) == 'boolean' then
      mod.state.blueRooms[stageIndex][mod.blueRoomIndex] = override
    else
      mod.state.blueRooms[stageIndex][mod.blueRoomIndex] = roomDesc.Clear
    end
  end
end

function mod:isBlueRoomClear(index)
  local stageIndex = mod:getStageIndex()
  if type(mod.state.blueRooms[stageIndex]) ~= 'table' then
    return false
  end
  
  return mod.state.blueRooms[stageIndex][index] and true or false -- nil evaluates to false
end

function mod:clearBlueRooms(clearAll)
  if clearAll then
    for key, _ in pairs(mod.state.blueRooms) do
      mod.state.blueRooms[key] = nil
    end
  else
    mod.state.blueRooms[mod:getStageIndex()] = nil
  end
end

function mod:setPitchBlackRoomState(state)
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  local stageIndex = mod:getStageIndex()
  if type(mod.state.pitchBlackRooms[stageIndex]) ~= 'table' then
    mod.state.pitchBlackRooms[stageIndex] = {}
  end
  
  mod.state.pitchBlackRooms[stageIndex][tostring(roomDesc.ListIndex)] = state
end

function mod:getPitchBlackRoomState()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  local stageIndex = mod:getStageIndex()
  if type(mod.state.pitchBlackRooms[stageIndex]) ~= 'table' then
    return nil
  end
  
  return mod.state.pitchBlackRooms[stageIndex][tostring(roomDesc.ListIndex)]
end

function mod:clearPitchBlackRooms(clearAll)
  if clearAll then
    for key, _ in pairs(mod.state.pitchBlackRooms) do
      mod.state.pitchBlackRooms[key] = nil
    end
  else
    mod.state.pitchBlackRooms[mod:getStageIndex()] = nil
  end
end

function mod:getStageIndex()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local isAltStage = level:IsAltStage()
  
  -- home switches these midway through, keep it consistent
  if stage == LevelStage.STAGE8 then
    stageType = StageType.STAGETYPE_ORIGINAL -- normal: STAGETYPE_ORIGINAL -> STAGETYPE_WOTL
    isAltStage = false                       -- normal: false -> true
  end
  
  return game:GetVictoryLap() .. '-' .. stage .. '-' .. stageType .. '-' .. (isAltStage and 1 or 0) .. '-' .. (level:IsPreAscent() and 1 or 0) .. '-' .. (level:IsAscent() and 1 or 0)
end

function mod:setStageSeed(seed)
  local level = game:GetLevel()
  mod.state.stageSeeds[tostring(level:GetStage())] = seed
end

function mod:clearStageSeeds()
  for key, _ in pairs(mod.state.stageSeeds) do
    mod.state.stageSeeds[key] = nil
  end
end

-- this doesn't work in the ascent, but curses don't work in the ascent so this is ok
function mod:isNewLevel()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  
  if roomDesc.GridIndex < 0 then
    return false
  end
  
  local visitedCounts = 0
  local rooms = level:GetRooms()
  
  for i = 0, #rooms - 1 do
    local room = rooms:Get(i)
    visitedCounts = visitedCounts + room.VisitedCount
    if visitedCounts > 1 then
      break
    end
  end
  
  return visitedCounts <= 1
end

function mod:getSurroundingGridIndexes(roomDesc)
  local indexes = {}
  local gridIdx = roomDesc.GridIndex
  local shape = roomDesc.Data.Shape
  
  local left = -1
  local right = 1
  local up = -13
  local down = 13
  
  if shape == RoomShape.ROOMSHAPE_1x1 then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down
  elseif shape == RoomShape.ROOMSHAPE_IH then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right
  elseif shape == RoomShape.ROOMSHAPE_IV then
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down
  elseif shape == RoomShape.ROOMSHAPE_1x2 then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
    indexes[DoorSlot.LEFT1] = gridIdx + down + left
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right
  elseif shape == RoomShape.ROOMSHAPE_IIV then
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
  elseif shape == RoomShape.ROOMSHAPE_2x1 then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down
    indexes[DoorSlot.UP1] = gridIdx + up + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + right
  elseif shape == RoomShape.ROOMSHAPE_IIH then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
  elseif shape == RoomShape.ROOMSHAPE_2x2 then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
    indexes[DoorSlot.LEFT1] = gridIdx + down + left
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right + right
    indexes[DoorSlot.UP1] = gridIdx + up + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + down + right
  elseif shape == RoomShape.ROOMSHAPE_LTL then
    indexes[DoorSlot.LEFT0] = gridIdx
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
    indexes[DoorSlot.UP0] = gridIdx
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
    indexes[DoorSlot.LEFT1] = gridIdx + down + left
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right + right
    indexes[DoorSlot.UP1] = gridIdx + up + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + down + right
  elseif shape == RoomShape.ROOMSHAPE_LTR then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
    indexes[DoorSlot.LEFT1] = gridIdx + down + left
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right + right
    indexes[DoorSlot.UP1] = gridIdx + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + down + right
  elseif shape == RoomShape.ROOMSHAPE_LBL then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down
    indexes[DoorSlot.LEFT1] = gridIdx + down
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right + right
    indexes[DoorSlot.UP1] = gridIdx + up + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + down + right
  elseif shape == RoomShape.ROOMSHAPE_LBR then
    indexes[DoorSlot.LEFT0] = gridIdx + left
    indexes[DoorSlot.RIGHT0] = gridIdx + right + right
    indexes[DoorSlot.UP0] = gridIdx + up
    indexes[DoorSlot.DOWN0] = gridIdx + down + down
    indexes[DoorSlot.LEFT1] = gridIdx + down + left
    indexes[DoorSlot.RIGHT1] = gridIdx + down + right
    indexes[DoorSlot.UP1] = gridIdx + up + right
    indexes[DoorSlot.DOWN1] = gridIdx + down + right
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

function mod:isMinesEscapeSequence()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  
  return not game:IsGreedMode() and
         (stage == LevelStage.STAGE2_2 or (mod:hasAnyCurse(LevelCurse.CURSE_OF_LABYRINTH) and stage == LevelStage.STAGE2_1)) and
         (stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B) and
         mod:getDimension(roomDesc) == 1
end

function mod:isMomsHeart()
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  
  return not game:IsGreedMode() and
         (stage == LevelStage.STAGE4_2 or (mod:hasAnyCurse(LevelCurse.CURSE_OF_LABYRINTH) and stage == LevelStage.STAGE4_1)) and
         (stageType == StageType.STAGETYPE_ORIGINAL or stageType == StageType.STAGETYPE_WOTL or stageType == StageType.STAGETYPE_AFTERBIRTH) and
         roomDesc.GridIndex >= 0 and
         room:GetType() == RoomType.ROOM_BOSS and
         room:IsCurrentRoomLastBoss()
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
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Hush)') or
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Hushed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hush)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hushed)')
end

function mod:isCursedChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Hushed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hushed)')
end

function mod:isHushChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Hush)') or
         challenge == Isaac.GetChallengeIdByName('Blue Room Challenge (Hushed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hush)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hushed)')
end

function mod:isDarkChallenge()
  local challenge = Isaac.GetChallenge()
  return challenge == Isaac.GetChallengeIdByName('Dark Room Challenge') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Cursed)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hush)') or
         challenge == Isaac.GetChallengeIdByName('Dark Room Challenge (Hushed)')
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  for _, v in ipairs({ 'Curses' }) do
    ModConfigMenu.RemoveSubcategory(mod.Name, v)
  end
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

mod:loadData(false, nil) -- make sure probability data is loaded before the first occurrence of onCurseEval
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, mod.onCurseEval)
mod:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, mod.onPreNewRoom) -- fires 0-n times per new room, 1-n for blue rooms
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.onPickupInit, PickupVariant.PICKUP_TROPHY)

if ModConfigMenu then
  mod:setupModConfigMenu()
end