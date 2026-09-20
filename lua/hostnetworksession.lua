Hooks:PostHook(HostNetworkSession, "on_peer_connection_established", "cim_hns_on_peer_connection_established", function(self, sender_peer, introduced_peer_id)
    local other = self._peers[introduced_peer_id]

    CIM:local_log("HOST connection_established from %s about #%s: sender %s | introduced %s",
        CIM:peer_str(sender_peer),
        CIM:safe_string(introduced_peer_id),
        CIM:handshake_str(sender_peer),
        other and CIM:handshake_str(other) or "gone"
    )
end)

Hooks:PostHook(HostNetworkSession, "on_remove_peer_confirmation", "cim_hns_on_remove_peer_confirmation", function(self, sender_peer, removed_peer_id)
    CIM:local_log("HOST remove_peer_confirmation from %s for #%s -> %s",
        CIM:peer_str(sender_peer),
        CIM:safe_string(removed_peer_id),
        CIM:handshake_str(sender_peer)
    )
end)

Hooks:PostHook(HostNetworkSession, "on_dead_connection_reported", "cim_hns_on_dead_connection_reported", function(self, reporter_peer_id, other_peer_id)
    CIM:local_log("HOST DEAD CONNECTION reported by #%s about #%s (queued, processed after %ss)",
        CIM:safe_string(reporter_peer_id),
        CIM:safe_string(other_peer_id),
        CIM:safe_string(HostNetworkSession._DEAD_CONNECTION_REPORT_PROCESS_DELAY)
    )
end)

Hooks:PostHook(HostNetworkSession, "chk_server_joinable_state", "cim_hns_chk_server_joinable_state", function(self)
    local mm = managers.network.matchmake

    CIM:local_log("HOST chk_server_joinable_state -> joinable=%s peers=%s free_id=%s state=%s",
        CIM:safe_string(mm and mm._server_joinable),
        CIM:safe_string(table.size(self._peers)),
        CIM:safe_string(CIM.P(function() return self:_get_free_client_id() end)),
        CIM:safe_string(CIM.P(function() return game_state_machine:last_queued_state_name() end))
    )
end)

Hooks:PostHook(HostNetworkSession, "_get_free_client_id", "cim_hns_get_free_client_id", function(self, user_id)
    local id = Hooks:GetReturn()

    if not id and table.size(self._peers) < tweak_data.max_players - 1 then
        local dirty = {}

        for pid, peer in pairs(self._peers) do
            table.insert(dirty, CIM:peer_str(peer) .. " " .. CIM:handshake_str(peer))
        end

        CIM:local_log("HOST _get_free_client_id -> NIL with %d peers (DIRTY SLOT). peers: %s",
            table.size(self._peers),
            table.concat(dirty, " | ")
        )
    end
end)

CIM.dropin_gate = CIM.dropin_gate or {}
Hooks:PostHook(HostNetworkSession, "chk_initiate_dropin_pause", "cim_hns_chk_initiate_dropin_pause", function(self, dropin_peer)
    if not dropin_peer or CIM.P(function() return dropin_peer:expecting_dropin() end) then
        return
    end

    local id = CIM.P(function() return dropin_peer:id() end)
    local why

    if not CIM.P(function() return dropin_peer:expecting_pause_sequence() end) then
        why = "not expecting pause sequence"
    elseif not CIM.P(function() return self:chk_peer_handshakes_complete(dropin_peer) end) then
        why = "handshakes incomplete " .. CIM:handshake_str(dropin_peer)
    elseif not CIM.P(function() return self:are_all_peer_assets_loaded() end) then
        why = "some peer still loading assets"
    elseif not CIM.P(function() return self:all_peers_done_loading_outfits() end) then
        local waiting = {}

        for pid, peer in pairs(self._peers) do
            if CIM.P(function() return peer:waiting_for_player_ready() end) and not CIM.P(function() return peer:other_peer_outfit_loaded_status() end) then
                table.insert(waiting, CIM:safe_string(pid))
            end
        end

        why = "waiting for outfit-loaded confirmation from peers [" .. table.concat(waiting, ",") .. "]"
    elseif not CIM.P(function() return dropin_peer:other_peer_outfit_loaded_status() end) then
        why = "dropin peer has not confirmed outfits loaded"
    else
        local pending = {}

        for pid, peer in pairs(self._peers) do
            local st = CIM.P(function() return peer:is_expecting_pause_confirmation(id) end)

            if st then
                table.insert(pending, CIM:safe_string(pid) .. "=" .. CIM:safe_string(st))
            end
        end

        why = "pause confirmations pending [" .. table.concat(pending, ",") .. "]"
    end

    local key = CIM:safe_string(id)

    if CIM.dropin_gate[key] ~= why then
        CIM.dropin_gate[key] = why
        CIM:local_log("HOST drop-in for #%s blocked: %s", key, why)
    end
end)

Hooks:PostHook(HostNetworkSession, "chk_request_peer_outfit_load_status", "cim_hns_chk_request_peer_outfit_load_status", function(self)
    CIM:local_log("HOST outfit-load status requested from all loaded peers, req_id=%s versions='%s'",
        CIM:safe_string(self._peer_outfit_loaded_status_request_id),
        CIM:safe_string(CIM.P(function() return self:_get_peer_outfit_versions_str() end))
    )
end)

Hooks:PostHook(HostNetworkSession, "on_peer_finished_loading_outfit", "cim_hns_on_peer_finished_loading_outfit", function(self, peer, request_id, versions_in)
    local mine = CIM.P(function() return self:_get_peer_outfit_versions_str() end)

    CIM:local_log("HOST outfit-loaded from %s req=%s/%s versions_match=%s (in='%s')",
        CIM:peer_str(peer),
        CIM:safe_string(request_id),
        CIM:safe_string(self._peer_outfit_loaded_status_request_id),
        CIM:safe_string(versions_in == "proactive" and "proactive" or (versions_in == mine)),
        CIM:safe_string(versions_in)
    )
end)

Hooks:PostHook(HostNetworkSession, "set_dropin_pause_request", "cim_hns_set_dropin_pause_request", function(self, peer, dropin_peer_id, state)
    CIM:local_log("HOST pause request to %s for dropin #%s -> %s",
        CIM:peer_str(peer),
        CIM:safe_string(dropin_peer_id),
        CIM:safe_string(state)
    )
end)

Hooks:PostHook(HostNetworkSession, "on_drop_in_pause_confirmation_received", "cim_hns_on_drop_in_pause_confirmation_received", function(self, dropin_peer_id, sender_peer)
    CIM:local_log("HOST pause confirmation from %s for dropin #%s",
        CIM:peer_str(sender_peer),
        CIM:safe_string(dropin_peer_id)
    )
end)

Hooks:PostHook(HostNetworkSession, "on_peer_save_received", "cim_hns_on_peer_save_received", function(self, event, event_data)
    if type(event_data) ~= "table" then
        return
    end

    local peer = CIM.P(function() return self:peer_by_ip(event_data.ip_address) end)
    local who = peer and CIM:peer_str(peer) or CIM:safe_string(event_data.ip_address)

    if event_data.index then
        if event_data.index == 1 or event_data.index == event_data.total or (event_data.index % 10) == 0 then
            CIM:local_log("HOST drop-in save to %s: packet %s/%s",
                who,
                CIM:safe_string(event_data.index),
                CIM:safe_string(event_data.total)
            )
        end
    else
        CIM:local_log("HOST drop-in save to %s COMPLETE -> synched", who)
    end
end)

Hooks:PostHook(HostNetworkSession, "set_peer_loading_state", "cim_hns_set_peer_loading_state", function(self, peer, state, load_counter)
    CIM:local_log("HOST set_peer_loading_state %s loading=%s counter=%s/%s",
        CIM:peer_str(peer),
        CIM:safe_string(state),
        CIM:safe_string(load_counter),
        CIM:safe_string(self._load_counter)
    )
end)

Hooks:PostHook(HostNetworkSession, "chk_drop_in_peer", "cim_hns_chk_drop_in_peer", function(self, dropin_peer)
    CIM:local_log("HOST chk_drop_in_peer %s expecting_dropin=%s",
        CIM:peer_str(dropin_peer),
        CIM:safe_string(CIM.P(function() return dropin_peer:expecting_dropin() end))
    )
end)
