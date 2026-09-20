Hooks:PostHook(NetworkMatchMakingSTEAM, "_make_room_info", "ci_make_room_info", function(self, lobby)
    local room = Hooks:GetReturn()
    
    if room then
        local ok_m, members = pcall(lobby.num_members, lobby)
        local ok_l, limit = pcall(lobby.member_limit, lobby)

        room.ci_members = ok_m and tonumber(members) or nil
        room.ci_limit = ok_l and tonumber(limit) or nil
    end

    local snap = CIM:lobby_snapshot(lobby)
    local id = CIM:safe_string(CIM.P(function() return lobby:id() end))
    local prev = CIM.seen_lobbies[id]
    local now = CIM:wall()

    if not prev or prev.snap ~= snap or now - prev.t > 30 then
        CIM.seen_lobbies[id] = { snap = snap, t = now }
        CIM:local_log("SEARCH %s", snap)
    end
end)

Hooks:PreHook(NetworkMatchMakingSTEAM, "search_lobby", "ci_search_lobby", function(...)
    CIM.lobby_filter._stale = {}
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "search_lobby", "ci_search_lobby_post", function(self, friends_only, no_filters, ...)
    local tb = CIM.P(function() return debug.traceback("", 3) end) or ""
    tb = tb:gsub("\n%s*", " | "):sub(1, 400)

    CIM:local_log("search_lobby friends_only=%s no_filters=%s from:%s", CIM:safe_string(friends_only), CIM:safe_string(no_filters), tb)
end)

local orig_join_with_check = NetworkMatchMakingSTEAM.join_server_with_check
function NetworkMatchMakingSTEAM:join_server_with_check(...)
    CIM._in_join_check = true
    local r = { orig_join_with_check(self, ...) }
    CIM._in_join_check = false

    return unpack(r)
end

Hooks:PostHook(NetworkMatchMakingSTEAM, "join_server_with_check", "cim_join_server_with_check", function(self, room_id, is_invite)
    CIM.join_t = CIM:wall()

    CIM:local_log("join_server_with_check room=%s invite=%s", CIM:safe_string(room_id), CIM:safe_string(is_invite))
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "is_server_ok", "CIM_is_server_ok", function(self, friends_only, room, attributes_list, is_invite, ...)
    local ok, err = Hooks:GetReturn()

    if not ok or not room or not room.room_id or is_invite or CIM.lobby_filter._in_join_check then
        return ok, err
    end

    local numbers = attributes_list and attributes_list.numbers
    local advertised = numbers and tonumber(numbers[5])
    local stale = CIM:is_stale_lobby(room.ci_members, room.ci_limit, advertised)

    if stale then
        CIM.lobby_filter._stale[room.room_id] = true

        if CIM:lobby_filter_mode() == CIM.lobby_filter.MODE_HIDDEN then
            return false, 1
        end
    else
        CIM.lobby_filter._stale[room.room_id] = nil
    end
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "join_server", "cim_join_server_post", function(self, room_id, skip_dialog, quickplay, is_invite)
    CIM:local_log("join_server room=%s quickplay=%s invite=%s", CIM:safe_string(room_id), CIM:safe_string(quickplay), CIM:safe_string(is_invite))
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "leave_game", "cim_leave_game_post", function(...)
    CIM:local_log("leave_game()")
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "set_num_players", "cim_set_num_players", function(self, num)
    if self._lobby_attributes and self.lobby_handler then
        CIM.stats.updates_issued = CIM.stats.updates_issued + 1
    end

    CIM:local_log("HOST set_num_players(%s) issued=%d",
        CIM:safe_string(num),
        CIM.stats.updates_issued
    )
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "set_server_state", "cim_set_server_state", function(self, state)
    if self._lobby_attributes and self.lobby_handler then
        CIM.stats.updates_issued = CIM.stats.updates_issued + 1
    end

    CIM:local_log("HOST set_server_state(%s) issued=%d", CIM:safe_string(state), CIM.stats.updates_issued)
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "set_server_joinable", "cim_set_server_joinable", function(self, state)
    CIM:local_log("HOST set_server_joinable(%s) [no-op on EOS]", CIM:safe_string(state))
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "set_attributes", "cim_set_attributes", function(self, ...)
    if not self.lobby_handler then
        CIM:local_log("HOST set_attributes: no lobby_handler, skipped")

        return
    end

    CIM.stats.updates_issued = CIM.stats.updates_issued + 2

    local a = self._lobby_attributes or {}
    local n = 0
    local total_len = 0

    for k, v in pairs(a) do
        n = n + 1
        total_len = total_len + #tostring(v)
    end

    local modlen = type(a.mods) == "string" and #a.mods or -1

    CIM:local_log("HOST set_attributes: %d attrs, total value bytes=%d, mods len=%d (EOS limit 1000/attr), num_players=%s state=%s perm=%s issued=%d",
        n,
        total_len,
        modlen,
        CIM:safe_string(a.num_players),
        CIM:safe_string(a.state),
        CIM:safe_string(a.permission),
        CIM.stats.updates_issued
    )

    if modlen > 1000 then
        CIM:local_log("HOST WARNING: mods attribute exceeds EOS 1000-char limit; every UpdateLobby may be rejected silently")
    end
end)

Hooks:PreHook(NetworkMatchMakingSTEAM, "_on_data_update", "cim_on_data_update", function(...)
    CIM.stats.updates_completed = CIM.stats.updates_completed + 1

    local mm = managers.network and managers.network.matchmake
    local np = mm and mm.lobby_handler and CIM:safe_string(CIM.P(function() return mm.lobby_handler:get_lobby_data("num_players") end)) or "?"

    CIM:local_log("EOS UpdateLobby completed (%d/%d) lobby num_players now=%s", CIM.stats.updates_completed, CIM.stats.updates_issued, np)
end)

Hooks:PreHook(NetworkMatchMakingSTEAM, "_on_memberstatus_change", "cim_on_memberstatus_change", function(self, memberstatus, ...)
    CIM:local_log(
        "EOS memberstatus callback fired: %s   (never expected on EOS - if you see this, the engine does emit member events)",
        CIM:safe_string(memberstatus)
    )
end)

Hooks:PostHook(NetworkMatchMakingSTEAM, "update", "cim_nmms_update", function(...)
    local now = CIM:wall()

    if now - CIM.last_heartbeat >= 5 then
        CIM.last_heartbeat = now
        CIM:heartbeat()
    end
end)
