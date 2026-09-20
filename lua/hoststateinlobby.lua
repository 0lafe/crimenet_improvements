CIM:hook_join_request(HostStateInLobby, "lobby")

Hooks:PostHook(HostStateInLobby, "on_join_auth_received", "cim_hs_lobby_on_join_auth_received", function(self, data, auth_ticket, sender)
    CIM:local_log("HOST[lobby] join auth received from %s", CIM:rpc_str(sender))
end)
