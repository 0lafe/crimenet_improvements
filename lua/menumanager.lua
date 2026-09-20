local function show_failed_menu(title, head, body, details)
    local lobby_context = CrimenetImprovements:lobby_context()
    local lines = { head, "", body }
    local extra = {}

    if lobby_context then
        local lobby = CrimenetImprovements:format_lobby()

        if lobby ~= "" then
            table.insert(extra, lobby)
        end
    end

    for _, detail in ipairs(details or {}) do
        table.insert(extra, detail)
    end

    if #extra > 0 then
        table.insert(lines, "")
        table.insert(lines, table.concat(extra, "\n"))
    end

    managers.system_menu:show({
        title = title,
        text = table.concat(lines, "\n"),
        button_list = {
            { text = managers.localization:text("dialog_ok") }
        }
    })
end

local orig_failed = MenuManager.show_failed_joining_dialog
function MenuManager:show_failed_joining_dialog(...)
    local head, body, details = CrimenetImprovements:explain_join_fail()

    if not head then
        return orig_failed(self, ...)
    end

    show_failed_menu(managers.localization:text("dialog_error_title"), head, body, details)
end

local orig_timed_out = MenuManager.show_request_timed_out_dialog
function MenuManager:show_request_timed_out_dialog(...)
    local head, body, details = CrimenetImprovements:explain_join_fail()

    if not head then
        return orig_timed_out(self, ...)
    end

    show_failed_menu(managers.localization:text("dialog_request_timed_out_title"), head, body, details)
end

CrimenetImprovements:load()

Hooks:Add("LocalizationManagerPostInit", "CrimenetImprovements_Localization", function(loc)
    loc:load_localization_file(CrimenetImprovements.mod_path .. "loc/english.txt", false)
end)

Hooks:Add("MenuManagerInitialize", "CrimenetImprovements_MenuInit", function(menu_manager)
    function MenuCallbackHandler:crimenetimprovements_set_mode(item)
        CrimenetImprovements.lobby_filter.settings.mode = item:value()
        CrimenetImprovements:save()
    end

    function MenuCallbackHandler:crimenetimprovements_save(item)
        CrimenetImprovements:save()
    end

    MenuHelper:LoadFromJsonFile(CrimenetImprovements.mod_path .. "menu/options.json", CrimenetImprovements, CrimenetImprovements.lobby_filter.settings)
end)