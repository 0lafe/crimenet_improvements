local function paint(panel, name, color)
    if panel and alive(panel) then
        local child = panel:child(name)

        if child then
            child:set_color(color)
        end
    end
end

local function apply_mark(job, stale_data)
    if not job or not stale_data or CrimenetImprovements:lobby_filter_mode() ~= CrimenetImprovements.lobby_filter.MODE_MARKED then
        return
    end

    local red = CrimenetImprovements:mark_color()

    paint(job.marker_panel, "marker_dot", red)
    paint(job.glow_panel, "glow_center", red)
    paint(job.glow_panel, "glow_stretch", red)

    if job.peers_panel and alive(job.peers_panel) then
        for _, flag in ipairs(job.peers_panel:children()) do
            flag:set_visible(true)
            flag:set_color(red)
        end
    end
end

Hooks:PostHook(CrimeNetGui, "add_server_job", "ci_add_server_job", function(self, data)
    local job = data and self._jobs[data.id]

    apply_mark(job, data and CrimenetImprovements.lobby_filter._stale[data.room_id])
end)

Hooks:PostHook(CrimeNetGui, "update_server_job", "ci_update_server_job", function(self, data, i)
    local idx = data and (data.id or i)
    local job = idx and self._jobs[idx]

    apply_mark(job, data and CrimenetImprovements.lobby_filter._stale[data.room_id])
end)