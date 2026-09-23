local function known(sender)
    local session = managers.network:session()
    local ip = CIM.P(function() return sender:ip_at_index(0) end)
    local peer = session and CIM.P(function() return session:peer_by_ip(ip) end)

    return peer and CIM:peer_str(peer) or ("UNKNOWN sender " .. CIM:safe_string(ip) .. " (message will be dropped)")
end

Hooks:PreHook(ConnectionNetworkHandler, "peer_exchange_info", "cim_cnh_peer_exchange_info", function(self, peer_id, sender)
    CIM:local_log("RX peer_exchange_info(#%s) from %s", CIM:safe_string(peer_id), known(sender))
end)

Hooks:PreHook(ConnectionNetworkHandler, "connection_established", "cim_cnh_connection_established", function(self, peer_id, sender)
    CIM:local_log("RX connection_established(#%s) from %s", CIM:safe_string(peer_id), known(sender))
end)

Hooks:PreHook(ConnectionNetworkHandler, "mutual_connection", "cim_cnh_mutual_connection", function(self, other_peer_id)
    CIM:local_log("RX mutual_connection(#%s)", CIM:safe_string(other_peer_id))
end)

Hooks:PreHook(ConnectionNetworkHandler, "kick_peer", "cim_cnh_kick_peer", function(self, peer_id, message_id, sender)
    CIM:local_log("RX kick_peer(#%s msg=%s) from %s",
        CIM:safe_string(peer_id),
        CIM:safe_string(message_id),
        known(sender)
    )
end)

Hooks:PreHook(ConnectionNetworkHandler, "remove_peer_confirmation", "cim_cnh_remove_peer_confirmation", function(self, removed_peer_id, sender)
    CIM:local_log("RX remove_peer_confirmation(#%s) from %s", CIM:safe_string(removed_peer_id), known(sender))
end)

Hooks:PreHook(ConnectionNetworkHandler, "report_dead_connection", "cim_cnh_report_dead_connection", function(self, other_peer_id, sender)
    CIM:local_log("RX report_dead_connection(#%s) from %s", CIM:safe_string(other_peer_id), known(sender))
end)

Hooks:PreHook(ConnectionNetworkHandler, "join_request_reply", "cim_cnh_join_request_reply", function(self, reply, ...)
    CIM:local_log("RX join_request_reply reply=%s", CIM:safe_string(reply))
end)

Hooks:PreHook(ConnectionNetworkHandler, "peer_handshake", "cim_cnh_peer_handshake", function(self, name, peer_id, peer_user_id)
    CIM:local_log("RX peer_handshake #%s '%s' uid=%s",
        CIM:safe_string(peer_id),
        CIM:safe_string(name),
        CIM:safe_string(peer_user_id)
    )
end)

Hooks:PreHook(ConnectionNetworkHandler, "sanity_check_network_status", "cim_cnh_sanity_check", function(self, sender)
    CIM:local_log("RX sanity_check_network_status from %s", known(sender))
end)

Hooks:PreHook(ConnectionNetworkHandler, "sanity_check_network_status_reply", "cim_cnh_sanity_check_reply", function(self, sender)
    CIM:local_log("RX sanity_check_network_status_reply from %s", known(sender))
end)
