local FastDrop = {}

-- Includes
local g = require("racing_plus/globals")

--
-- Fast drop functions
--

-- Check for fast-drop inputs
function FastDrop:CheckDropInput()
  -- If they do not have a hotkey bound, do nothing
  local hotkeyDrop
  if RacingPlusData ~= nil then
    hotkeyDrop = RacingPlusData:Get("hotkeyDrop")
  end
  if hotkeyDrop == nil or
     hotkeyDrop == 0 then

    return
  end

  -- Check for the input
  -- (we check all inputs instead of "player.ControllerIndex" because
  -- a controller player might be using the keyboard to reset)
  -- (we use "IsActionPressed()" instead of "IsActionTriggered()" because
  -- it is faster to drop on press than on release)
  local pressed = false
  for i = 0, 3 do -- There are 4 possible inputs/players from 0 to 3
    if Input.IsButtonPressed(hotkeyDrop, i) then
      pressed = true
      break
    end
  end
  if not pressed then
    return
  end

  -- Trinkets (this does handle the Tick properly)
  local pos3 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropTrinket(pos3, false)
  local pos4 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropTrinket(pos4, false)

  -- Pocket items (cards, pills, runes, etc.)
  local pos1 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropPoketItem(0, pos1) -- Spider misspelled this
  local pos2 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropPoketItem(1, pos2)
end

-- Check for fast-drop inputs (trinket-only)
function FastDrop:CheckDropInputTrinket()
  -- If they do not have a hotkey bound, do nothing
  local hotkeyDropTrinket
  if RacingPlusData ~= nil then
    hotkeyDropTrinket = RacingPlusData:Get("hotkeyDropTrinket")
  end
  if hotkeyDropTrinket == nil or
     hotkeyDropTrinket == 0 then

    return
  end

  -- Check for the input
  -- (we check all inputs instead of "player.ControllerIndex" because
  -- a controller player might be using the keyboard to reset)
  -- (we use "IsActionPressed()" instead of "IsActionTriggered()" because
  -- it is faster to drop on press than on release)
  local pressed = false
  for i = 0, 3 do -- There are 4 possible inputs/players from 0 to 3
    if Input.IsButtonPressed(hotkeyDropTrinket, i) then
      pressed = true
      break
    end
  end
  if not pressed then
    return
  end

  -- Trinkets
  -- (this code does handle the Tick properly)
  local pos1 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropTrinket(pos1, false)
  local pos2 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropTrinket(pos2, false)
end

-- Check for fast-drop inputs (pocket-item-only)
function FastDrop:CheckDropInputPocket()
  -- If they do not have a hotkey bound, do nothing
  local hotkeyDropPocket
  if RacingPlusData ~= nil then
    hotkeyDropPocket = RacingPlusData:Get("hotkeyDropPocket")
  end
  if hotkeyDropPocket == nil or
     hotkeyDropPocket == 0 then

    return
  end

  -- Check for the input
  -- (we check all inputs instead of "player.ControllerIndex" because
  -- a controller player might be using the keyboard to reset)
  -- (we use "IsActionPressed()" instead of "IsActionTriggered()" because
  -- it is faster to drop on press than on release)
  local pressed = false
  for i = 0, 3 do -- There are 4 possible inputs/players from 0 to 3
    if Input.IsButtonPressed(hotkeyDropPocket, i) then
      pressed = true
      break
    end
  end
  if not pressed then
    return
  end

  -- Pocket items (cards, pills, runes, etc.)
  local pos1 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropPoketItem(0, pos1) -- Spider misspelled this
  local pos2 = g.r:FindFreePickupSpawnPosition(g.p.Position, 0, true)
  g.p:DropPoketItem(1, pos2)
end

return FastDrop
