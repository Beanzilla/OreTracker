
-- https://rubenwardy.com/minetest_modding_book/en/map/environment.html#finding-nodes

-- A public API
oretracker = {}

oretracker.S = minetest.get_translator("oretracker")
oretracker.modpath = minetest.get_modpath("oretracker")
oretracker.store = minetest.get_mod_storage()

-- Settings
-- Do not set detect_range to a very high number it may cause extreme loads when there are multiple players with this range
-- Recommended range is 8 blocks
oretracker.detect_range = 8 -- Range in blocks
-- The prefered fastest is 1 second, 0 or negative is instantanious updates (Which greatly impacts the server/client)
-- Recommended default is 3 seconds.
oretracker.scan_frequency = 3 -- Frequency in seconds

-- This attempts to detect the gamemode
if not minetest.registered_nodes["default:stone"] then
    if not minetest.registered_nodes["mcl_core:stone"] then
        oretracker.gamemode = "N/A"
    else
        oretracker.gamemode = "MCL"
        -- Attempt to determine if it's MCL5 or MCL2
        if not minetest.registered_nodes["mcl_nether:ancient_debris"] then
            oretracker.gamemode = "MCL2"
        else
            oretracker.gamemode = "MCL5"
        end
    end
else
    oretracker.gamemode = "MTG"
end

minetest.log("action", "[oretracker] Detected game "..oretracker.gamemode..".")

-- Form a container to track what ores we want to follow
oretracker.ores = {}

dofile(oretracker.modpath .. "/api.lua")

-- Use api to assign ores we know/should be caring about
if oretracker.gamemode == "MCL2" or oretracker.gamemode == "MCL5" then
    oretracker.add_ore("mcl_core:stone_with_coal")
    oretracker.add_ore("mcl_core:stone_with_iron")
    oretracker.add_ore("mcl_core:stone_with_gold")
    oretracker.add_ore("mcl_core:stone_with_redstone")
    oretracker.add_ore("mcl_core:stone_with_redstone_lit")
    oretracker.add_ore("mcl_core:stone_with_lapis")
    oretracker.add_ore("mcl_core:stone_with_emerald")
    oretracker.add_ore("mcl_core:stone_with_diamond")
    oretracker.add_ore("mcl_nether:quartz_ore") -- This fails on MCL2 :S
--    oretracker.add_ore("mcl_nether:glowstone") -- Same here, though by default this is disabled as glowstone isn't a "ore"
end

if oretracker.gamemode == "MCL5" then
    oretracker.add_ore("mcl_copper:stone_with_copper")
    oretracker.add_ore("mcl_nether:ancient_debris")
    oretracker.add_ore("mcl_nether_gold:nether_gold_ore")
end

if oretracker.gamemode == "MTG" then
    oretracker.add_ore("default:stone_with_coal")
    oretracker.add_ore("default:stone_with_iron")
    oretracker.add_ore("default:stone_with_gold")
    oretracker.add_ore("default:stone_with_copper")
    oretracker.add_ore("default:stone_with_tin")
    oretracker.add_ore("default:stone_with_mese")
    oretracker.add_ore("default:stone_with_diamond")
end

local size = 0
local result = "Ores: "
for i, v in ipairs(oretracker.ores) do
    result = result..v.." "
    size = size + 1
end
minetest.log("action", "[oretracker] Found "..size.." ores configured.")
minetest.log("action", "[oretracker] "..result)

-- Now to add the tracker notification system
oretracker.check_player = function(player)
    local p = player
    if not minetest.is_player(p) then
        p = minetest.get_player_by_name(p)
    end
    local pos = p:get_pos()
    local pname = p:get_player_name()
    -- I need to clean up the player's ore waypoints added by the latter code
    oretracker.clear_pos(pname)
    local p1 = vector.subtract(pos, {x = oretracker.detect_range, y = oretracker.detect_range, z = oretracker.detect_range})
    local p2 = vector.add(pos, {x = oretracker.detect_range, y = oretracker.detect_range, z = oretracker.detect_range})
    local area = minetest.find_nodes_in_area(p1, p2, oretracker.ores)
    for i=1, #area do
        local node = minetest.get_node_or_nil(area[i])
        if node == nil then
            minetest.log("action", "[oretracker] Failed to obtain node at "..minetest.pos_to_string(area[1], 1)..".")
        else
            local delta = vector.subtract(area[i], pos)
            local distance = (delta.x*delta.x) + (delta.y*delta.y) + (delta.z*delta.z)
            if distance <= oretracker.detect_range*oretracker.detect_range then
                distance = string.format("%.0f", math.sqrt(distance))
                local block = "?"
                local color = 0xffffff
                if string.find(node.name, "coal") then
                    block = "Coa"
                    color = 0xc8c8c8
                elseif string.find(node.name, "iron") then
                    block = "Iro"
                    color = 0xaf644b
                elseif string.find(node.name, "gold") then
                    block = "Gol"
                    color = 0xc8c84b
                elseif string.find(node.name, "mese") then
                    block = "Mes"
                    color = 0xffff4b
                elseif string.find(node.name, "diamond") then
                    block = "Dia"
                    color = 0x4bfafa
                elseif string.find(node.name, "quartz") then
                    block = "Qua"
                    color = 0xc8c8c8
                elseif string.find(node.name, "copper") then
                    block = "Cop"
                    color = 0xc86400
                elseif string.find(node.name, "tin") then
                    block = "Tin"
                    color = 0xc8c8c8
                elseif string.find(node.name, "debris") then
                    block = "Deb"
                    color = 0xaa644b
                elseif string.find(node.name, "lapis") then
                    block = "Lap"
                    color = 0x4b4bc8
                elseif string.find(node.name, "redstone") then
                    block = "Red"
                    color = 0xc81919
                elseif string.find(node.name, "glowstone") then
                    block = "Glo"
                    color = 0xffff4b
                end
                if block == "?" then
                    minetest.log("action", "[oretracker] Found '"..node.name.."' at "..minetest.pos_to_string(area[i], 1).." which is "..distance.." away from '"..pname..".")
                    block = node.name
                end
                -- Make a waypoint with the nodes name
                oretracker.add_pos(pname, area[i], block, color)
            end
        end
    end
end

local interval = 0
minetest.register_globalstep(function(dtime)
    interval = interval - dtime
    if interval <= 0 then
        for _, player in ipairs(minetest.get_connected_players()) do
            oretracker.check_player(player)
        end
        interval = oretracker.scan_frequency
    end
end)
