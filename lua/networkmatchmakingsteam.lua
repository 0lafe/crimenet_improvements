Hooks:PostHook(NetworkMatchMakingSTEAM, "_make_room_info", "ci_make_room_info", function(self, lobby)
    local room = Hooks:GetReturn()
    
    if room then
        local ok_m, members = pcall(lobby.num_members, lobby)
        local ok_l, limit = pcall(lobby.member_limit, lobby)

        room.ci_members = ok_m and tonumber(members) or nil
        room.ci_limit = ok_l and tonumber(limit) or nil
    end
end)

Hooks:PreHook(NetworkMatchMakingSTEAM, "search_lobby", "ci_search_lobby", function(...)
    CrimenetImprovements.lobby_filter._stale = {}
end)

local orig_join_with_check = NetworkMatchMakingSTEAM.join_server_with_check
function NetworkMatchMakingSTEAM:join_server_with_check(...)
    CrimenetImprovements._in_join_check = true
    local r = { orig_join_with_check(self, ...) }
    CrimenetImprovements._in_join_check = false

    return unpack(r)
end

Hooks:PostHook(NetworkMatchMakingSTEAM, "is_server_ok", "crimenetimprovements_is_server_ok", function(self, friends_only, room, attributes_list, is_invite, ...)
    local ok, err = Hooks:GetReturn()

    if not ok or not room or not room.room_id or is_invite or CrimenetImprovements.lobby_filter._in_join_check then
        return ok, err
    end

    local numbers = attributes_list and attributes_list.numbers
    local advertised = numbers and tonumber(numbers[5])
    local stale = CrimenetImprovements:is_stale_lobby(room.ci_members, room.ci_limit, advertised)

    if stale then
        CrimenetImprovements.lobby_filter._stale[room.room_id] = true

        if CrimenetImprovements:lobby_filter_mode() == CrimenetImprovements.lobby_filter.MODE_HIDDEN then
            return false, 1
        end
    else
        CrimenetImprovements.lobby_filter._stale[room.room_id] = nil
    end
end)