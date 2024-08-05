local component = require("component")
local sides = require("sides")
local event = require("event")

local function loadNonConsumables(filename)
  local nonConsumables = {}
  local file, err = io.open(filename, "r")
  if not file then
    os.exit("Could not open non-consumables file: " .. err)
  end
  for line in file:lines() do
    nonConsumables[line] = true
  end
  file:close()
  return nonConsumables
end

local function findTransposers()
  local transposers = {}
  for address, _ in component.list("transposer") do
    table.insert(transposers, component.proxy(address))
  end
  if #transposers == 0 then
    os.exit("There must be at least one transposer connected to the system.")
  end
  print(string.format("Found %d transposers.", #transposers))
  return transposers
end

local function getSides(transposer)
  for side = 0, 5 do
    local name = transposer.getInventoryName(side)
    if name == "tile.interface" then
      transposer.inputBusSide = side
    elseif name == "gt.blockmachines" and transposer.getTankCount(side) > 0 then
      transposer.inputHatchSide = side
    elseif name == "tile.appliedenergistics2.BlockInterface" then
      transposer.interfaceSide = side
    end
  end

  if not transposer.interfaceSide then
    os.exit("No interface block was found next to the transposer.")
  end

  if not transposer.inputBusSide then
    os.exit("No input bus was found next to the transposer.")
  end
end

local function mainLoop(transposers, nonConsumables)
  repeat
    for _, transposer in pairs(transposers) do
      local item = transposer.getStackInSlot(transposer.inputBusSide, 1)
      if item and nonConsumables[item.label] then
        if not transposer.inputHatchSide or transposer.getFluidInTank(transposer.inputHatchSide, 1).amount == 0 then
          transposer.transferItem(transposer.inputBusSide, transposer.interfaceSide, 1, 1, 1)
        end
      end
    end
  until event.pull(0.01) == "interrupted"
end

local function main()
  local nonConsumables = loadNonConsumables("ncs")
  local transposers = findTransposers()

  for _, transposer in pairs(transposers) do
    getSides(transposer)
  end

  mainLoop(transposers, nonConsumables)
end

main()