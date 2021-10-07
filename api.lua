
oretracker.add_ore = function(orename)
    if minetest.registered_nodes[orename] then
        table.insert(oretracker.ores, orename)
    else
        minetest.log("action", "[oretracker] Failed to add '"..orename.."' as it is a unregistered node.")
    end
end

oretracker.add_pos = function(pname, pos, title, color)
    if not title then
        title = minetest.pos_to_string(pos)
    end
    local player = minetest.get_player_by_name(pname)
    local wps = minetest.deserialize(oretracker.store:get_string(pname)) or {}
    if not color then
        color = 0xffffff
    end
    table.insert(wps, 
        player:hud_add({
            hud_elem_type = "waypoint",
            name = title,
            text = "m",
            number = color,
            world_pos = pos
        })
    )
    oretracker.store:set_string(pname, minetest.serialize(wps))
end

oretracker.clear_pos = function(pname)
    local player = minetest.get_player_by_name(pname)
    local wps = minetest.deserialize(oretracker.store:get_string(pname)) or {}
    for i, v in ipairs(wps) do
        player:hud_remove(v)
    end
    oretracker.store:set_string(pname, minetest.serialize({}))
end