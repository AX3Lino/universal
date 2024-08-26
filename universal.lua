local component = require("component")
local sides = require("sides")
local event = require("event")
local thread = require("thread")

maxTimeout = 2

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
    transposer.tankCount = transposer.getTankCount(side)
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

local function run(transposer, nonConsumables)
  local timeout = 0.05
  getSides(transposer)
  while true do
    local item = transposer.getStackInSlot(transposer.inputBusSide, 1)
    -- We found an item! Bump the activity.
    if item then
      timeout = 0.05
      -- We only have a non-consumable left!
      if nonConsumables[item.label] then
        local allTanksEmpty = true
        -- We have a tank, so check that there are no fluids left.
        if transposer.inputHatchSide then
          for tankIndex = 1, transposer.tankCount do
            if transposer.getFluidInTank(transposer.inputHatchSide, tankIndex).amount > 0 then
              allTanksEmpty = false
              break
            end
          end
        end
      
        -- If all tanks were empty, move the non-consumable.
        if allTanksEmpty then
          transposer.transferItem(transposer.inputBusSide, transposer.interfaceSide, 1, 1, 1)
        end
      end
    else
      timeout = math.min(timeout + 0.05, maxTimeout)
    end
    os.sleep(timeout)
  end
end

local function main()
  local nonConsumables = loadNonConsumables("ncs")
  local transposers = findTransposers()

  for _, transposer in pairs(transposers) do
    thread.create(run, transposer, nonConsumables)
  end
end

main()
