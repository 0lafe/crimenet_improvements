local orig_request_join_host = ClientNetworkSession.request_join_host
function ClientNetworkSession:request_join_host(host_rpc, is_invite, result_cb, ...)
    local lobby_context = CrimenetImprovements:lobby_context()

    if lobby_context then
        lobby_context.t_request = CrimenetImprovements:wall()
        lobby_context.host_rpc = host_rpc
    end

    local function cb(res, ...)
        local lobby_context_2 = CrimenetImprovements:lobby_context()

        if lobby_context_2 then
            lobby_context_2.res = tostring(res)
            lobby_context_2.t_res = CrimenetImprovements:wall()

            CrimenetImprovements:log("join result %s | received=%s silent=%s queued=%s auth_reply=%s join_reply=%s eos=%s | %s",
                lobby_context_2.res,
                tostring(lobby_context_2.received),
                tostring(lobby_context_2.last_silent),
                tostring(CrimenetImprovements:format_queued()),
                tostring(lobby_context_2.auth_reply),
                tostring(lobby_context_2.join_reply),
                tostring(lobby_context_2.eos_result),
                CrimenetImprovements:format_lobby():gsub("\n", " | ")
            )
        end

        return result_cb(res, ...)
    end

    return orig_request_join_host(self, host_rpc, is_invite, cb, ...)
end

function CrimenetImprovements:sample()
    local lobby_context = self._lobby_context

    if not lobby_context or not lobby_context.t_request or not lobby_context.host_rpc then
        return
    end

    local silent = self:P(Network.receive_silent_time, Network, lobby_context.host_rpc)
    if type(silent) == "number" then
        lobby_context.last_silent = silent
        if silent + 0.25 < self:wall() - lobby_context.t_request then
            lobby_context.received = true
        end
    end

    local q = self:P(Network.get_connection_send_status, Network, lobby_context.host_rpc)
    if type(q) == "table" then
        lobby_context.queued = q
    end
end

Hooks:PreHook(ClientNetworkSession, 'update', "crimenet_improvements_cns_update", function(self, ...)
    if self._cb_find_game and self._server_peer then
        CrimenetImprovements:sample()
    end
end)

Hooks:PreHook(ClientNetworkSession, 'on_auth_request_received', "crimenet_improvements_cns_oarr", function(self, reply, ...)
    local lobby_context = CrimenetImprovements:lobby_context()

    if lobby_context and self._cb_find_game then
        lobby_context.auth_reply = reply
        lobby_context.received = true
    end
end)

Hooks:PreHook(ClientNetworkSession, 'on_join_request_reply', "crimenet_improvements_cns_ojrr", function(self, reply, ...)
    local lobby_context = CrimenetImprovements:lobby_context()

    if lobby_context and self._cb_find_game then
        lobby_context.join_reply = reply
        lobby_context.received = true
    end
end)
