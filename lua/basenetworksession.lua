Hooks:PostHook(BaseNetworkSession, "add_peer", "cim_bns_add_peer", function(self, name, rpc, in_lobby, loading, synched, id, character, user_id, account_type_str, account_id)
    CIM:local_log("add_peer id=%s name='%s' user_id=%s acct=%s/%s rpc=%s in_lobby=%s loading=%s synched=%s",
        CIM:safe_string(id),
        CIM:safe_string(name),
        CIM:safe_string(user_id),
        CIM:safe_string(account_type_str),
        CIM:safe_string(account_id),
        CIM:rpc_str(rpc),
        CIM:safe_string(in_lobby),
        CIM:safe_string(loading),
        CIM:safe_string(synched)
    )
end)

Hooks:PreHook(BaseNetworkSession, "remove_peer", "cim_bns_remove_peer", function(self, peer, peer_id, reason)
    CIM:local_log("remove_peer %s reason=%s %s",
        CIM:peer_str(peer),
        CIM:safe_string(reason),
        CIM:handshake_str(peer)
    )
end)

Hooks:PreHook(BaseNetworkSession, "on_peer_lost", "cim_bns_on_peer_lost", function(self, peer, peer_id)
    local rpc = CIM.P(function() return peer:rpc() end)

    CIM:local_log("PEER LOST %s ip=%s silent=%s verified=%s",
        CIM:peer_str(peer),
        CIM:safe_string(CIM.P(function() return peer:ip() end)),
        rpc and CIM:safe_string(CIM.P(function() return Network:receive_silent_time(rpc) end)) or "norpc",
        CIM:safe_string(CIM.P(function() return peer:ip_verified() end))
    )
end)

Hooks:PreHook(BaseNetworkSession, "on_peer_left", "cim_bns_on_peer_left", function(self, peer, peer_id)
    CIM:local_log("PEER LEFT %s", CIM:peer_str(peer))
end)

Hooks:PreHook(BaseNetworkSession, "on_peer_kicked", "cim_bns_on_peer_kicked", function(self, peer, peer_id, message_id)
    CIM:local_log("PEER KICKED %s message_id=%s",
        CIM:peer_str(peer),
        CIM:safe_string(message_id)
    )
end)

Hooks:PostHook(BaseNetworkSession, "chk_send_connection_established", "cim_bns_chk_send_connection_established", function(self, name, user_id, peer)
    peer = peer or CIM.P(function() return self:peer_by_user_id(user_id) end)

    CIM:local_log("chk_send_connection_established name='%s' uid=%s -> %s rpc=%s",
        CIM:safe_string(name),
        CIM:safe_string(user_id),
        peer and "sent" or "no peer yet",
        peer and CIM:rpc_str(CIM.P(function() return peer:rpc() end)) or "-"
    )
end)

Hooks:PostHook(BaseNetworkSession, "add_connection_to_trash", "cim_bns_add_connection_to_trash", function(self, rpc)
    CIM:local_log("add_connection_to_trash %s", CIM:rpc_str(rpc))
end)
