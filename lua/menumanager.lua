local function show_failed_menu(title, head, body, details)
    local lobby_context = CIM:lobby_context()
    local lines = { head, "", body }
    local extra = {}

    if lobby_context then
        local lobby = CIM:format_lobby()

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
    local head, body, details = CIM:explain_join_fail()

    if not head then
        return orig_failed(self, ...)
    end

    show_failed_menu(managers.localization:text("dialog_error_title"), head, body, details)
end

local orig_timed_out = MenuManager.show_request_timed_out_dialog
function MenuManager:show_request_timed_out_dialog(...)
    local head, body, details = CIM:explain_join_fail()

    if not head then
        return orig_timed_out(self, ...)
    end

    show_failed_menu(managers.localization:text("dialog_request_timed_out_title"), head, body, details)
end

CIM:load()

Hooks:Add("LocalizationManagerPostInit", "CIM_Localization", function(loc)
    loc:load_localization_file(CIM.mod_path .. "loc/english.txt", false)
end)

Hooks:Add("MenuManagerInitialize", "CIM_MenuInit", function(menu_manager)
    function MenuCallbackHandler:CIM_set_mode(item)
        CIM.lobby_filter.settings.mode = item:value()
        CIM:save()
    end

    function MenuCallbackHandler:CIM_save(item)
        CIM:save()
    end

    MenuHelper:LoadFromJsonFile(CIM.mod_path .. "menu/options.json", CIM, CIM.lobby_filter.settings)
end)