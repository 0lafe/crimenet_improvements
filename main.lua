if not CrimenetImprovements then
    CrimenetImprovements = {
        mod_path = ModPath,
        required = {},
    }

    CrimenetImprovements.EOS_RESULTS = {
        EOS_Lobby_TooManyPlayers = {
            "The lobby is full.",
            "EOS already has 4 members in it, but the host's advertised player count is stale, which is why CrimeNet still listed it. Nothing on your side can fix this; pick another lobby."
        },
        EOS_Lobby_LobbyFull = {
            "The lobby is full.",
            "EOS refused the join because every seat is taken."
        },
        EOS_NotFound = {
            "The lobby no longer exists.",
            "The host closed it, started a new one, or left. CrimeNet was showing a stale entry."
        },
        EOS_Lobby_InvalidLobby = {
            "The lobby no longer exists.",
            "EOS does not recognise the lobby id any more."
        },
        EOS_Lobby_PresenceLobbyExists = {
            "You are still registered in another lobby.",
            "EOS thinks you are already in a lobby, usually a leftover from an earlier session that did not shut down cleanly. Restarting the game clears it."
        },
        EOS_Lobby_LobbyMembershipExists = {
            "You are already a member of this lobby.",
            "A previous join attempt left a ghost membership behind. Wait a minute or restart the game."
        },
        EOS_NoConnection = {
            "No connection to Epic Online Services.",
            "The EOS backend could not be reached. Check your internet connection or the Epic service status."
        },
        EOS_TimedOut = {
            "Epic Online Services did not answer in time.",
            "The lobby service request timed out. Retrying may work."
        },
        EOS_ServiceFailure = {
            "Epic Online Services reported an internal error.",
            "Retrying may work."
        },
        EOS_InvalidUser = {
            "Your EOS login is not valid.",
            "The game's EOS session is not logged in. Restarting the game usually fixes this."
        },
        EOS_Lobby_NoPermission = {
            "The lobby does not allow you to join.",
            "Its permission level changed to invite-only or friends-only after CrimeNet listed it."
        }
    }
    
    function CrimenetImprovements:P(f, ...)
        local ok, r = pcall(f, ...)

        if ok then
            return r
        end

        return nil
    end

    function CrimenetImprovements:wall()
        return TimerManager:wall():time()
    end

    function CrimenetImprovements:log(fmt, ...)
        log(string.format("[CrimenetImprovements] " .. fmt, ...))
    end

    function CrimenetImprovements:begin(room_id)
        self._lobby_context = {
            room_id = room_id,
            t_join_lobby = self:wall(),
            eos_result = nil,
            host_name = nil,
            attr_players = nil,
            eos_members = nil,
            eos_limit = nil,
            t_request = nil,
            received = false,
            last_silent = nil,
            queued = nil,
            auth_reply = nil,
            join_reply = nil,
            res = nil,
            t_res = nil
        }

        return self._lobby_context
    end

    function CrimenetImprovements:lobby_context()
        return self._lobby_context
    end
    
    function CrimenetImprovements:snapshot_lobby(handler)
        local c = self._lobby_context

        if not c or not handler then
            return
        end

        c.host_name = self:P(function() return handler:key_value("owner_name") end)
        c.attr_players = tonumber(self:P(function() return handler:key_value("num_players") end))
        c.eos_members = tonumber(self:P(function() return handler:num_members() end))
        c.eos_limit = tonumber(self:P(function() return handler:member_limit() end))
    end

    function CrimenetImprovements:format_lobby()
        local parts = {}
        local context = self._lobby_context

        if context.host_name then
            table.insert(parts, "Host: " .. tostring(context.host_name))
        end

        if context.attr_players or context.eos_members then
            table.insert(parts, string.format("Players: advertised %s, EOS members %s/%s",
                tostring(context.attr_players or "?"), tostring(context.eos_members or "?"), tostring(context.eos_limit or "?")))
        end

        if context.room_id then
            table.insert(parts, "Lobby id: " .. tostring(context.room_id))
        end

        return table.concat(parts, "\n")
    end

    function CrimenetImprovements:format_queued()
        if type(self._lobby_context.queued) ~= "table" then
            return nil
        end

        local n = 0

        for _, amount in pairs(self._lobby_context.queued) do
            n = n + (tonumber(amount) or 0)
        end
        
        return n
    end

    function CrimenetImprovements:explain_join_fail()
        local c = self._lobby_context

        if not c then
            return nil
        end

        local t_last = c.t_res or c.t_join_lobby or 0

        if self:wall() - t_last > 5 then
            return nil
        end

        if c.res == "JOINED_LOBBY" or c.res == "JOINED_GAME" then
            return nil
        end

        if (not c.eos_result or c.eos_result == "success") and not c.res then
            return nil
        end

        local details = {}

        if c.eos_result and c.eos_result ~= "success" then
            local known = self.EOS_RESULTS[c.eos_result]
            local head = known and known[1] or "Epic Online Services refused the lobby join."
            local body = known and known[2] or ("EOS returned " .. tostring(c.eos_result) .. ".")

            table.insert(details, "EOS result: " .. tostring(c.eos_result))

            return head, body, details
        end

        local elapsed = c.t_res and c.t_request and (c.t_res - c.t_request) or nil
        if elapsed then
            table.insert(details, string.format("Waited %.1f s for the host", elapsed))
        end

        local queued = CrimenetImprovements:format_queued()
        if queued then
            table.insert(details, string.format("Packets still queued to host: %d", queued))
        end

        if c.last_silent then
            table.insert(details, string.format("Time since last packet from host: %.1f s", c.last_silent))
        end

        local refused = c.auth_reply == 0 or c.join_reply == 0
        if refused then
            return "The host refused the join request.",
                "The host's game answered but rejected you. It does this when it has no free player slot left (a stale slot from a previous player counts), when it thinks you are already in the session, when it is not joinable any more, or when it is in single-player mode.",
                details
        end

        if c.res == "FAILED_CONNECT" then
            if not c.received then
                return "No connection to the host could be established.",
                    "Nothing was received from the host in the whole waiting period. The EOS lobby join succeeded, so the lobby is real; the peer-to-peer link between you and the host never came up. That is almost always NAT/firewall incompatibility between the two of you (a relay could not be negotiated either) or a host whose game is frozen or loading. Trying the same host again rarely helps; other hosts will usually work fine.",
                    details
            end
            return "The host did not answer the join request.",
                "Packets from the host did arrive, so the connection works, but the host never replied to the join request. The host may be mid-load, frozen, or running a mod that breaks join handling.",
                details
        end

        if c.res == "TIMED_OUT" then
            return "The host stopped responding during the handshake.",
                "The host accepted the join request and started the authentication exchange, then went silent. Usually the host lost connection or the host's game hung.",
                details
        end

        return nil
    end

end

if RequiredScript and not CrimenetImprovements.required[RequiredScript] then
  local fname = CrimenetImprovements.mod_path .. RequiredScript:gsub(".+/(.+)", "lua/%1.lua")
  if io.file_is_readable(fname) then
    dofile(fname)
  end

  CrimenetImprovements.required[RequiredScript] = true
end
