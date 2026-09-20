function CIM:hook_join_request(class, tag)
    Hooks:PreHook(class, "on_join_request_received", "cim_hs_" .. tag .. "_on_join_request_received", function(self, data, peer_name, peer_account_id, peer_account_type_str, is_invite, client_preferred_character, xuid, peer_level, peer_rank, peer_stinger_index, join_attempt_identifier, sender)
        local session = data.session
        local old = CIM.P(function() return session:chk_peer_already_in(sender) end)
        local dup_acct = CIM.P(function() return session:peer_by_account_id(peer_account_id) end)

        CIM:local_log("HOST[%s] JOIN REQUEST from '%s' acct=%s/%s %s invite=%s attempt=%s | peers=%s free_id=%s joinable=%s already_in=%s dup_account=%s wants_load=%s",
            tag,
            CIM:safe_string(peer_name),
            CIM:safe_string(peer_account_type_str),
            CIM:safe_string(peer_account_id),
            CIM:rpc_str(sender),
            CIM:safe_string(is_invite),
            CIM:safe_string(join_attempt_identifier),
            CIM:safe_string(table.size(data.peers)),
            CIM:safe_string(CIM.P(function() return session:_get_free_client_id() end)),
            CIM:safe_string(managers.network.matchmake:is_server_joinable()),
            old and CIM:peer_str(old) or "no",
            dup_acct and CIM:peer_str(dup_acct) or "no",
            CIM:safe_string(data.wants_to_load_level)
        )
    end)
end

Hooks:PostHook(HostStateBase, "_send_request_denied", "cim_hs_base_send_request_denied", function(self, sender, reason, my_user_id)
    local name = "?"
    local map = HostNetworkSession and HostNetworkSession.JOIN_REPLY

    if map then
        for k, v in pairs(map) do
            if v == reason then
                name = k
            end
        end
    end

    CIM:local_log("HOST join DENIED %s reason=%s(%s)",
        CIM:rpc_str(sender),
        CIM:safe_string(reason),
        name
    )
end)
