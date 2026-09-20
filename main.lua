if not CIM then
    CIM = {
        mod_path = ModPath,
        save_path = SavePath .. "CrimenetImprovements.json",
        required = {},
        log_file = nil,
        stats = { updates_issued = 0, updates_completed = 0 },
        seen_lobbies = {},
        last_heartbeat = 0,
        join_t = 0,
        lobby_filter = {
            MODE_HIDDEN = 1,
            MODE_MARKED = 2,
            MODE_DISPLAYED = 3,
            settings = { mode = 1 },
            _stale = {},
            _in_join_check = false
        }
    }

    function CIM:safe_string(v)
        local ok, r = pcall(tostring, v)
        return ok and r or "?"
    end

    function CIM:wall()
        local ok, t = pcall(function() return TimerManager:wall():time() end)
        return ok and t or 0
    end

    function CIM:log(fmt, ...)
        log(string.format("[CIM] " .. fmt, ...))
    end

    local function pack(...)
        return { n = select("#", ...), ... }
    end

    function CIM.P(f, ...)
        local r = pack(pcall(f, ...))

        if r[1] then
            return unpack(r, 2, r.n)
        end

        return nil
    end

    function CIM:load()
        local file = io.open(self.save_path, "r")
        if not file then
            return
        end

        local ok, data = pcall(json.decode, file:read("*all"))

        file:close()

        if ok and type(data) == "table" and type(data.mode) == "number" then
            self.lobby_filter.settings.mode = math.clamp(math.floor(data.mode), 1, 3)
        end
    end

    function CIM:save()
        local file = io.open(self.save_path, "w+")
        if file then
            file:write(json.encode(self.lobby_filter.settings))
            file:close()
        end
    end

    dofile(CIM.mod_path .. "lib/verbose_logging.lua")
    dofile(CIM.mod_path .. "lib/lobby_filter.lua")
    dofile(CIM.mod_path .. "lib/mm_diagnostic.lua")
end

if RequiredScript and not CIM.required[RequiredScript] then
  local fname = CIM.mod_path .. RequiredScript:gsub(".+/(.+)", "lua/%1.lua")
  if io.file_is_readable(fname) then
    dofile(fname)
  end

  CIM.required[RequiredScript] = true
end
