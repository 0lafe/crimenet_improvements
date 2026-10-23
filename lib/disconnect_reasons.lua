-- Explains in chat why a player disconnected.
--
-- Vanilla prints "<name> disconnected." for every non-voluntary removal. The
-- removal paths we can tell apart in Lua (who decided) are tagged by the hooks
-- via CIM:mark_removal just before remove_peer runs; the native half (CIM_EOS)
-- adds what Epic's P2P layer knows about the link to that player. Both are
-- combined into a headline (replaces the vanilla line) and an optional hint.

CIM.removals = setmetatable({}, { __mode = "k" })
CIM.slow_warned = {}
CIM.last_slow_check = 0

CIM.DC_MARK_TTL = 5
CIM.DC_SLOW_CONNECT_WARN = 8
CIM.DC_HEALTHY_SILENCE = 5

function CIM:explain_enabled()
    return self.lobby_filter.settings.explain ~= false
end

function CIM:eos_link(peer)
    local api = rawget(_G, "CIM_EOS")

    if type(api) ~= "table" or type(api.link) ~= "function" or not peer then
        return nil
    end

    local id = self.P(function() return peer:user_id() end)
    if type(id) ~= "string" then
        return nil
    end

    local link = self.P(api.link, id)

    return type(link) == "table" and link or nil
end

function CIM:eos_nat()
    local api = rawget(_G, "CIM_EOS")

    if type(api) ~= "table" or type(api.nat) ~= "function" then
        return nil
    end

    local nat = self.P(api.nat)

    return type(nat) == "string" and nat ~= "Unknown" and nat or nil
end

function CIM:peer_silent(peer)
    local rpc = self.P(function() return peer:rpc() end)

    return rpc and tonumber(self.P(function() return Network:receive_silent_time(rpc) end)) or nil
end

function CIM:mark_removal(peer, source, data)
    if not peer then
        return
    end

    data = data or {}
    data.source = source
    data.t = self:wall()
    data.silent = data.silent or self:peer_silent(peer)

    if data.loading == nil then
        data.loading = self.P(function() return peer:loading() end)
    end

    self.removals[peer] = data
end

function CIM:take_removal_mark(peer)
    local mark = self.removals[peer]
    self.removals[peer] = nil

    if mark and self:wall() - mark.t <= self.DC_MARK_TTL then
        return mark
    end

    return nil
end

-- What the P2P link to this player looked like when it went away. Returns a
-- hint string id, or nil when there is nothing useful to say.
function CIM:link_hint(link, mark)
    if not link then
        return nil
    end

    local member = link.member
    local established = link.established_age ~= nil

    if not established and link.attempt_age then
        return link.glare and "cim_dc_hint_glare" or "cim_dc_hint_never"
    end

    if not established then
        return nil
    end

    local broken = link.lost_age ~= nil or (link.closed_age ~= nil and link.close_reason ~= "ClosedByLocalUser")

    if member == "DISCONNECTED" then
        return "cim_dc_hint_offline"
    end

    if link.close_reason == "ClosedByPeer" or member == "LEFT" then
        return "cim_dc_hint_closed"
    end

    if broken then
        return "cim_dc_hint_dropped"
    end

    local silent = mark and mark.silent

    if silent and silent >= self.DC_HEALTHY_SILENCE then
        return mark.loading and "cim_dc_hint_frozen_loading" or "cim_dc_hint_frozen"
    end

    return "healthy"
end

-- Returns headline, hint (localized strings, hint may be nil), or nil to keep
-- the vanilla message.
function CIM:explain_removal(peer, reason)
    local mark = self:take_removal_mark(peer)

    if not self:explain_enabled() or reason == "left" then
        return nil
    end

    local name = self:safe_string(self.P(function() return peer:name() end))
    local loc = managers.localization
    local macros = { name = name }
    local link = self:eos_link(peer)
    local source = mark and mark.source
    local head, hint

    if reason == "kicked" then
        if mark and mark.message_id == 6 then
            head = "cim_dc_head_banned"
        else
            return nil
        end
    elseif reason == "auth_fail" then
        head, hint = "cim_dc_head_auth", "cim_dc_hint_auth"
    elseif source == "rejoin" then
        head = "cim_dc_head_rejoin"
    elseif source == "dead_report" then
        head, hint = "cim_dc_head_dead_report", "cim_dc_hint_dead_report"
        macros.other = mark.other or "?"
    else
        hint = self:link_hint(link, mark)

        if source == "host" then
            head = "cim_dc_head_host"

            if hint == "healthy" then
                local silent = self:peer_silent(peer)
                hint = silent and silent < self.DC_HEALTHY_SILENCE and "cim_dc_hint_host_side" or nil
            end
        elseif source == "timeout" and mark.silent then
            head = "cim_dc_head_timeout"
            macros.secs = string.format("%.0f", mark.silent)
        elseif source == "transport" then
            head = "cim_dc_head_transport"
        else
            head = "cim_dc_head_lost"
        end

        if hint == "healthy" then
            hint = nil
        end
    end

    if hint == "cim_dc_hint_never" then
        macros.nat = self:eos_nat() or "?"
    end

    self:local_log("DISCONNECT %s reason=%s source=%s mark{silent=%s loading=%s msg=%s} link{%s} -> %s / %s",
        self:peer_str(peer),
        self:safe_string(reason),
        self:safe_string(source),
        self:safe_string(mark and mark.silent),
        self:safe_string(mark and mark.loading),
        self:safe_string(mark and mark.message_id),
        self:link_str(link),
        self:safe_string(head),
        self:safe_string(hint)
    )

    return loc:text(head, macros), hint and loc:text(hint, macros) or nil
end

function CIM:link_str(link)
    if not link then
        return "none"
    end

    local parts = {}

    for k, v in pairs(link) do
        table.insert(parts, self:safe_string(k) .. "=" .. (type(v) == "number" and string.format("%.1f", v) or self:safe_string(v)))
    end

    table.sort(parts)

    return table.concat(parts, " ")
end

-- The vanilla lines _on_peer_removed may print for this peer; only these get
-- replaced, so unrelated system messages fired from the same call pass through.
function CIM:vanilla_removal_lines(peer)
    local macros = { name = self.P(function() return peer:name() end) }
    local lines = {}

    for _, id in ipairs({ "menu_chat_peer_lost", "menu_chat_peer_kicked", "menu_chat_peer_failed" }) do
        local text = self.P(function() return managers.localization:text(id, macros) end)

        if text then
            lines[text] = true
        end
    end

    return lines
end

-- Warn once per connection attempt when a link to a session member has not
-- come up after DC_SLOW_CONNECT_WARN seconds (the "stuck syncing" phase that
-- ends in a 15-20 s timeout).
function CIM:check_slow_links()
    local now = self:wall()

    if now - self.last_slow_check < 1 then
        return
    end

    self.last_slow_check = now

    local session = managers.network and managers.network:session()
    local chat = managers.chat

    if not session or not chat or not self:explain_enabled() or not rawget(_G, "CIM_EOS") then
        return
    end

    for _, peer in pairs(self.P(function() return session:peers() end) or {}) do
        local link = self:eos_link(peer)

        if link and link.attempt_age and not link.established_age and not link.closed_age and link.attempt_age >= self.DC_SLOW_CONNECT_WARN then
            local uid = self:safe_string(self.P(function() return peer:user_id() end))
            local started = now - link.attempt_age
            local prev = self.slow_warned[uid]

            if not prev or math.abs(prev - started) > 2 then
                self.slow_warned[uid] = started

                local macros = {
                    name = self:safe_string(self.P(function() return peer:name() end)),
                    secs = string.format("%.0f", link.attempt_age)
                }

                self:local_log("SLOW LINK %s %s", self:peer_str(peer), self:link_str(link))

                chat:feed_system_message(ChatManager.GAME, managers.localization:text(link.glare and "cim_dc_slow_glare" or "cim_dc_slow", macros))
            end
        end
    end
end
