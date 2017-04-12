local RPFastTravel = {}

--
-- Includes
--

local RPGlobals = require("src/rpglobals")
local RPSprites = require("src/rpsprites")

--
-- Constants
--

RPFastTravel.trapdoorOpenDistance = 60 -- This feels about right
RPFastTravel.trapdoorTouchDistance = 16 -- This feels about right (it is slightly smaller than vanilla)

--
-- Variables
--

RPFastTravel.sprites = {}

--
-- Trapdoor / heaven door functions
--

-- "Replace" functions for trapdoor / heaven door
-- (called from the "RPCheckEntities:Grid()" and "RPCheckEntities:NonGrid()" functions)
function RPFastTravel:ReplaceTrapdoor(entity, i)
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local room = game:GetRoom()
  local roomType = room:GetType()
  local player = game:GetPlayer(0)

  -- Delete the Womb 2 trapdoor and don't replace it if we have the Polaroid
  -- (also check for The Negative, since we might have both under certain conditions)
  if (stage == LevelStage.STAGE4_2 or -- 8
      stage == LevelStage.STAGE4_3) and -- 9
     roomType == RoomType.ROOM_BOSS and -- 5
     player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) and -- 327
     player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE) == false then -- 328

    -- Delete the Womb 2 trapdoor if we have the Polaroid
    entity.Sprite = Sprite() -- If we don't do this, it will still show for a frame
    room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work
    return
  end

  -- Find out whether we should move the trapdoor from where it spawned
  local position = entity.Position
  if ((stage == LevelStage.STAGE4_2 and -- 8
       entity.Position.X == 280 and -- If it spawned in the vanilla location on Womb 2
       entity.Position.Y == 280) or
      (stage == LevelStage.STAGE4_3 and -- 9
       entity.Position.X == 560 and -- Or if it spawned in the vanilla location on Blue Womb
       entity.Position.Y == 280)) and
     roomType == RoomType.ROOM_BOSS and -- 5
     (player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) or -- 327
      player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)) and -- 328
     (player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) == false or -- 327
      player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE) == false) then -- 328

    -- Since we deleted the beam of light, the trapdoor will look off-center on Womb 2 / Blue Womb,
    -- so move the trapdoor to the center of the room
    -- (we can't modify entity.Position for some reason, so we have to make a new position variable)
    position = room:GetCenterPos()
    if stage == LevelStage.STAGE4_3 then -- 9
      -- It looks weird if we move it to the center on the Blue Womb; just make it aligned horizontally instead
      position.Y = entity.Position.Y
    end
  end

  -- Spawn a custom entity to emulate the original
  local trapdoor
  local type = 0
  if roomIndex == GridRooms.ROOM_BLUE_WOOM_IDX then -- -8
    type = 2
    trapdoor = game:Spawn(Isaac.GetEntityTypeByName("Blue Womb Trapdoor (Fast-Travel)"),
                          Isaac.GetEntityVariantByName("Blue Womb Trapdoor (Fast-Travel)"),
                          position, Vector(0, 0), nil, 0, 0)

  elseif stage == LevelStage.STAGE3_2 or -- 6
     stage == LevelStage.STAGE4_1 then -- 7

    type = 1
    trapdoor = game:Spawn(Isaac.GetEntityTypeByName("Womb Trapdoor (Fast-Travel)"),
                          Isaac.GetEntityVariantByName("Womb Trapdoor (Fast-Travel)"),
                          position, Vector(0, 0), nil, 0, 0)
  else
    trapdoor = game:Spawn(Isaac.GetEntityTypeByName("Trapdoor (Fast-Travel)"),
                          Isaac.GetEntityVariantByName("Trapdoor (Fast-Travel)"),
                          position, Vector(0, 0), nil, 0, 0)
  end
  trapdoor.DepthOffset = -100 -- This is needed so that the entity will not appear on top of the player

  -- The custom entity will not respawn if we leave the room,
  -- so we need to keep track of it for the remainder of the floor
  RPGlobals.run.replacedTrapdoors[#RPGlobals.run.replacedTrapdoors + 1] = {
    room = roomIndex,
    pos  = position,
  }

  -- Always spawn the trapdoor closed
  trapdoor:ToEffect().State = 1
  trapdoor:GetSprite():Play("Closed", true)

  -- Log it
  local debugString = "Replaced "
  if type == 2 then
    debugString = debugString .. "blue womb "
  elseif type == 1 then
    debugString = debugString .. "womb "
  end
  debugString = debugString .. "trapdoor in room " .. tostring(roomIndex) .. " at "
  debugString = debugString .. "(" .. tostring(entity.Position.X) .. ", " .. tostring(entity.Position.Y) .. ")"
  Isaac.DebugString(debugString)

  -- Remove the original entity
  if i == -1 then
    -- We are replacing a Big Chest
    entity:Remove()
  else
    -- We are replacing a trapdoor grid entity
    entity.Sprite = Sprite() -- If we don't do this, it will still show for a frame
    room:RemoveGridEntity(i, 0, false) -- entity:Destroy() does not work
  end
end

function RPFastTravel:ReplaceHeavenDoor(entity)
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local room = game:GetRoom()
  local roomType = room:GetType()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local player = game:GetPlayer(0)

  -- Delete the beam of light and don't replace it if we have The Negative
  -- (also check for The Polaroid, since we might have both under certain conditions)
  if (stage == LevelStage.STAGE4_2 or -- 8
      stage == LevelStage.STAGE4_3) and -- 9
     roomType == RoomType.ROOM_BOSS and -- 5
     player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) == false and -- 327
     player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE) then -- 328

    entity:Remove()
    return
  end

  -- Find out whether we should move the trapdoor from where it spawned
  local position = entity.Position
  if ((stage == LevelStage.STAGE4_2 and -- 8
       entity.Position.X == 360 and -- If it spawned in the vanilla location on Womb 2
       entity.Position.Y == 280) or
      (stage == LevelStage.STAGE4_3 and -- 9
       entity.Position.X == 640 and -- Or if it spawned in the vanilla location on Blue Womb
       entity.Position.Y == 280)) and
     roomType == RoomType.ROOM_BOSS and -- 5
     (player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) or -- 327
      player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE)) and -- 328
     (player:HasCollectible(CollectibleType.COLLECTIBLE_POLAROID) == false or -- 327
      player:HasCollectible(CollectibleType.COLLECTIBLE_NEGATIVE) == false) then -- 328

    -- Since we deleted the trapdoor, the beam of light will look off-center on Womb 2 / Blue Womb,
    -- so move the beam of light to the center of the room
    -- (we can't modify entity.Position for some reason, so we have to make a new position variable)
    position = room:GetCenterPos()
    if stage == LevelStage.STAGE4_3 then -- 9
      -- It looks weird if we move it to the center on the Blue Womb; just make it aligned horizontally instead
      position.Y = entity.Position.Y
    end
  end

  -- Spawn a custom entity to emulate the original
  local heaven = game:Spawn(Isaac.GetEntityTypeByName("Heaven Door (Fast-Travel)"),
                            Isaac.GetEntityVariantByName("Heaven Door (Fast-Travel)"),
                            position, Vector(0,0), nil, 0, roomSeed)
  heaven.DepthOffset = 15 -- The default offset of 0 is too low, and 15 is just about perfect

  -- The custom entity will not respawn if we leave the room,
  -- so we need to keep track of it for the remainder of the floor
  RPGlobals.run.replacedHeavenDoors[#RPGlobals.run.replacedHeavenDoors + 1] = {
    room = roomIndex,
    pos  = position,
  }

  -- Log it
  Isaac.DebugString("Replaced beam of light in room " .. tostring(roomIndex) .. " at (" ..
                    tostring(entity.Position.X) .. "," .. tostring(entity.Position.Y) .. ")")

  -- Remove the original entity
  entity:Remove()
end

-- Called from the "RPCheckEntities:NonGrid()" function
function RPFastTravel:CheckPickupOverHole(pickup)
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end

  -- Check to see if it is overlapping with a trapdoor / beam of light / crawlspace
  local squareSize = RPFastTravel.trapdoorTouchDistance + 2
  for i = 1, #RPGlobals.run.replacedTrapdoors do
    if roomIndex == RPGlobals.run.replacedTrapdoors[i].room and
       pickup.Position.X >= RPGlobals.run.replacedTrapdoors[i].pos.X - squareSize and
       pickup.Position.X <= RPGlobals.run.replacedTrapdoors[i].pos.X + squareSize and
       pickup.Position.Y >= RPGlobals.run.replacedTrapdoors[i].pos.Y - squareSize and
       pickup.Position.Y <= RPGlobals.run.replacedTrapdoors[i].pos.Y + squareSize then

      RPFastTravel:MovePickupOverHole(pickup, RPGlobals.run.replacedTrapdoors[i].pos)
      return
    end
  end
  for i = 1, #RPGlobals.run.replacedHeavenDoors do
    if roomIndex == RPGlobals.run.replacedHeavenDoors[i].room and
       pickup.Position.X >= RPGlobals.run.replacedHeavenDoors[i].pos.X - squareSize and
       pickup.Position.X <= RPGlobals.run.replacedHeavenDoors[i].pos.X + squareSize and
       pickup.Position.Y >= RPGlobals.run.replacedHeavenDoors[i].pos.Y - squareSize and
       pickup.Position.Y <= RPGlobals.run.replacedHeavenDoors[i].pos.Y + squareSize then

      RPFastTravel:MovePickupOverHole(pickup, RPGlobals.run.replacedHeavenDoors[i].pos)
      return
    end
  end
  for i = 1, #RPGlobals.run.replacedCrawlspaces do
    if roomIndex == RPGlobals.run.replacedCrawlspaces[i].room and
       pickup.Position.X >= RPGlobals.run.replacedCrawlspaces[i].pos.X - squareSize and
       pickup.Position.X <= RPGlobals.run.replacedCrawlspaces[i].pos.X + squareSize and
       pickup.Position.Y >= RPGlobals.run.replacedCrawlspaces[i].pos.Y - squareSize and
       pickup.Position.Y <= RPGlobals.run.replacedCrawlspaces[i].pos.Y + squareSize then

      RPFastTravel:MovePickupOverHole(pickup, RPGlobals.run.replacedCrawlspaces[i].pos)
      return
    end
  end
end

function RPFastTravel:MovePickupOverHole(pickup, posHole)
  -- Local variables
  local game = Game()
  local room = game:GetRoom()
  local squareSize = RPFastTravel.trapdoorTouchDistance + 2

  -- Generate new spawn positions until we find one that doesn't overlap with the hole
  local newPos
  local overlapping = false
  for i = 0, 100 do
    newPos = room:FindFreePickupSpawnPosition(pickup.Position, i, true)
    if newPos.X >= posHole.X - squareSize and
       newPos.X <= posHole.X + squareSize and
       newPos.Y >= posHole.Y - squareSize and
       newPos.Y <= posHole.Y + squareSize then

      overlapping = true
    end
    if overlapping == false then
      break
    end
  end
  if overlapping then
    -- We were not able to find a free location after 100 attempts, so give up and just delete the pickup
    pickup:Remove()
    Isaac.DebugString("Error: Failed to find a free location after 100 attempts for pickup: " ..
                      tostring(pickup.Type) .. "." .. tostring(pickup.Variant) .. "." .. tostring(pickup.SubType))
  else
    -- Move it
    game:Spawn(pickup.Type, pickup.Variant, newPos, pickup.Velocity, pickup.Parent, pickup.SubType, pickup.InitSeed)
    pickup:Remove()
    Isaac.DebugString("Moved a pickup that was overlapping with a hole: " ..
                      tostring(pickup.Type) .. "." .. tostring(pickup.Variant) .. "." .. tostring(pickup.SubType))
  end
end

-- Called from the "RPCheckEntities:NonGrid()" function
function RPFastTravel:CheckTrapdoorEnter(entity, upwards)
  -- Local variables
  local game = Game()
  local player = game:GetPlayer(0)
  local level = game:GetLevel()
  local stage = level:GetStage()

  -- Check to see if the player is touching the trapdoor
  local squareSize = RPFastTravel.trapdoorTouchDistance
  if RPGlobals.run.trapdoor.state == 0 and
     ((upwards == false and entity:ToEffect().State == 0) or -- The trapdoor is open
      (upwards and stage == 8 and entity.FrameCount >= 40 and entity.InitSeed ~= 0) or
      -- We want the player to be forced to dodge the final wave of tears from It Lives!, so we have to delay
      -- (we initially spawn it with an InitSeed equal to the room seed)
      (upwards and stage == 8 and entity.FrameCount >= 16 and entity.InitSeed == 0) or
      -- The extra delay should not apply if they are re-entering the room
      -- (we respawn beams of light with an InitSeed of 0)
      (upwards and stage ~= 8 and entity.FrameCount >= 16)) and
      -- The beam of light opening animation is 16 frames long
     player.Position.X >= entity.Position.X - squareSize and
     player.Position.X <= entity.Position.X + squareSize and
     player.Position.Y >= entity.Position.Y - squareSize and
     player.Position.Y <= entity.Position.Y + squareSize and
     player:IsHoldingItem() == false then

    -- State 1 is activated the moment we touch the trapdoor
    RPGlobals.run.trapdoor.state = 1
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
    RPGlobals.run.trapdoor.upwards = upwards
    RPGlobals.run.trapdoor.frame = Isaac.GetFrameCount() + 40
    -- The "Trapdoor" animation is 16 frames long and the "LightTravel" animation is 28 frames long,
    -- but we need to delay for longer than that to make it look smooth
    -- (we keep the "Trapdoor" animation at 2 for quick chest animations and
    -- make a custom "Trapdoor2" animation that is 40 frames long)
    -- (we have increased the "FrameNum" for the "LightTravel" animations to 40)

    player.ControlsEnabled = false
    player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE -- 0
    -- (this is necessary so that enemy attacks don't move the player while they are doing the jumping animation)
    player.Position = entity.Position -- Teleport the player on top of the trapdoor
    player.Velocity = Vector(0, 0) -- Remove all of the player's momentum
    if upwards then
      player:PlayExtraAnimation("LightTravel")
    else
      player:PlayExtraAnimation("Trapdoor2") -- This is a custom elongated animation
    end
  end
end

-- Called from the PostRender callback
function RPFastTravel:CheckTrapdoor()
  -- Local varaibles
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local room = game:GetRoom()
  local player = game:GetPlayer(0)
  local frameCount = Isaac.GetFrameCount()

  if RPGlobals.run.trapdoor.state == 1 and
     frameCount >= RPGlobals.run.trapdoor.frame then

    -- State 2 is activated when the "Trapdoor" animation is completed
    player.Visible = false

    -- Make the screen fade to black (we can go to any room for this, so we just use the starting room)
    game:StartRoomTransition(level:GetStartingRoomIndex(), Direction.NO_DIRECTION, -- -1
                             RPGlobals.RoomTransition.TRANSITION_NONE) -- 0

    -- Mark to change floors after the screen is black
    RPGlobals.run.trapdoor.state = 2
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
    RPGlobals.run.trapdoor.frame = frameCount + 8
    -- 9 is too many (you can start to see the same room again)

  elseif RPGlobals.run.trapdoor.state == 2 and
         frameCount >= RPGlobals.run.trapdoor.frame then

    -- Stage 3 is actiated when the screen is black
    RPGlobals.run.trapdoor.state = 3
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
    RPGlobals.run.trapdoor.floor = stage
    RPGlobals:GotoNextFloor(RPGlobals.run.trapdoor.upwards) -- The argument is "upwards"

  elseif RPGlobals.run.trapdoor.state == 5 and
         RPGlobals.run.trapdoor.floor ~= stage then

    -- State 6 is activated when we get to the new floor
    -- (stages 4 and 5 are in the PostNewRoom callback)
    RPGlobals.run.trapdoor.state = 6
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
    game:Spawn(Isaac.GetEntityTypeByName("Pitfall (Custom)"), Isaac.GetEntityVariantByName("Pitfall (Custom)"),
               room:GetCenterPos(), Vector(0,0), nil, 0, 0)

    -- Move Isaac to the center of the room
    player.Position = room:GetCenterPos()

    -- Show what the new floor (the game won't show this naturally since we used the console command to get here)
    local spriteName = tostring(stage) .. "-" .. tostring(stageType)
    RPFastTravel.sprites.stage = Sprite()
    RPFastTravel.sprites.stage:Load("gfx/stage/" .. spriteName .. ".anm2", true)
    RPFastTravel.sprites.stage:Play("TextIn", true)

  elseif RPGlobals.run.trapdoor.state == 6 and
         player.ControlsEnabled then

     -- State 7 is activated when the player controls are enabled
     -- (this happens automatically by the game)
     RPGlobals.run.trapdoor.state = 7
     Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
     RPGlobals.run.trapdoor.frame = frameCount + 10 -- Wait a while longer
     player.ControlsEnabled = false

  elseif RPGlobals.run.trapdoor.state == 7 and
         frameCount >= RPGlobals.run.trapdoor.frame then

     -- State 8 is activated when the the hole is spawned and ready
     RPGlobals.run.trapdoor.state = 8
     Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)
     RPGlobals.run.trapdoor.frame = frameCount + 25
     -- The "JumpOut" animation is 15 frames long, so give a bit of leeway

     -- Make Isaac visable again
     player.SpriteScale = RPGlobals.run.trapdoor.scale

     -- Re-give Isaac the collision that we removed earlier
     player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL -- 4

     -- Play the jumping out of the hole animation
     player:PlayExtraAnimation("Jump")

     -- Make the hole do the dissapear animation
     for i, entity in pairs(Isaac.GetRoomEntities()) do
       if entity.Type == Isaac.GetEntityTypeByName("Pitfall (Custom)") and
          entity.Variant == Isaac.GetEntityVariantByName("Pitfall (Custom)") then

         entity:GetSprite():Play("Disappear", true)
         break
       end
     end

  elseif RPGlobals.run.trapdoor.state == 8 and
         frameCount >= RPGlobals.run.trapdoor.frame then

    -- We are finished when the the player has emerged from the hole
    RPGlobals.run.trapdoor.state = 0
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state .. " (finished)")
    player.ControlsEnabled = true

    -- Kill the hole
    for i, entity in pairs(Isaac.GetRoomEntities()) do
      if entity.Type == 1001 then
        entity:Remove()
        break
      end
    end

    -- Hide the stage text
    RPFastTravel.sprites.stage:Play("TextOut", true)
  end

  -- Fix the bug where Dr. Fetus bombs can be shot while jumping
  if RPGlobals.run.trapdoor.state > 0 then
    player.FireDelay = 1
  end
end

function RPFastTravel:CheckTrapdoor2()
  -- Local variables
  local game = Game()
  local player = game:GetPlayer(0)

  -- We will hit the PostNewRoom callback twice when doing a fast-travel, so do nothing on the first time
  if RPGlobals.run.trapdoor.state == 3 then
    RPGlobals.run.trapdoor.state = 4
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)

  elseif RPGlobals.run.trapdoor.state == 4 then
    RPGlobals.run.trapdoor.state = 5
    Isaac.DebugString("Trapdoor state: " .. RPGlobals.run.trapdoor.state)

    -- Make the player invisible so that we can jump out of the hole later
    -- (this has to be in the PostNewRoom callback so that we don't get bugs with the Glowing Hour Glass)
    -- (we can't use "player.Visible = false" because it won't do anything here)
    RPGlobals.run.trapdoor.scale = player.SpriteScale
    player.SpriteScale = Vector(0, 0)
  end
end

--
-- Crawlspace functions
--

-- Called from the "RPCheckEntities:Grid()" function
function RPFastTravel:ReplaceCrawlspace(entity, i)
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local room = game:GetRoom()
  local player = game:GetPlayer(0)

  -- Spawn a custom entity to emulate the original
  local crawlspace = game:Spawn(Isaac.GetEntityTypeByName("Crawlspace (Fast-Travel)"),
                                Isaac.GetEntityVariantByName("Crawlspace (Fast-Travel)"),
                                entity.Position, Vector(0,0), nil, 0, 0)
  crawlspace.DepthOffset = -100 -- This is needed so that the entity will not appear on top of the player

  -- The custom entity will not respawn if we leave the room,
  -- so we need to keep track of it for the remainder of the floor
  RPGlobals.run.replacedCrawlspaces[#RPGlobals.run.replacedCrawlspaces + 1] = {
    room = roomIndex,
    pos  = entity.Position,
  }

  -- Log it
  Isaac.DebugString("Replaced crawlspace in room " .. tostring(roomIndex) .. " at (" ..
                    tostring(entity.Position.X) .. "," .. tostring(entity.Position.Y) .. ")")

  -- Figure out if it should spawn open or closed, depending on how close we are
  local squareSize = RPFastTravel.trapdoorOpenDistance
  if player.Position.X >= entity.Position.X - squareSize and
     player.Position.X <= entity.Position.X + squareSize and
     player.Position.Y >= entity.Position.Y - squareSize and
     player.Position.Y <= entity.Position.Y + squareSize then

    crawlspace:ToEffect().State = 1
    crawlspace:GetSprite():Play("Closed", true)
    Isaac.DebugString("Spawned crawlspace (closed, state 1).")
  else
    crawlspace:GetSprite():Play("Open Animation", true)
    Isaac.DebugString("Spawned crawlspace (opened, state 0).")
  end

  -- Remove the original entity
  entity.Sprite = Sprite() -- If we don't do this, it will still show for a frame
  room:RemoveGridEntity(i, 0, false) -- entity:Destroy() does not work
end

-- Called from the "RPCheckEntities:NonGrid()" function
function RPFastTravel:CheckCrawlspaceEnter(entity)
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local player = game:GetPlayer(0)

  -- Check to see if the player is touching the crawlspace
  local squareSize = RPFastTravel.trapdoorTouchDistance
  if entity:ToEffect().State == 0 and -- The crawlspace is open
     player.Position.X >= entity.Position.X - squareSize and
     player.Position.X <= entity.Position.X + squareSize and
     player.Position.Y >= entity.Position.Y - squareSize and
     player.Position.Y <= entity.Position.Y + squareSize then

    -- If we don't set this, we will return to the center of the room by default
    level.DungeonReturnPosition = entity.Position

    -- We need to keep track of which room we came from
    -- (this is needed in case we are in a Boss Rush or other room with a negative room index)
    level.DungeonReturnRoomIndex = roomIndex

    -- Go to the crawlspace
    game:StartRoomTransition(GridRooms.ROOM_DUNGEON_IDX, Direction.DOWN, -- -4, 3
                             RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
  end
end

-- Called from the PostUpdate callback
function RPFastTravel:CheckCrawlspaceExit()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local room = game:GetRoom()
  local player = game:GetPlayer(0)
  local playerGridIndex = room:GetGridIndex(player.Position)

  if room:GetType() == RoomType.ROOM_DUNGEON and -- 16
     playerGridIndex == 2 then -- If the player is standing on top of the ladder

    -- Do a manual room transition
    level.LeaveDoor = -1 -- You have to set this before every teleport or else it will send you to the wrong room
    game:StartRoomTransition(level.DungeonReturnRoomIndex, Direction.UP, -- 1
                             RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
  end
end

-- Fix the softlock with Boss Rushes and crawlspaces
-- (called from the PostUpdate callback)
function RPFastTravel:CheckCrawlspaceSoftlock()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local room = game:GetRoom()
  local prevRoomIndex = level:GetPreviousRoomIndex() -- We need the unsafe version here
  local player = game:GetPlayer(0)
  local playerGridIndex = room:GetGridIndex(player.Position)

  if room:GetType() == RoomType.ROOM_BOSSRUSH and -- 17
     prevRoomIndex == GridRooms.ROOM_DUNGEON_IDX then -- -4

    if playerGridIndex == 7 then -- Top left door
      RPGlobals.run.bossRushReturn = Direction.UP -- 1
      game:StartRoomTransition(RPFastTravel:GetBossRoomIndex(), Direction.UP, -- 1
                               RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
      Isaac.DebugString("Exited Boss Rush, moving to boss room manually (up).")
    elseif playerGridIndex == 139 then -- Right top door
      RPGlobals.run.bossRushReturn = Direction.RIGHT -- 2
      game:StartRoomTransition(RPFastTravel:GetBossRoomIndex(), Direction.RIGHT, -- 2
                               RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
      Isaac.DebugString("Exited Boss Rush, moving to boss room manually (right).")
    elseif playerGridIndex == 427 then -- Bottom left door
      RPGlobals.run.bossRushReturn = Direction.DOWN -- 3
      game:StartRoomTransition(RPFastTravel:GetBossRoomIndex(), Direction.DOWN, -- 3
                               RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
      Isaac.DebugString("Exited Boss Rush, moving to boss room manually (down).")
    elseif playerGridIndex == 112 then -- Left top door
      RPGlobals.run.bossRushReturn = Direction.LEFT -- 0
      game:StartRoomTransition(RPFastTravel:GetBossRoomIndex(), Direction.LEFT, -- 0
                               RPGlobals.RoomTransition.TRANSITION_NONE) -- 0
      Isaac.DebugString("Exited Boss Rush, moving to boss room manually (left).")
    end
  end
end

-- Called in the PostNewRoom callback
function RPFastTravel:CheckCrawlspaceMiscBugs()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local prevRoomIndex = level:GetPreviousRoomIndex() -- We need the unsafe version here
  local room = game:GetRoom()
  local player = game:GetPlayer(0)

  -- For some reason, we won't go back to location of the crawlspace if we entered from the Boss Rush,
  -- so move there manually
  -- (this will look glitchy because the game wants to spawn us next to the Boss Rush door,
  -- but there is no way around this; even if we change player.Position on every frame in the PostRender callback,
  -- the glitchy warp will still occur)
  if roomIndex == GridRooms.ROOM_BOSSRUSH_IDX and -- --5
     prevRoomIndex == GridRooms.ROOM_DUNGEON_IDX then -- -4

    player.Position = level.DungeonReturnPosition
    Isaac.DebugString("Exited crawlspace in Boss Rush, teleport complete.")
  end

  -- For some reason, if we exit and re-enter a crawlspace in a Boss Rush, we won't spawn on the ladder,
  -- so move there manually (this causes no visual hiccups like the above code does)
  if roomIndex == GridRooms.ROOM_DUNGEON_IDX and -- -4
     level.DungeonReturnRoomIndex == GridRooms.ROOM_BOSSRUSH_IDX then -- -4

    player.Position = Vector(120, 160) -- This is the standard starting location at the top of the ladder
    Isaac.DebugString("Entered crawlspace from Boss Rush, teleport complete.")
  end

  -- When returning to the boss room from a Boss Rush with a crawlspace in it,
  -- we might not end up in a spot where the player expects, so move to the most logical position manually
  if RPGlobals.run.bossRushReturn ~= -1 then
    if RPGlobals.run.bossRushReturn == Direction.LEFT then -- 0
      -- Returning from the right door
      player.Position = room:GetGridPosition(73)
      Isaac.DebugString("Entered boss room from Boss Rush (going left), teleport complete.")
    elseif RPGlobals.run.bossRushReturn == Direction.UP then -- 1
      -- Returning from the bottom door
      player.Position = RPGlobals.GridToPos(112)
      Isaac.DebugString("Entered boss room from Boss Rush (going up), teleport complete.")
    elseif RPGlobals.run.bossRushReturn == Direction.RIGHT then -- 2
      -- Returning from the left door
      player.Position = RPGlobals.GridToPos(61)
      Isaac.DebugString("Entered boss room from Boss Rush (going left), teleport complete.")
    elseif RPGlobals.run.bossRushReturn == Direction.DOWN then -- 3
      -- Returning from the top door
      player.Position = RPGlobals.GridToPos(22)
      Isaac.DebugString("Entered boss room from Boss Rush (going down), teleport complete.")
    end
    RPGlobals.run.bossRushReturn = -1
  end
end

function RPFastTravel:GetBossRoomIndex()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local rooms = level:GetRooms()

  for i = 0, rooms.Size - 1 do -- This is 0 indexed
    local roomType = rooms:Get(i).Data.Type
    if roomType == RoomType.ROOM_BOSS then -- 5
      return rooms:Get(i).SafeGridIndex
    end
  end

  -- We should never get here
  Isaac.DebugString("Error: Was not able to find the boss room index.")
  return level:GetStartingRoomIndex()
end

--
-- Shared functions
--

-- Called from the "RPCheckEntities:NonGrid()" function
function RPFastTravel:CheckTrapdoorCrawlspaceOpen(entity)
  -- Local variables
  local game = Game()
  local room = game:GetRoom()
  local roomType = room:GetType()
  local player = game:GetPlayer(0)

  -- Don't do anything if the trapdoor / crawlspace is already open
  if entity:ToEffect().State == 0 then
    return
  end

  -- Don't do anything if it is freshly spawned in a boss room and the player is relatively close
  local squareSizeBig = RPFastTravel.trapdoorOpenDistance * 2.5
  if roomType == RoomType.ROOM_BOSS and -- 5
     entity.FrameCount <= 30 and
     entity.DepthOffset ~= -101 and -- We use -101 to signify that it is a respawned trapdoor
     player.Position.X >= entity.Position.X - squareSizeBig and
     player.Position.X <= entity.Position.X + squareSizeBig and
     player.Position.Y >= entity.Position.Y - squareSizeBig and
     player.Position.Y <= entity.Position.Y + squareSizeBig then

    return
  end

  -- Don't do anything if the player is standing too close to the trapdoor / crawlspace
  local squareSize = RPFastTravel.trapdoorOpenDistance
  if player.Position.X >= entity.Position.X - squareSize and
     player.Position.X <= entity.Position.X + squareSize and
     player.Position.Y >= entity.Position.Y - squareSize and
     player.Position.Y <= entity.Position.Y + squareSize then

    return
  end

  -- Open it
  entity:ToEffect().State = 0
  entity:GetSprite():Play("Open Animation", true)
  Isaac.DebugString("Opened trap door (player moved away).")
end

-- Called from the PostNewRoom callback
function RPFastTravel:CheckRoomRespawn()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local room = game:GetRoom()
  local player = game:GetPlayer(0)

  -- Respawn trapdoors, if necessary
  for i = 1, #RPGlobals.run.replacedTrapdoors do
    if RPGlobals.run.replacedTrapdoors[i].room == roomIndex then
      -- Remove any grid entities that will overlap with the custom entity
      -- (this is needed because rocks may respawn in the room after we remove the trapdoor)
      local gridIndex = room:GetGridIndex(RPGlobals.run.replacedTrapdoors[i].pos)
      local gridEntity = room:GetGridEntity(gridIndex)
      if gridEntity ~= nil then
        room:RemoveGridEntity(gridIndex, 0, false) -- entity:Destroy() does not work
        Isaac.DebugString("Removed a grid entity at index " .. tostring(gridIndex) ..
                          " that would interfere with the trapdoor.")
      end

      -- Spawn the new custom entity
      local entity
      if roomIndex == GridRooms.ROOM_BLUE_WOOM_IDX then -- -8
        entity = game:Spawn(Isaac.GetEntityTypeByName("Blue Womb Trapdoor (Fast-Travel)"),
                            Isaac.GetEntityVariantByName("Blue Womb Trapdoor (Fast-Travel)"),
                            RPGlobals.run.replacedTrapdoors[i].pos, Vector(0,0), nil, 0, 0)
      elseif stage == LevelStage.STAGE3_2 or -- 6
         stage == LevelStage.STAGE4_1 then -- 7

        entity = game:Spawn(Isaac.GetEntityTypeByName("Womb Trapdoor (Fast-Travel)"),
                            Isaac.GetEntityVariantByName("Womb Trapdoor (Fast-Travel)"),
                            RPGlobals.run.replacedTrapdoors[i].pos, Vector(0,0), nil, 0, 0)
      else
        entity = game:Spawn(Isaac.GetEntityTypeByName("Trapdoor (Fast-Travel)"),
                            Isaac.GetEntityVariantByName("Trapdoor (Fast-Travel)"),
                            RPGlobals.run.replacedTrapdoors[i].pos, Vector(0,0), nil, 0, 0)
      end
      entity.DepthOffset = -101 -- This is needed so that the entity will not appear on top of the player
      -- We use -101 instead of -100 to signify that it is a respawned trapdoor

      -- Figure out if it should spawn open or closed, depending on how close we are
      local squareSize = RPFastTravel.trapdoorOpenDistance
      if (player.Position.X >= entity.Position.X - squareSize and
          player.Position.X <= entity.Position.X + squareSize and
          player.Position.Y >= entity.Position.Y - squareSize and
          player.Position.Y <= entity.Position.Y + squareSize) or
         roomIndex == GridRooms.ROOM_BOSSRUSH_IDX then -- -5
         -- (always spawn trapdoors closed in the Boss Rush to prevent specific bugs)

        entity:ToEffect().State = 1
        entity:GetSprite():Play("Closed", true)
        Isaac.DebugString("Respawned trapdoor (closed, state 1).")
      else
        -- The default animation is "Opened", which is what we want
        Isaac.DebugString("Respawned trapdoor (opened, state 0).")
      end
    end
  end

  -- Respawn crawlspaces, if necessary
  for i = 1, #RPGlobals.run.replacedCrawlspaces do
    if RPGlobals.run.replacedCrawlspaces[i].room == roomIndex then
      -- Remove any grid entities that will overlap with the custom entity
      -- (this is needed because rocks may respawn in the room after we remove the trapdoor)
      local gridIndex = room:GetGridIndex(RPGlobals.run.replacedCrawlspaces[i].pos)
      local gridEntity = room:GetGridEntity(gridIndex)
      if gridEntity ~= nil then
        room:RemoveGridEntity(gridIndex, 0, false) -- entity:Destroy() does not work
        Isaac.DebugString("Removed a grid entity at index " .. tostring(gridIndex) ..
                          " that would interfere with the crawlspace.")
      end

      -- Spawn the new custom entity
      local entity = game:Spawn(Isaac.GetEntityTypeByName("Crawlspace (Fast-Travel)"),
                                  Isaac.GetEntityVariantByName("Crawlspace (Fast-Travel)"),
                                  RPGlobals.run.replacedCrawlspaces[i].pos, Vector(0,0), nil, 0, 0)
      entity.DepthOffset = -100 -- This is needed so that the entity will not appear on top of the player

      -- Figure out if it should spawn open or closed, depending on how close we are
      local squareSize = RPFastTravel.trapdoorOpenDistance
      if (player.Position.X >= entity.Position.X - squareSize and
          player.Position.X <= entity.Position.X + squareSize and
          player.Position.Y >= entity.Position.Y - squareSize and
          player.Position.Y <= entity.Position.Y + squareSize) or
         roomIndex == GridRooms.ROOM_BOSSRUSH_IDX then -- -5
         -- (always spawn trapdoors closed in the Boss Rush to prevent specific bugs)

        entity:ToEffect().State = 1
        entity:GetSprite():Play("Closed", true)
        Isaac.DebugString("Respawned crawlspace (closed, state 1).")
      else
        -- The default animation is "Opened", which is what we want
        Isaac.DebugString("Respawned crawlspace (opened, state 0).")
      end
    end
  end

  -- Respawn beams of light, if necessary
  for i = 1, #RPGlobals.run.replacedHeavenDoors do
    if RPGlobals.run.replacedHeavenDoors[i].room == roomIndex then
      -- Spawn the new custom entity
      local entity = game:Spawn(Isaac.GetEntityTypeByName("Heaven Door (Fast-Travel)"),
                                Isaac.GetEntityVariantByName("Heaven Door (Fast-Travel)"),
                                RPGlobals.run.replacedHeavenDoors[i].pos, Vector(0,0), nil, 0, 0)
      -- Use an InitSeed of 0 to signify that it is respawned
      entity.DepthOffset = 15 -- The default offset of 0 is too low, and 15 is just about perfect
      Isaac.DebugString("Respawned heaven door.")
    end
  end
end

function RPFastTravel:SpriteDisplay()
  if RPFastTravel.sprites.stage == nil then
    return
  end

  local pos = RPSprites:GetScreenCenterPosition()
  pos.Y = pos.Y - 85 -- Move it below the top door
  RPFastTravel.sprites.stage:Render(pos, Vector(0, 0), Vector(0, 0))
  RPFastTravel.sprites.stage:Update()
end

return RPFastTravel
