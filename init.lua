-- Define a namespace for the module
warn_system = {}

local S = minetest.get_translator("warn")


-- Path to the JSON file for warnings
local warns_json_file_path = minetest.get_worldpath() .. "/warns_data.json"

-- Initialize the warnings variable outside load_warns_database
local warns = {}

-- Register privilege to access warning commands
minetest.register_privilege("warn_perm", {
    description = S("Allows access to warn commands."),
    give_to_singleplayer = false,  -- Allow a single player to possess this permission
})

-- Function to load the warnings database
function warn_system.load_warns_database()
    local json_file = io.open(warns_json_file_path, "r")
    if json_file then
        warns = minetest.deserialize(json_file:read("*all"))
        json_file:close()
        minetest.log("action", S("[warn_system] Warnings database loaded successfully."))
    else
        -- Create the JSON file if it doesn't exist
        local new_json_file = io.open(warns_json_file_path, "w")
        new_json_file:write(minetest.serialize(warns))
        new_json_file:close()
        minetest.log("action", S("[warn_system] New warnings database created."))
    end
end

-- Function to save warnings to JSON file
function warn_system.save_warns()
    local json_file = io.open(warns_json_file_path, "w")
    if json_file then
        json_file:write(minetest.serialize(warns))
        json_file:close()
    end
end

-- Function to cancel a warning
function warn_system.cancel_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].canceled = true
    warn_system.save_warns()
end

-- Function to reactivate a warning
function warn_system.reactivate_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].canceled = false
    warn_system.save_warns()
end

-- Function to mark a warning as read by the player
function warn_system.read_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].read = true
    warn_system.save_warns()
end

-- Function to mark a warning as unread by the player
function warn_system.unread_warn(player_name, warn_num)
    if not warns[player_name] or not warns[player_name]["warn"..warn_num] then
        return
    end
    warns[player_name]["warn"..warn_num].read = false
    warn_system.save_warns()
end

-- Function to open a warning to the player in a graphical interface
-- for a specific warning with a button to mark it as read
-- calls the function warn_system.read_warn to mark the warning as read
function warn_system.show_warn_formspec(player_name, warn_num)
    local warn_data = warns[player_name]["warn"..warn_num]
    local form = "size[10,8]" ..
        "label[0,0;".. S("Warning #") .. warn_num .. "]" ..
        "label[0,1;".. S("Reason") .. ": " .. warn_data.reason .. "]" ..
        "label[0,2;".. S("Date") .. ": " .. warn_data.date .. "]" ..
        "label[0,3;".. S("Please acknowledge this warning.") .. "]" ..
        "label[0,4;".. S("You can access the server rules at any time with /rules.") .. "]" ..
        "label[0,5;".. S("Failure to comply may result in sanctions.") .. "]" ..

        -- Close button and call to warn_system.read_warn function
        "button_exit[3,7;4,1;".. S("Mark as Read") .. "_" .. warn_num .. ";".. S("Mark as Read") .."]"
    minetest.show_formspec(player_name, "warn_system:show_warn_" .. warn_num, form)
    minetest.chat_send_player(player_name, S("Warning #") .. warn_num .. " " .. S("displayed."))
end

-- Function to check and display the next unread warning
local function check_and_display_next_warning(player_name)
    -- sets a variable to an unread and uncanceled warning
    local next_warn
    for warn_num, warn_data in pairs(warns[player_name]) do
        if not warn_data.read and not warn_data.canceled then
            next_warn = tonumber(warn_num:match("%d+"))
            break
        end
    end 
    -- If an unread warning is found, call the warn_system.show_warn_formspec function after 5 seconds
    if next_warn then
        minetest.after(2, function()
            warn_system.show_warn_formspec(player_name, next_warn)
        end)
    end

end

-- Detect if the player has read the warning and mark it as read by sending a message
minetest.register_on_player_receive_fields(function(player, formname, fields)
    -- If the form is that of the warning (warn_system:show_warn_(warning number))
    if formname:find("warn_system:show_warn_") then
        -- Use the warn_system.read_warn function to mark the warning as read
        local warn_num = tonumber(formname:match("(%d+)"))
        local player_name = player:get_player_name()
        warn_system.read_warn(player_name, warn_num)
        -- Send a message in the chat to confirm that the warning has been marked as read
        minetest.chat_send_player(player_name, S("Warning number") .. " " .. warn_num .. " " .. S("marked as read."))
        -- Check and display the next unread warning
        check_and_display_next_warning(player_name)
    end
end)

-- Function to get the number of warnings for a player
function warn_system.get_num_warns(player_name)
    local player_warns = warns[player_name]
    local num_warns = 0
    if player_warns then
        for _ in pairs(player_warns) do
            num_warns = num_warns + 1
        end
    end
    return num_warns
end

-- Command to display the number of warnings for a player
minetest.register_chatcommand("num_warns", {
    params = "<player>",
    description = S("Displays the number of warnings for a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player = param
        if not target_player then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /num_warns <player>"))
            return
        end
        local num_warns = warn_system.get_num_warns(target_player)
        minetest.chat_send_player(name, S("Player") .. " " .. target_player .. " " .. S("has") .. " " .. num_warns .. " " .. S("warnings."))
    end,
})

-- Function to give a warning to a player
function warn_system.give_warn(player_name, reason)
    if not warns[player_name] then
        warns[player_name] = {}
    end
    local num_warns = warn_system.get_num_warns(player_name) + 1
    local warn_num = "warn" .. num_warns
    warns[player_name][warn_num] = {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        reason = reason,
        read = false,
        canceled = false
    }
    warn_system.save_warns()
    minetest.chat_send_player(player_name, S("You have received a warning for the following reason") .. ": " .. reason .. ". " .. S("This is your warning number") .. " " .. num_warns)
    -- checks if the player is online and displays the warning
    if minetest.get_player_by_name(player_name) then
        warn_system.show_warn_formspec(player_name, num_warns)
    end
end

-- Command to display specific warnings for a player and use the warn_system.show_warn_formspec function
minetest.register_chatcommand("show_warn", {
    params = "<player> <warning number>",
    description = S("Displays a specific warning for a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /show_warn <player> <warning number>"))
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, S("The specified player is not online."))
            return
        end
        if not warns[target_player] or not warns[target_player]["warn"..warn_num] then
            minetest.chat_send_player(name, S("Warning not found."))
            return
        end
        warn_system.show_warn_formspec(target_player, tonumber(warn_num))
    end,
})

-- Command to cancel a warning
minetest.register_chatcommand("cancel_warn", {
    params = "<player> <warning number>",
    description = S("Cancels a warning given to a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /cancel_warn <player> <warning number>"))
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, S("The specified player is not online."))
            return
        end
        warn_system.cancel_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, S("Warning") .. " #" .. warn_num .. " " .. S("cancelled for player") .. " " .. target_player)
    end,
})

-- Command to reactivate a warning
minetest.register_chatcommand("reactivate_warn", {
    params = "<player> <warning number>",
    description = S("Reactivates a cancelled warning for a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /reactivate_warn <player> <warning number>"))
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, S("The specified player is not online."))
            return
        end
        warn_system.reactivate_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, S("Warning") .. " #" .. warn_num .. " " .. S("reactivated for player") .. " " .. target_player)
    end,
})

-- Command to mark a warning as read by the player
minetest.register_chatcommand("read_warn", {
    params = "<player> <warning number>",
    description = S("Marks a warning as read for a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player, warn_num = param:match("(%S+)%s+(%d+)")
        if not target_player or not warn_num then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /read_warn <player> <warning number>"))
            return
        end
        if not minetest.get_player_by_name(target_player) then
            minetest.chat_send_player(name, S("The specified player is not online."))
            return
        end
        warn_system.read_warn(target_player, tonumber(warn_num))
        minetest.chat_send_player(name, S("Warning") .. " #" .. warn_num .. " " .. S("marked as read for player") .. " " .. target_player)
    end,
})

-- Command to give a warning to a player
minetest.register_chatcommand("warn", {
    params = "<player> <reason>",
    description = S("Gives a warning to a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player, reason = param:match("(%S+)%s+(.+)")
        if not target_player or not reason then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /warn <player> <reason>"))
            return
        end
        warn_system.give_warn(target_player, reason)
        minetest.chat_send_player(name, S("Warning given to") .. " " .. target_player .. " " .. S("for the following reason") .. ": " .. reason)
    end,
})

-- Command to view all warnings for a player
minetest.register_chatcommand("warns", {
    params = "<player>",
    description = S("Displays all warnings for a player"),
    privs = {warn_perm=true},
    func = function(name, param)
        local target_player = param
        if not target_player then
            minetest.chat_send_player(name, S("Incorrect syntax. Usage: /view_warns <player>"))
            return
        end
        local player_warns = warns[target_player]
        if not player_warns then
            minetest.chat_send_player(name, S("This player has no warnings."))
            return
        end
        minetest.chat_send_player(name, S("Warnings for player") .. " " .. target_player .. ":")
        for warn_num, warn_data in pairs(player_warns) do
            local status = warn_data.read and S("Read") or S("Unread")
            local canceled = warn_data.canceled and S("Cancelled") or S("Active")
            minetest.chat_send_player(name, S("Warning") .. " #" .. warn_num .. " - " .. S("Reason") .. ": " .. warn_data.reason .. " - " .. S("Date") .. ": " .. warn_data.date .. " - " .. S("Status") .. ": " .. status .. " - " .. canceled)
        end
    end,
})

-- When a player joins, check and display the next unread warning
minetest.register_on_joinplayer(function(player)
    -- checks if the player has warnings
    if not warns[player:get_player_name()] then
        return
    end
    local player_name = player:get_player_name()
    local next_warn
    for warn_num, warn_data in pairs(warns[player_name]) do
        if not warn_data.read and not warn_data.canceled then
            next_warn = tonumber(warn_num:match("%d+"))
            break
        end
    end 
    -- If an unread warning is found, call the warn_system.show_warn_formspec function after 5 seconds
    if next_warn then
        minetest.after(1, function()
            warn_system.show_warn_formspec(player_name, next_warn)
        end)
    end
end)

-- Load the warnings database at startup
warn_system.load_warns_database()
