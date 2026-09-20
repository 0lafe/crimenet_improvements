CIM:hook_join_request(HostStateInGame, "ingame")

Hooks:PostHook(HostStateInGame, "on_join_auth_received", "cim_hs_ingame_on_join_auth_received", function(self, data, auth_ticket, sender)
    CIM:local_log("HOST[ingame] join auth received from %s", CIM:rpc_str(sender))
end)
