function CIM:open_log_file()
	if CIM.log_file or CIM.log_file == false then
		return
	end

	CIM.log_file = false

	local dir = self.mod_path .. "logs/"

	local ok = pcall(function()
		if not file.DirectoryExists(dir) then
			file.CreateDirectory(dir)
		end
	end)

	if not ok then
        self:log("could not create " .. dir)

		return
	end

	local G = rawget(_G, "Global")
	local path = type(G) == "table" and G.cim_internal_log_path or nil
	local resumed = path ~= nil

	if not path then
		path = dir .. os.date("%Y_%m_%d_%H%M%S") .. "_cim_lua.log"
	end

	local f = io.open(path, "a")
	if not f then
        self:log("could not open " .. path)

		return
	end

	CIM.log_file = f

	if type(G) == "table" then
		G.cim_internal_log_path = path
	end

	f:write(
        string.format(
            "%s ===== Lua state %s (%s) =====\n",
            os.date("%H:%M:%S"),
            resumed and "restart" or "start",
            os.date("%Y-%m-%d")
        )
    )
	f:flush()

    self:log("logging to " .. path)
end

function CIM:local_log(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)

	if not ok then
		msg = tostring(fmt) .. " <fmt error: " .. tostring(msg) .. ">"
	end

	if self.log_file then
		self.log_file:write(string.format("%s [wall %9.2f] %s\n", os.date("%H:%M:%S"), self:wall(), msg))
		self.log_file:flush()
	else
		self:log("ERROR log file gone")
		self:log(string.format("[MMDiag %9.2f] %s", self:wall(), msg))
	end
end

function CIM:rpc_str(rpc)
	if not rpc then
		return "rpc=nil"
	end
	
	return string.format("%s/%s",
        CIM:safe_string(CIM.P(function() return rpc:protocol_at_index(0) end)),
        CIM:safe_string(CIM.P(function() return rpc:ip_at_index(0) end))
    )
end

function CIM:peer_str(peer)
	if not peer then
		return "peer=nil"
	end

	return string.format("#%s '%s' uid=%s",
        CIM:safe_string(CIM.P(function() return peer:id() end)),
        CIM:safe_string(CIM.P(function() return peer:name() end)),
        CIM:safe_string(CIM.P(function() return peer:user_id() end))
    )
end

function CIM:lobby_snapshot(lobby)
	if not lobby then
		return "lobby=nil"
	end

	local kv = function(k) return CIM:safe_string(CIM.P(function() return lobby:key_value(k) end)) end
	local mods = CIM.P(function() return lobby:key_value("mods") end)
	local modlen = type(mods) == "string" and #mods or -1

	return string.format("id=%s owner='%s' attr{num_players=%s state=%s perm=%s drop_in=%s level=%s} eos{members=%s limit=%s} modstr_len=%d",
		CIM:safe_string(CIM.P(function() return lobby:id() end)),
        kv("owner_name"),
        kv("num_players"),
        kv("state"),
        kv("permission"),
        kv("drop_in"),
        kv("level"),
		CIM:safe_string(CIM.P(function() return lobby:num_members() end)),
        CIM:safe_string(CIM.P(function() return lobby:member_limit() end)),
        modlen
    )
end

function CIM:handshake_str(peer)
	local hs = CIM.P(function() return peer:handshakes() end)

	if type(hs) ~= "table" then
		return "hs=?"
	end

	local parts = {}
	for k, v in pairs(hs) do
		table.insert(parts, CIM:safe_string(k) .. "=" .. CIM:safe_string(v))
	end

	table.sort(parts)

	return "hs{" .. table.concat(parts, ",") .. "}"
end

function CIM:send_status_str(rpc)
	local st = CIM.P(function() return Network:get_connection_send_status(rpc) end)

	if type(st) ~= "table" then
		return "q=?"
	end

	local parts = {}
	for k, v in pairs(st) do
		table.insert(parts, CIM:safe_string(k) .. ":" .. CIM:safe_string(v))
	end

	table.sort(parts)

	return "q{" .. table.concat(parts, ",") .. "}"
end

function CIM:heartbeat()
	local mm = managers.network and managers.network.matchmake
	local session = managers.network and managers.network:session()

	if not mm and not session then
		return
	end

	if mm and mm.lobby_handler then
		self:local_log("HB lobby: %s server_joinable=%s", self:lobby_snapshot(mm.lobby_handler), CIM:safe_string(mm._server_joinable))
	end

	if session then
		local is_host = CIM.P(function() return session:is_host() end)
		local free_id = is_host and CIM:safe_string(CIM.P(function() return session:_get_free_client_id() end)) or "-"

		self:local_log("HB session: host=%s players=%s free_client_id=%s updates issued/completed=%d/%d",
			CIM:safe_string(is_host),
            CIM:safe_string(CIM.P(function() return session:amount_of_players() end)),
            free_id,
            CIM.stats.updates_issued,
            CIM.stats.updates_completed
        )

		local peers = CIM.P(function() return session:peers() end) or {}

		for _, peer in pairs(peers) do
			local rpc = CIM.P(function() return peer:rpc() end)

			self:local_log("HB   peer %s ip=%s verified=%s loading=%s synched=%s in_lobby=%s silent=%s %s %s outfit{loaded=%s loading_assets=%s other_ok=%s} dropin{pause_seq=%s expecting=%s}",
				self:peer_str(peer),
                CIM:safe_string(CIM.P(function() return peer:ip() end)),
                CIM:safe_string(CIM.P(function() return peer:ip_verified() end)),
				CIM:safe_string(CIM.P(function() return peer:loading() end)),
                CIM:safe_string(CIM.P(function() return peer:synched() end)),
                CIM:safe_string(CIM.P(function() return peer:in_lobby() end)),
				rpc and CIM:safe_string(CIM.P(function() return Network:receive_silent_time(rpc) end)) or "norpc",
				self:handshake_str(peer),
                rpc and self:send_status_str(rpc) or "",
				CIM:safe_string(CIM.P(function() return peer:is_outfit_loaded() end)),
                CIM:safe_string(CIM.P(function() return peer:is_loading_outfit_assets() end)),
				CIM:safe_string(CIM.P(function() return peer:other_peer_outfit_loaded_status() end)),
				CIM:safe_string(CIM.P(function() return peer:expecting_pause_sequence() end)),
                CIM:safe_string(CIM.P(function() return peer:expecting_dropin() end))
            )
		end
	end
end

CIM:open_log_file()