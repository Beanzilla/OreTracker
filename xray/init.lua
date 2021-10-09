-- https://rubenwardy.com/minetest_modding_book/en/map/environment.html#finding-nodes

-- A public API
xray = {}

xray.S = minetest.get_translator("xray")
xray.modpath = minetest.get_modpath("xray")
xray.store = {}
xray.p_stats = {}

-- Settings
-- Do not set detect_range to a very high number it may cause extreme loads when there are multiple players with this range
-- Recommended range is 6 blocks
xray.detect_range = 6 -- Range in blocks
-- 0 or negative is instantanious updates (Which greatly impacts the server/client)
-- Recommended frequency is 1 second.
xray.scan_frequency = 1 -- Frequency in seconds
-- Light level that xray nodes emit (Max is 14 min is 0)
-- Recommended light_level is 4. (Provides enough light to use the mod, might need to use torches if you want it lighter, or adjust here)
xray.light_level = 4 -- From 0-14

-- Only turn this on if you have strange blobs of invisible blocks (due to a server crash, etc.)
local fix_mode = false

-- This attempts to detect the gamemode
if not minetest.registered_nodes["default:stone"] then
    if not minetest.registered_nodes["mcl_core:stone"] then
        xray.gamemode = "N/A"
    else
        -- Attempt to determine if it's MCL5 or MCL2
        if not minetest.registered_nodes["mcl_deepslate:deepslate"] then
            xray.gamemode = "MCL2"
        else
            xray.gamemode = "MCL5"
        end
    end
else
    xray.gamemode = "MTG"
end

minetest.log("action", "[oretracker-xray] Detected game "..xray.gamemode..".")

-- Form a container to track what ores we want to follow
xray.nodes = {}

-- Make our counterparts
dofile(xray.modpath .. "/register.lua")

-- Make our api
dofile(xray.modpath .. "/api.lua")

-- Use api to assign ores we know/should be caring about
if xray.gamemode == "MCL2" or xray.gamemode == "MCL5" then
    xray.add_node("mcl_core:stone") -- xray:mcl_stone
    xray.add_node("mcl_core:granite") -- xray:mcl_granite
    xray.add_node("mcl_core:andesite") -- xray:mcl_andesite
    xray.add_node("mcl_core:diorite") -- xray:mcl_diorite
    xray.add_node("mcl_core:sandstone") -- xray:mcl_sstone
    xray.add_node("mcl_core:redsandstone") -- xray:mcl_rsstone
end

if xray.gamemode == "MCL5" then
    xray.add_node("mcl_blackstone:blackstone") -- xray:mcl_bstone
    xray.add_node("mcl_blackstone:basalt") -- xray:mcl_basalt
    xray.add_node("mcl_nether:netherrack") -- xray:mcl_netherrack
    -- Deepslate now included
    xray.add_node("mcl_deepslate:deepslate") -- xray:mcl_deepslate
end

if xray.gamemode == "MTG" then
    xray.add_node("default:stone") -- xray:mtg_stone
    xray.add_node("default:desert_stone") -- xray:mtg_dstone
    xray.add_node("default:sandstone") -- xray:mtg_sstone
    xray.add_node("default:desert_sandstone") -- xray:mtg_dsstone
    xray.add_node("default:silver_sandstone") -- xray:mtg_ssstone
end

-- Include our nodes so we can cleanup after ourselves
-- Yeah there will be warnings in your logs about unknown nodes but who really checks that anyway.
xray.add_node("xray:mtg_stone")
xray.add_node("xray:mtg_dstone")
xray.add_node("xray:mtg_sstone")
xray.add_node("xray:mtg_dsstone")
xray.add_node("xray:mtg_ssstone")
xray.add_node("xray:mcl_stone")
xray.add_node("xray:mcl_granite")
xray.add_node("xray:mcl_andesite")
xray.add_node("xray:mcl_diorite")
xray.add_node("xray:mcl_sstone")
xray.add_node("xray:mcl_rsstone")
xray.add_node("xray:mcl_bstone")
xray.add_node("xray:mcl_basalt")
xray.add_node("xray:mcl_netherrack")
xray.add_node("xray:mcl_deepslate")

local size = 0
local result = "Nodes: "
for i, v in ipairs(xray.nodes) do
    result = result..v.." "
    size = size + 1
end
minetest.log("action", "[oretracker-xray] Found "..size.." nodes configured.")
minetest.log("action", "[oretracker-xray] "..result)

-- Itterates an area of nodes, then swaps nodes if stone or stone varient
xray.check_player = function(p)
    local pos = p:get_pos()
    local pname = p:get_player_name()
    local p1 = vector.subtract(pos, {x = xray.detect_range, y = xray.detect_range, z = xray.detect_range})
    local p2 = vector.add(pos, {x = xray.detect_range, y = xray.detect_range, z = xray.detect_range})
    local area = minetest.find_nodes_in_area(p1, p2, xray.nodes)
    for i=1, #area do
        local node = minetest.get_node_or_nil(area[i])
        if node == nil then
            minetest.log("action", "[oretracker-xray] Failed to obtain node at "..minetest.pos_to_string(area[1], 1)..".")
        else
            local delta = vector.subtract(area[i], pos)
            local distance = (delta.x*delta.x) + (delta.y*delta.y) + (delta.z*delta.z)
            if distance <= xray.detect_range*xray.detect_range then
                --distance = string.format("%.0f", math.sqrt(distance))
                -- Place the counterpart
                --minetest.log("action", "xray "..pname.." "..minetest.pos_to_string(area[1], 1))
                if xray.p_stats[pname] then
                    -- Adds the counter since we are enabled
                    xray.add_pos(pname, area[i])
                elseif string.find(node.name, "xray") and fix_mode then
                    -- Attempt to cleanup that node if it's one of ours
                    -- Warning don't leave fix_mode on all the time, can cause someone elses xray to be blocked because of ordering
                    xray.fix_pos(area[i])
                end
            end
        end
    end
end

-- Now register with minetest to actually do something

local interval = 0
minetest.register_globalstep(function(dtime)
    interval = interval - dtime
    if interval <= 0 then
        for _, player in ipairs(minetest.get_connected_players()) do
            local p = player
            if not minetest.is_player(p) then
                p = minetest.get_player_by_name(p)
            end
            if p ~= nil then
                -- I need to clean up the player's nodes added by the latter code
                xray.clear_pos(p:get_player_name())
                -- Now make new nodes
                xray.check_player(p)
            end
        end
        interval = xray.scan_frequency
    end
end)

minetest.register_on_joinplayer(function(player, laston)
    xray.p_stats[player:get_player_name()] = false
end)

minetest.register_on_leaveplayer(function(player, timeout)
    local indx = 0
    local found = false
    for pname, val in ipairs(xray.p_stats) do
        if pname == player:get_player_name() then
            found = true
            break
        end
        indx = indx + 1
    end
    if found then
        -- Attempt to cleanup that player's invisible nodes before they log off
        xray.p_stats[player:get_player_name()] = false
        minetest.log("action", "Cleaning up "..player:get_player_name().." as they wish to leave.")
        xray.clear_pos(player:get_player_name())
        table.remove(xray.p_stats, indx)
    end
end)

-- A priv for players so they can't abuse this power
minetest.register_privilege("xray", {
    description = "Oretracker Xray Priv",
    give_to_singleplayer = true -- Also given to those with server priv
})

minetest.register_chatcommand("xray", {
    privs = {
        shout = true,
        xray = true -- Require our xray
    },
    func = function(name, param)
        if xray.p_stats[name] then
            xray.p_stats[name] = false
            minetest.chat_send_player(name, "Xray: OFF")
        else
            xray.p_stats[name] = true
            minetest.chat_send_player(name, "Xray: ON")
        end
    end,
})
