
local PostNewRoom = {}

-- Includes
local g                   = require("src/globals")
local FastClear           = require("src/fastclear")
local FastTravel          = require("src/fasttravel")
local Speedrun            = require("src/speedrun")
local SpeedrunPostNewRoom = require("src/speedrunpostnewroom")
local ChangeCharOrder     = require("src/changecharorder")
local Sprites             = require("src/sprites")
local SeededDeath         = require("src/seededdeath")
local SeededRooms         = require("src/seededrooms")
local Samael              = require("src/samael")

-- ModCallbacks.MC_POST_NEW_ROOM (19)
function PostNewRoom:Main()
  -- Local variables
  local game = Game()
  local gameFrameCount = game:GetFrameCount()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local roomDesc = level:GetCurrentRoomDesc()
  local roomStageID = roomDesc.Data.StageID
  local roomVariant = roomDesc.Data.Variant

  Isaac.DebugString("MC_POST_NEW_ROOM - " .. tostring(roomStageID) .. "." .. tostring(roomVariant))

  -- Make an exception for the "Race Start Room" and the "Change Char Order" room
  PostNewRoom:RaceStart()
  ChangeCharOrder:PostNewRoom()

  -- Make sure the callbacks run in the right order
  -- (naturally, PostNewRoom gets called before the PostNewLevel and PostGameStarted callbacks)
  if gameFrameCount == 0 or
     (g.run.currentFloor ~= stage or
      g.run.currentFloorType ~= stageType) then

    return
  end

  PostNewRoom:NewRoom()
end

function PostNewRoom:NewRoom()
  -- Local variables
  local game = Game()
  local room = game:GetRoom()
  local roomType = room:GetType()
  local roomClear = room:IsClear()
  local player = game:GetPlayer(0)
  local character = player:GetPlayerType()
  local activeCharge = player:GetActiveCharge()
  local maxHearts = player:GetMaxHearts()
  local soulHearts = player:GetSoulHearts()
  local boneHearts = player:GetBoneHearts()

  Isaac.DebugString("MC_POST_NEW_ROOM2")

  g.run.roomsEntered = g.run.roomsEntered + 1
  g.run.currentRoomClearState = roomClear
  -- This is needed so that we don't get credit for clearing a room when
  -- bombing from a room with enemies into an empty room

  -- Check to see if we need to remove the heart container from a Strength card on Keeper
  -- (this has to be above the resetting of the "g.run.usedStrength" variable)
  if character == PlayerType.PLAYER_KEEPER and -- 14
     g.run.keeper.baseHearts == 4 and
     g.run.usedStrength then

    g.run.keeper.baseHearts = 2
    player:AddMaxHearts(-2, true) -- Take away a heart container
    Isaac.DebugString("Took away 1 heart container from Keeper (via a Strength card). (PostNewRoom)")
  end

  -- Clear variables that track things per room
  g.run.fastCleared          = false
  g.run.currentGlobins       = {} -- Used for softlock prevention
  g.run.currentHaunts        = {} -- Used to speed up Lil' Haunts
  g.run.currentLilHaunts     = {} -- Used to delete invulnerability frames
  g.run.currentHoppers       = {} -- Used to prevent softlocks
  g.run.usedStrength         = false
  g.run.handsDelay           = 0
  g.run.naturalTeleport      = false
  g.run.diceRoomActivated    = false
  g.run.megaSatanDead        = false
  g.run.endOfRunText         = false -- Shown when the run is completed but only for one room
  g.run.teleportSubverted    = false -- Used for repositioning the player on It Lives! / Gurdy (1/2)
  g.run.teleportSubvertScale = Vector(1, 1) -- Used for repositioning the player on It Lives! / Gurdy (2/2)
  g.run.matriarch            = {
    chubIndex = -1,
    stunFrame = 0,
  }

  -- Clear fast-clear variables that track things per room
  FastClear.buttonsAllPushed = false
  FastClear.roomInitializing = false
  -- (this is set to true when the room frame count is -1 and set to false here, where the frame count is 0)

  -- Check to see if we need to fix the Wraith Skull + Hairpin bug
  Samael:CheckHairpin()

  -- Check to see if we need to respawn trapdoors / crawlspaces / beams of light
  FastTravel:CheckRoomRespawn()

  -- Check if we are just arriving on a new floor
  FastTravel:CheckTrapdoor2()

  -- Check for miscellaneous crawlspace bugs
  FastTravel:CheckCrawlspaceMiscBugs()

  -- Remove the "More Options" buff if they have entered a Treasure Room
  if g.run.removeMoreOptions == true and
     roomType == RoomType.ROOM_TREASURE then -- 4

    g.run.removeMoreOptions = false
    player:RemoveCollectible(CollectibleType.COLLECTIBLE_MORE_OPTIONS) -- 414
  end

  -- Check health (to fix the bug where we don't die at 0 hearts)
  -- (this happens if Keeper uses Guppy's Paw or when Magdalene takes a devil deal that grants soul/black hearts)
  if maxHearts == 0 and
     soulHearts == 0 and
     boneHearts == 0 and
     g.run.seededSwap.swapping == false and -- Make an exception if we are manually swapping health values
     InfinityTrueCoopInterface == nil then -- Make an exception if the True Co-op mod is on

    player:Kill()
    Isaac.DebugString("Manually killing the player since they are at 0 hearts.")
  end

  -- Make the Schoolbag work properly with the Glowing Hour Glass
  if player:HasCollectible(CollectibleType.COLLECTIBLE_SCHOOLBAG_CUSTOM) then
    -- Recharge our active item if we used the Glowing Hour Glass
    if g.run.schoolbag.nextRoomCharge then
      g.run.schoolbag.nextRoomCharge = false
      player:SetActiveCharge(g.run.schoolbag.lastRoomSlot1Charges)
    end

    -- Keep track of our last Schoolbag item
    g.run.schoolbag.lastRoomItem = g.run.schoolbag.item
    g.run.schoolbag.lastRoomSlot1Charges = activeCharge
    g.run.schoolbag.lastRoomSlot2Charges = g.run.schoolbag.charge
  end

  -- Check for the Satan room
  PostNewRoom:CheckSatanRoom()

  -- Check to see if we are entering the Mega Satan room so we can update the floor tracker and
  -- prevent cheating on the "Everything" race goal
  PostNewRoom:CheckMegaSatanRoom()

  -- Check for all of the Scolex boss rooms
  PostNewRoom:CheckScolexRoom()

  -- Check for the unavoidable puzzle room in the Dank Depths
  PostNewRoom:CheckDepthsPuzzle()

  -- Check for various NPCs
  PostNewRoom:CheckEntities()

  -- Check to see if we need to respawn an end-of-race or end-of-speedrun trophy
  PostNewRoom:CheckRespawnTrophy()

  -- Do race related stuff
  PostNewRoom:Race()

  -- Do speedrun related stuff
  SpeedrunPostNewRoom:Main()
end

-- Instantly spawn the first part of the fight (there is an annoying delay before The Fallen and the leeches spawn)
function PostNewRoom:CheckSatanRoom()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  local roomStageID = roomDesc.Data.StageID
  local roomVariant = roomDesc.Data.Variant
  local room = game:GetRoom()
  local roomClear = room:IsClear()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local challenge = Isaac.GetChallenge()

  if roomClear then
    return
  end

  if roomStageID ~= 0 or roomVariant ~= 3600 then -- Satan
    return
  end

  -- In the season 3 speedrun challenge, there is a custom boss instead of Satan
  if challenge == Isaac.GetChallengeIdByName("R+7 (Season 3)") then
    return
  end

  local seed = roomSeed
  game:Spawn(EntityType.ENTITY_LEECH, 1, -- 55.1 (Kamikaze Leech)
             g:GridToPos(5, 3), Vector(0, 0), nil, 0, seed)
  seed = g:IncrementRNG(seed)
  game:Spawn(EntityType.ENTITY_LEECH, 1, -- 55.1 (Kamikaze Leech)
             g:GridToPos(7, 3), Vector(0, 0), nil, 0, seed)
  seed = g:IncrementRNG(seed)
  game:Spawn(EntityType.ENTITY_FALLEN, 0, -- 81.0 (The Fallen)
             g:GridToPos(6, 3), Vector(0, 0), nil, 0, seed)

  -- Prime the statue to wake up quicker
  for i, entity in pairs(Isaac.GetRoomEntities()) do
    if entity.Type == EntityType.ENTITY_SATAN then -- 84
      entity:ToNPC().I1 = 1
    end
  end

  Isaac.DebugString("Spawned the first wave manually and primed the statue.")
end

-- Check to see if we are entering the Mega Satan room so we can update the floor tracker and
-- prevent cheating on the "Everything" race goal
function PostNewRoom:CheckMegaSatanRoom()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local room = game:GetRoom()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local player = game:GetPlayer(0)
  local sfx = SFXManager()

  -- Check to see if we are entering the Mega Satan room
  if roomIndex ~= GridRooms.ROOM_MEGA_SATAN_IDX then -- -7
    return
  end

  -- Emulate reaching a new floor, using a custom floor number of 13 (The Void is 12)
  Isaac.DebugString('Entered the Mega Satan room.')

  -- Check to see if we are cheating on the "Everything" race goal
  if g.race.goal == "Everything" and g.run.killedLamb == false then
    -- Do a little something fun
    sfx:Play(SoundEffect.SOUND_THUMBS_DOWN, 1, 0, false, 1) -- 267
    for i = 1, 20 do
      local pos = room:FindFreePickupSpawnPosition(player.Position, 50, true)
      -- Use a value of 50 to spawn them far from the player
      local monstro = game:Spawn(EntityType.ENTITY_MONSTRO, 0, pos, Vector(0, 0), nil, 0, 0)
      monstro.MaxHitPoints = 1000000
      monstro.HitPoints = 1000000
    end
  end
end

function PostNewRoom:CheckScolexRoom()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local roomDesc = level:GetCurrentRoomDesc()
  local roomStageID = roomDesc.Data.StageID
  local roomVariant = roomDesc.Data.Variant
  local room = game:GetRoom()
  local roomClear = room:IsClear()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local challenge = Isaac.GetChallenge()

  -- We don't need to modify Scolex if the room is already cleared
  if roomClear then
    return
  end

  -- We only need to check for rooms from the "Special Rooms" STB
  if roomStageID ~= 0 then
    return
  end

  -- Don't do anything if we are not in one of the Scolex boss rooms
  -- (there are no Double Trouble rooms with Scolexes)
  if roomVariant ~= 1070 and
     roomVariant ~= 1071 and
     roomVariant ~= 1072 and
     roomVariant ~= 1073 and
     roomVariant ~= 1074 and
     roomVariant ~= 1075 then

    return
  end

  if g.race.rFormat == "seeded" or
     challenge == Isaac.GetChallengeIdByName("R+7 (Season 6 Beta)") then

     -- Since Scolex attack patterns ruin seeded races, delete it and replace it with two Frails
    -- (there are 10 Scolex entities)
    for i, entity in pairs(Isaac.GetRoomEntities()) do
      if entity.Type == EntityType.ENTITY_PIN and entity.Variant == 1 then -- 62.1 (Scolex)
        entity:Remove() -- This takes a game frame to actually get removed
      end
    end

    for i = 1, 2 do
      -- We don't want to spawn both of them on top of each other since that would make them behave a little glitchy
      local pos = room:GetCenterPos()
      if i == 1 then
        pos.X = pos.X - 150
      elseif i == 2 then
        pos.X = pos.X + 150
      end
      -- Note that pos.X += 200 causes the hitbox to appear too close to the left/right side,
      -- causing damage if the player moves into the room too quickly
      local frail = game:Spawn(EntityType.ENTITY_PIN, 2, pos, Vector(0,0), nil, 0, roomSeed)
      frail.Visible = false -- It will show the head on the first frame after spawning unless we do this
      -- The game will automatically make the entity visible later on
    end
    Isaac.DebugString("Spawned 2 replacement Frails for Scolex with seed: " .. tostring(roomSeed))
  end
end

-- Prevent unavoidable damage in a specific room in the Dank Depths
function PostNewRoom:CheckDepthsPuzzle()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local roomDesc = level:GetCurrentRoomDesc()
  local roomVariant = roomDesc.Data.Variant
  local room = game:GetRoom()
  local gridSize = room:GetGridSize()

  -- We only need to check if we are in the Dank Depths
  if stage ~= LevelStage.STAGE3_1 and -- 5
     stage ~= LevelStage.STAGE3_2 then -- 6

    return
  end
  if stageType ~= StageType.STAGETYPE_AFTERBIRTH then -- 2
    return
  end

  if roomVariant ~= 41 and
     roomVariant ~= 10041 and -- (flipped)
     roomVariant ~= 20041 and -- (flipped)
     roomVariant ~= 30041 then -- (flipped)

    return
  end

  -- Scan the entire room to see if any rocks were replaced with spikes
  for i = 1, gridSize do
    local gridEntity = room:GetGridEntity(i)
    if gridEntity ~= nil then
      local saveState = gridEntity:GetSaveState()
      if saveState.Type == GridEntityType.GRID_SPIKES then -- 17
        -- Remove the spikes
        gridEntity.Sprite = Sprite() -- If we don't do this, it will still show for a frame
        room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work

        -- Originally, we would add a rock here with:
        -- "Isaac.GridSpawn(GridEntityType.GRID_ROCK, 0, gridEntity.Position, true) -- 17"
        -- However, this results in invisible collision persisting after the rock is killed
        -- This bug can probably be subverted by waiting a frame for the spikes to fully despawn,
        -- but then having rocks spawn "out of nowhere" would look glitchy,
        -- so just remove the spikes and don't do anything else
        Isaac.DebugString("Removed spikes from the Dank Depths bomb puzzle room.")
      end
    end
  end
end

-- Check for various NPCs all at once
-- (we want to loop through all of the entities in the room only once to maximize performance)
function PostNewRoom:CheckEntities()
  -- Local variables
  local game = Game()
  local gameFrameCount = game:GetFrameCount()
  local room = game:GetRoom()
  local roomClear = room:IsClear()
  local roomShape = room:GetRoomShape()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local player = game:GetPlayer(0)

  local subvertTeleport = false
  for i, entity in pairs(Isaac.GetRoomEntities()) do
    if entity.Type == EntityType.ENTITY_GURDY or -- 36
       entity.Type == EntityType.ENTITY_MOM or -- 45
       entity.Type == EntityType.ENTITY_MOMS_HEART then -- 78 (this includes It Lives!)

      subvertTeleport = true

    elseif entity.Type == EntityType.ENTITY_SLOTH or -- Sloth (46.0) and Super Sloth (46.1)
       entity.Type == EntityType.ENTITY_PRIDE then -- Pride (52.0) and Super Pride (52.1)

      -- Replace all Sloths / Super Sloths / Prides / Super Prides with a new one that has an InitSeed equal to the room
      -- (we want the card drop to always be the same if there happens to be more than one in the room;
      -- in vanilla the type of card that drops depends on the order you kill them in)
      game:Spawn(entity.Type, entity.Variant, entity.Position, entity.Velocity, entity.Parent, entity.SubType, roomSeed)
      entity:Remove()

    elseif entity.Type == EntityType.ENTITY_THE_HAUNT and entity.Variant == 0 then -- Haunt (260.0)
      -- Speed up the first Lil' Haunt attached to a Haunt (1/3)
      -- Later on this frame, the Lil' Haunts will spawn and have their state altered
      -- in the "PostNPCInit:Main()" function
      -- We will mark to actually detach one of them one frame from now
      -- (or two of them, if there are two Haunts in the room)
      g.run.speedLilHauntsFrame = gameFrameCount + 1

      -- We also need to check for the black champion version of The Haunt,
      -- since both of his Lil' Haunts should detach at the same time
      if entity:ToNPC():GetBossColorIdx() == 17 then
        g.run.speedLilHauntsBlack = true
      end

      g.run.currentHaunts[#g.run.currentHaunts + 1] = entity.Index
      Isaac.DebugString("Added Haunt #" .. tostring(#g.run.currentHaunts) ..
                        " with index " .. tostring(entity.Index) .. " to the table.")
    end
  end

  -- Subvert the disruptive teleportation from Gurdy, Mom, Mom's Heart, and It Lives
  if subvertTeleport and
     roomClear == false and
     roomShape == RoomShape.ROOMSHAPE_1x1 then -- 1
     -- (there are Double Trouble rooms with Gurdy but they don't cause a teleport)

     g.run.teleportSubverted = true

    -- Make the player invisible or else it will show them on the teleported position for 1 frame
    -- (we can't just move the player here because the teleport occurs after this callback finishes)
    g.run.teleportSubvertScale = player.SpriteScale
    player.SpriteScale = Vector(0, 0)
    -- (we actually move the player on the next frame in the "PostRender:CheckSubvertTeleport()" function)

    -- Also make the familiars invisible
    -- (for some reason, we can use the "Visible" property instead of
    -- resorting to "SpriteScale" like we do for the player)
    for i, entity in pairs(Isaac.GetRoomEntities()) do
      if entity.Type == EntityType.ENTITY_FAMILIAR then -- 3
        entity.Visible = false
      end
    end
  end
end

-- Check to see if we need to respawn an end-of-race or end-of-speedrun trophy
function PostNewRoom:CheckRespawnTrophy()
  -- Local variables
  local game = Game()
  local level = game:GetLevel()
  local room = game:GetRoom()
  local stage = level:GetStage()
  local stageType = level:GetStageType()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local roomType = room:GetType()
  local roomClear = room:IsClear()

  -- There are only trophies on The Chest or the Dark Room
  if stage ~= 11 then
    return
  end

  -- If the room is not clear, we couldn't have already finished the race/speedrun
  if roomClear == false then
    return
  end

  -- All races finish in some sort of boss room
  if roomType ~= RoomType.ROOM_BOSS then -- 5
    return
  end

  -- From here on out, handle custom speedrun challenges and races separately
  if Speedrun:InSpeedrun() then
    -- All of the custom speedrun challenges end at the Blue Baby room or The Lamb room
    if roomIndex == GridRooms.ROOM_MEGA_SATAN_IDX then -- -7
      return
    end

     -- Don't respawn the trophy if the player just finished a R+9/14 speedrun
    if Speedrun.finished then
      return
    end

    -- Don't respawn the trophy if the player is in the middle of a R+9/14 speedrun
    if Speedrun.spawnedCheckpoint then
      return
    end

  elseif g.raceVars.finished == false and
         g.race.status == "in progress" then

    -- Check to see if we are in the final room corresponding to the goal
    if g.race.goal == "Blue Baby" then
      if stageType == 0 or roomIndex == GridRooms.ROOM_MEGA_SATAN_IDX then
        return
      end

    elseif g.race.goal == "The Lamb" then
      if stageType == 1 or roomIndex == GridRooms.ROOM_MEGA_SATAN_IDX then
        return
      end

    elseif g.race.goal == "Mega Satan" then
      if roomIndex ~= GridRooms.ROOM_MEGA_SATAN_IDX then
        return
      end

    elseif g.race.goal == "Everything" then
      if stageType == 1 or roomIndex ~= GridRooms.ROOM_MEGA_SATAN_IDX then
        return
      end
    end

  else
    -- We are not in a custom speedrun challenge and not in a race
    return
  end

  -- We are re-entering a boss room after we have already spawned the trophy (which is a custom entity),
  -- so we need to respawn it
  game:Spawn(Isaac.GetEntityTypeByName("Race Trophy"), Isaac.GetEntityVariantByName("Race Trophy"),
             room:GetCenterPos(), Vector(0, 0), nil, 0, 0)
  Isaac.DebugString("Respawned the end of race trophy.")
end

function PostNewRoom:Race()
  -- Local variables
  local game = Game()
  local room = game:GetRoom()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local roomDesc = level:GetCurrentRoomDesc()
  local roomStageID = roomDesc.Data.StageID
  local roomVariant = roomDesc.Data.Variant
  local roomType = room:GetType()
  local roomClear = room:IsClear()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"
  local gridSize = room:GetGridSize()
  local sfx = SFXManager()

  -- Remove the final place graphic if it is showing
  Sprites:Init("place2", 0)

  -- Go to the custom "Race Start" room
  if (g.race.status == "open" or
      g.race.status == "starting") and
     g.run.roomsEntered == 1 then

    Isaac.ExecuteCommand("goto s.boss.9999")
    -- We can't use an existing boss room because after the boss is removed, a pedestal will spawn
    Isaac.DebugString("Going to the race room.")
    -- We do more things in the "PostNewRoom" callback
    return
  end

  -- Check for the special death condition
  SeededDeath:PostNewRoom()
  SeededDeath:PostNewRoomCheckSacrificeRoom()

  -- Check for rooms that should be manually seeded during seeded races
  SeededRooms:PostNewRoom()

  -- Prevent players from skipping a floor by using the I AM ERROR room on Womb 2 on the "Everything" race goal
  if stage == LevelStage.STAGE4_2 and -- 8
     roomType == RoomType.ROOM_ERROR and -- 3
     g.race.goal == "Everything" then

    for i = 1, gridSize do
      local gridEntity = room:GetGridEntity(i)
      if gridEntity ~= nil then
        local saveState = gridEntity:GetSaveState()
        if saveState.Type == GridEntityType.GRID_TRAPDOOR then -- 17
          -- Remove the crawlspace and spawn a Heaven Door (1000.39), which will get replaced on the next frame
          -- in the "FastTravel:ReplaceHeavenDoor()" function
          room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work
          game:Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR,
                     gridEntity.Position, Vector(0, 0), nil, 0, 0)
          Isaac.DebugString("Stopped the player from skipping Cathedral from the I AM ERROR room.")
        end
      end
    end
  end

  -- Check to see if we need to open the Mega Satan Door
  if (g.race.goal == "Mega Satan" or
      g.raceVars.finished or
      (g.race.goal == "Everything") and
       g.run.killedLamb) and
     stage == 11 and -- If this is The Chest or Dark Room
     roomIndex == level:GetStartingRoomIndex() then

    local door = room:GetDoor(1) -- The top door is always 1
    door:TryUnlock(true)
    sfx:Stop(SoundEffect.SOUND_UNLOCK00) -- 156
    -- door:IsOpen() is always equal to false here for some reason,
    -- so just open it every time we enter the room and silence the sound effect
    Isaac.DebugString("Opened the Mega Satan door.")
  end

  -- Check to see if we need to spawn Victory Lap bosses
  if g.raceVars.finished and
     roomClear == false and
     roomStageID == 0 and
     (roomVariant == 3390 or -- Blue Baby
      roomVariant == 3391 or
      roomVariant == 3392 or
      roomVariant == 3393 or
      roomVariant == 5130) then -- The Lamb

    -- Replace Blue Baby / The Lamb with some random bosses (based on the number of Victory Laps)
    for i, entity in pairs(Isaac.GetRoomEntities()) do
      if entity.Type == EntityType.ENTITY_ISAAC or -- 102
         entity.Type == EntityType.ENTITY_THE_LAMB then -- 273

        entity:Remove()
      end
    end

    local randomBossSeed = roomSeed
    local numBosses = g.raceVars.victoryLaps + 1
    for i = 1, numBosses do
      randomBossSeed = g:IncrementRNG(randomBossSeed)
      math.randomseed(randomBossSeed)
      local randomBoss = g.bossArray[math.random(1, #g.bossArray)]
      if randomBoss[1] == 19 then
        -- Larry Jr. and The Hollow require multiple segments
        for j = 1, 6 do
          game:Spawn(randomBoss[1], randomBoss[2], room:GetCenterPos(), Vector(0,0), nil, randomBoss[3], roomSeed)
        end
      else
        game:Spawn(randomBoss[1], randomBoss[2], room:GetCenterPos(), Vector(0,0), nil, randomBoss[3], roomSeed)
      end
    end
    Isaac.DebugString("Replaced Blue Baby / The Lamb with " .. tostring(numBosses) .. " random bosses.")
  end

  PostNewRoom:CheckSeededMOTreasure()
end

function PostNewRoom:RaceStart()
  -- Local variables
  local game = Game()
  local gameFrameCount = game:GetFrameCount()
  local level = game:GetLevel()
  local roomIndex = level:GetCurrentRoomDesc().SafeGridIndex
  if roomIndex < 0 then -- SafeGridIndex is always -1 for rooms outside the grid
    roomIndex = level:GetCurrentRoomIndex()
  end
  local room = game:GetRoom()
  local sfx = SFXManager()
  local player = game:GetPlayer(0)

  -- Set up the "Race Room"
  if gameFrameCount ~= 0 or
     roomIndex ~= GridRooms.ROOM_DEBUG_IDX or -- -3
     (g.race.status ~= "open" and
      g.race.status ~= "starting") then

    return
  end

  -- Stop the boss room sound effect
  sfx:Stop(SoundEffect.SOUND_CASTLEPORTCULLIS) -- 190

  -- We want to trap the player in the room, so delete all 4 doors
  for i = 0, 3 do
    room:RemoveDoor(i)
  end

  -- Put the player next to the bottom door
  player.Position = Vector(320, 400)

  -- Spawn two Gaping Maws (235.0)
  game:Spawn(EntityType.ENTITY_GAPING_MAW, 0, g:GridToPos(5, 5), Vector(0, 0), nil, 0, 0)
  game:Spawn(EntityType.ENTITY_GAPING_MAW, 0, g:GridToPos(7, 5), Vector(0, 0), nil, 0, 0)
end

function PostNewRoom:CheckSeededMOTreasure()
  -- Local variables
  local game = Game()
  local room = game:GetRoom()
  local roomType = room:GetType()
  local gridSize = room:GetGridSize()
  local roomSeed = room:GetSpawnSeed() -- Gets a reproducible seed based on the room, something like "2496979501"

  -- Check to see if we need to make a custom item room for Seeded MO
  if roomType == RoomType.ROOM_TREASURE and -- 4
     g.race.rFormat == "seededMO" then

    -- Delete everything in the room
    for i = 1, gridSize do
      local gridEntity = room:GetGridEntity(i)
      if gridEntity ~= nil then
        if gridEntity:GetSaveState().Type ~= GridEntityType.GRID_WALL and -- 15
           gridEntity:GetSaveState().Type ~= GridEntityType.GRID_DOOR then -- 16

          room:RemoveGridEntity(i, 0, false) -- gridEntity:Destroy() does not work
        end
      end
    end
    for i, entity in pairs(Isaac.GetRoomEntities()) do
      if entity.Type ~= EntityType.ENTITY_PLAYER then -- 1
        entity:Remove()
      end
    end

    -- Define the item pedestal positions
    local itemPos = {
      {
        {X = 6, Y = 3},
      },
      {
        {X = 5, Y = 3},
        {X = 7, Y = 3},
      },
      {
        {X = 4, Y = 3},
        {X = 6, Y = 3},
        {X = 8, Y = 3},
      },
      {
        {X = 5, Y = 2},
        {X = 7, Y = 2},
        {X = 5, Y = 4},
        {X = 7, Y = 4},
      },
      {
        {X = 5, Y = 2},
        {X = 7, Y = 2},
        {X = 4, Y = 4},
        {X = 6, Y = 4},
        {X = 8, Y = 4},
      },
      {
        {X = 4, Y = 2},
        {X = 6, Y = 2},
        {X = 8, Y = 2},
        {X = 4, Y = 4},
        {X = 6, Y = 4},
        {X = 8, Y = 4},
      },
    }

    -- Define the various item tiers
    local itemTiers = {
      {1, 2, 3, 4, 5},
      {6, 7, 8, 9, 10},
    }

    -- Find out which tier we need
    math.randomseed(roomSeed)
    local chosenTier = math.random(1, #itemTiers)

    -- Place the item pedestals (5.100)
    for i = 1, #itemTiers[chosenTier] do
      local X = itemPos[#itemTiers[chosenTier]][i].X
      local Y = itemPos[#itemTiers[chosenTier]][i].Y
      local itemID = itemTiers[chosenTier][i]
      local itemPedestal = game:Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE,
                                      g:GridToPos(X, Y), Vector(0, 0), nil, itemID, 0)
      -- The seed can be 0 since the pedestal will be replaced on the next frame
      itemPedestal:ToPickup().TheresOptionsPickup = true
    end
  end
end

return PostNewRoom
