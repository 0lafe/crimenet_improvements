local orig_join_lobby = Steam.join_lobby
function Steam:join_lobby(lobby_id, callback, ...)
    CIM:save_current_lobby(lobby_id)

    local t0 = CIM:wall()

    CIM:local_log("EOS join_lobby(%s) called", CIM:safe_string(lobby_id))

    local function new_cb(result, handler, ...)
        CIM:local_log("EOS join_lobby(%s) -> '%s' after %.2fs handler: %s",
            CIM:safe_string(lobby_id),
            CIM:safe_string(result),
            CIM:wall() - t0,
            CIM:lobby_snapshot(handler)
        )

        local lobby_context = CIM:lobby_context()

        if lobby_context and lobby_context.room_id == lobby_id then
            lobby_context.eos_result = tostring(result)
            CIM:snapshot_lobby(handler)
        end
        
        return callback(result, handler, ...)
    end

    return orig_join_lobby(self, lobby_id, new_cb, ...)
end

CIM:local_log(
    "loaded. IS_EPIC_MM=%s IS_STEAM_MM=%s DISTRIBUTION=%s DISTRIBUTION_MM=%s protocol=%s",
    CIM:safe_string(IS_EPIC_MM),
    CIM:safe_string(IS_STEAM_MM),
    CIM:safe_string(DISTRIBUTION),
    CIM:safe_string(DISTRIBUTION_MM),
    CIM:safe_string(CIM.P(function() return DistributionMatchmaking:network_protocol() end))
)

local orig_create = Steam.create_lobby
function Steam:create_lobby(callback, max_members, type)
    local t0 = CIM:wall()

    CIM:local_log("EOS create_lobby(max=%s type=%s) called",
        CIM:safe_string(max_members),
        CIM:safe_string(type)
    )

    local function new_cb(result, handler, ...)
        CIM:local_log("EOS create_lobby -> '%s' after %.2fs handler: %s",
            CIM:safe_string(result),
            CIM:wall() - t0,
            CIM:lobby_snapshot(handler)
        )
        
        return callback(result, handler, ...)
    end

    return orig_create(self, new_cb, max_members, type)
end