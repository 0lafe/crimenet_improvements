local orig = NetworkManager.join_game_at_host_rpc
function NetworkManager:join_game_at_host_rpc(host_rpc, is_invite, result_cb)
    local t0 = CIM:wall()

    CIM:local_log("join_game_at_host_rpc host=%s invite=%s (%.2fs since join_server_with_check)",
        CIM:rpc_str(host_rpc),
        CIM:safe_string(is_invite),
        t0 - CIM.join_t
    )

    local function new_cb(res, ...)
        CIM:local_log("join_game_at_host_rpc -> %s after %.2fs (args: %s)",
            CIM:safe_string(res),
            CIM:wall() - t0,
            table.concat({
                CIM:safe_string((select(1, ...))),
                CIM:safe_string((select(2, ...))),
                CIM:safe_string((select(3, ...)))
            }, ",")
        )

        return result_cb(res, ...)
    end

    return orig(self, host_rpc, is_invite, new_cb)
end

Hooks:PostHook(NetworkManager, "on_peer_added", "cim_on_peer_added", function(self, peer, peer_id)
    CIM:local_log("on_peer_added %s -> amount_of_players=%s",
        CIM:peer_str(peer),
        CIM:safe_string(CIM.P(function() return self:session():amount_of_players() end))
    )
end)