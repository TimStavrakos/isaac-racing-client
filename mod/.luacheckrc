-- These are all of the declarations in the "enums.lua" file in the "scripts" subdirectory,
-- sorted alphabetically
globals = {
  "ActionTriggers",
  "BabySubType",
  "BombSubType",
  "BombVariant",
  "ButtonAction",
  "CacheFlag",
  "Card",
  "Challenge",
  "ChestSubType",
  "CoinSubType",
  "CollectibleType",
  "Color",
  "DamageFlag",
  "Difficulty",
  "Direction",
  "DoorSlot",
  "DoorState",
  "DoorVariant",
  "EffectVariant",
  "EntityCollisionClass",
  "EntityFlag",
  "EntityGridCollisionClass",
  "EntityPartition",
  "EntityPtr",
  "EntityRef",
  "EntityType",
  "FamiliarVariant",
  "Font",
  "Game",
  "GameStateFlag",
  "GetPtrHash",
  "GridCollisionClass",
  "GridEntityType",
  "GridRooms",
  "HeartSubType",
  "Input",
  "InputHook",
  "Isaac",
  "ItemConfig",
  "ItemPoolType",
  "ItemType",
  "KColor",
  "Keyboard",
  "KeySubType",
  "LaserOffset",
  "LevelCurse",
  "LevelStage",
  "LevelStateFlag",
  "LocustSubtypes",
  "ModCallbacks",
  "Mouse",
  "Music",
  "MusicManager",
  "NpcState",
  "NullItemID",
  "PickupPrice",
  "PickupVariant",
  "PillColor",
  "PillEffect",
  "PlayerForm",
  "PlayerItemState",
  "PlayerSpriteLayer",
  "PlayerType",
  "ProjectileFlags",
  "ProjectileParams",
  "ProjectileVariant",
  "Random",
  "RandomVector",
  "RegisterMod",
  "RNG",
  "RoomShape",
  "RoomType",
  "SeedEffect",
  "SFXManager",
  "SortingLayer",
  "SoundEffect",
  "Sprite",
  "StageType",
  "TearFlags",
  "TearVariant",
  "TrinketType",
  "Vector",
  "WeaponType",

  -- Racing+ global variables
  "RacingPlusGlobals",
  "RacingPlusSchoolbag",
  "RacingPlusSpeedrun",
  "RacingPlusData",

  -- Other mods
  "SinglePlayerCoopBabies", -- The Babies Mod
  "RacingPlusRebalanced",
  "VanillaStreakText",
  "InfinityTrueCoopInterface", -- The True Co-op Mod
  "MinimapAPI",
}

-- Luacheck complains about functions in a module declared with a colon if self is unused;
-- we may want all functions to be declared with a colon for uniformity
unused_args = false
