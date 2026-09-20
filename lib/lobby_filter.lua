function CIM:lobby_filter_mode()
    return self.lobby_filter.settings.mode
end

function CIM:mark_color()
    return tweak_data.screen_colors.important_1 or Color.red
end

function CIM:is_stale_lobby(members, limit, advertised)
    if not members or not advertised then
        return false
    end

    limit = limit or 4

    return members >= limit and advertised < members
end