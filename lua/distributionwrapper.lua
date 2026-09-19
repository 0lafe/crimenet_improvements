local orig_join_lobby = Steam.join_lobby
function Steam:join_lobby(lobby_id, callback, ...)
    CrimenetImprovements:begin(lobby_id)

    local function new_cb(result, handler, ...)
        local lobby_context = CrimenetImprovements:lobby_context()

        if lobby_context and lobby_context.room_id == lobby_id then
            lobby_context.eos_result = tostring(result)
            CrimenetImprovements:snapshot_lobby(handler)
        end
        
        return callback(result, handler, ...)
    end

    return orig_join_lobby(self, lobby_id, new_cb, ...)
end