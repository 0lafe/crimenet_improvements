local orig_request_join_host = ClientNetworkSession.request_join_host
function ClientNetworkSession:request_join_host(host_rpc, is_invite, result_cb, ...)
    local lobby_context = CIM:lobby_context()

    if lobby_context then
        lobby_context.t_request = CIM:wall()
        lobby_context.host_rpc = host_rpc
    end

    local function cb(res, ...)
        local lobby_context_2 = CIM:lobby_context()

        if lobby_context_2 then
            lobby_context_2.res = tostring(res)
            lobby_context_2.t_res = CIM:wall()

            CIM:log("join result %s | received=%s silent=%s queued=%s auth_reply=%s join_reply=%s eos=%s | %s",
                lobby_context_2.res,
                tostring(lobby_context_2.received),
                tostring(lobby_context_2.last_silent),
                tostring(CIM:format_queued()),
                tostring(lobby_context_2.auth_reply),
                tostring(lobby_context_2.join_reply),
                tostring(lobby_context_2.eos_result),
                CIM:format_lobby():gsub("\n", " | ")
            )
        end

        return result_cb(res, ...)
    end

    return orig_request_join_host(self, host_rpc, is_invite, cb, ...)
end

function CIM:sample()
    local lobby_context = self._lobby_context

    if not lobby_context or not lobby_context.t_request or not lobby_context.host_rpc then
        return
    end

    local silent = self.P(Network.receive_silent_time, Network, lobby_context.host_rpc)
    if type(silent) == "number" then
        lobby_context.last_silent = silent
        if silent + 0.25 < self:wall() - lobby_context.t_request then
            lobby_context.received = true
        end
    end

    local q = self.P(Network.get_connection_send_status, Network, lobby_context.host_rpc)
    if type(q) == "table" then
        lobby_context.queued = q
    end
end

Hooks:PreHook(ClientNetworkSession, 'update', "crimenet_improvements_cns_update", function(self, ...)
    if self._cb_find_game and self._server_peer then
        CIM:sample()
    end
end)

Hooks:PreHook(ClientNetworkSession, 'on_auth_request_received', "crimenet_improvements_cns_oarr", function(self, reply, ...)
    local lobby_context = CIM:lobby_context()

    if lobby_context and self._cb_find_game then
        lobby_context.auth_reply = reply
        lobby_context.received = true
    end
end)

Hooks:PreHook(ClientNetworkSession, 'on_join_request_reply', "crimenet_improvements_cns_ojrr", function(self, reply, ...)
    local lobby_context = CIM:lobby_context()

    if lobby_context and self._cb_find_game then
        lobby_context.join_reply = reply
        lobby_context.received = true
    end
end)

Hooks:PostHook(ClientNetworkSession, "peer_handshake", "cim_cns_peer_handshake", function(self, name, peer_id, peer_user_id, peer_account_type_str, peer_account_id, in_lobby, loading, synched)
    local peer = self._peers[peer_id]

    CIM:local_log("CLIENT peer_handshake #%s '%s' uid=%s in_lobby=%s loading=%s synched=%s -> rpc=%s",
        CIM:safe_string(peer_id),
        CIM:safe_string(name),
        CIM:safe_string(peer_user_id),
        CIM:safe_string(in_lobby),
        CIM:safe_string(loading),
        CIM:safe_string(synched),
        peer and CIM:rpc_str(CIM.P(function() return peer:rpc() end)) or "no peer"
    )
end)

Hooks:PostHook(ClientNetworkSession, "on_peer_requested_info", "cim_cns_on_peer_requested_info", function(self, peer_id)
    CIM:local_log("CLIENT peer_exchange_info from host about #%s -> marked ip_verified, sent our info directly",
        CIM:safe_string(peer_id)
    )
end)

Hooks:PostHook(ClientNetworkSession, "on_mutual_connection", "cim_cns_on_mutual_connection", function(self, other_peer_id)
    CIM:local_log("CLIENT mutual_connection with #%s", CIM:safe_string(other_peer_id))
end)

Hooks:PostHook(ClientNetworkSession, "on_join_request_reply", "cim_cns_on_join_request_reply", function(self, reply, my_peer_id, my_character, level_index, difficulty_index, one_down, state_index, server_character, user_id)
    CIM:local_log("CLIENT join_request_reply=%s my_peer_id=%s level=%s state=%s host_uid=%s",
        CIM:safe_string(reply),
        CIM:safe_string(my_peer_id),
        CIM:safe_string(level_index),
        CIM:safe_string(state_index),
        CIM:safe_string(user_id)
    )
end)

Hooks:PostHook(ClientNetworkSession, "on_join_request_timed_out", "cim_cns_on_join_request_timed_out", function(self)
    CIM:local_log("CLIENT join request TIMED OUT")
end)

Hooks:PostHook(ClientNetworkSession, "on_auth_request_received", "cim_cns_on_auth_request_received", function(self, reply, auth_ticket)
    CIM:local_log("CLIENT auth_request reply=%s ticket_len=%s",
        CIM:safe_string(reply),
        type(auth_ticket) == "string" and #auth_ticket or "nil"
    )
end)

Hooks:PostHook(ClientNetworkSession, "ok_to_load_level", "cim_cns_ok_to_load_level", function(self, load_counter)
    CIM:local_log("CLIENT ok_to_load_level counter=%s", CIM:safe_string(load_counter))
end)

Hooks:PostHook(ClientNetworkSession, "notify_host_when_outfits_loaded", "cim_cns_notify_host_when_outfits_loaded", function(self, request_id, outfit_versions_str)
    CIM:local_log("CLIENT outfit-loaded reply to host req=%s versions='%s'",
        CIM:safe_string(request_id),
        CIM:safe_string(outfit_versions_str)
    )
end)

Hooks:PostHook(ClientNetworkSession, "on_peer_save_received", "cim_cns_on_peer_save_received", function(self, event, event_data)
    if type(event_data) ~= "table" then
        return
    end

    if event_data.index then
        if event_data.index == 1 or event_data.index == event_data.total or (event_data.index % 10) == 0 then
            CIM:local_log("CLIENT drop-in save packet %s/%s",
                CIM:safe_string(event_data.index),
                CIM:safe_string(event_data.total)
            )
        end
    else
        CIM:local_log("CLIENT drop-in save COMPLETE")
    end
end)
