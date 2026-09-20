Hooks:PreHook(NetworkPeer, "_ping_timedout", "cim_ping_timedout", function(self)
    local rpc = self._rpc

    CIM:local_log("PEER TIMEOUT %s ip=%s silent=%s verified=%s",
        CIM:peer_str(self),
        CIM:safe_string(self._ip),
        rpc and CIM:safe_string(CIM.P(function() return Network:receive_silent_time(rpc) end)) or "norpc",
        CIM:safe_string(self._ip_verified)
    )
end)

Hooks:PostHook(NetworkPeer, "set_ip_verified", "cim_set_ip_varified", function(self, state)
    CIM:local_log("peer %s ip_verified=%s",
        CIM:peer_str(self),
        CIM:safe_string(state)
    )
end)