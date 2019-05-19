local cur_scriptname = GetScriptName()
local cur_version = "1.1.8"
local git_version = "https://raw.githubusercontent.com/Skillmeister/Gamesense-like-UI/master/version.txt"
local git_repository = "https://raw.githubusercontent.com/Skillmeister/Gamesense-like-UI/master/UIEdited.lua"
local app_awusers = "http://api.shadyretard.io/awusers"


-- Check for updates
local function git_update()
	if cur_version ~= http.Get(git_version) then
		local this_script = file.Open(cur_scriptname, "w")
		this_script:Write(http.Get(git_repository))
		this_script:Close()
		print("[Lua Scripting] " .. cur_scriptname .. " has updated itself from version " .. cur_version .. " to " .. http.Get(git_version))
		print("[Lua Scripting] Please reload " .. cur_scriptname)
	else
		print("[Lua Scripting] " .. cur_scriptname .. " is up-to-date")
	end
end

--[[
	SenseUI by Ruppet
	====================================
	SenseUI is Immediate-Mode GUI for Aimware which have "GameSense" cheat style.
]]

-- Anti multiload



--
--
-- Start GEHelper.lua
--
--

-- Grenade Helper by ShadyRetard
local THROW_RADIUS = 20;
local WALK_SPEED = 100;
local DRAW_MARKER_DISTANCE = 100;
local GH_ACTION_COOLDOWN = 30;
local GAME_COMMAND_COOLDOWN = 40;
local GRENADE_SAVE_FILE_NAME = "grenade_data.dat";
local maps = {}

local GH_WINDOW_ACTIVE = gui.Checkbox(gui.Reference("VISUALS", "MISC", "Assistance"), "GH_WINDOW_ACTIVE", "Grenade Helper", false);
local GH_WINDOW = gui.Window("GH_WINDOW", "Grenade Helper", 200, 200, 450, 150);
local GH_NEW_NADE_GB = gui.Groupbox(GH_WINDOW, "Add grenade throw", 15, 15, 200, 100);
local GH_ENABLE_KEYBINDS = gui.Checkbox(GH_NEW_NADE_GB, "GH_ENABLE_KEYBINDS", "Enable Add Keybinds", false);
local GH_ADD_KB = gui.Keybox(GH_NEW_NADE_GB, "GH_ADD_KB", "Add key", "");
local GH_DEL_KB = gui.Keybox(GH_NEW_NADE_GB, "GH_DEL_KB", "Remove key", "");

local GH_SETTINGS_GB = gui.Groupbox(GH_WINDOW, "Settings", 230, 15, 200, 100);
local GH_HELPER_ENABLED = gui.Checkbox(GH_SETTINGS_GB, "GH_HELPER_ENABLED", "Enable Grenade Helper", false);
local GH_VISUALS_DISTANCE_SL = gui.Slider(GH_SETTINGS_GB, "GH_VISUALS_DISTANCE_SL", "Display Distance", 800, 1, 9999);

local window_show = false;
local window_cb_pressed = true;
local should_load_data = true;
local last_action = globals.TickCount();
local throw_to_add;
local chat_add_step = 1;
local message_to_say;
local my_last_message = globals.TickCount();
local screen_w, screen_h = 0,0;
local should_load_data = true;

local nade_type_mapping = {
    "auto",
    "smokegrenade",
    "flashbang",
    "hegrenade",
    "molotovgrenade";
    "decoy";
}

local throw_type_mapping = {
    "stand",
    "jump",
    "run",
    "crouch",
    "right";
}

local chat_add_messages = {
    "[GH] Welcome to GH Setup. Type 'cancel' at any time to cancel. Please enter the name of the throw (e.g. CT to B site):",
    "[GH] Please enter the throw type (stand / jump / run / crouch / right):"
}

-- Just open up the file in append mode, should create the file if it doesn't exist and won't override anything if it does
local my_file = file.Open(GRENADE_SAVE_FILE_NAME, "a");
my_file:Close();

local current_map_name;

function gameEventHandler(event)
    if (GH_HELPER_ENABLED:GetValue() == false) then
        return;
    end

    local event_name = event:GetName();

    if (event_name == "player_say" and throw_to_add ~= nil) then
        local self_pid = client.GetLocalPlayerIndex();
        print(self_pid);
        local chat_uid = event:GetInt('userid');
        local chat_pid = client.GetPlayerIndexByUserID(chat_uid);
        print(chat_pid);

        if (self_pid ~= chat_pid) then
            return;
        end

        my_last_message = globals.TickCount();

        local say_text = event:GetString('text');

        if (say_text == "cancel") then
            message_to_say = "[GH] Throw cancelled";
            throw_to_add = nil;
            chat_add_step = 0;
            return;
        end

        -- Don't use the bot's messages
        if (string.sub(say_text, 1, 4) == "[GH]") then
            return;
        end

        -- Enter name
        if (chat_add_step == 1) then
            throw_to_add.name = say_text;
        elseif (chat_add_step == 2) then
            if (hasValue(throw_type_mapping, say_text) == false) then
                message_to_say = "[GH] The throw type '" .. say_text .. "' is invalid, please enter one of the following values: stand / jump / run / crouch / right";
                return;
            end

            throw_to_add.type = say_text;
            message_to_say = "[GH] Your throw '" .. throw_to_add.name .. "' - " .. throw_to_add.type .. " has been added.";
            table.insert(maps[current_map_name], throw_to_add);
            throw_to_add = nil;
            local value = convertTableToDataString(maps);
            local data_file = file.Open(GRENADE_SAVE_FILE_NAME, "w");
            if (data_file ~= nil) then
                data_file:Write(value);
                data_file:Close();
            end

            chat_add_step = 0;
            return;
        else
            chat_add_step = 0;
            return;
        end

        chat_add_step = chat_add_step + 1;
        message_to_say = chat_add_messages[chat_add_step];

        return;
    end
end

function drawEventHandler()
    if (should_load_data) then
        loadData();
        should_load_data = false;
    end

    showWindow();

    if (GH_HELPER_ENABLED:GetValue() == false) then
        return;
    end

    screen_w, screen_h = draw.GetScreenSize();

    local active_map_name = engine.GetMapName();

    -- If we don't have an active map, stop
    if (active_map_name == nil or maps == nil) then
        return;
    end

    if (maps[active_map_name] == nil) then
        maps[active_map_name] = {};
    end

    if (current_map_name ~= active_map_name) then
        current_map_name = active_map_name;
    end

    if (maps[current_map_name] == nil) then
        return;
    end

    if (my_last_message ~= nil and my_last_message > globals.TickCount()) then
        my_last_message = globals.TickCount();
    end

    if (message_to_say ~= nil and globals.TickCount() - my_last_message > 100) then
        client.ChatTeamSay(message_to_say);
        message_to_say = nil;
    end

    showNadeThrows();
end

function moveEventHandler(cmd)
    if (GH_HELPER_ENABLED:GetValue() == false) then
        return;
    end

    local me = entities.GetLocalPlayer();
    if (current_map_name == nil or maps == nil or maps[current_map_name] == nil or me == nil or not me:IsAlive()) then
        throw_to_add = nil;
        chat_add_step = 1;
        message_to_say = nil;
        return;
    end

    if (throw_to_add ~= nil) then
        return;
    end


    local add_keybind = GH_ADD_KB:GetValue();
    local del_keybind = GH_DEL_KB:GetValue();
    if (GH_ENABLE_KEYBINDS:GetValue() == false or (add_keybind == 0 and del_keybind == 0)) then
        return;
    end

    if (last_action ~= nil and last_action > globals.TickCount()) then
        last_action = globals.TickCount();
    end

    if (add_keybind ~= 0 and input.IsButtonDown(add_keybind) and globals.TickCount() - last_action > GH_ACTION_COOLDOWN) then
        last_action = globals.TickCount();
        return doAdd(cmd);
    end

    local closest_throw, distance = getClosestThrow(maps[current_map_name], me, cmd);
    if (closest_throw == nil or distance > THROW_RADIUS) then
        return;
    end

    if (del_keybind ~= 0 and input.IsButtonDown(del_keybind) and globals.TickCount() - last_action > GH_ACTION_COOLDOWN) then
        last_action = globals.TickCount();
        return doDel(closest_throw);
    end
end

function showWindow()
    window_show = GH_WINDOW_ACTIVE:GetValue();

    if input.IsButtonPressed(gui.GetValue("msc_menutoggle")) then
        window_cb_pressed = not window_cb_pressed;
    end

    if (window_show and window_cb_pressed) then
        GH_WINDOW:SetActive(1);
    else
        GH_WINDOW:SetActive(0);
    end
end

function loadData()
    local data_file = file.Open(GRENADE_SAVE_FILE_NAME, "r");
    if (data_file == nil) then
        return;
    end

    local throw_data = data_file:Read();
    data_file:Close();
    if (throw_data ~= nil and throw_data ~= "") then
        maps = parseStringifiedTable(throw_data);
    end
end

function doAdd(cmd)
    local me = entities.GetLocalPlayer();
    if (current_map_name == nil or maps[current_map_name] == nil or me == nil or not me:IsAlive()) then
        return;
    end

    local my_x, my_y, my_z = me:GetAbsOrigin();
    local ax, ay, az = cmd:GetViewAngles();

    local nade_type = getWeaponName(me);
    if (nade_type ~= nil and nade_type ~= "smokegrenade" and nade_type ~= "flashbang" and nade_type ~= "molotovgrenade" and nade_type ~= "hegrenade" and nade_type ~= "decoy") then
        return;
    end

    local new_throw = {
        name = "",
        type = "not_set",
        nade = nade_type,
        pos = {
            x = my_x,
            y = my_y,
            z = my_z
        },
        ax = ax,
        ay = ay
    };

    throw_to_add = new_throw;
    chat_add_step = 1;
    message_to_say = chat_add_messages[chat_add_step];
end

function doDel(throw)
    if (current_map_name == nil or maps[current_map_name] == nil) then
        return;
    end

    removeFirstThrow(throw);

    local value = convertTableToDataString(maps);
    local data_file = file.Open(GRENADE_SAVE_FILE_NAME, "w");
    if (data_file ~= nil) then
        data_file:Write(value);
        data_file:Close();
    end
end

function showNadeThrows()
    local me = entities:GetLocalPlayer();

    if (me == nil) then
        return;
    end

    local weapon_name = getWeaponName(me);

    if (weapon_name ~= nil and weapon_name ~= "smokegrenade" and weapon_name ~= "flashbang" and weapon_name ~= "molotovgrenade" and weapon_name ~= "hegrenade" and weapon_name ~= "decoy") then
        return;
    end

    local throws_to_show, within_distance = getActiveThrows(maps[current_map_name], me, weapon_name);

    for i=1, #throws_to_show do
        local throw = throws_to_show[i];
        local cx, cy = client.WorldToScreen(throw.pos.x, throw.pos.y, throw.pos.z);
        local text_color_r, text_color_g, text_color_b, text_color_a = gui.GetValue('clr_grenadetracer_text');
        local line_color_r, line_color_g, line_color_b, line_color_a = gui.GetValue('clr_grenadetracer_line');
        local bounce_color_r, bounce_color_g, bounce_color_b, bounce_color_a = gui.GetValue('clr_grenadetracer_bounce');
        local final_color_r, final_color_g, final_color_b, final_color_a = gui.GetValue('clr_grenadetracer_final');

        if (within_distance) then
            local z_offset = 64;
            if (throw.type == "crouch") then
                z_offset = 46;
            end

            local t_x, t_y, t_z = getThrowPosition(throw.pos.x, throw.pos.y, throw.pos.z, throw.ax, throw.ay, z_offset);
            local draw_x, draw_y = client.WorldToScreen(t_x, t_y, t_z);
            if (draw_x ~= nil and draw_y ~= nil) then
                draw.Color(final_color_r, final_color_g, final_color_b, final_color_a);
                draw.RoundedRect(draw_x - 10, draw_y - 10, draw_x + 10, draw_y + 10);

                -- Draw a line from the center of our screen to the throw position
                draw.Color(line_color_r, line_color_g, line_color_b, line_color_a);
                draw.Line(draw_x, draw_y, screen_w / 2, screen_h / 2);

                draw.Color(text_color_r, text_color_g, text_color_b, text_color_a);
                local text_size_w, text_size_h = draw.GetTextSize(throw.name);
                draw.Text(draw_x - text_size_w / 2, draw_y - 30 - text_size_h / 2, throw.name);
                text_size_w, text_size_h = draw.GetTextSize(throw.type);
                draw.Text(draw_x - text_size_w / 2, draw_y - 20 - text_size_h / 2, throw.type);
            end
        end

        local ulx, uly = client.WorldToScreen(throw.pos.x - THROW_RADIUS / 2, throw.pos.y - THROW_RADIUS / 2, throw.pos.z);
        local blx, bly = client.WorldToScreen(throw.pos.x - THROW_RADIUS / 2, throw.pos.y + THROW_RADIUS / 2, throw.pos.z);
        local urx, ury = client.WorldToScreen(throw.pos.x + THROW_RADIUS / 2, throw.pos.y - THROW_RADIUS / 2, throw.pos.z);
        local brx, bry = client.WorldToScreen(throw.pos.x + THROW_RADIUS / 2, throw.pos.y + THROW_RADIUS / 2, throw.pos.z);

        if (cx ~= nil and cy ~= nil and ulx ~= nil and uly ~= nil and blx ~= nil and bly ~= nil and urx ~= nil and ury ~= nil and brx ~= nil and bry ~= nil) then
            local alpha = 0;
            if (throw.distance < GH_VISUALS_DISTANCE_SL:GetValue()) then
                alpha = (1 - throw.distance / GH_VISUALS_DISTANCE_SL:GetValue()) * text_color_a;
            end

            if (throw.name ~= nil) then
                local text_size_w, text_size_h = draw.GetTextSize(throw.name);
                draw.Color(text_color_r, text_color_g, text_color_b, alpha);
                draw.Text(cx - text_size_w / 2, cy - 20 - text_size_h / 2, throw.name);
            end

            -- Show radius as green when in distance, blue otherwise
            if (within_distance) then
                draw.Color(final_color_r, final_color_g, final_color_b, final_color_a);
            else
                draw.Color(bounce_color_r, bounce_color_g, bounce_color_b, alpha);
            end

            -- Top left to rest
            draw.Line(ulx, uly, blx, bly);
            draw.Line(ulx, uly, urx, ury);
            draw.Line(ulx, uly, brx, bry);

            -- Bottom right to rest
            draw.Line(brx, bry, blx, bly);
            draw.Line(brx, bry, urx, ury);

            -- Diagonal
            draw.Line(blx, bly, urx, ury);
        end
    end
end

function getThrowPosition(pos_x, pos_y, pos_z, ax, ay, z_offset)
    return pos_x - DRAW_MARKER_DISTANCE * math.cos(math.rad(ay + 180)), pos_y - DRAW_MARKER_DISTANCE * math.sin(math.rad(ay + 180)), pos_z - DRAW_MARKER_DISTANCE * math.tan(math.rad(ax)) + z_offset;
end

function getWeaponName(me)
    local my_weapon = me:GetPropEntity("m_hActiveWeapon");
    if (my_weapon == nil) then
        return nil;
    end

    local weapon_name = my_weapon:GetClass();
    weapon_name = weapon_name:gsub("CWeapon", "");
    weapon_name = weapon_name:lower();

    if (weapon_name:sub(1, 1) == "c") then
        weapon_name = weapon_name:sub(2)
    end

    if (weapon_name == "incendiarygrenade") then
        weapon_name = "molotovgrenade";
    end

    return weapon_name;
end

function getDistanceToTarget(my_x, my_y, my_z, t_x, t_y, t_z)
    local dx = my_x - t_x;
    local dy = my_y - t_y;
    local dz = my_z - t_z;
    return math.sqrt(dx^2 + dy^2 + dz^2);
end

function getActiveThrows(map, me, nade_name)
    local throws = {};
    local throws_in_distance = {};
    -- Determine if any are within range, we should only show those if that's the case
    for i=1, #map do
        local throw = map[i];
        if (throw ~= nil and throw.nade == nade_name) then
            local my_x, my_y, my_z = me:GetAbsOrigin();
            local distance = getDistanceToTarget(my_x, my_y, throw.pos.z, throw.pos.x, throw.pos.y, throw.pos.z);
            throw.distance = distance;
            if (distance < THROW_RADIUS) then
                table.insert(throws_in_distance, throw);
            else
                table.insert(throws, throw);
            end
        end
    end

    if (#throws_in_distance > 0) then
        return throws_in_distance, true;
    end

    return throws, false;
end

function getClosestThrow(map, me, cmd)
    local closest_throw;
    local closest_distance;
    local closest_distance_from_center;
    local my_x, my_y, my_z = me:GetAbsOrigin();
    for i = 1, #map do
        local throw = map[i];
        local distance = getDistanceToTarget(my_x, my_y, throw.pos.z, throw.pos.x, throw.pos.y, throw.pos.z);
        local z_offset = 64;
        if (throw.type == "crouch") then
            z_offset = 46;
        end
        local pos_x, pos_y, pos_z = getThrowPosition(throw.pos.x, throw.pos.y, throw.pos.z, throw.ax, throw.ay, z_offset);
        local draw_x, draw_y = client.WorldToScreen(pos_x, pos_y, pos_z);
        local distance_from_center;

        if (draw_x ~= nil and draw_y ~= nil) then
            distance_from_center = math.abs(screen_w / 2 - draw_x + screen_h / 2 - draw_y);
        end

        if (
        closest_distance == nil
                or (
        distance <= THROW_RADIUS
                and (
        closest_distance_from_center == nil
                or (closest_distance_from_center ~= nil and distance_from_center ~= nil and distance_from_center < closest_distance_from_center)
        )
        )
                or (
        (closest_distance_from_center == nil and distance < closest_distance)
        )
        ) then
            closest_throw = throw;
            closest_distance = distance;
            closest_distance_from_center = distance_from_center;
        end
    end

    return closest_throw, closest_distance;
end

function parseStringifiedTable(stringified_table)
    local new_map = {};

    local strings_to_parse = {};
    for i in string.gmatch(stringified_table, "([^\n]*)\n") do
        table.insert(strings_to_parse, i);
    end

    for i=1, #strings_to_parse do
        local matches = {};

        for word in string.gmatch(strings_to_parse[i], "([^,]*)") do
            table.insert(matches, word);
        end

        local map_name = matches[1];
        if new_map[map_name] == nil then
            new_map[map_name] = {};
        end

        table.insert(new_map[map_name], {
            name = matches[2],
            type = matches[3],
            nade = matches[4],
            pos = {
                x = tonumber(matches[5]),
                y = tonumber(matches[6]),
                z = tonumber(matches[7])
            },
            ax = tonumber(matches[8]),
            ay = tonumber(matches[9]);
        });
    end

    return new_map;
end

function convertTableToDataString(object)
    local converted = "";
    for map_name, map in pairs(object) do
        for i, throw in ipairs(map) do
            if (throw ~= nil) then
                converted = converted..map_name.. ','..throw.name..','..throw.type..','..throw.nade..','..throw.pos.x..','..throw.pos.y..','..throw.pos.z..','..throw.ax..','..throw.ay..'\n';
            end
        end
    end

    return converted;
end

function hasValue(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function removeFirstThrow(throw)
    for i, v in ipairs(maps[current_map_name]) do
        if (v.name == throw.name and v.pos.x == throw.pos.x and v.pos.y == throw.pos.y and v.pos.z == throw.pos.z) then
            return table.remove(maps[current_map_name], i);
        end
    end
end

--
--
-- End GEHelper.lua
--
--

--
--
-- Start Speclist.lua
--
--

local mouseX, mouseY, x, y, dx, dy, w, h, menuPressed = 0, 0, 10, 700, 0, 0, 300, 50, 1;
local shouldDrag = 0;
local font_main = draw.CreateFont("Impact", 23, 200);
local font_spec = draw.CreateFont("Impact", 23, 200);
local topbarSize = 0;
local ref = gui.Reference('MISC', "GENERAL", "Extra");
local showMenu = gui.Checkbox(ref, "rab_material_spec_list", "Show Material Spectators Menu", false);

--GUI Starts here
local mainWindow = gui.Window("rab_material_spec_list", "Material Spectators", 50, 50, 200, 180);
local settings = gui.Groupbox(mainWindow, "Settings", 13, 13, 140, 120);
local masterSwitch = gui.Checkbox(settings, "rab_material_spec_masterswitch", "Master Switch", false);
local theme = gui.Combobox(settings, "rab_material_spec_theme", "Theme", "Light", "Dark", "Amoled");
local hideBots = gui.Checkbox(settings, "rab_material_spec_hide_bots", "Hide Bots", false);
local primary_color = { { 255, 140, 0 }, { 255, 140, 0 }, { 255, 140, 0 } };
local secondary_color = { { 255, 140, 0 }, { 255, 140, 0 }, { 255, 140, 0 } }
local text_color = { { 255, 140, 0 }, { 255, 140, 0 }, { 255, 140, 0 } }

--This gets a player array of all the specatators that is specating our local player thanks to Cheeseot
local function getSpectators()
    local spectators = {};
    local lp = entities.GetLocalPlayer();
    if lp ~= nil then
        local players = entities.FindByClass("CCSPlayer");
        local specI = 1;
        for i = 1, #players do
            local player = players[i];
            if player ~= lp and player:GetHealth() <= 0 then
                local name = player:GetName();
                if player:GetPropEntity("m_hObserverTarget") ~= nil then
                    local playerindex = player:GetIndex();
                    local ping = entities.GetPlayerResources():GetPropInt("m_iPing", playerindex);
                    local shouldAdd = true;
                    if(ping == 0) then
                        if (hideBots:GetValue()) then
                            shouldAdd = false;
                        end
                    end
                        if name ~= "GOTV" and playerindex ~= 1 then
                            local target = player:GetPropEntity("m_hObserverTarget");
                            if target:IsPlayer() then
                                local targetindex = target:GetIndex();
                                local myindex = client.GetLocalPlayerIndex();
                                if lp:IsAlive() then
                                    if targetindex == myindex and shouldAdd then
                                        spectators[specI] = player;
                                        specI = specI + 1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return spectators;
end

--Adding this makes the top-bar draggable thanks to Ruppet.
local function dragFeature()
    if input.IsButtonDown(1) then
        mouseX, mouseY = input.GetMousePos();
        if shouldDrag == 1 then
            x = mouseX - dx;
            y = mouseY - dy;
        end
        if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + 40 then
            shouldDrag = true;
            dx = mouseX - x;
            dy = mouseY - y;
        end
    else
        shouldDrag = 0;
    end
end

local function getFadeRGB(speed)
    local r = math.floor(math.sin((globals.RealTime()) * speed) * 127 + 128)
    local g = math.floor(math.sin((globals.RealTime()) * speed + 2) * 127 + 128)
    local b = math.floor(math.sin((globals.RealTime()) * speed + 4) * 127 + 128)
    return { r, g, b };
end

--This draws the nice looking material window designed and developed by Rab
local function drawWindow(spectators)
    local h = h + (spectators * 17);

end

local function drawSpectators(spectators)
    for index, player in pairs(spectators) do
        draw.SetFont(font_spec);
        local currentTheme = theme:GetValue() + 1;
        local rgb = text_color;
        draw.Color( 255, 140, 0 , 255);
        draw.Text(x + 0, (y + 0 - 5) + (index * 17), player:GetName())
    end;
end

local function handleGUI()
    if input.IsButtonPressed(gui.GetValue("msc_menutoggle")) then
        menuPressed = menuPressed == 0 and 1 or 0;
    end
    if (showMenu:GetValue()) then
        mainWindow:SetActive(menuPressed);
    else
        mainWindow:SetActive(0);
    end
end

callbacks.Register("Draw", function()
    handleGUI();
    if (masterSwitch:GetValue() ~= true) then return end;
    dragFeature();
    local spectators = getSpectators();
    drawWindow(#spectators);
    drawSpectators(spectators);
end)


--
--
-- End Speclist.lua
--
--

--
--
-- Start AutoZues.lua
--
--

local SetValue = gui.SetValue;

local LGT_EXTRA_REF = gui.Reference( "LEGIT", "Extra" );

local Auto_Zeus = gui.Combobox( LGT_EXTRA_REF, "lua_autozeus", "Auto Zeus", "Off", "Legitbot", "Ragebot" );

callbacks.Register( 'Draw',  function()

	if entities.GetLocalPlayer() == nil then
		return
	end

	local LocalPlayerEntity = entities.GetLocalPlayer();
	local WeaponID = LocalPlayerEntity:GetWeaponID();

	if WeaponID == 31 then 
		Taser = true
	else
		Taser = false
	end

end
)
local function AutoZeus()

	if not gui.GetValue("lbot_active") then
		return
	end

	if Auto_Zeus:GetValue() == 0 then
		return
	end

	if Taser then
		if Auto_Zeus:GetValue() == 1 then
			SetValue( "rbot_active", 0 )
			SetValue( "lbot_trg_enable", 1 )
			SetValue( "lbot_trg_autofire", 1 )
			SetValue( "lbot_trg_key", 0 )
			SetValue( "lbot_trg_hitchance", 80 )
			SetValue( "lbot_trg_mode", 3 )
			SetValue( "lbot_trg_delay", 0 )
			SetValue( "lbot_trg_burst", 0 )
			SetValue( "lbot_trg_throughsmoke", 0 )
		elseif Auto_Zeus:GetValue() == 2 then
			SetValue( "lbot_trg_enable", 0 )
			SetValue( "rbot_taser_hitchance", 80 )
			SetValue( "rbot_active", 1 )
			SetValue( "rbot_enable", 1 )
			SetValue( "rbot_fov", 15 )
			SetValue( "rbot_speedlimit", 1 )
			SetValue( "rbot_silentaim", 1 )
			if ( gui.GetValue( "lbot_positionadjustment" ) > 0 ) then
				SetValue( "rbot_positionadjustment", 5 )
			else
				SetValue( "rbot_positionadjustment", 0 )
			end
		end
	else
		if Auto_Zeus:GetValue() == 1 then
			SetValue( "lbot_trg_enable", 0 )
		elseif Auto_Zeus:GetValue() == 2 then
			SetValue( "rbot_active", 0 )
		end
	end

end



--
--
-- End AutoZues.lua
--
--

--
--
-- Start SmartFakeLag.lua
--
--

local SetValue = gui.SetValue;
local GetValue = gui.GetValue;
 
local Version = "4.5"
 
local MSC_FAKELAG_REF = gui.Reference( "MISC", "ENHANCEMENT", "Fakelag" );
 
local FAKELAG_EXTRA_TEXT = gui.Text( MSC_FAKELAG_REF, "Fakelag Extra" );
local FAKELAG_EXTRA = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_extra_enable", "Enable", 0 );
local FAKELAG_ON_SLOWWALK = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_slowwalk", "Disable On Slow Walk", 0 );
local FAKELAG_ON_KNIFE = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_knife", "Disable On Knife", 0 );
local FAKELAG_ON_TASER = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_taser", "Disable On Taser", 0 );
local FAKELAG_ON_GRENADE = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_grenade", "Disable On Grenade", 0 );
local FAKELAG_ON_PISTOL = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_pistol", "Disable On Pistol", 0 );
local FAKELAG_ON_REVOLVER = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_revolver", "Disable On Revolver", 0 );
local FAKELAG_ON_PING = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_ping", "Disable Fakelag On Ping", 0 )
local FAKELAG_ON_PING_AMOUNT = gui.Slider( MSC_FAKELAG_REF, "lua_fakelag_ping_amount", "Amount", 120, 0, 1000 )
 
local FAKELAG_SMART_MODE_TEXT = gui.Text( MSC_FAKELAG_REF, "Fakelag Smart Mode" )
local FAKELAG_SMART_MODE = gui.Checkbox( MSC_FAKELAG_REF, "lua_fakelag_smartmode_enable", "Enable", 0 );
local FAKELAG_SMART_MODE_STANDING = gui.Combobox( MSC_FAKELAG_REF, "lua_fakelag_standing", "While Standing", "Off", "Factor", "Switch", "Adaptive", "Random", "Peek", "Rapid Peek" );
local FAKELAG_SMART_MODE_STANDING_FACTOR = gui.Slider( MSC_FAKELAG_REF, "lua_fakelag_standing_factor", "Factor", 15, 1, 15 );
local FAKELAG_SMART_MODE_MOVING = gui.Combobox( MSC_FAKELAG_REF, "lua_fakelag_moving", "While Moving", "Off", "Factor", "Switch", "Adaptive", "Random", "Peek", "Rapid Peek" );
local FAKELAG_SMART_MODE_MOVING_FACTOR = gui.Slider( MSC_FAKELAG_REF, "lua_fakelag_moving_factor", "Factor", 15, 1, 15 );
local FAKELAG_SMART_MODE_INAIR = gui.Combobox( MSC_FAKELAG_REF, "lua_fakelag_inair", "While In Air", "Off", "Factor", "Switch", "Adaptive", "Random", "Peek", "Rapid Peek" );
local FAKELAG_SMART_MODE_INAIR_FACTOR = gui.Slider( MSC_FAKELAG_REF, "lua_fakelag_inair_factor", "Factor", 15, 1, 15 );
 
local Ping = 0
local Time = 0
 
local function GetWeapon()
 
    if entities.GetLocalPlayer() == nil then
        return
    end
 
    local LocalPlayerEntity = entities.GetLocalPlayer();
    local WeaponID = LocalPlayerEntity:GetWeaponID();
    local WeaponType = LocalPlayerEntity:GetWeaponType();
 
    if ( WeaponType == 0 and WeaponID ~= 31 ) then Knife = true else Knife = false end
    if ( WeaponType == 1 and WeaponID ~= 64 ) then Pistol = true else Pistol = false end
    if WeaponID == 31 then Taser = true else Taser = false end
    if WeaponType == 9 then Grenade = true else Grenade = false end
    if WeaponID == 64 then Revolver = true else Revolver = false end
 
end
 
local function FakelagExtra()
 
    if FAKELAG_EXTRA:GetValue() then
       
        if ( FAKELAG_ON_KNIFE:GetValue() and Knife ) or -- On Knife
           ( FAKELAG_ON_TASER:GetValue() and Taser ) or -- On Taser
           ( FAKELAG_ON_GRENADE:GetValue() and Grenade ) or -- On Grenade
           ( FAKELAG_ON_PISTOL:GetValue() and Pistol ) or -- On Pistol
           ( FAKELAG_ON_REVOLVER:GetValue() and Revolver ) then -- On Revolver
            SetValue( "msc_fakelag_enable", 0 );
        else
            SetValue( "msc_fakelag_enable", 1 );
        end
 
    end
 
end
 
local function FakelagOnPing()
 
    if FAKELAG_EXTRA:GetValue() then
        if FAKELAG_ON_PING:GetValue() then
 
            if entities.GetPlayerResources() ~= nil then
                Ping = entities.GetPlayerResources():GetPropInt( "m_iPing", client.GetLocalPlayerIndex() );
            end
            FakelagOnPingAmount = math.floor( FAKELAG_ON_PING_AMOUNT:GetValue() )
 
            if ( Ping >= FakelagOnPingAmount ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_KNIFE:GetValue() and Knife ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_TASER:GetValue() and Taser ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_GRENADE:GetValue() and Grenade ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PISTOL:GetValue() and Pistol ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_REVOLVER:GetValue() and Revolver ) then
                SetValue( "msc_fakelag_enable", 0 );
            else
                SetValue( "msc_fakelag_enable", 1 );
            end
 
        end
    end
 
end        
 
local function FakelagOnSlowWalk()
 
    if FAKELAG_EXTRA:GetValue() then
 
        if GetValue( "msc_slowwalk" ) ~= 0 then
            SlowWalkFakelagOff = input.IsButtonDown( GetValue( "msc_slowwalk" ) )
        end
 
        if FAKELAG_ON_SLOWWALK:GetValue() and GetValue( "msc_slowwalk" ) ~= 0 then
            if ( SlowWalkFakelagOff ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_KNIFE:GetValue() and Knife ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_TASER:GetValue() and Taser ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_GRENADE:GetValue() and Grenade ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PISTOL:GetValue() and Pistol ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_REVOLVER:GetValue() and Revolver ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PING:GetValue() and Ping >= FakelagOnPingAmount ) then
                SetValue( "msc_fakelag_enable", 0 );
            else
                SetValue( "msc_fakelag_enable", 1 );
            end
        end
 
    end
 
end
 
local function FakelagSmartMode()
 
    if FAKELAG_SMART_MODE:GetValue() then
 
        local FAKELAG_STANDING = FAKELAG_SMART_MODE_STANDING:GetValue();
        local FAKELAG_MOVING = FAKELAG_SMART_MODE_MOVING:GetValue();
        local FAKELAG_INAIR = FAKELAG_SMART_MODE_INAIR:GetValue();
 
        local FAKELAG_STANDING_FACTOR = math.floor( FAKELAG_SMART_MODE_STANDING_FACTOR:GetValue() )
        local FAKELAG_MOVING_FACTOR = math.floor( FAKELAG_SMART_MODE_MOVING_FACTOR:GetValue() )
        local FAKELAG_INAIR_FACTOR = math.floor( FAKELAG_SMART_MODE_INAIR_FACTOR:GetValue() )
 
        if entities.GetLocalPlayer() ~= nil then
 
            local LocalPlayerEntity = entities.GetLocalPlayer();
            local fFlags = LocalPlayerEntity:GetProp( "m_fFlags" );
 
            local VelocityX = LocalPlayerEntity:GetPropFloat( "localdata", "m_vecVelocity[0]" );
            local VelocityY = LocalPlayerEntity:GetPropFloat( "localdata", "m_vecVelocity[1]" );
 
            local Velocity = math.sqrt( VelocityX^2 + VelocityY^2 );
 
            -- Standing
            if ( Velocity == 0 and ( fFlags == 257 or fFlags == 261 or fFlags == 263 ) ) then
                Standing = true
            else
                Standing = false
            end
 
            -- Moving
            if ( Velocity > 0 and ( fFlags == 257 or fFlags == 261 or fFlags == 263 ) ) then
                Moving = true
            else
                Moving = false
            end
 
            -- In Air
            if fFlags == 256 or fFlags == 262 then
                InAir = true
                Time = globals.CurTime();
            else
                InAir = false
            end
        end
 
        if Standing and Time + 0.2 < globals.CurTime() then
            if ( FAKELAG_STANDING == 0 ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_KNIFE:GetValue() and Knife ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_TASER:GetValue() and Taser ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_GRENADE:GetValue() and Grenade ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PISTOL:GetValue() and Pistol ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_REVOLVER:GetValue() and Revolver ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PING:GetValue() and Ping >= FakelagOnPingAmount ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_SLOWWALK:GetValue() and GetValue( "msc_slowwalk" ) ~= 0 and SlowWalkFakelagOff ) then
                SetValue( "msc_fakelag_enable", 0 );
            else
                SetValue( "msc_fakelag_enable", 1 );
            end
            if FAKELAG_STANDING > 0 then
                STANDING_MODE = ( FAKELAG_STANDING - 1 )
            end
            SetValue( "msc_fakelag_mode", STANDING_MODE );
            SetValue( "msc_fakelag_value", FAKELAG_STANDING_FACTOR );
        end
 
        if Moving and Time + 0.2 < globals.CurTime() then
            if ( FAKELAG_MOVING == 0 ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_KNIFE:GetValue() and Knife ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_TASER:GetValue() and Taser ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_GRENADE:GetValue() and Grenade ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PISTOL:GetValue() and Pistol ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_REVOLVER:GetValue() and Revolver ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PING:GetValue() and Ping >= FakelagOnPingAmount ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_SLOWWALK:GetValue() and GetValue( "msc_slowwalk" ) ~= 0 and SlowWalkFakelagOff ) then
                SetValue( "msc_fakelag_enable", 0 );
            else
                SetValue( "msc_fakelag_enable", 1 );
            end
            if FAKELAG_MOVING > 0 then
                MOVING_MODE = ( FAKELAG_MOVING - 1 )
            end
            SetValue( "msc_fakelag_mode", MOVING_MODE );
            SetValue( "msc_fakelag_value", FAKELAG_MOVING_FACTOR );
        end
 
        if InAir then
            if ( FAKELAG_INAIR == 0 ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_KNIFE:GetValue() and Knife ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_TASER:GetValue() and Taser ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_GRENADE:GetValue() and Grenade ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PISTOL:GetValue() and Pistol ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_REVOLVER:GetValue() and Revolver ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_PING:GetValue() and Ping >= FakelagOnPingAmount ) or
               ( FAKELAG_EXTRA:GetValue() and FAKELAG_ON_SLOWWALK:GetValue() and GetValue( "msc_slowwalk" ) ~= 0 and SlowWalkFakelagOff ) then
                SetValue( "msc_fakelag_enable", 0 );
            else
                SetValue( "msc_fakelag_enable", 1 );
            end
            if FAKELAG_INAIR > 0 then
                INAIR_MODE = ( FAKELAG_INAIR - 1 )
            end
            SetValue( "msc_fakelag_mode", INAIR_MODE );
            SetValue( "msc_fakelag_value", FAKELAG_INAIR_FACTOR );
        end
 
    end
 
end
--
--
-- End SmartFakeLag.lua
--
--




--
--
--
-- Begin Blockbot.lua
--
--
local font_icon = draw.CreateFont("Webdings", 30, 30)
local font_warning = draw.CreateFont("Verdana", 15, 15)



-- UI Elements --
local ref_msc_auto_other = gui.Reference("MISC", "AUTOMATION", "Other")

local txt_header = gui.Text( ref_msc_auto_other, "Block Bot")
local key_blockbot = gui.Keybox(ref_msc_auto_other, "msc_blockbot", "On Key", 0)
local cob_blockbot_mode = gui.Combobox(ref_msc_auto_other, "msc_blockbot_mode", "Mode", "Match Speed", "Maximum Speed")
local chb_blockbot_retreat = gui.Checkbox(ref_msc_auto_other, "chb_blockbot_retreat", " Retreat on BunnyHop", 0)
-----------------


-- Shared Variables
local Target = nil
local CrouchBlock = false
local LocalPlayer = nil

local awusers = {}

local function OnFrameMain()

	LocalPlayer = entities.GetLocalPlayer()
	
	if not gui.GetValue("lua_allow_http") then
		return
	end
	
	if LocalPlayer == nil or engine.GetServerIP() == nil then
		return
	end
	
	if (key_blockbot:GetValue() == nil or key_blockbot:GetValue() == 0) or not LocalPlayer:IsAlive() then
		return
	end
	
	if input.IsButtonDown(key_blockbot:GetValue()) and Target == nil then
		
		for Index, Entity in pairs(entities.FindByClass("CCSPlayer")) do
			if Entity:GetIndex() ~= LocalPlayer:GetIndex() and Entity:IsAlive() then
				local EntityID = client.GetPlayerInfo(Entity:GetIndex())["SteamID"]
				local isPleb = true
				
				for Index, SteamID in pairs(awusers) do	
					if SteamID == EntityID then
						isPleb = false
						break		
					end
				end
				
				if isPleb then
					if Target == nil then
						Target = Entity;
					elseif vector.Distance({LocalPlayer:GetAbsOrigin()}, {Target:GetAbsOrigin()}) > vector.Distance({LocalPlayer:GetAbsOrigin()}, {Entity:GetAbsOrigin()}) then
						Target = Entity;
					end
				end
				
			end
		end
		
	elseif not input.IsButtonDown(key_blockbot:GetValue()) or not Target:IsAlive() then
		Target = nil
	end

	if Target ~= nil then
		local NearPlayer_toScreen = {client.WorldToScreen(Target:GetBonePosition(5))}
		
		if select(3, Target:GetHitboxPosition(0)) < select(3, LocalPlayer:GetAbsOrigin()) and vector.Distance({LocalPlayer:GetAbsOrigin()}, {Target:GetAbsOrigin()}) < 100 then
			CrouchBlock = true
			draw.Color(255, 255, 0, 255)
		else
			CrouchBlock = false
			draw.Color(255, 0, 0, 255)
		end
		
		draw.SetFont(font_icon)
		
		if NearPlayer_toScreen[1] ~= nil and NearPlayer_toScreen[2] ~= nil then
			draw.TextShadow(NearPlayer_toScreen[1] - select(1, draw.GetTextSize("x")) / 2, NearPlayer_toScreen[2], "x")
		end
		
	end
	
end

local function OnCreateMoveMain(UserCmd)
	
	if Target ~= nil then
		local LocalAngles = {UserCmd:GetViewAngles()}
		local VecForward = {vector.Subtract( {Target:GetAbsOrigin()},  {LocalPlayer:GetAbsOrigin()} )}
		local AimAngles = {vector.Angles( VecForward )}
		local TargetSpeed = vector.Length(Target:GetPropFloat("localdata", "m_vecVelocity[0]"), Target:GetPropFloat("localdata", "m_vecVelocity[1]"), Target:GetPropFloat("localdata", "m_vecVelocity[2]"))
		
		if CrouchBlock then
			if cob_blockbot_mode:GetValue() == 0 then
				UserCmd:SetForwardMove( ( (math.sin(math.rad(LocalAngles[2]) ) * VecForward[2]) + (math.cos(math.rad(LocalAngles[2]) ) * VecForward[1]) ) * 10 )
				UserCmd:SetSideMove( ( (math.cos(math.rad(LocalAngles[2]) ) * -VecForward[2]) + (math.sin(math.rad(LocalAngles[2]) ) * VecForward[1]) ) * 10 )
			elseif cob_blockbot_mode:GetValue() == 1 then
				UserCmd:SetForwardMove( ( (math.sin(math.rad(LocalAngles[2]) ) * VecForward[2]) + (math.cos(math.rad(LocalAngles[2]) ) * VecForward[1]) ) * 200 )
				UserCmd:SetSideMove( ( (math.cos(math.rad(LocalAngles[2]) ) * -VecForward[2]) + (math.sin(math.rad(LocalAngles[2]) ) * VecForward[1]) ) * 200 )
			end
		else
			local DiffYaw = AimAngles[2] - LocalAngles[2]

			if DiffYaw > 180 then
				DiffYaw = DiffYaw - 360
			elseif DiffYaw < -180 then
				DiffYaw = DiffYaw + 360
			end
			
			if TargetSpeed > 285 and chb_blockbot_retreat:GetValue() then
				UserCmd:SetForwardMove(-math.abs(TargetSpeed))
			end
			
			if cob_blockbot_mode:GetValue() == 0 then
				if math.abs(DiffYaw) > 0.75 then
					UserCmd:SetSideMove(450 * -DiffYaw)
				end
			elseif cob_blockbot_mode:GetValue() == 1 then
				if DiffYaw > 0.25 then
					UserCmd:SetSideMove(-450)
				elseif DiffYaw < -0.25 then
					UserCmd:SetSideMove(450)
				end
			end
			
		end
		
	end
	
end

function handleGet(content)
	if (content == nil) then
		return
    end
	
	awusers = {}
	for stringindex in content:gmatch("([^\t]*)") do
		table.insert(awusers, stringindex)
	end
end

local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end

function urlencode(url) -- Straight up stolen from ShadyRetard, thanks for all the help.
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end

-- Had to add this because everyone is retarded
local function OnFrameWarning()
	if math.floor(common.Time()) % 2 > 0 then
		draw.Color(255, 255, 255, 255)
	else
		draw.Color(255, 0, 0, 255)
	end
	draw.SetFont(font_warning)
	draw.Text(0, 0, "[Lua Scripting] Please enable Lua HTTP and Lua script/config and reload script")
end

local function OnEventMain(GameEvent)
	
	if client.GetLocalPlayerIndex() == nil then
		return
	end
	
	local LocalSteamID = client.GetPlayerInfo(client.GetLocalPlayerIndex())["SteamID"]
	
	if GameEvent:GetName() == "round_prestart" then
		http.Get(app_awusers .. "?steamid=" .. urlencode(LocalSteamID), handleGet)
	end

end

if gui.GetValue("lua_allow_http") and gui.GetValue("lua_allow_cfg") then
	
	callbacks.Register("Draw", OnFrameMain)
	callbacks.Register("CreateMove", OnCreateMoveMain)
	callbacks.Register("FireGameEvent", OnEventMain)
	
	client.AllowListener("round_prestart")
else
	print("[Lua Scripting] Please enable Lua HTTP and Lua script/config and reload script")
end

--
--
-- End Blockbot.lua
--
--

if SenseUI ~= nil then
	return
end

local awrefer = gui.Reference("MISC", "General", "Main");
gui.Combobox(awrefer, "senseui_color", "Theme color", "Green", "Blue", "Red", "Purple", "Orange", "Pink");

SenseUI = {};
SenseUI.EnableLogs = false;

SenseUI.Keys = {
	esc = 27, f1 = 112, f2 = 113, f3 = 114, f4 = 115, f5 = 116,
	f6 = 117, f7 = 118, f8 = 119, f9 = 120, f10 = 121, f11 = 122,
	f12 = 123, tilde = 192, one = 49, two = 50, three = 51, four = 52,
	five = 53, six = 54, seven = 55, eight = 56, nine = 57, zero = 48,
	minus = 189, equals = 187, backslash = 220, backspace = 8,
	tab = 9, q = 81, w = 87, e = 69, r = 82, t = 84, y = 89, u = 85,
	i = 73, o = 79, p = 80, bracket_o = 219, bracket_c = 221,
	a = 65, s = 83, d = 68, f = 70, g = 71, h = 72, j = 74, k = 75,
	l = 76, semicolon = 186, quotes = 222, caps = 20, enter = 13,
	shift = 16, z = 90, x = 88, c = 67, v = 86, b = 66, n = 78,
	m = 77, comma = 188, dot = 190, slash = 191, ctrl = 17,
	win = 91, alt = 18, space = 32, scroll = 145, pause = 19,
	insert = 45, home = 36, pageup = 33, pagedn = 34, delete = 46,
	end_key = 35, uparrow = 38, leftarrow = 37, downarrow = 40, 
	rightarrow = 39, num = 144, num_slash = 111, num_mult = 106,
	num_sub = 109, num_7 = 103, num_8 = 104, num_9 = 105, num_plus = 107,
	num_4 = 100, num_5 = 101, num_6 = 102, num_1 = 97, num_2 = 98,
	num_3 = 99, num_enter = 13, num_0 = 96, num_dot = 110, mouse_1 = 1, mouse_2 = 2
};

SenseUI.KeyDetection = {
	always_on = 1,
	on_hotkey = 2,
	toggle = 3,
	off_hotkey = 4
};

SenseUI.Icons = {
	rage = { "C", 6 },
	legit = { "D", 5 },
	visuals = { "E", 4 },
	settings = { "F", 3 },
	skinchanger = { "G", 2 },
	playerlist = { "H", 1 },
	antiaim = { "I", 0 }
};

local gs_windows = {};		-- Contains all windows
local gs_curwindow = "";	-- Current window ID
local gs_curgroup = "";		-- Current group ID
local gs_curtab = "";		-- Current tab
local gs_curinput = "";		-- Current input

local gs_fonts = {
	verdana_12 		= draw.CreateFont( "Verdana", 12, 400 ),
	verdana_12b 	= draw.CreateFont( "Verdana", 12, 700 ),
	verdana_10 		= draw.CreateFont( "Verdana", 10, 400 ),
	astriumtabs		= draw.CreateFont( "Astriumtabs2", 41, 400 )
}

local gs_curchild = {
	id = "",
	x = 0,
	y = 0,
	elements = {},
	selected = {},
	multiselect = false,
	last_id = "",
	minimal_width = 0
};

local gs_isBlocked = false;

local gs_mx = 0;	-- Mouse X
local gs_my = 0;	-- Mouse Y

-- CUSTOM DRAWING --
local render = {};

render.outline = function( x, y, w, h, col )
	draw.Color( col[1], col[2], col[3], col[4] );
	draw.OutlinedRect( x, y, x + w, y + h );
end

render.rect = function( x, y, w, h, col )
	draw.Color( col[1], col[2], col[3], col[4] );
	draw.FilledRect( x, y, x + w, y + h );
end

render.rect2 = function( x, y, w, h )
	draw.FilledRect( x, y, x + w, y + h );
end

render.gradient = function( x, y, w, h, col1, col2, is_vertical )
	render.rect( x, y, w, h, col1 );

	local r, g, b = col2[1], col2[2], col2[3];

	if is_vertical then
		for i = 1, h do
			local a = i / h * 255;
			render.rect( x, y + i, w, 1, { r, g, b, a } );
		end
	else
		for i = 1, w do
			local a = i / w * 255;
			render.rect( x + i, y, 1, h, { r, g, b, a } );
		end
	end
end

render.text = function( x, y, text, col, font )
	if font ~= nil then
		draw.SetFont( font )
	else
		draw.SetFont( gs_fonts.verdana_12 )
	end

	draw.Color( col[1], col[2], col[3], col[4] );
	draw.Text( x, y, text );
end
-- CUSTOM DRAWING --

-- Needed for some actions
local function gs_clone( orig )
    return { table.unpack( orig ) };
end

-- Check if a and b in bounds
local function gs_inbounds( a, b, mina, minb, maxa, maxb )
	if a >= mina and a <= maxa and b >= minb and b <= maxb then
		return true;
	else
		return false;
	end
end

-- Get size of non-array table
local function gs_tablecount( T )
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

-- Just checks if logs are enabled
local function gs_log( text )
	if SenseUI.EnableLogs then
		print( text );
	end
end

-- Clamps value
local function gs_clamp( val, min, max )
	if val < min then return min end
	if val > max then return max end

	return val;
end

-- I'm too lazy to do shit what I moved into this func
local function gs_newelement()
	local wnd = gs_windows[gs_curwindow];
	local group = wnd.groups[gs_curgroup];

	return wnd, group;
end

-- Begins window
local function gs_beginwindow( id, x, y, w, h )
	-- Check values
	if id == nil or x < 0 or y < 0 or w < 0 or h < 25 then
		return false;
	end

	-- Check if we already have window with id
	local wnd = gs_windows[id];

	if wnd == nil then
		-- Create window
		wnd = {
			-- Position and size
			x  	= 0,
			y  	= 0,
			w  	= 0,
			h 	= 0,

			-- Needed to work
			is_opened = true,
			alpha = 255,
			dx = 0,
			dy = 0,
			drag = false,
			resize = false,
			dmx = 0,
			dmy = 0,
			tabs = {},
			groups = {},

			-- Settings
			is_movable = false,
			is_sizeable = false,
			open_key = nil,
			draw_texture = false
		};

		wnd.x = x;
		wnd.y = y;
		wnd.w = w;
		wnd.h = h;

		gs_windows[id] = wnd;

		gs_log( "Window " .. id .. " has been created" );
	end

	gs_curwindow = id;

	-- Backend
	if wnd.open_key ~= nil then
		-- Window toggle
		if input.IsButtonPressed( wnd.open_key ) then
			wnd.is_opened = not wnd.is_opened;
			gs_log( "Window " .. id .. " has been toggled" );
		end
	end

	-- Close animation
	local fade_factor = ((1.0 / 0.15) * globals.FrameTime()) * 255; -- Animation takes 150ms to finish. This helps to make it look the same on 200 fps and on 30fps

	if not wnd.is_opened and wnd.alpha ~= 0 then
		wnd.alpha = gs_clamp( wnd.alpha - fade_factor, 0, 255 );
	end

	-- Open animation
	if wnd.is_opened and wnd.alpha ~= 255 then
		wnd.alpha = gs_clamp( wnd.alpha + fade_factor, 0, 255 );
	end

	gs_windows[id] = wnd;

	-- Check if window opened
	if not wnd.is_opened and wnd.alpha == 0 then
		gs_curchild.id = "";
		gs_isBlocked = false;
		return false;
	end

	-- Movement
	if wnd.is_movable then
		-- If clicked and in bounds
		if input.IsButtonDown( 1 ) then
			gs_mx, gs_my = input.GetMousePos();

			if wnd.drag then
				wnd.x = gs_mx - wnd.dx;
				wnd.y = gs_my - wnd.dy;
				wnd.x2 = wnd.x + wnd.w;
				wnd.y2 = wnd.y + wnd.h;
			end

			if gs_inbounds( gs_mx, gs_my, wnd.x, wnd.y, wnd.x + wnd.w, wnd.y + 20 ) and wnd.h > 30 then
				wnd.drag = true;
				wnd.dx = gs_mx - wnd.x;
				wnd.dy = gs_my - wnd.y;
			end

			gs_windows[id] = wnd;
		else
			gs_windows[id].drag = false;
		end
	end

	local size_changing = false;

	if wnd.is_sizeable then
		-- If clicked and in bounds
		if input.IsButtonDown( 1 ) then
			gs_mx, gs_my = input.GetMousePos();

			if wnd.resize then
				wnd.w = gs_mx - wnd.dmx;
				wnd.h = gs_my - wnd.dmy;

				if wnd.w < 50 then
					wnd.w = 50;
				end

				if wnd.h < 50 then
					wnd.h = 50;
				end
			end

			if gs_inbounds( gs_mx, gs_my, wnd.x + wnd.w - 5, wnd.y + wnd.h - 5, wnd.x + wnd.w - 1, wnd.y + wnd.h - 1 ) then
				wnd.resize = true;
				size_changing = true;
				wnd.dmx = gs_mx - wnd.w;
				wnd.dmy = gs_my - wnd.h;
			end

			gs_windows[id] = wnd;
		else
			gs_windows[id].resize = false;
		end
	end

	-- Begin draw
	local lmd_outlinehelp = function( off, col )
		render.outline( wnd.x - off, wnd.y - off, wnd.w + off * 2, wnd.h + off * 2, col );
	end

	-- Window base
	render.rect( wnd.x, wnd.y, wnd.w, wnd.h, { 19, 19, 19, wnd.alpha } );

	if wnd.draw_texture then -- This thing is very shitty rn, waiting till polak will add textures into draw.
		draw.Color( 12, 12, 12, wnd.alpha );
		for i = 1, wnd.h, 4 do
			
			local y1 = wnd.y+i;
			local y2 = y1-2;
			
			for j=0, wnd.w, 4 do
				local x1 = wnd.x+j;
				render.rect2( x1 - 2, y1, 1, 3);
				render.rect2( x1 , y2, 1, 3);
			end
		end
	end

	-- Window border
	lmd_outlinehelp( 0, { 31, 31, 31, wnd.alpha } );

	if size_changing then
		lmd_outlinehelp( 1, { 149, 184, 6, wnd.alpha } );
	else
		lmd_outlinehelp( 1, { 60, 60, 60, wnd.alpha } );
	end

	lmd_outlinehelp( 2, { 40, 40, 40, wnd.alpha } );
	lmd_outlinehelp( 3, { 40, 40, 40, wnd.alpha } );
	lmd_outlinehelp( 4, { 40, 40, 40, wnd.alpha } );
	lmd_outlinehelp( 5, { 60, 60, 60, wnd.alpha } );
	lmd_outlinehelp( 6, { 31, 31, 31, wnd.alpha } );

	-- If sizeable, draw litte triangle
	if wnd.is_sizeable then
		if size_changing then
			render.rect( wnd.x + wnd.w - 5, wnd.y + wnd.h - 1, 5, 1, { 149, 184, 6, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 4, wnd.y + wnd.h - 2, 4, 1, { 149, 184, 6, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 3, wnd.y + wnd.h - 3, 3, 1, { 149, 184, 6, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 2, wnd.y + wnd.h - 4, 2, 1, { 149, 184, 6, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 1, wnd.y + wnd.h - 5, 1, 1, { 149, 184, 6, wnd.alpha } );
		else
			render.rect( wnd.x + wnd.w - 5, wnd.y + wnd.h - 1, 5, 1, { 60, 60, 60, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 4, wnd.y + wnd.h - 2, 4, 1, { 60, 60, 60, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 3, wnd.y + wnd.h - 3, 3, 1, { 60, 60, 60, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 2, wnd.y + wnd.h - 4, 2, 1, { 60, 60, 60, wnd.alpha } );
			render.rect( wnd.x + wnd.w - 1, wnd.y + wnd.h - 5, 1, 1, { 60, 60, 60, wnd.alpha } );
		end
	end

	return true;
end

local function gs_addgradient(  )
	local wnd = gs_windows[gs_curwindow];

	render.gradient( wnd.x, wnd.y, wnd.w / 2, 1, { 59, 175, 222, wnd.alpha }, { 202, 70, 205, wnd.alpha }, false );
	render.gradient( wnd.x + ( wnd.w / 2 ), wnd.y, wnd.w / 2, 1, { 202, 70, 205, wnd.alpha }, { 201, 227, 58, wnd.alpha }, false );
end

local function gs_endwindow(  )
	if gs_curchild.id ~= "" then
		gs_mx, gs_my = input.GetMousePos();

		local highest_w = 0;

		draw.SetFont( gs_fonts.verdana_12b );

		for i = 1, #gs_curchild.elements do
			local textw, texth = draw.GetTextSize( gs_curchild.elements[i] );

			if highest_w < textw then
				highest_w = textw;
			end
		end

		if highest_w < gs_curchild.minimal_width then
			highest_w = gs_curchild.minimal_width;
		end

		if input.IsButtonPressed( 1 ) and not gs_inbounds( gs_mx, gs_my, gs_curchild.x, gs_curchild.y - 20, gs_curchild.x + 20 + highest_w, gs_curchild.y + 20 * #gs_curchild.elements + #gs_curchild.elements ) then
			gs_curchild.id = "";
			gs_curchild.minimal_width = 0;
			gs_isBlocked = false;
		end

		render.rect( gs_curchild.x, gs_curchild.y, 20 + highest_w, 20 * #gs_curchild.elements + #gs_curchild.elements, { 36, 36, 36, 255 } );

		local text_offset = 0;

		for i = 1, #gs_curchild.elements do
			local r, g, b = 181, 181, 181;
			local speed = 3
			local fnt = gs_fonts.verdana_12;

			if gs_inbounds( gs_mx, gs_my, gs_curchild.x, gs_curchild.y + text_offset, gs_curchild.x + 20 + highest_w, gs_curchild.y + text_offset + 20 ) then
				if input.IsButtonPressed( 1 ) then
					if gs_curchild.multiselect then
						if gs_curchild.selected[gs_curchild.elements[i]] == nil then
							gs_curchild.selected[gs_curchild.elements[i]] = true;
						else
							if gs_curchild.selected[gs_curchild.elements[i]] then
								gs_curchild.selected[gs_curchild.elements[i]] = false;
							else
								gs_curchild.selected[gs_curchild.elements[i]] = true;
							end
						end
					else
						gs_curchild.selected = { i };
						gs_curchild.minimal_width = 0;
						gs_curchild.last_id = gs_curchild.id;
						gs_curchild.id = "";
						gs_isBlocked = false;
					end
				end

				render.rect( gs_curchild.x, gs_curchild.y + text_offset, 20 + highest_w, 21, { 28, 28, 28, 255 } );
				fnt = gs_fonts.verdana_12b;
			end
			
			local r12, g12, b12 = 149, 184, 6;
			if gui.GetValue("senseui_color") == 0 then
				r12, g12, b12 = 149, 184, 6;
			elseif gui.GetValue("senseui_color") == 1 then
				r12, g12, b12 = 6, 132, 182;
			elseif gui.GetValue("senseui_color") == 2 then
				r12, g12, b12 = 182, 6, 6;
			elseif gui.GetValue("senseui_color") == 3 then
				r12, g12, b12 = 146, 6, 182;
			elseif gui.GetValue("senseui_color") == 4 then
				r12, g12, b12 = 205, 107, 8;
			elseif gui.GetValue("senseui_color") == 5 then
				r12, g12, b12 = 214, 10, 193;
			end
			
			if not gs_curchild.multiselect then
				for k = 1, #gs_curchild.selected do
					if gs_curchild.selected[k] == i then
						if gui.GetValue("senseui_color") == 0 then
							r, g, b = 149, 184, 6;
						elseif gui.GetValue("senseui_color") == 1 then
							r, g, b = 6, 132, 182;
						elseif gui.GetValue("senseui_color") == 2 then
							r, g, b = 182, 6, 6;
						elseif gui.GetValue("senseui_color") == 3 then
							r, g, b = 146, 6, 182;
						elseif gui.GetValue("senseui_color") == 4 then
							r, g, b = 205, 107, 8;
						elseif gui.GetValue("senseui_color") == 5 then
							r, g, b = 214, 10, 193;
						end
						fnt = gs_fonts.verdana_12b;
					end
				end
			else
				if gs_curchild.selected[gs_curchild.elements[i]] ~= nil and gs_curchild.selected[gs_curchild.elements[i]] == true then
					if gui.GetValue("senseui_color") == 0 then
						r, g, b = 149, 184, 6;
					elseif gui.GetValue("senseui_color") == 1 then
						r, g, b = 6, 132, 182;
					elseif gui.GetValue("senseui_color") == 2 then
						r, g, b = 182, 6, 6;
					elseif gui.GetValue("senseui_color") == 3 then
						r, g, b = 146, 6, 182;
					elseif gui.GetValue("senseui_color") == 4 then
						r, g, b = 205, 107, 8;
					elseif gui.GetValue("senseui_color") == 5 then
						r, g, b = 214, 10, 193;
					end
					fnt = gs_fonts.verdana_12b;
				end
			end

			render.text( gs_curchild.x + 10, gs_curchild.y + text_offset + 4, gs_curchild.elements[i], { r, g, b, 255 }, fnt );

			text_offset = text_offset + 20 + 1;
		end

		render.outline( gs_curchild.x, gs_curchild.y, 20 + highest_w, 20 * #gs_curchild.elements + #gs_curchild.elements, { 5, 5, 5, 255 } );
	end

	gs_curwindow = "";
end

local function gs_setwindowmovable( val )
	if gs_windows[gs_curwindow].is_movable ~= val then
		gs_windows[gs_curwindow].is_movable = val;

		if val then val = "true" else val = "false" end
		gs_log("SetWindowMoveable has been set to " .. val);
	end
end

local function gs_setwindowsizeable( val )
	if gs_windows[gs_curwindow].is_sizeable ~= val then
		gs_windows[gs_curwindow].is_sizeable = val;

		if val then val = "true" else val = "false" end
		gs_log("SetWindowSizeable has been set to " .. val);
	end
end

local function gs_setwindowdrawtexture( val )
	if gs_windows[gs_curwindow].draw_texture ~= val then
		gs_windows[gs_curwindow].draw_texture = val;

		if val then val = "true" else val = "false" end
		gs_log("SetWindowDrawTexture has been set to " .. val);
	end
end

local function gs_setwindowopenkey( val )
	if gs_windows[gs_curwindow].open_key ~= val then
		gs_windows[gs_curwindow].open_key = val;

		local txt = "nil";

		if val ~= nil then
			txt = val;
		end

		gs_log("SetWindowOpenKey has been set to " .. txt);
	end
end

local function gs_begingroup( id, title, x, y, w, h )
	local wnd = gs_windows[gs_curwindow];
	local tab = wnd.tabs[gs_curtab];
	local tx = 0;

	if tab ~= nil then
		tx = 80;
	end

	-- Checks
	if id == nil then return false end

	-- Check if we already have window with id
	local group = wnd.groups[id];

	if group == nil then
		-- Create window
		group = {
			-- Position and size
			x  	= 0,
			y  	= 0,
			w  	= 0,
			h 	= 0,

			-- Other stuff
			title = nil,
			is_moveable = false,
			is_sizeable = false,

			-- Stuff needed to work
			is_nextline = true,
			nextline_offset = 15,
			dx = 0,
			dy = 0,
			drag = false,
			resize = false,
			highest_w = 0,
			highest_h = 0,
			last_y = 20
		};

		group.x = x + tx;
		group.y = y;
		group.w = w;
		group.h = h;

		group.title = title;

		wnd.groups[id] = group;

		gs_log( "Group " .. id .. " has been created" );
	end

	if group.x + wnd.x < wnd.x or group.y + wnd.y < wnd.y or wnd.x + group.x + group.w + 15 > wnd.x + wnd.w or wnd.y + group.y + group.h + 15 > wnd.y + wnd.h then
		return false;
	end

	gs_curgroup = id;

	draw.SetFont( gs_fonts.verdana_12b );
	local textw, texth = draw.GetTextSize( group.title );
	local oldw, oldh = draw.GetTextSize( title );
	local groupaftertext = group.w - 18 - textw - 3;
	local groupaftertext_n = group.w - 18 - oldw - 3;

	local size_changing = false;

	-- Movement
	if not gs_isBlocked then
		if group.is_moveable then
			-- If clicked and in bounds
			if input.IsButtonDown( 1 ) then
				gs_mx, gs_my = input.GetMousePos();

				if group.drag then
					group.x = gs_mx - group.dx;
					group.y = gs_my - group.dy;

					if group.x < 25 then
						group.x = 25;
					end

					if wnd.w < group.x + group.w + 25 then
						group.x = group.x - ((group.x + group.w + 25) - wnd.w);
					end

					if wnd.h < group.y + group.h + 25 then
						group.y = group.y - ((group.y + group.h + 25) - wnd.h);
					end

					if group.y < 25 then
						group.y = 25;
					end
				end

				if gs_inbounds( gs_mx, gs_my, wnd.x + group.x + 15, wnd.y + group.y, wnd.x + group.x + 15 + textw, wnd.y + group.y + texth ) and group.h > 30 then
					group.drag = true;
					size_changing = true;
					group.dx = gs_mx - group.x;
					group.dy = gs_my - group.y;
				end

				wnd.groups[id] = group;
			else
				wnd.groups[id].drag = false;
			end
		end

		if group.is_sizeable then
			-- If clicked and in bounds
			if input.IsButtonDown( 1 ) then
				gs_mx, gs_my = input.GetMousePos();

				if group.resize then
					group.w = gs_mx - group.dmx;
					group.h = gs_my - group.dmy;

					if group.w < 50 then
						group.w = 50;
					end

					if group.w < group.highest_w + 50 then
						group.w = group.highest_w + 50;
					end

					if group.h < 50 then
						group.h = 50;
					end

					if group.h < group.highest_h + 25 then
						group.h = group.highest_h + 25;
					end

					if group.w + group.x + 25 > wnd.w then
						group.w = group.w - ((group.w + group.x + 25) - wnd.w);
					end

					if group.h + group.y + 25 > wnd.h then
						group.h = group.h - ((group.h + group.y + 25) - wnd.h);
					end
				end

				if gs_inbounds( gs_mx, gs_my, wnd.x + group.x + group.w - 5, wnd.y + group.y + group.h - 5, wnd.x + group.x + group.w - 1, wnd.y + group.y + group.h - 1 )  then
					group.resize = true;
					size_changing = true;
					group.dmx = gs_mx - group.w;
					group.dmy = gs_my - group.h;
				end

				wnd.groups[id] = group;
			else
				wnd.groups[id].resize = false;
			end
		end
	end

	wnd.groups[id].highest_h = 0;

	-- Draw
	if groupaftertext_n > 15 then
		group.title = title;
	end

	-- Subtract title if width more than 15
	if groupaftertext < 15 then
		while groupaftertext < 15 do
			group.title = group.title:sub( 1, -2 );

			textw, texth = draw.GetTextSize( group.title );
			groupaftertext = w - 18 - textw - 3;
		end

		group.title = group.title:sub( 1, -5 );
		group.title = group.title .. "...";
	end

	local r, g, b = 65, 65, 65;

	if size_changing then
		r, g, b = 149, 184, 6;
	end

	render.rect( wnd.x + group.x, wnd.y + group.y, group.w, group.h, { 19, 19, 19, wnd.alpha } );

	render.rect( wnd.x + group.x, wnd.y + group.y, 1, group.h, { r, g, b, wnd.alpha } );
	render.rect( wnd.x + group.x - 1, wnd.y + group.y - 1, 1, group.h + 2, { 5, 5, 5, wnd.alpha } );

	render.rect( wnd.x + group.x, wnd.y + group.y + group.h, group.w + 1, 1, { r, g, b, wnd.alpha } );
	render.rect( wnd.x + group.x - 1, wnd.y + group.y + group.h + 1, group.w + 3, 1, { 5, 5, 5, wnd.alpha } );

	render.rect( wnd.x + group.x + group.w, wnd.y + group.y, 1, group.h, { r, g, b, wnd.alpha } );
	render.rect( wnd.x + group.x + group.w + 1, wnd.y + group.y - 1, 1, group.h + 2, { 5, 5, 5, wnd.alpha } );

	if group.title ~= nil and groupaftertext >= 15 then
		render.rect( wnd.x + group.x, wnd.y + group.y, 15, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + 1, wnd.y + group.y - 1, 14, 1, { 5, 5, 5, wnd.alpha } );

		if size_changing then
			render.text( wnd.x + group.x + 18, wnd.y + group.y - 6, group.title, { r, g, b, wnd.alpha }, gs_fonts.verdana_12b );
		else
			render.text( wnd.x + group.x + 18, wnd.y + group.y - 6, group.title, { 181, 181, 181, wnd.alpha }, gs_fonts.verdana_12b );
		end

		render.rect( wnd.x + group.x + 18 + textw + 3, wnd.y + group.y, groupaftertext, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + 18 + textw + 3, wnd.y + group.y - 1, groupaftertext + 1, 1, { 5, 5, 5, wnd.alpha } );
	else
		render.rect( wnd.x + group.x, wnd.y + group.y, group.w, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + 1, wnd.y + group.y - 1, group.w + 1, 1, { 5, 5, 5, wnd.alpha } );
	end

	-- If sizeable, draw litte triangle
	if group.is_sizeable then
		render.rect( wnd.x + group.x + group.w - 5, wnd.y + group.y + group.h - 1, 5, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + group.w - 4, wnd.y + group.y + group.h - 2, 4, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + group.w - 3, wnd.y + group.y + group.h - 3, 3, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + group.w - 2, wnd.y + group.y + group.h - 4, 2, 1, { r, g, b, wnd.alpha } );
		render.rect( wnd.x + group.x + group.w - 1, wnd.y + group.y + group.h - 5, 1, 1, { r, g, b, wnd.alpha } );
	end

	return true;
end

local function gs_endgroup(  )
	local wnd = gs_windows[gs_curwindow];
	local group = wnd.groups[gs_curgroup];

	if group.w + group.x + 25 > wnd.w then
		group.w = gs_clamp( group.w - ((group.w + group.x + 25) - wnd.w), 50, wnd.w - 50 );
	end

	if group.h + group.y + 25 > wnd.h then
		group.h = gs_clamp( group.h - ((group.h + group.y + 25) - wnd.h), 50, wnd.h - 50 );
	end

	if wnd.x + wnd.w < wnd.x + group.x + group.w + 25 then
		group.x = group.x - ((group.x + group.w + 25) - wnd.w);
	end

	if wnd.y + wnd.h < wnd.y + group.y + group.h + 25 then
		group.y = group.y - ((group.y + group.h + 25) - wnd.h);
	end

	if group.x < 25 then
		group.x = 25;
	end

	if group.y < 25 then
		group.y = 25;
	end

	if group.is_sizeable then
		if group.w < group.highest_w + 50 then
			group.w = group.highest_w + 50;
		end

		if group.h < group.highest_h + 25 then
			group.h = group.highest_h + 25;
		end

		if group.h + 15 < group.x + group.nextline_offset then
			group.h = group.nextline_offset + 15;
		end
	end

	wnd.groups[gs_curgroup] = group;

	wnd.groups[gs_curgroup].nextline_offset = 15;
	wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].highest_h + 20;
	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].last_y = 20;

	gs_curgroup = "";
end

local function gs_setgroupmoveable( val )
	local wnd = gs_windows[gs_curwindow];

	if wnd.groups[gs_curgroup].is_moveable ~= val then
		wnd.groups[gs_curgroup].is_moveable = val;

		if val then val = "true" else val = "false" end
		gs_log("SetGroupMoveable has been set to " .. val);
	end
end

local function gs_setgroupsizeable( val )
	local wnd = gs_windows[gs_curwindow];

	if wnd.groups[gs_curgroup].is_sizeable ~= val then
		wnd.groups[gs_curgroup].is_sizeable = val;

		if val then val = "true" else val = "false" end
		gs_log("SetGroupSizeable has been set to " .. val);
	end
end

local function gs_checkbox( title, var , is_alt)
	local wnd, group = gs_newelement();

	local textw, texth = draw.GetTextSize( title );
	local x, y = wnd.x + group.x + 10, wnd.y + group.y + group.nextline_offset;

	-- Backend
	if input.IsButtonPressed( 1 ) and gs_inbounds( gs_mx, gs_my, x, y, x + 15 + textw, y + texth ) and not gs_isBlocked then
		-- Update value
		var = not var;
	end

	-- Draw
	render.outline( x, y, 8, 8, { 5, 5, 5, wnd.alpha } );
	
	local r12, g12, b12 = 149, 184, 6;
	if gui.GetValue("senseui_color") == 0 then
		r12, g12, b12 = 149, 184, 6;
	elseif gui.GetValue("senseui_color") == 1 then
		r12, g12, b12 = 6, 132, 182;
	elseif gui.GetValue("senseui_color") == 2 then
		r12, g12, b12 = 182, 6, 6;
	elseif gui.GetValue("senseui_color") == 3 then
		r12, g12, b12 = 146, 6, 182;
	elseif gui.GetValue("senseui_color") == 4 then
		r12, g12, b12 = 205, 107, 8;
	elseif gui.GetValue("senseui_color") == 5 then
		r12, g12, b12 = 214, 10, 193;
	end
	
	local r11, g11, b11 = 80, 99, 3;
	if gui.GetValue("senseui_color") == 0 then
		r11, g11, b11 = 80, 99, 3;
	elseif gui.GetValue("senseui_color") == 1 then
		r11, g11, b11 = 3, 79, 98;
	elseif gui.GetValue("senseui_color") == 2 then
		r11, g11, b11 = 98, 3, 3;
	elseif gui.GetValue("senseui_color") == 3 then
		r11, g11, b11 = 68, 3, 98;
	elseif gui.GetValue("senseui_color") == 4 then
		r11, g11, b11 = 123, 57, 4;
	elseif gui.GetValue("senseui_color") == 5 then
		r11, g11, b11 = 112, 4, 94;
	end
	
	if var then
		render.gradient( x + 1, y + 1, 6, 5, { r12, g12, b12, wnd.alpha }, { r11, g11, b11, wnd.alpha }, true );
	else
		render.gradient( x + 1, y + 1, 6, 5, { 65, 65, 65, wnd.alpha }, { 45, 45, 45, wnd.alpha }, true );
	end
	
	local r1, g1, b1 = 181, 181, 181;
	
	if is_alt then
		r1, g1, b1 = 190, 190, 110;
	end
	
	render.text( x + 13, y - 3, title, { r1, g1, b1, wnd.alpha } );

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + 17;

	if group.highest_w < 15 + textw then
		wnd.groups[gs_curgroup].highest_w = 15 + textw;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	return var;
end

local function gs_button( title, w, h )
	local wnd, group = gs_newelement();

	local textw, texth = draw.GetTextSize( title );
	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset;

	-- Backend
	local var = false;

	if input.IsButtonDown( 1 ) and gs_inbounds( gs_mx, gs_my, x, y, x + w, y + h ) and not gs_isBlocked then
		var = true;
	end

	-- Draw
	render.outline( x, y, w, h, { 5, 5, 5, wnd.alpha } );
	render.outline( x + 1, y + 1, w - 2, h - 2, { 65, 65, 65, wnd.alpha } );

	local r, g, b = 181, 181, 181;

	if var then
		r, g, b = 255, 255, 255;
		render.gradient( x + 2, y + 2, w - 4, h - 5, { 45, 45, 45, wnd.alpha }, { 55, 55, 55, wnd.alpha }, true );
	else
		render.gradient( x + 2, y + 2, w - 4, h - 5, { 55, 55, 55, wnd.alpha }, { 45, 45, 45, wnd.alpha }, true );
	end

	render.text( x + (w / 2 - textw / 2), y + (h / 2 - texth / 2), title, { r, g, b, wnd.alpha }, gs_fonts.verdana_12b );

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + h + 5;

	if group.highest_w < w then
		wnd.groups[gs_curgroup].highest_w = w;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	return var;
end

local function gs_slider( title, min, max, fmt, min_text, max_text, show_buttons, var )
	local wnd, group = gs_newelement();

	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset - 3;
	local textw, texth = 0, 0;

	gs_mx, gs_my = input.GetMousePos();

	if title ~= nil then
		textw, texth = draw.GetTextSize( title );
		texth = texth + 2;
	end

	-- Backend
	local m = 0;

	if min ~= 0 then
		m = min;

		var = var - m;
		min = min - m;
		max = max - m;
	end

	if not gs_isBlocked then
		if input.IsButtonDown( 1 ) and gs_inbounds( gs_mx, gs_my, x, y + texth, x + 155, y + texth + 8 ) then
			local relative_x = gs_clamp( gs_mx - x, 0, 153 );
			local ratio = relative_x / 153;

			var = math.floor( min + ((max - min) * ratio) );
		end

		-- Handle -/+ buttons
		if input.IsButtonPressed( 1 ) and gs_inbounds( gs_mx, gs_my, x - 5, y + texth + 1, x - 2, y + texth + 4 ) and show_buttons then
			var = var - 1;
		end

		if input.IsButtonPressed( 1 ) and gs_inbounds( gs_mx, gs_my, x + 155 + 2, y + texth + 1, x + 155 + 5, y + texth + 4 ) and show_buttons then
			var = var + 1;
		end
	end

	-- Clamp final value
	var = math.ceil( gs_clamp( var, min, max ) );

	local w = 153 / max * var;

	var = var + m;
	min = min + m;
	max = max + m;

	-- Draw
	if title ~= nil then
		render.text( x, y - 2, title, { 181, 181, 181, wnd.alpha } );
	end
	
	local r12, g12, b12 = 149, 184, 6;
	if gui.GetValue("senseui_color") == 0 then
		r12, g12, b12 = 149, 184, 6;
	elseif gui.GetValue("senseui_color") == 1 then
		r12, g12, b12 = 6, 132, 182;
	elseif gui.GetValue("senseui_color") == 2 then
		r12, g12, b12 = 182, 6, 6;
	elseif gui.GetValue("senseui_color") == 3 then
		r12, g12, b12 = 146, 6, 182;
	elseif gui.GetValue("senseui_color") == 4 then
		r12, g12, b12 = 205, 107, 8;
	elseif gui.GetValue("senseui_color") == 5 then
		r12, g12, b12 = 214, 10, 193;
	end
	
	local r11, g11, b11 = 80, 99, 3;
	if gui.GetValue("senseui_color") == 0 then
		r11, g11, b11 = 80, 99, 3;
	elseif gui.GetValue("senseui_color") == 1 then
		r11, g11, b11 = 3, 79, 98;
	elseif gui.GetValue("senseui_color") == 2 then
		r11, g11, b11 = 98, 3, 3;
	elseif gui.GetValue("senseui_color") == 3 then
		r11, g11, b11 = 68, 3, 98;
	elseif gui.GetValue("senseui_color") == 4 then
		r11, g11, b11 = 123, 57, 4;
	elseif gui.GetValue("senseui_color") == 5 then
		r11, g11, b11 = 112, 4, 94;
	end
	
	render.outline( x, y + texth, 155, 4, { 5, 5, 5, wnd.alpha } );
	render.gradient( x + 1, y + texth + 1, 153, 4, { 45, 45, 45, wnd.alpha }, { 65, 65, 65, wnd.alpha }, true );
	render.gradient( x + 1, y + texth + 1, w, 4, { r12, g12, b12, wnd.alpha }, { r11, g11, b11, wnd.alpha }, true );

	if show_buttons then
		if var ~= min then
			render.rect( x - 5, y + texth + 3, 3, 1, { 181, 181, 181, wnd.alpha } );
		end

		if var ~= max then
			render.rect( x + 155 + 2, y + texth + 3, 3, 1, { 181, 181, 181, wnd.alpha } );
			render.rect( x + 155 + 3, y + texth + 2, 1, 3, { 181, 181, 181, wnd.alpha } );
		end
	end

	local vard = var;

	if fmt ~= nil then
		vard = vard .. fmt;
	end

	if min_text ~= nil and var == min then
		vard = min_text;
	end

	if max_text ~= nil and var == max then
		vard = max_text;
	end

	draw.SetFont( gs_fonts.verdana_12b );
	local varw, varh = draw.GetTextSize( vard );

	render.text( x + w - varw / 2, y + texth + varh / 6, vard, { 181, 181, 181, wnd.alpha }, gs_fonts.verdana_12b );

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + texth + 14;

	if group.highest_w < 155 then
		wnd.groups[gs_curgroup].highest_w = 155;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	return var;
end

local function gs_label( text, is_alt )
	local wnd, group = gs_newelement();

	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset - 3;
	local textw, texth = draw.GetTextSize( text );
	local r, g, b = 181, 181, 181;

	if is_alt then
		r, g, b = 190, 190, 120;
	end

	render.text( x, y, text, { r, g, b, wnd.alpha } );

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + 17;

	if group.highest_w < textw then
		wnd.groups[gs_curgroup].highest_w = textw;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;
end

local gs_curbind = {
	id = "",
	is_selecting = false
};

local gs_keytable = {
	esc = { 27, "[ESC]" }, f1 = { 112, "[F1]" }, f2 = { 113, "[F2]" }, f3 = { 114, "[F3]" }, f4 = { 115, "[F4]" }, f5 = { 116, "[F5]" },
	f6 = { 117, "[F6]" }, f7 = { 118, "[F7]" }, f8 = { 119, "[F8]" }, f9 = { 120, "[F9]" }, f10 = { 121, "[F10]" }, f11 = { 122, "[F11]" },
	f12 = { 123, "[F12]" }, tilde = { 192, "[~]" }, one = { 49, "[1]" }, two = { 50, "[2]" }, three = { 51, "[3]" }, four = { 52, "[4]" },
	five = { 53, "[5]" }, six = { 54, "[6]" }, seven = { 55, "[7]" }, eight = { 56, "[8]" }, nine = { 57, "[9]" }, zero = { 48, "[0]" },
	minus = { 189, "[_]" }, equals = { 187, "[=]" }, backslash = { 220, "[\\]" }, backspace = { 8, "[BKSP]" },
	tab = { 9, "[TAB]" }, q = { 81, "[Q]" }, w = { 87, "[W]" }, e = { 69, "[E]" }, r = { 82, "[R]" }, t = { 84, "[T]" }, y = { 89, "[Y]" }, u = { 85, "[U]" },
	i = { 73, "[I]" }, o = { 79, "[O]" }, p = { 80, "[P]" }, bracket_o = { 219, "[[]" }, bracket_c = { 221, "[]]" },
	a = { 65, "[A]" }, s = { 83, "[S]" }, d = { 68, "[D]" }, f = { 70, "[F]" }, g = { 71, "[G]" }, h = { 72, "[H]" }, j = { 74, "[J]" }, k = { 75, "[K]" },
	l = { 76, "[L]" }, semicolon = { 186, "[;]" }, quotes = { 222, "[']" }, caps = { 20, "[CAPS]" }, enter = { 13, "[RETN]" },
	shift = { 16, "[SHI]" }, z = { 90, "[Z]" }, x = { 88, "[X]" }, c = { 67, "[C]" }, v = { 86, "[V]" }, b = { 66, "[B]" }, n = { 78, "[N]" },
	m = { 77, "[M]" }, comma = { 188, "[,]" }, dot = { 190, "[.]" }, slash = { 191, "[/]" }, ctrl = { 17, "[CTRL]" },
	win = { 91, "[WIN]" }, alt = { 18, "[ALT]" }, space = { 32, "[SPC]" }, scroll = { 145, "[SCRL]" }, pause = { 19, "[PAUS]" },
	insert = { 45, "[INS]" }, home = { 36, "[HOME]" }, pageup = { 33, "[PGUP]" }, pagedn = { 34, "[PGDN]" }, delete = { 46, "[DEL]" },
	end_key = { 35, "[END]" }, uparrow = { 38, "[UP]" }, leftarrow = { 37, "[LEFT]" }, downarrow = { 40, "[DOWN]" }, 
	rightarrow = { 39, "[RGHT]" }, num = { 144, "[NUM]" }, num_slash = { 111, "[/]" }, num_mult = { 106, "[*]" },
	num_sub = { 109, "[-]" }, num_7 = { 103, "[7]" }, num_8 = { 104, "[8]" }, num_9 = { 105, "[9]" }, num_plus = { 107, "[+]" },
	num_4 = { 100, "[4]" }, num_5 = { 101, "[5]" }, num_6 = { 102, "[6]" }, num_1 = { 97, "[1]" }, num_2 = { 98, "[2]" },
	num_3 = { 99, "[3]" }, num_enter = { 13, "[ENT]" }, num_0 = { 96, "[0]" }, num_dot = { 110, "[.]" }, mouse_1 = { 1, "[M1]" }, mouse_2 = { 2, "[M2]" }
};

local function gs_key2name( key )
	local ktxt = "[-]";

	for k, v in pairs( gs_keytable ) do
		if v[1] == key then
			ktxt = v[2];
		end
	end

	return ktxt;
end

local function gs_bind( id, detect_editable, var, key_held, detect_type )
	local wnd, group = gs_newelement();

	local x, y = wnd.x + group.x + group.w - 10, group.last_y;
	local r, g, b = 96, 96, 96;

	if gs_curbind.id == id then
		if gs_curbind.is_selecting then
			r, g, b = 255, 0, 0;
		end
	end

	local did_select = false;

	-- Backend
	if gs_curbind.id == id and gs_curbind.is_selecting and not gs_isBlocked then
		for k, v in pairs( SenseUI.Keys ) do
			if input.IsButtonPressed( v ) and v ~= SenseUI.Keys.esc then
				var = v;
				gs_curbind.is_selecting = false;

				did_select = true;
				break;
			else 
				if input.IsButtonPressed( v ) and v == SenseUI.Keys.esc then
					var = nil;
					gs_curbind.is_selecting = false;

					did_select = true;
					break;
				end
			end
		end

		if not did_select then
			gs_curbind.is_selecting = true;
		end
	end

	local text = gs_key2name( var );

	draw.SetFont( gs_fonts.verdana_10 );
	local textw, texth = draw.GetTextSize( text );

	x = x - textw;

	gs_mx, gs_my = input.GetMousePos();

	if input.IsButtonPressed( 1 ) then
		if gs_inbounds( gs_mx, gs_my, x, y, x + textw, y + texth ) then
			gs_curbind.id = id;
			gs_curbind.is_selecting = true;
		end
	end

	if input.IsButtonPressed( 2 ) and detect_editable and not gs_isBlocked then
		if not gs_curbind.is_selecting then
			if gs_inbounds( gs_mx, gs_my, x, y, x + textw, y + texth ) then
				gs_curchild.minimal_width = 0;
				gs_curchild.id = id .. "_child";
				gs_curchild.x = x;
				gs_curchild.multiselect = false;
				gs_curchild.y = y + texth + 2;
				gs_curchild.elements = { "Always on", "On hotkey", "Toggle", "Off hotkey" };
				gs_curchild.selected = { detect_type };
				gs_isBlocked = true;
			end
		end
	end

	if gs_curchild.last_id == id .. "_child" then
		detect_type = gs_curchild.selected[1];
	end

	local held_done = false;

	if detect_type == 3 or detect_type == 1 then
		held_done = true;
	end

	if var ~= nil and var ~= 0 then
		if detect_type == 2 and input.IsButtonDown( var ) then
			held_done = true;
			key_held = true;
		end

		if detect_type == 4 and input.IsButtonDown( var ) then
			held_done = true;
			key_held = false;
		end

		if detect_type == 3 and input.IsButtonPressed( var ) then
			key_held = not key_held;
		end

		if detect_type == 1 then
			key_held = true;
		end

		if not held_done then
			if detect_type ~= 4 then
				key_held = false;
			else
				key_held = true;
			end
		end
	end

	-- Draw
	render.text( x, y, text, { r, g, b, wnd.alpha }, gs_fonts.verdana_10 );

	return var, key_held, detect_type;
end

function gs_drawtabbar( )
	local wnd = gs_newelement();
	local tab = nil;

	for k, v in pairs( wnd.tabs ) do
		if v.selected then
			tab = v;
		end
	end

	if tab ~= nil then
		local tabNumeric = 0;

		for k, v in pairs( wnd.tabs ) do
			if v.id == tab.id then
				tabNumeric = v.numID;
			end
		end

		render.rect( wnd.x, wnd.y, 79, 24 + tabNumeric * 80, { 12, 12, 12, wnd.alpha } );
		render.rect( wnd.x, wnd.y + 24 + (tabNumeric + 1) * 80, 79, wnd.h - (24 + (tabNumeric + 1) * 80), { 12, 12, 12, wnd.alpha } );

		render.rect( wnd.x + 80, wnd.y, 1, 25 + tabNumeric * 80, { 75, 75, 75, wnd.alpha } );
		render.rect( wnd.x, wnd.y + 25 + tabNumeric * 80, 81, 1, { 75, 75, 75, wnd.alpha } );
		render.rect( wnd.x, wnd.y + 25 + (tabNumeric + 1) * 80, 80, 1, { 75, 75, 75, wnd.alpha } );
		render.rect( wnd.x + 80, wnd.y + 25 + (tabNumeric + 1) * 80, 1, wnd.h - (25 + (tabNumeric + 1) * 80), { 75, 75, 75, wnd.alpha } );
	end
end

function gs_begintab( id, icon )
	local wnd = gs_newelement();

	if wnd.tabs[id] == nil then
		local gs_tab = {
			id = "",
			icon = "",
			numID = 0,

			selected = false,

			groups = {}
		};

		gs_tab.id = id;
		gs_tab.icon = icon;
		gs_tab.numID = gs_tablecount( wnd.tabs );

		wnd.tabs[id] = gs_tab;
	end

	gs_curtab = id;

	local tab = wnd.tabs[gs_curtab];

	-- Backend

	local r, g, b = 90, 90, 90;
	if tab.selected then
		r, g, b = 210, 210, 210;
	end

	local tabNumeric = 0;

	for k, v in pairs( wnd.tabs ) do
		if v.id == id then
			tabNumeric = v.numID;
		end
	end

	gs_mx, gs_my = input.GetMousePos();
	if gs_inbounds( gs_mx, gs_my, wnd.x, wnd.y + (25 + tabNumeric * 80), wnd.x + 80, wnd.y + (25 + tabNumeric * 80) + 80 ) and not gs_isBlocked then
		r, g, b = 210, 210, 210;

		if input.IsButtonPressed( 1 ) then
			for k, v in pairs( wnd.tabs ) do
				wnd.tabs[k].selected = false;

				if v.id == id then
					wnd.tabs[k].selected = true;
				end
			end
		end
	end

	-- Draw

	draw.SetFont( gs_fonts.astriumtabs );
	local textw, texth = draw.GetTextSize( tab.icon[1] );

	render.text( wnd.x + (40 - textw / 2), wnd.y + (25 + tabNumeric * 80) + (40 - texth / 2) - tab.icon[2], tab.icon[1], { r, g, b, wnd.alpha }, gs_fonts.astriumtabs );

	return tab.selected;
end

local function gs_endtab( )
	local wnd = gs_newelement();
	local smthselected = false;

	for k, v in pairs( wnd.tabs ) do
		if v.selected then
			smthselected = true;
			break;
		end
	end

	if not smthselected then
		wnd.tabs[gs_curtab].selected = true;
	end

	gs_curtab = "";
end

local function gs_combo( title, elements, var )
	local wnd, group = gs_newelement();
	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset - 3;
	local bg_col = { 26, 26, 26, wnd.alpha };
	local textw, texth = 0, 0;

	if title ~= nil then
		draw.GetTextSize( title );
	end

	local is_up = false;

	local ltitle = elements[1] .. var;

	if title ~= nil then
		ltitle = title;
	end

	-- Backend
	gs_mx, gs_my = input.GetMousePos();
	if gs_inbounds( gs_mx, gs_my, x, y + texth + 2, x + 155, y + texth + 22 ) and not gs_isBlocked then
		bg_col = { 36, 36, 36, wnd.alpha };

		if input.IsButtonPressed( 1 ) then
			gs_curchild.id = ltitle .. "_child";
			gs_curchild.x = x;
			gs_curchild.y = y + texth + 22;
			gs_curchild.minimal_width = 135;
			gs_curchild.multiselect = false;
			gs_curchild.elements = elements;
			gs_curchild.selected = { var };
			gs_isBlocked = true;
		end
	end

	if gs_curchild.id == ltitle .. "_child" then
		is_up = true;
	end

	if gs_curchild.last_id == ltitle .. "_child" then
		var = gs_curchild.selected[1];
		gs_curchild.last_id = "";
	end

	-- Drawing
	if title ~= nil then
		render.text( x, y, title, { 181, 181, 181, wnd.alpha } );
	end

	render.gradient( x, y + texth + 2, 155, 19, bg_col, { 36, 36, 36, wnd.alpha }, true );
	render.outline( x, y + texth + 2, 155, 20, { 5, 5, 5, wnd.alpha } );

	render.text( x + 10, y + 6 + texth , elements[var], { 181, 181, 181, wnd.alpha } );

	if not is_up then
		render.rect( x + 150 - 9, y + texth + 11, 5, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 8, y + texth + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 7, y + texth + 13, 1, 1, { 181, 181, 181, wnd.alpha } );
	else
		render.rect( x + 150 - 7, y + texth + 11, 1, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 8, y + texth + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 9, y + texth + 13, 5, 1, { 181, 181, 181, wnd.alpha } );
	end

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + texth + 27;

	if group.highest_w < 155 then
		wnd.groups[gs_curgroup].highest_w = 155;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	return var;
end

local function gs_multicombo( title, elements, var )
	local wnd, group = gs_newelement();
	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset - 3;
	local bg_col = { 26, 26, 26, wnd.alpha };
	local textw, texth = draw.GetTextSize( title );
	local is_up = false;

	-- Backend
	gs_mx, gs_my = input.GetMousePos();
	if gs_inbounds( gs_mx, gs_my, x, y + texth + 2, x + 155, y + texth + 22 ) and not gs_isBlocked then
		bg_col = { 36, 36, 36, wnd.alpha };

		if input.IsButtonPressed( 1 ) then
			gs_curchild.id = title .. "_child";
			gs_curchild.x = x;
			gs_curchild.y = y + texth + 22;
			gs_curchild.minimal_width = 135;
			gs_curchild.multiselect = true;
			gs_curchild.elements = elements;
			gs_curchild.selected = var;
			gs_isBlocked = true;
		end
	end

	if gs_curchild.id == title .. "_child" then
		is_up = true;
	end

	if gs_curchild.last_id == title .. "_child" then
		var = gs_curchild.selected;
		gs_curchild.last_id = "";
	end

	-- Drawing
	render.text( x, y, title, { 181, 181, 181, wnd.alpha } );

	render.gradient( x, y + texth + 2, 155, 19, bg_col, { 36, 36, 36, wnd.alpha }, true );
	render.outline( x, y + texth + 2, 155, 20, { 5, 5, 5, wnd.alpha } );

	local fmt = "";
	for i = 1, #elements do
		local f_len = #fmt < 16;
		local f_frst = #fmt <= 0;

		if var[elements[i]] and f_len then
			if not f_frst then
				fmt = fmt .. ", ";
			end

			fmt = fmt .. elements[i];
		else
			if not f_len then
				local selected = 0;

				for k = 1, #elements do
					if var[elements[k]] then
						selected = selected + 1;
					end
				end

				fmt = selected .. " selected";
				break;
			end
		end
	end

	if fmt == "" then
		fmt = "-";
	end

	render.text( x + 10, y + 6 + texth , fmt, { 181, 181, 181, wnd.alpha } );

	if not is_up then
		render.rect( x + 150 - 9, y + texth + 11, 5, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 8, y + texth + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 7, y + texth + 13, 1, 1, { 181, 181, 181, wnd.alpha } );
	else
		render.rect( x + 150 - 7, y + texth + 11, 1, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 8, y + texth + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
		render.rect( x + 150 - 9, y + texth + 13, 5, 1, { 181, 181, 181, wnd.alpha } );
	end

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + texth + 27;

	if group.highest_w < 155 then
		wnd.groups[gs_curgroup].highest_w = 155;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	return var;
end

-- it's like
-- [ normal, with shift ]
local gs_textTable = {
	[SenseUI.Keys.tilde] = { "`", "~" },
	[SenseUI.Keys.one] = { "1", "!" },
	[SenseUI.Keys.two] = { "2", "@" },
	[SenseUI.Keys.three] = { "3", "#" },
	[SenseUI.Keys.four] = { "4", "$" },
	[SenseUI.Keys.five] = { "5", "%" },
	[SenseUI.Keys.six] = { "6", "^" },
	[SenseUI.Keys.seven] = { "7", "&" },
	[SenseUI.Keys.eight] = { "8", "*" },
	[SenseUI.Keys.nine] = { "9", "(" },
	[SenseUI.Keys.zero] = { "0", ")" },
	[SenseUI.Keys.minus] = { "-", "_" },
	[SenseUI.Keys.equals] = { "=", "+" },
	[SenseUI.Keys.backslash] = { "\\", "|" },
	[SenseUI.Keys.q] = { "q", "Q" },
	[SenseUI.Keys.w] = { "w", "W" },
	[SenseUI.Keys.e] = { "e", "E" },
	[SenseUI.Keys.r] = { "r", "R" },
	[SenseUI.Keys.t] = { "t", "T" },
	[SenseUI.Keys.y] = { "y", "Y" },
	[SenseUI.Keys.u] = { "u", "U" },
	[SenseUI.Keys.i] = { "i", "I" },
	[SenseUI.Keys.o] = { "o", "O" },
	[SenseUI.Keys.p] = { "p", "P" },
	[SenseUI.Keys.bracket_o] = { "[", "{" },
	[SenseUI.Keys.bracket_c] = { "]", "}" },
	[SenseUI.Keys.a] = { "a", "A" },
	[SenseUI.Keys.s] = { "s", "S" },
	[SenseUI.Keys.d] = { "d", "D" },
	[SenseUI.Keys.f] = { "f", "F" },
	[SenseUI.Keys.g] = { "g", "G" },
	[SenseUI.Keys.h] = { "h", "H" },
	[SenseUI.Keys.j] = { "j", "J" },
	[SenseUI.Keys.k] = { "k", "K" },
	[SenseUI.Keys.l] = { "l", "L" },
	[SenseUI.Keys.semicolon] = { ";", ":" },
	[SenseUI.Keys.quotes] = { "'", "\"" },
	[SenseUI.Keys.z] = { "z", "Z" },
	[SenseUI.Keys.x] = { "x", "X" },
	[SenseUI.Keys.c] = { "c", "C" },
	[SenseUI.Keys.v] = { "v", "V" },
	[SenseUI.Keys.b] = { "b", "B" },
	[SenseUI.Keys.n] = { "n", "N" },
	[SenseUI.Keys.m] = { "m", "M" },
	[SenseUI.Keys.comma] = { ",", "<" },
	[SenseUI.Keys.dot] = { ".", ">" },
	[SenseUI.Keys.slash] = { "/", "?" },
	[SenseUI.Keys.space] = { " ", " " }
};

local function gs_listbox( elements, maxElements, showSearch, var, searchVar, scrollVar )
	local wnd, group = gs_newelement();
	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset - 3;

	if showSearch then
		render.outline( x, y, 155, 20, { 5, 5, 5, wnd.alpha } );
		render.outline( x + 1, y + 1, 153, 18, { 28, 28, 28, wnd.alpha } );
		render.rect( x + 2, y + 2, 151, 16, { 36, 36, 36, wnd.alpha } );

		gs_mx, gs_my = input.GetMousePos();
		if input.IsButtonDown( 1 ) then
			if gs_inbounds( gs_mx, gs_my, x, y, x + 155, y + 20 ) then
				gs_curinput = elements[1] .. maxElements .. var .. elements[#elements];
				gs_isBlocked = true;
			elseif not gs_inbounds( gs_mx, gs_my, x, y, x + 155, y + 20 ) and gs_curinput == elements[1] .. maxElements .. var .. elements[#elements] then
				gs_curinput = "";
				gs_isBlocked = false;
			end
		end

		if gs_curinput == elements[1] .. maxElements .. var .. elements[#elements] then
			if input.IsButtonPressed( SenseUI.Keys.esc ) then
				gs_curinput = "";
				gs_isBlocked = false;
			end

			if input.IsButtonPressed( SenseUI.Keys.backspace ) then
				searchVar = searchVar:sub( 1, -2 );
			end

			for k, v in pairs( gs_textTable ) do
				if input.IsButtonPressed( k ) then
					if input.IsButtonDown( SenseUI.Keys.shift ) then
						if draw.GetTextSize( searchVar .. v[2] ) <= 135 then
							searchVar = searchVar .. v[2];
						end
					else
						if draw.GetTextSize( searchVar .. v[1] ) <= 135 then
							searchVar = searchVar .. v[1];
						end
					end
				end
			end
		end

		if gs_curinput == elements[1] .. maxElements .. var .. elements[#elements] then
			render.text( x + 8, y + 4, searchVar .. "_", { 181, 181, 181, wnd.alpha } );
		else
			render.text( x + 8, y + 4, searchVar, { 181, 181, 181, wnd.alpha } );
		end

		-- Do search thingy
		if searchVar ~= "" then
			local newElements = {};

			for i = 1, #elements do
				if elements[i]:sub( 1, #searchVar ) == searchVar then
					newElements[#newElements + 1] = elements[i];
				end
			end

			elements = newElements;
		end

		y = y + 20;
	end

	-- Prevent bugs here
	if ( #elements - maxElements ) * 20 >= maxElements * 20 then
		while ( #elements - maxElements ) * 20 >= maxElements * 20 do
			maxElements = maxElements + 1;
		end
	end

	local h = maxElements * 20;

	render.outline( x, y, 155, h + 2, { 5, 5, 5, wnd.alpha } );
	render.rect( x + 1, y + 1, 153, h, { 36, 36, 36, wnd.alpha } );

	local bottomElements = 0;
	local topElements = 0;
	local shouldDrawScroll = false;

	for i = 1, #elements do
		local r, g, b = 181, 181, 181;
		local font = gs_fonts.verdana_12;

		local elementY = ( y + i * 20 - 19 ) - scrollVar * 20;
		local shouldDraw = true;

		if elementY > y + h then
			shouldDraw = false;
			bottomElements = bottomElements + 1;
			shouldDrawScroll = true;
		elseif elementY < y then
			shouldDraw = false;
			topElements = topElements + 1;
			shouldDrawScroll = true;
		end

		if shouldDraw then
			gs_mx, gs_my = input.GetMousePos();
			if gs_inbounds( gs_mx, gs_my, x + 1, elementY, x + 149, elementY + 20 ) and not gs_isBlocked then
				font = gs_fonts.verdana_12b;
				render.rect( x + 1, elementY, 153, 20, { 28, 28, 28, wnd.alpha } );

				if input.IsButtonPressed( 1 ) then
					var = i;
				end
			end

			if var == i then
				if gui.GetValue("senseui_color") == 0 then
					r, g, b = 149, 184, 6;
				elseif gui.GetValue("senseui_color") == 1 then
					r, g, b = 6, 132, 182;
				elseif gui.GetValue("senseui_color") == 2 then
					r, g, b = 182, 6, 6;
				elseif gui.GetValue("senseui_color") == 3 then
					r, g, b = 146, 6, 182;
				elseif gui.GetValue("senseui_color") == 4 then
					r, g, b = 205, 107, 8;
				elseif gui.GetValue("senseui_color") == 5 then
					r, g, b = 214, 10, 193;
				end
				font = gs_fonts.verdana_12b;

				render.rect( x + 1, elementY, 153, 20, { 28, 28, 28, wnd.alpha } );
			end

			render.text( x + 10, elementY + 3, elements[i], { r, g, b, wnd.alpha }, font );
		end
	end

	if shouldDrawScroll then
		render.rect( x + 149, y + 1, 5, h, { 32, 32, 32, wnd.alpha } );

		local c = 38;
		local scrY = y + scrollVar + scrollVar * 20 + 1;
		local scrH = ( h - ( ( #elements - maxElements ) * 20 ) ) - scrollVar;

		gs_mx, gs_my = input.GetMousePos();
		if gs_inbounds( gs_mx, gs_my, x + 149, scrY, x + 154, scrY + scrH ) and not gs_isBlocked then
			c = 46;

			if input.IsButtonDown( 1 ) then
				c = 28;
			end
		end

		if gs_inbounds( gs_mx, gs_my, x + 149, y, x + 154, y + h ) and input.IsButtonDown( 1 ) and not gs_isBlocked then
			local relative_y = gs_clamp( gs_my - y, 0, h );
			local ratio = relative_y / h + ( relative_y / h ) / 2;

			scrollVar = gs_clamp( math.floor( ( #elements - maxElements ) * ratio ), 0, #elements - maxElements );
		end

		render.outline( x + 149, scrY, 5, scrH, { c, c, c, wnd.alpha } );
		render.rect( x + 150, scrY + 1, 3, scrH - 1, { c + 8, c + 8, c + 8, wnd.alpha } );

		if bottomElements ~= 0 then
			render.rect( x + 150 - 9, y + h - 18 + 11, 5, 1, { 181, 181, 181, wnd.alpha } );
			render.rect( x + 150 - 8, y + h - 18 + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
			render.rect( x + 150 - 7, y + h - 18 + 13, 1, 1, { 181, 181, 181, wnd.alpha } );
		end

		if topElements ~= 0 then
			render.rect( x + 150 - 7, y - 5 + 11, 1, 1, { 181, 181, 181, wnd.alpha } );
			render.rect( x + 150 - 8, y - 5 + 12, 3, 1, { 181, 181, 181, wnd.alpha } );
			render.rect( x + 150 - 9, y - 5 + 13, 5, 1, { 181, 181, 181, wnd.alpha } );
		end
	end

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + h + 5;

	if showSearch then
		wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + 20;
	end

	if group.highest_w < 155 then
		wnd.groups[gs_curgroup].highest_w = 155;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	if showSearch then
		wnd.groups[gs_curgroup].last_y = wnd.groups[gs_curgroup].last_y - 20;
	end

	return var, scrollVar, searchVar;
end

local function gs_textbox( id, title, var )
	local wnd, group = gs_newelement();
	local x, y = wnd.x + group.x + 25, wnd.y + group.y + group.nextline_offset;

	if title ~= nil then
		render.text( x, y, title, { 181, 181, 181, wnd.alpha } );

		y = y + 13;
	end

	render.outline( x, y, 155, 20, { 5, 5, 5, wnd.alpha } );
	render.outline( x + 1, y + 1, 153, 18, { 28, 28, 28, wnd.alpha } );
	render.rect( x + 2, y + 2, 151, 16, { 36, 36, 36, wnd.alpha } );

	gs_mx, gs_my = input.GetMousePos();
	if input.IsButtonDown( 1 ) then
		if gs_inbounds( gs_mx, gs_my, x, y, x + 155, y + 20 ) then
			gs_curinput = id;
			gs_isBlocked = true;
		elseif not gs_inbounds( gs_mx, gs_my, x, y, x + 155, y + 20 ) and gs_curinput == id then
			gs_curinput = "";
			gs_isBlocked = false;
		end
	end

	if gs_curinput == id then
		if input.IsButtonPressed( SenseUI.Keys.esc ) then
			gs_curinput = "";
			gs_isBlocked = false;
		end

		if input.IsButtonPressed( SenseUI.Keys.backspace ) then
			var = var:sub( 1, -2 );
		end

		for k, v in pairs( gs_textTable ) do
			if input.IsButtonPressed( k ) then
				if input.IsButtonDown( SenseUI.Keys.shift ) then
					if draw.GetTextSize( var .. v[2] ) <= 135 then
						var = var .. v[2];
					end
				else
					if draw.GetTextSize( var .. v[1] ) <= 135 then
						var = var .. v[1];
					end
				end
			end
		end
	end

	if gs_curinput == id then
		render.text( x + 8, y + 4, var .. "_", { 181, 181, 181, wnd.alpha } );
	else
		render.text( x + 8, y + 4, var, { 181, 181, 181, wnd.alpha } );
	end

	wnd.groups[gs_curgroup].is_nextline = true;
	wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + 28;

	if title ~= nil then
		wnd.groups[gs_curgroup].nextline_offset = wnd.groups[gs_curgroup].nextline_offset + 13;
	end

	if group.highest_w < 155 then
		wnd.groups[gs_curgroup].highest_w = 155;
	end

	if group.highest_h < wnd.groups[gs_curgroup].nextline_offset then
		wnd.groups[gs_curgroup].highest_h = wnd.groups[gs_curgroup].nextline_offset - wnd.groups[gs_curgroup].nextline_offset / 2;
	end

	wnd.groups[gs_curgroup].last_y = y;

	if title ~= nil then
		wnd.groups[gs_curgroup].last_y = wnd.groups[gs_curgroup].last_y + 13;
	end

	return var;
end

SenseUI.BeginWindow = gs_beginwindow;
SenseUI.AddGradient = gs_addgradient;
SenseUI.EndWindow = gs_endwindow;
SenseUI.SetWindowMoveable = gs_setwindowmovable;
SenseUI.SetWindowOpenKey = gs_setwindowopenkey;
SenseUI.SetWindowDrawTexture = gs_setwindowdrawtexture;
SenseUI.BeginGroup = gs_begingroup;
SenseUI.EndGroup = gs_endgroup;
SenseUI.Checkbox = gs_checkbox;
SenseUI.SetWindowSizeable = gs_setwindowsizeable;
SenseUI.SetGroupMoveable = gs_setgroupmoveable;
SenseUI.SetGroupSizeable = gs_setgroupsizeable;
SenseUI.Button = gs_button;
SenseUI.Slider = gs_slider;
SenseUI.Label = gs_label;
SenseUI.Bind = gs_bind;
SenseUI.BeginTab = gs_begintab;
SenseUI.DrawTabBar = gs_drawtabbar;
SenseUI.EndTab = gs_endtab;
SenseUI.Combo = gs_combo;
SenseUI.MultiCombo = gs_multicombo;
SenseUI.Listbox = gs_listbox;
SenseUI.Textbox = gs_textbox;

list = 1;
listScroll = 0;
listSearch = "";

knives = { "Huntsman", "Karambit", "Butterfly", "Flip", "Ursus", "Gut", "M9 Bayonet", "Bayonet", "Bowie", "Stilleto" }
configs = {}

selected = 1
scroll = 0

configname = ""

kn = 1;

load_pressed = false
save_pressed = false
add_pressed = false
remove_pressed = false

local old_load_pressed, old_save_pressed, old_add_pressed, old_remove_pressed

sniper_select = 1;
shotgun_select = 1;
rifle_select = 1;
smg_select = 1;
pistol_select = 1;
lselect = 1;
knife_select = 1;
pselect = 1;
aa_choose = 1;
weapon_select = 1;
gehelper = 1;
mpt = gui.GetValue("msc_fakelag_limit");
-------------- for normal work
window_moveable = true;
bind_button = SenseUI.Keys.home;
bind_active = false;
bind_detect = SenseUI.KeyDetection.on_hotkey;
show_gradient = true;
window_bkey = SenseUI.Keys.delete;
window_bact = false;
window_bdet = SenseUI.KeyDetection.on_hotkey;

local enemy_flags = {
	["Has C4"] = gui.GetValue("esp_enemy_hasc4"),
	["Has Defuser"] = gui.GetValue("esp_enemy_hasdefuser"),
	["Is Defusing"] = gui.GetValue("esp_enemy_defusing"),
	["Is Flashed"] = gui.GetValue("esp_enemy_flashed"),
	["Is Scoped"] = gui.GetValue("esp_enemy_scoped"),
	["Is Reloading"] = gui.GetValue("esp_enemy_reloading"),
	["Competitive Rank"] = gui.GetValue("esp_enemy_comprank"),
	["Money"] = gui.GetValue("esp_enemy_money")
}
local team_flags = {
	["Has C4"] = gui.GetValue("esp_team_hasc4"),
	["Has Defuser"] = gui.GetValue("esp_team_hasdefuser"),
	["Is Defusing"] = gui.GetValue("esp_team_defusing"),
	["Is Flashed"] = gui.GetValue("esp_team_flashed"),
	["Is Scoped"] = gui.GetValue("esp_team_scoped"),
	["Is Reloading"] = gui.GetValue("esp_team_reloading"),
	["Competitive Rank"] = gui.GetValue("esp_team_comprank"),
	["Money"] = gui.GetValue("esp_team_money")
}
local self_flags = {
	["Has C4"] = gui.GetValue("esp_self_hasc4"),
	["Has Defuser"] = gui.GetValue("esp_self_hasdefuser"),
	["Is Defusing"] = gui.GetValue("esp_self_defusing"),
	["Is Flashed"] = gui.GetValue("esp_self_flashed"),
	["Is Scoped"] = gui.GetValue("esp_self_scoped"),
	["Is Reloading"] = gui.GetValue("esp_self_reloading"),
	["Competitive Rank"] = gui.GetValue("esp_self_comprank"),
	["Money"] = gui.GetValue("esp_self_money")
}
local removals = {
	["Flash"] = gui.GetValue("vis_noflash"),
	["Smoke"] = gui.GetValue("vis_nosmoke"),
	["Recoil"] = gui.GetValue("vis_norecoil")
}
local render = {
	["Teammate"] = gui.GetValue("vis_norender_teammates"),
	["Enemy"] = gui.GetValue("vis_norender_enemies"),
	["Weapon"] = gui.GetValue("vis_norender_weapons"),
	["Ragdoll"] = gui.GetValue("vis_norender_ragdolls")
}
local pistol_hitboxes = {
	["Head"] = gui.GetValue("rbot_pistol_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_pistol_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_pistol_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_pistol_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_pistol_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_pistol_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_pistol_hitbox_legs")
}
local revolver_hitboxes = {
	["Head"] = gui.GetValue("rbot_revolver_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_revolver_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_revolver_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_revolver_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_revolver_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_revolver_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_revolver_hitbox_legs")
}
local smg_hitboxes = {
	["Head"] = gui.GetValue("rbot_smg_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_smg_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_smg_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_smg_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_smg_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_smg_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_smg_hitbox_legs")
}
local rifle_hitboxes = {
	["Head"] = gui.GetValue("rbot_rifle_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_rifle_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_rifle_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_rifle_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_rifle_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_rifle_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_rifle_hitbox_legs")
}
local shotgun_hitboxes = {
	["Head"] = gui.GetValue("rbot_shotgun_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_shotgun_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_shotgun_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_shotgun_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_shotgun_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_shotgun_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_shotgun_hitbox_legs")
}
local scout_hitboxes = {
	["Head"] = gui.GetValue("rbot_scout_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_scout_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_scout_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_scout_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_scout_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_scout_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_scout_hitbox_legs")
}
local autosniper_hitboxes = {
	["Head"] = gui.GetValue("rbot_autosniper_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_autosniper_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_autosniper_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_autosniper_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_autosniper_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_autosniper_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_autosniper_hitbox_legs")
}
local sniper_hitboxes = {
	["Head"] = gui.GetValue("rbot_sniper_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_sniper_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_sniper_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_sniper_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_sniper_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_sniper_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_sniper_hitbox_legs")
}
local lmg_hitboxes = {
	["Head"] = gui.GetValue("rbot_lmg_hitbox_head"),
	["Neck"] = gui.GetValue("rbot_lmg_hitbox_neck"),
	["Chest"] = gui.GetValue("rbot_lmg_hitbox_chest"),
	["Stomach"] = gui.GetValue("rbot_lmg_hitbox_stomach"),
	["Pelvis"] = gui.GetValue("rbot_lmg_hitbox_pelvis"),
	["Arms"] = gui.GetValue("rbot_lmg_hitbox_arms"),
	["Legs"] = gui.GetValue("rbot_lmg_hitbox_legs")
}
local pistol_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_pistol_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_pistol_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_pistol_hitbox_optbacktrack")
}
local revolver_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_revolver_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_revolver_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_revolver_hitbox_optbacktrack")
}
local smg_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_smg_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_smg_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_smg_hitbox_optbacktrack")
}
local rifle_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_rifle_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_rifle_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_rifle_hitbox_optbacktrack")
}
local shotgun_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_shotgun_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_shotgun_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_shotgun_hitbox_optbacktrack")
}
local scout_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_scout_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_scout_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_scout_hitbox_optbacktrack")
}
local autosniper_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_autosniper_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_autosniper_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_autosniper_hitbox_optbacktrack")
}
local sniper_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_sniper_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_sniper_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_sniper_hitbox_optbacktrack")
}
local lmg_optimization = {
	["Adaptive hitboxes"] = gui.GetValue("rbot_lmg_hitbox_adaptive"),
	["Nearby points"] = gui.GetValue("rbot_lmg_hitbox_optpoints"),
	["Backtracking"] = gui.GetValue("rbot_lmg_hitbox_optbacktrack")
}
local condition_aa = {
	["Dormant"] = gui.GetValue("rbot_antiaim_on_dormant"),
	["On freeze period"] = gui.GetValue("rbot_antiaim_on_freezeperiod"),
	["On grenades"] = gui.GetValue("rbot_antiaim_on_grenades"),
	["On knife"] = gui.GetValue("rbot_antiaim_on_knife"),
	["On use"] = gui.GetValue("rbot_antiaim_on_use"),
	["On ladder"] = gui.GetValue("rbot_antiaim_ladder")
}

local antitrig = {
	["SlowWalk"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Knife"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Taser"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Grenade"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Pistol"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Revolver"] = gui.GetValue("lua_fakelag_slowwalk"),
	["Ping"] = gui.GetValue("lua_fakelag_slowwalk")
}

SenseUI.EnableLogs = false;

function draw_callback()
	if SenseUI.BeginWindow( "wnd1", 50, 50, 620, 670) then
		SenseUI.DrawTabBar();

		if show_gradient then
			SenseUI.AddGradient();
		end
		SenseUI.SetWindowDrawTexture( false ); -- Makes huge fps drop. Not recommended to use yet
		SenseUI.SetWindowMoveable( window_moveable );
		SenseUI.SetWindowOpenKey( window_bkey );

		if SenseUI.BeginTab( "aimbot", SenseUI.Icons.rage ) then


			if SenseUI.BeginGroup( "legitaim", "Legit Aimbot", 25, 25, 235, 205 ) then
				SenseUI.SetGroupMoveable( true );
				SenseUI.SetGroupSizeable( true );
				lselect = SenseUI.Combo("", { "Pistol", "SMG", "Rifle", "Shotgun", "Sniper" }, lselect );
				if lselect == 1 then
				
				local pistol_awall = (gui.GetValue("lbot_pistol_autowall")); 
				local pistol_fov = (gui.GetValue("lbot_pistol_fov") * 3.33333333333333);
				local pistol_curve = (gui.GetValue("lbot_pistol_curve") * 10);
				local pistol_smooth = (gui.GetValue("lbot_pistol_smooth") * 3.33333333333333);
				local pistol_rand = (gui.GetValue("lbot_pistol_randomize") * 10);
				local pistol_stype = (gui.GetValue("lbot_pistol_smoothtype") + 1);
				local pistol_rcs = (gui.GetValue("lbot_pistol_rcs"));
				local pistol_rcs2 = (gui.GetValue("lbot_pistol_rcs_standalone"));
				local pistol_rcshori = (gui.GetValue("lbot_pistol_rcs_horiz"));
				local pistol_hitboxpri = (gui.GetValue("lbot_pistol_hitbox") + 1);
				local pistol_hboxselect = (gui.GetValue("lbot_pistol_hitboxselect") + 1);
				
				pistol_fov = SenseUI.Slider("FOV", 0.00, 100.00, "°", "Off", "Rage Legit", true, pistol_fov)
				gui.SetValue("lbot_pistol_fov", pistol_fov / 3.33333333333333)
				
				SenseUI.Label("FOV Type");
				pistol_stype = SenseUI.Combo("1", { "Dynamic", "Static" }, pistol_stype);
				gui.SetValue("lbot_pistol_smoothtype", pistol_stype-1)
				
				pistol_smooth = SenseUI.Slider("Smooth", 0.00, 100.00, "%", "Rage", "Legit", true, pistol_smooth)
				gui.SetValue("lbot_pistol_smooth", pistol_smooth / 3.33333333333333)
				
				pistol_rand = SenseUI.Slider("Randomize", 0.00, 100.00, "", "Off", "Muy Randimo", true, pistol_rand)
				gui.SetValue("lbot_pistol_randomize", pistol_rand / 10)
				
				pistol_rcs = SenseUI.Checkbox("RCS", pistol_rcs)
				gui.SetValue("lbot_pistol_rcs", pistol_rcs);
				
				pistol_rcs2 = SenseUI.Checkbox("RCS Standalone", pistol_rcs2)
				gui.SetValue("lbot_pistol_rcs_standalone", pistol_rcs2);
				
				pistol_rcshori = SenseUI.Slider("RCS Horizontal", 0.00, 100.00, "%", "Off", "", true, pistol_rcshori)
				gui.SetValue("lbot_pistol_rcs_horiz", pistol_rcshori)
			
				SenseUI.Label("Hitbox Priority/Selection")
				pistol_hitboxpri = SenseUI.Combo("2", { "Head", "Chest", "Stomach" }, pistol_hitboxpri)
				gui.SetValue("lbot_pistol_hitbox", pistol_hitboxpri - 1)

				pistol_hboxselect = SenseUI.Combo("3", {"Priority", "Dynamic", "Nearest"}, pistol_hboxselect)
				gui.SetValue("lbot_pistol_hitboxselect", pistol_hboxselect - 1)
				
				pistol_awall = SenseUI.Checkbox("AutoWall", pistol_awall)
				gui.SetValue("lbot_pistol_autowall", pistol_awall)
				
				
				end
				if lselect == 2 then
				
				local smg_awall = (gui.GetValue("lbot_smg_autowall")); 
				local smg_fov = (gui.GetValue("lbot_smg_fov") * 3.33333333333333);
				local smg_curve = (gui.GetValue("lbot_smg_curve") * 10);
				local smg_smooth = (gui.GetValue("lbot_smg_smooth") * 3.33333333333333);
				local smg_rand = (gui.GetValue("lbot_smg_randomize") * 10);
				local smg_stype = (gui.GetValue("lbot_smg_smoothtype") + 1);
				local smg_rcs = (gui.GetValue("lbot_smg_rcs"));
				local smg_rcs2 = (gui.GetValue("lbot_smg_rcs_standalone"));
				local smg_rcshori = (gui.GetValue("lbot_smg_rcs_horiz"));
				local smg_hitboxpri = (gui.GetValue("lbot_smg_hitbox") + 1);
				local smg_hboxselect = (gui.GetValue("lbot_smg_hitboxselect") + 1);
				
				smg_fov = SenseUI.Slider("FOV", 0.00, 100.00, "°", "Off", "Rage Legit", true, smg_fov)
				gui.SetValue("lbot_smg_fov", smg_fov / 3.33333333333333)
			
				SenseUI.Label("FOV Type");
				smg_stype = SenseUI.Combo("4", { "Dynamic", "Static" }, smg_stype);
				gui.SetValue("lbot_smg_smoothtype", smg_stype-1)
			
				smg_smooth = SenseUI.Slider("Smooth", 0.00, 100.00, "%", "Rage", "Legit", true, smg_smooth)
				gui.SetValue("lbot_smg_smooth", smg_smooth / 3.33333333333333)
				
				smg_rand = SenseUI.Slider("Randomize", 0.00, 100.00, "", "Off", "Muy Randimo", true, smg_rand)
				gui.SetValue("lbot_smg_randomize", smg_rand / 10)
				
				smg_rcs = SenseUI.Checkbox("RCS", smg_rcs)
				gui.SetValue("lbot_smg_rcs", smg_rcs);
				
				smg_rcs2 = SenseUI.Checkbox("RCS Standalone", smg_rcs2)
				gui.SetValue("lbot_smg_rcs_standalone", smg_rcs2);
				
				smg_rcshori = SenseUI.Slider("RCS Horizontal", 0.00, 100.00, "%", "Off", "", true, smg_rcshori)
				gui.SetValue("lbot_smg_rcs_horiz", smg_rcshori)
				
				SenseUI.Label("Hitbox Priority/Selection");
				smg_hitboxpri = SenseUI.Combo("5", { "Head", "Chest", "Stomach" }, smg_hitboxpri)
				gui.SetValue("lbot_smg_hitbox", smg_hitboxpri - 1)

				smg_hboxselect = SenseUI.Combo("6", {"Priority", "Dynamic", "Nearest"}, smg_hboxselect)
				gui.SetValue("lbot_smg_hitboxselect", smg_hboxselect - 1);
				
				
				smg_awall = SenseUI.Checkbox("AutoWall", smg_awall)
				gui.SetValue("lbot_smg_autowall", smg_awall)
				end
				if lselect == 3 then
				
				local rifle_awall = (gui.GetValue("lbot_rifle_autowall")); 
				local rifle_fov = (gui.GetValue("lbot_rifle_fov") * 3.33333333333333);
				local rifle_curve = (gui.GetValue("lbot_rifle_curve") * 10);
				local rifle_smooth = (gui.GetValue("lbot_rifle_smooth") * 3.33333333333333);
				local rifle_rand = (gui.GetValue("lbot_rifle_randomize") * 10);
				local rifle_stype = (gui.GetValue("lbot_rifle_smoothtype") + 1);
				local rifle_rcs = (gui.GetValue("lbot_rifle_rcs"));
				local rifle_rcs2 = (gui.GetValue("lbot_rifle_rcs_standalone"));
				local rifle_rcshori = (gui.GetValue("lbot_rifle_rcs_horiz"));
				local rifle_hitboxpri = (gui.GetValue("lbot_rifle_hitbox") + 1);
				local rifle_hboxselect = (gui.GetValue("lbot_rifle_hitboxselect") + 1);
				
				rifle_fov = SenseUI.Slider("FOV", 0.00, 100.00, "°", "Off", "Rage Legit", true, rifle_fov)
				gui.SetValue("lbot_rifle_fov", rifle_fov / 3.33333333333333)
			
				SenseUI.Label("FOV Type");
				rifle_stype = SenseUI.Combo("7", { "Dynamic", "Static" }, rifle_stype);
				gui.SetValue("lbot_rifle_smoothtype", rifle_stype-1)
				
				rifle_smooth = SenseUI.Slider("Smooth", 0.00, 100.00, "%", "Rage", "Legit", true, rifle_smooth)
				gui.SetValue("lbot_rifle_smooth", rifle_smooth / 3.33333333333333)
				
				rifle_rand = SenseUI.Slider("Randomize", 0.00, 100.00, "", "Off", "Muy Randimo", true, rifle_rand)
				gui.SetValue("lbot_rifle_randomize", rifle_rand / 10)
				
				rifle_rcs = SenseUI.Checkbox("RCS", rifle_rcs)
				gui.SetValue("lbot_rifle_rcs", rifle_rcs);

				rifle_rcs2 = SenseUI.Checkbox("RCS Standalone", rifle_rcs2)
				gui.SetValue("lbot_rifle_rcs_standalone", rifle_rcs2);
				
				
				rifle_rcshori = SenseUI.Slider("RCS Horizontal", 0.00, 100.00, "%", "Off", "", true, rifle_rcshori)
				gui.SetValue("lbot_rifle_rcs_horiz", rifle_rcshori)
				
				SenseUI.Label("Hitbox Priority/Selection");
				rifle_hitboxpri = SenseUI.Combo("8", { "Head", "Chest", "Stomach" }, rifle_hitboxpri)
				gui.SetValue("lbot_rifle_hitbox", rifle_hitboxpri - 1)
				

					

				rifle_hboxselect = SenseUI.Combo("9", {"Priority", "Dynamic", "Nearest"}, rifle_hboxselect)
				gui.SetValue("lbot_rifle_hitboxselect", rifle_hboxselect - 1);
				
				rifle_awall = SenseUI.Checkbox("AutoWall", rifle_awall)
				gui.SetValue("lbot_rifle_autowall", rifle_awall)
				end
				if lselect == 4 then
				
				local shotgun_awall = (gui.GetValue("lbot_shotgun_autowall")); 
				local shotgun_fov = (gui.GetValue("lbot_shotgun_fov") * 3.33333333333333);
				local shotgun_curve = (gui.GetValue("lbot_shotgun_curve") * 10);
				local shotgun_smooth = (gui.GetValue("lbot_shotgun_smooth") * 3.33333333333333);
				local shotgun_rand = (gui.GetValue("lbot_shotgun_randomize") * 10);
				local shotgun_stype = (gui.GetValue("lbot_shotgun_smoothtype") + 1);
				local shotgun_rcs = (gui.GetValue("lbot_shotgun_rcs"));
				local shotgun_rcs2 = (gui.GetValue("lbot_shotgun_rcs_standalone"));
				local shotgun_rcshori = (gui.GetValue("lbot_shotgun_rcs_horiz"));
				local shotgun_hitboxpri = (gui.GetValue("lbot_shotgun_hitbox") + 1);
				local shotgun_hboxselect = (gui.GetValue("lbot_shotgun_hitboxselect") + 1);
				
				shotgun_fov = SenseUI.Slider("FOV", 0.00, 100.00, "°", "Off", "Rage Legit", true, shotgun_fov)
				gui.SetValue("lbot_shotgun_fov", shotgun_fov / 3.33333333333333)
			
				SenseUI.Label("FOV Type");
				shotgun_stype = SenseUI.Combo("10", { "Dynamic", "Static" }, shotgun_stype);
				gui.SetValue("lbot_shotgun_smoothtype", shotgun_stype-1)

				shotgun_smooth = SenseUI.Slider("Smooth", 0.00, 100.00, "%", "Rage", "Legit", true, shotgun_smooth)
				gui.SetValue("lbot_shotgun_smooth", shotgun_smooth / 3.33333333333333)
				
				shotgun_rand = SenseUI.Slider("Randomize", 0.00, 100.00, "", "Off", "Muy Randimo", true, shotgun_rand)
				gui.SetValue("lbot_shotgun_randomize", shotgun_rand / 10)
				
				shotgun_rcs = SenseUI.Checkbox("RCS", shotgun_rcs)
				gui.SetValue("lbot_shotgun_rcs", shotgun_rcs);
				
				shotgun_rcs2 = SenseUI.Checkbox("RCS Standalone", shotgun_rcs2)
				gui.SetValue("lbot_shotgun_rcs_standalone", shotgun_rcs2);
				
				shotgun_rcshori = SenseUI.Slider("RCS Horizontal", 0.00, 100.00, "%", "Off", "", true, shotgun_rcshori)
				gui.SetValue("lbot_shotgun_rcs_horiz", shotgun_rcshori)
				
				SenseUI.Label("Hitbox Priority/Selection");
				shotgun_hitboxpri = SenseUI.Combo("11", { "Head", "Chest", "Stomach" }, shotgun_hitboxpri);
				gui.SetValue("lbot_shotgun_hitbox", shotgun_hitboxpri - 1)

				shotgun_hboxselect = SenseUI.Combo("12", {"Priority", "Dynamic", "Nearest"}, shotgun_hboxselect);
				gui.SetValue("lbot_shotgun_hitboxselect", shotgun_hboxselect - 1);
				
				shotgun_awall = SenseUI.Checkbox("AutoWall", shotgun_awall)
				gui.SetValue("lbot_shotgun_autowall", shotgun_awall)
				end
				if lselect == 5 then
				
				local sniper_awall = (gui.GetValue("lbot_sniper_autowall")); 
				local sniper_fov = (gui.GetValue("lbot_sniper_fov") * 3.33333333333333);
				local sniper_curve = (gui.GetValue("lbot_sniper_curve") * 10);
				local sniper_smooth = (gui.GetValue("lbot_sniper_smooth") * 3.33333333333333);
				local sniper_rand = (gui.GetValue("lbot_sniper_randomize") * 10);
				local sniper_stype = (gui.GetValue("lbot_sniper_smoothtype") + 1);
				local sniper_rcs = (gui.GetValue("lbot_sniper_rcs"));
				local sniper_rcs2 = (gui.GetValue("lbot_sniper_rcs_standalone"));
				local sniper_rcshori = (gui.GetValue("lbot_sniper_rcs_horiz"));
				local sniper_hitboxpri = (gui.GetValue("lbot_sniper_hitbox") + 1);
				local sniper_hboxselect = (gui.GetValue("lbot_sniper_hitboxselect") + 1);
				
				sniper_fov = SenseUI.Slider("FOV", 0.00, 100.00, "°", "Off", "Rage Legit", true, sniper_fov)
				gui.SetValue("lbot_sniper_fov", sniper_fov / 3.33333333333333)
				
				SenseUI.Label("FOV Type");
				sniper_stype = SenseUI.Combo("13", { "Dynamic", "Static" }, sniper_stype);
				gui.SetValue("lbot_sniper_smoothtype", sniper_stype-1)
			
				sniper_smooth = SenseUI.Slider("Smooth", 0.00, 100.00, "%", "Rage", "Legit", true, sniper_smooth)
				gui.SetValue("lbot_sniper_smooth", sniper_smooth / 3.33333333333333)
				
				sniper_rand = SenseUI.Slider("Randomize", 0.00, 100.00, "", "Off", "Muy Randimo", true, sniper_rand)
				gui.SetValue("lbot_sniper_randomize", sniper_rand / 10)
				
				sniper_rcs = SenseUI.Checkbox("RCS", sniper_rcs)
				gui.SetValue("lbot_sniper_rcs", sniper_rcs);
				
				sniper_rcs2 = SenseUI.Checkbox("RCS Standalone", sniper_rcs2)
				gui.SetValue("lbot_sniper_rcs_standalone", sniper_rcs2);
				
				sniper_rcshori = SenseUI.Slider("RCS Horizontal", 0.00, 100.00, "%", "Off", "", true, sniper_rcshori)
				gui.SetValue("lbot_sniper_rcs_horiz", sniper_rcshori)
				
				SenseUI.Label("Hitbox Priority/Selection");
				sniper_hitboxpri = SenseUI.Combo("14", { "Head", "Chest", "Stomach" }, sniper_hitboxpri);
				gui.SetValue("lbot_sniper_hitbox", sniper_hitboxpri - 1)

				sniper_hboxselect = SenseUI.Combo("15", {"Priority", "Dynamic", "Nearest"}, sniper_hboxselect);
				gui.SetValue("lbot_sniper_hitboxselect", sniper_hboxselect - 1);
				
				sniper_awall = SenseUI.Checkbox("AutoWall", sniper_awall)
				gui.SetValue("lbot_sniper_autowall", sniper_awall)
				end
				SenseUI.EndGroup();
			end
			if SenseUI.BeginGroup( "EXTRA", "Extra", 285, 25, 200, 380 ) then
				local lbot_backtrack = (gui.GetValue("lbot_positionadjustment") * 995);
				local lbot_fakelat = (gui.GetValue("msc_fakelatency_enable"));
				local lbot_fakelatlvl = (gui.GetValue("msc_fakelatency_amount") * 1000);
				
				
				lbot_fakelat = SenseUI.Checkbox("Increased Backtrack", lbot_fakelat)
				gui.SetValue("msc_fakelatency_enable", lbot_fakelat)
				local fakelatkey = gui.GetValue("msc_fakelatency_key");
				fakelatkey = SenseUI.Bind("flk", true, fakelatkey);
				gui.SetValue("msc_fakelatency_key", fakelatkey);
				
				lbot_fakelatlvl = SenseUI.Slider("Increase Backtrack", 0.00, 1000.00, "ms", "Off", "Muy Backtrack", true, lbot_fakelatlvl)
				gui.SetValue("msc_fakelatency_amount", lbot_fakelatlvl / 1000);
				
				
				lbot_backtrack = SenseUI.Slider("Backtrack", 0.00, 200.00, "ms", "Off", "Muy Backtrack", true, lbot_backtrack)
				gui.SetValue("lbot_positionadjustment", lbot_backtrack / 995)
				

				local fakelagenable = gui.GetValue("msc_fakelag_enable");
				fakelagenable = SenseUI.Checkbox("AntiTrig enable", fakelagenable);
				gui.SetValue("msc_fakelag_enable", fakelagenable);
				
				local fakelagbind = gui.GetValue("msc_fakelag_key");
				fakelagbind = SenseUI.Bind("flag", true, fakelagbind);
				gui.SetValue("msc_fakelag_key", fakelagbind);
				
				local fakelagamount = gui.GetValue("msc_fakelag_value");
				fakelagamount = SenseUI.Slider("AntiTrig amount", 1, mpt+1, "", "1", mpt+1, false, fakelagamount);
				gui.SetValue("msc_fakelag_value", fakelagamount);
				
				local fakelagpeek = gui.GetValue("msc_fakelag_peekdist");
				fakelagpeek = SenseUI.Slider("AntiTrig Peek Dist", 1, 50, "", "1", "50", false, fakelagpeek);
				gui.SetValue("msc_fakelag_peekdist", fakelagpeek);
				
				SenseUI.Label("AntiTrig mode");
				local fakelagmode = (gui.GetValue("msc_fakelag_mode") - 3 );
				fakelagmode = SenseUI.Combo("trig", {"Peek", "Rapid Peek" }, fakelagmode);
				gui.SetValue("msc_fakelag_mode", fakelagmode + 3);
				
				local fakelagewsh = gui.GetValue("msc_fakelag_attack");
				fakelagewsh = SenseUI.Checkbox("AntiTrig while shooting", fakelagewsh);
				gui.SetValue("msc_fakelag_attack", fakelagewsh);
				
				local fakelagwst = gui.GetValue("msc_fakelag_standing");
				fakelagwst = SenseUI.Checkbox("AntiTrig while standing", fakelagwst);
				gui.SetValue("msc_fakelag_standing", fakelagwst);
				
				local fakelagwund = gui.GetValue("msc_fakelag_unducking");
				fakelagwund = SenseUI.Checkbox("AntiTrig while unducking", fakelagwund);
				gui.SetValue("msc_fakelag_unducking", fakelagwund);
				
				SenseUI.Label("AntiTrig style");
				local fakelagstylell = (gui.GetValue("msc_fakelag_style") + 1 );
				
				fakelagstylell = SenseUI.Combo("ssd", { "Always", "Avoid ground", "Hit ground" }, fakelagstylell);
				gui.SetValue("msc_fakelag_style", fakelagstylell-1);
				mpt = SenseUI.Slider("Max server process ticks", 1, 61, "", "1", "61" , false, mpt);
				gui.SetValue("msc_fakelag_limit", mpt);
				
				local extraantitrig = (gui.GetValue("lua_fakelag_extra_enable"));
				extraantitrig = SenseUI.Checkbox("Smart Antitrig(WIP)", extraantitrig);
				gui.SetValue("lua_fakelag_extra_enable", extraantitrig);
				
				antitrig = SenseUI.MultiCombo("Smart Antitrig settings", { "SlowWalk", "Knife", "Taser", "Grenade", "Pistol", "Revolver", "Ping" }, antitrig);
				gui.SetValue("lua_fakelag_slowwalk", antitrig["SlowWalk"]);
				gui.SetValue("lua_fakelag_knife", antitrig["Knife"]);
				gui.SetValue("lua_fakelag_taser", antitrig["Taser"]);
				gui.SetValue("lua_fakelag_grenade", antitrig["Grenade"]);
				gui.SetValue("lua_fakelag_pistol", antitrig["Pistol"]);
				gui.SetValue("lua_fakelag_revolver", antitrig["Revolver"]);
				gui.SetValue("lua_fakelag_ping", antitrig["Ping"]);
				
				
				SenseUI.EndGroup();

			end
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "antiaim", SenseUI.Icons.antiaim ) then
			if SenseUI.BeginGroup( "antiaim main", "Anti-Aim Main", 25, 25, 235, 295 ) then
				local aa_enable = gui.GetValue("rbot_antiaim_enable");
				aa_enable = SenseUI.Checkbox("Enable AA", aa_enable);
				gui.SetValue("rbot_antiaim_enable", aa_enable);
				SenseUI.Label("At targets");
				local attargets = (gui.GetValue("rbot_antiaim_at_targets") + 1);
				attargets = SenseUI.Combo("attargets_rage", { "Off", "Average", "Closest" }, attargets);
				gui.SetValue("rbot_antiaim_at_targets", attargets-1);
				SenseUI.Label("Auto direction");
				local adirection = (gui.GetValue("rbot_antiaim_autodir") + 1); 
				adirection = SenseUI.Combo("adirection_rage", { "Off", "Default", "Desync", "Desync jitter" }, adirection);
				gui.SetValue("rbot_antiaim_autodir", adirection-1);
				local jitter_r = gui.GetValue("rbot_antiaim_jitter_range");
				jitter_r = SenseUI.Slider("Jitter range", 0, 180, "°", "0°", "180°", false, jitter_r);
				gui.SetValue("rbot_antiaim_jitter_range", jitter_r);
				local spinbot_s = (gui.GetValue("rbot_antiaim_spinbot_speed") * 10);
				spinbot_s = SenseUI.Slider("Spinbot speed", -200, 200, "", "-20", "20", false, spinbot_s);
				gui.SetValue("rbot_antiaim_spinbot_speed", spinbot_s / 10);
				local speedswitch = (gui.GetValue("rbot_antiaim_switch_speed") * 100);
				speedswitch = SenseUI.Slider("Switch speed", 0, 100, "%", "0%", "100%", false, speedswitch);
				gui.SetValue("rbot_antiaim_switch_speed", speedswitch / 100);
				local switch_r = gui.GetValue("rbot_antiaim_switch_range");
				switch_r = SenseUI.Slider("Switch range", 0, 180, "°", "0°", "180°", false, switch_r);
				gui.SetValue("rbot_antiaim_switch_range", switch_r);
				SenseUI.Label("Fake duck bind");
				local fakeduck_bind = gui.GetValue("rbot_antiaim_fakeduck");
				fakeduck_bind = SenseUI.Bind("fduck", true, fakeduck_bind);
				gui.SetValue("rbot_antiaim_fakeduck", fakeduck_bind);
				condition_aa = SenseUI.MultiCombo("Working", { "On use", "On freeze period", "On grenades", "On knife", "On ladder", "Dormant" }, condition_aa);
				gui.SetValue("rbot_antiaim_on_dormant", condition_aa["Dormant"]);
				gui.SetValue("rbot_antiaim_on_freezeperiod", condition_aa["On freeze period"]);
				gui.SetValue("rbot_antiaim_on_grenades", condition_aa["On grenades"]);
				gui.SetValue("rbot_antiaim_on_knife", condition_aa["On knife"]);
				gui.SetValue("rbot_antiaim_on_use", condition_aa["On use"]);
				gui.SetValue("rbot_antiaim_ladder", condition_aa["On ladder"]);
				SenseUI.EndGroup();
			end
			if SenseUI.BeginGroup( "anti-aim", "Anti-Aim", 285, 25, 235, 285 ) then
				SenseUI.Label("AA Mode Choose");
				aa_choose = SenseUI.Combo( "aa_choose_rage", { "Stand", "Move", "Edge" }, aa_choose);
				if aa_choose == 1 then
					SenseUI.Label("Pitch");
					local pitch_stand = (gui.GetValue("rbot_antiaim_stand_pitch_real") + 1);
					pitch_stand = SenseUI.Combo( "pitch_rage_stand", { "Off", "Emotion", "Down", "Up", "Zero", "Mixed", "Custom" }, pitch_stand);
					gui.SetValue("rbot_antiaim_stand_pitch_real", pitch_stand-1);
					local custom_pitch = gui.GetValue("rbot_antiaim_stand_pitch_custom");
					custom_pitch = SenseUI.Slider( "Custom pitch", -180, 180, "°", "0°", "180°", false, custom_pitch);
					gui.SetValue("rbot_antiaim_stand_pitch_custom", custom_pitch);
					SenseUI.Label("Yaw");
					local yaw_stand = (gui.GetValue("rbot_antiaim_stand_real") + 1);
					yaw_stand = SenseUI.Combo( "just choose2", { "Off", "Static", "Spinbot", "Jitter", "Zero", "Switch" }, yaw_stand);
					gui.SetValue("rbot_antiaim_stand_real", yaw_stand-1);
					local custom_yaw = gui.GetValue("rbot_antiaim_stand_real_add");
					custom_yaw = SenseUI.Slider( "Custom yaw", -180, 180, "°", "0°", "180°", false, custom_yaw);
					gui.SetValue("rbot_antiaim_stand_real_add", custom_yaw);
					SenseUI.Label("Yaw desync");
					local desync_stand = (gui.GetValue("rbot_antiaim_stand_desync") + 1);
					desync_stand = SenseUI.Combo( "just choose3", { "Off", "Still", "Balance", "Stretch", "Jitter" }, desync_stand);
					gui.SetValue("rbot_antiaim_stand_desync", desync_stand-1);
					local stand_velocity = gui.GetValue("rbot_antiaim_stand_velocity");
					stand_velocity = SenseUI.Slider( "Stand Velocity Treshold", 0, 250, "", "0.1", "250", false, stand_velocity);
					gui.SetValue("rbot_antiaim_stand_velocity", stand_velocity);
				else if aa_choose == 2 then
					SenseUI.Label("Pitch");
					local pitch_move = (gui.GetValue("rbot_antiaim_move_pitch_real") + 1);
					pitch_move = SenseUI.Combo( "just choose4", { "Off", "Emotion", "Down", "Up", "Zero", "Mixed", "Custom" }, pitch_move);
					gui.SetValue("rbot_antiaim_move_pitch_real", pitch_move-1);
					local custom_pitch_move = gui.GetValue("rbot_antiaim_move_pitch_custom");
					custom_pitch_move = SenseUI.Slider( "Custom pitch", -180, 180, "°", "0°", "180°", false, custom_pitch_move);
					gui.SetValue("rbot_antiaim_move_pitch_custom", custom_pitch_move);
					SenseUI.Label("Yaw");
					local yaw_move = (gui.GetValue("rbot_antiaim_move_real") + 1);
					yaw_move = SenseUI.Combo( "just choose5", { "Off", "Static", "Spinbot", "Jitter", "Zero", "Switch" }, yaw_move);
					gui.SetValue("rbot_antiaim_move_real", yaw_move-1);
					local custom_yaw_move = gui.GetValue("rbot_antiaim_move_real_add");
					custom_yaw_move = SenseUI.Slider( "Custom yaw", -180, 180, "°", "0°", "180°", false, custom_yaw_move);
					gui.SetValue("rbot_antiaim_move_real_add", custom_yaw_move);
					SenseUI.Label("Yaw desync");
					local desync_move = (gui.GetValue("rbot_antiaim_move_desync") + 1);
					desync_move = SenseUI.Combo( "just choose6", { "Off", "Still", "Balance", "Stretch", "Jitter" }, desync_move);
					gui.SetValue("rbot_antiaim_move_desync", desync_move-1);
				else if aa_choose == 3 then
					local desync_edge = (gui.GetValue("rbot_antiaim_edge_desync") + 1);
					local custom_pitch_edge = gui.GetValue("rbot_antiaim_edge_pitch_custom");
					local custom_yaw_edge = gui.GetValue("rbot_antiaim_edge_real_add");
					SenseUI.Label("Pitch");
					local pitch_edge = (gui.GetValue("rbot_antiaim_edge_pitch_real") + 1);
					pitch_edge = SenseUI.Combo( "just choose7", { "Off", "Emotion", "Down", "Up", "Zero", "Mixed", "Custom" }, pitch_edge);
					gui.SetValue("rbot_antiaim_edge_pitch_real", pitch_edge-1);
					custom_pitch_edge = SenseUI.Slider( "Custom pitch", -180, 180, "°", "0°", "180°", false, custom_pitch_edge);
					gui.SetValue("rbot_antiaim_edge_pitch_custom", custom_pitch_edge);
					SenseUI.Label("Yaw");
					local yaw_edge = (gui.GetValue("rbot_antiaim_edge_real") + 1);
					yaw_edge = SenseUI.Combo( "just choose8", { "Off", "Static", "Spinbot", "Jitter", "Zero", "Switch" }, yaw_edge);
					gui.SetValue("rbot_antiaim_edge_real", yaw_edge-1);
					custom_yaw_edge = SenseUI.Slider( "Custom yaw", -180, 180, "°", "0°", "180°", false, custom_yaw_edge);
					gui.SetValue("rbot_antiaim_edge_real_add", custom_yaw_edge);
					SenseUI.Label("Yaw desync");
					desync_edge = SenseUI.Combo( "just choose9", { "Off", "Still", "Balance", "Stretch", "Jitter" }, desync_edge);
					gui.SetValue("rbot_antiaim_edge_desync", desync_edge-1);
				end
				end
				end
				SenseUI.EndGroup();
			end
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "gunsettings", SenseUI.Icons.legit ) then
			if SenseUI.BeginGroup( "gunssettingss", "Main", 25, 25, 235, 485 ) then
				SenseUI.Label("Weapon selection");
				weapon_select = SenseUI.Combo("nvmd_rage", { "Pistol", "Revolver", "SMG", "Rifle", "Shotgun", "Scout", "AutoSniper", "AWP", "LMG" }, weapon_select );
				if weapon_select == 1 then
				
				local p_autowall = (gui.GetValue("rbot_pistol_autowall") + 1);
				local p_hitchance = gui.GetValue("rbot_pistol_hitchance");
				local p_mindamage = gui.GetValue("rbot_pistol_mindamage");
				local p_hitprior = (gui.GetValue("rbot_pistol_hitbox") + 1);
				local p_bodyaim = (gui.GetValue("rbot_pistol_hitbox_bodyaim") + 1);
				local p_method = (gui.GetValue("rbot_pistol_hitbox_method") + 1);
				local p_baimX = gui.GetValue("rbot_pistol_bodyaftershots");
				local p_baimHP = gui.GetValue("rbot_pistol_bodyifhplower");
				local p_hscale = (gui.GetValue("rbot_pistol_hitbox_head_ps") * 100);
				local p_nscale = (gui.GetValue("rbot_pistol_hitbox_neck_ps") * 100);
				local p_cscale = (gui.GetValue("rbot_pistol_hitbox_chest_ps") * 100);
				local p_sscale = (gui.GetValue("rbot_pistol_hitbox_stomach_ps") * 100);
				local p_pscale = (gui.GetValue("rbot_pistol_hitbox_pelvis_ps") * 100);
				local p_ascale = (gui.GetValue("rbot_pistol_hitbox_arms_ps") * 100);
				local p_lscale = (gui.GetValue("rbot_pistol_hitbox_legs_ps") * 100);
				local p_autoscale = gui.GetValue("rbot_pistol_hitbox_auto_ps");
				local p_autoscales = (gui.GetValue("rbot_pistol_hitbox_auto_ps_max") * 100);
				
				SenseUI.Label("Auto wall type");
				p_autowall = SenseUI.Combo("p_autowall", { "Off", "Accurate", "Optimized" }, p_autowall);
				gui.SetValue("rbot_pistol_autowall", p_autowall-1);
				SenseUI.Label("Auto stop");
				local pistol_as = (gui.GetValue("rbot_pistol_autostop") + 1);
				pistol_as = SenseUI.Combo("pistol_as", { "Off", "Full stop", "Minimal speed" }, pistol_as);
				gui.SetValue("rbot_pistol_autostop", pistol_as-1);
				SenseUI.Label("Target selection");
				local pistol_ts = (gui.GetValue("rbot_pistol_mode") + 1);
				pistol_ts = SenseUI.Combo("pistol_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, pistol_ts);
				gui.SetValue("rbot_pistol_mode", pistol_ts-1);
				p_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, p_hitchance);
				gui.SetValue("rbot_pistol_hitchance", p_hitchance);
				p_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, p_mindamage);
				gui.SetValue("rbot_pistol_mindamage", p_mindamage);
				SenseUI.Label("Hitbox priority");
				p_hitprior = SenseUI.Combo("p_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, p_hitprior);
				gui.SetValue("rbot_pistol_hitbox", p_hitprior-1);
				SenseUI.Label("Body aim hitbox");
				p_bodyaim = SenseUI.Combo("p_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, p_bodyaim);
				gui.SetValue("rbot_pistol_hitbox_bodyaim", p_bodyaim-1);
				SenseUI.Label("Hitbox selection method");
				p_method = SenseUI.Combo("p_method", { "Damage", "Accuracy" }, p_method);
				gui.SetValue("rbot_pistol_hitbox_method", p_method-1);
				p_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, p_baimX);
				gui.SetValue("rbot_pistol_bodyaftershots", p_baimX);
				p_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, p_baimHP);
				gui.SetValue("rbot_pistol_bodyifhplower", p_baimHP);
				
				pistol_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, pistol_optimization);
				gui.SetValue("rbot_pistol_hitbox_adaptive", pistol_optimization["Adaptive hitbox"]); 
				gui.SetValue("rbot_pistol_hitbox_optpoints", pistol_optimization["Nearby points"]);
				gui.SetValue("rbot_pistol_hitbox_optbacktrack", pistol_optimization["Backtracking"]);
					else if weapon_select == 2 then
					
					local rev_autowall = (gui.GetValue("rbot_revolver_autowall") + 1);
					local rev_hitchance = gui.GetValue("rbot_revolver_hitchance");
					local rev_mindamage = gui.GetValue("rbot_revolver_mindamage");
					local rev_hitprior = (gui.GetValue("rbot_revolver_hitbox") + 1);
					local rev_bodyaim = (gui.GetValue("rbot_revolver_hitbox_bodyaim") + 1);
					local rev_method = (gui.GetValue("rbot_revolver_hitbox_method") + 1);
					local rev_baimX = gui.GetValue("rbot_revolver_bodyaftershots");
					local rev_baimHP = gui.GetValue("rbot_revolver_bodyifhplower");
					local rev_hscale = (gui.GetValue("rbot_revolver_hitbox_head_ps") * 100);
					local rev_nscale = (gui.GetValue("rbot_revolver_hitbox_neck_ps") * 100);
					local rev_cscale = (gui.GetValue("rbot_revolver_hitbox_chest_ps") * 100);
					local rev_sscale = (gui.GetValue("rbot_revolver_hitbox_stomach_ps") * 100);
					local rev_pscale = (gui.GetValue("rbot_revolver_hitbox_pelvis_ps") * 100);
					local rev_ascale = (gui.GetValue("rbot_revolver_hitbox_arms_ps") * 100);
					local rev_lscale = (gui.GetValue("rbot_revolver_hitbox_legs_ps") * 100);
					local rev_autoscale = gui.GetValue("rbot_revolver_hitbox_auto_ps");
					local rev_autoscales = (gui.GetValue("rbot_revolver_hitbox_auto_ps_max") * 100);
					
					SenseUI.Label("Auto wall type");
					rev_autowall = SenseUI.Combo("rev_autowall", { "Off", "Accurate", "Optimized" }, rev_autowall);
					gui.SetValue("rbot_revolver_autowall", rev_autowall-1);
					SenseUI.Label("Auto stop");
					local revolver_as = (gui.GetValue("rbot_revolver_autostop") + 1);
					revolver_as = SenseUI.Combo("revolver_as", { "Off", "Full stop", "Minimal speed" }, revolver_as);
					gui.SetValue("rbot_revolver_autostop", revolver_as-1);
					SenseUI.Label("Target selection");
					local revolver_ts = (gui.GetValue("rbot_revolver_mode") + 1);
					revolver_ts = SenseUI.Combo("revolver_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, revolver_ts);
					gui.SetValue("rbot_revolver_mode", revolver_ts-1);
					rev_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, rev_hitchance);
					gui.SetValue("rbot_revolver_hitchance", rev_hitchance);
					rev_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, rev_mindamage);
					gui.SetValue("rbot_revolver_mindamage", rev_mindamage);
					SenseUI.Label("Hitbox priority");
					rev_hitprior = SenseUI.Combo("rev_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, rev_hitprior);
					gui.SetValue("rbot_revolver_hitbox", rev_hitprior-1);
					SenseUI.Label("Body aim hitbox");
					rev_bodyaim = SenseUI.Combo("rev_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, rev_bodyaim);
					gui.SetValue("rbot_revolver_hitbox_bodyaim", rev_bodyaim-1);
					SenseUI.Label("Hitbox selection method");
					rev_method = SenseUI.Combo("rev_method", { "Damage", "Accuracy" }, rev_method);
					gui.SetValue("rbot_revolver_hitbox_method", rev_method-1);
					rev_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, rev_baimX);
					gui.SetValue("rbot_revolver_bodyaftershots", rev_baimX);
					rev_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, rev_baimHP);
					gui.SetValue("rbot_revolver_bodyifhplower", rev_baimHP);
				
					revolver_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, revolver_optimization);
					gui.SetValue("rbot_revolver_hitbox_adaptive", revolver_optimization["Adaptive hitbox"]); 
					gui.SetValue("rbot_revolver_hitbox_optpoints", revolver_optimization["Nearby points"]);
					gui.SetValue("rbot_revolver_hitbox_optbacktrack", revolver_optimization["Backtracking"]);
						else if weapon_select == 3 then
						
						local smg_autowall = (gui.GetValue("rbot_smg_autowall") + 1);
						local smg_hitchance = gui.GetValue("rbot_smg_hitchance");
						local smg_mindamage = gui.GetValue("rbot_smg_mindamage");
						local smg_hitprior = (gui.GetValue("rbot_smg_hitbox") + 1);
						local smg_bodyaim = (gui.GetValue("rbot_smg_hitbox_bodyaim") + 1);
						local smg_method = (gui.GetValue("rbot_smg_hitbox_method") + 1);
						local smg_baimX = gui.GetValue("rbot_smg_bodyaftershots");
						local smg_baimHP = gui.GetValue("rbot_smg_bodyifhplower");
						local smg_hscale = (gui.GetValue("rbot_smg_hitbox_head_ps") * 100);
						local smg_nscale = (gui.GetValue("rbot_smg_hitbox_neck_ps") * 100);
						local smg_cscale = (gui.GetValue("rbot_smg_hitbox_chest_ps") * 100);
						local smg_sscale = (gui.GetValue("rbot_smg_hitbox_stomach_ps") * 100);
						local smg_pscale = (gui.GetValue("rbot_smg_hitbox_pelvis_ps") * 100);
						local smg_ascale = (gui.GetValue("rbot_smg_hitbox_arms_ps") * 100);
						local smg_lscale = (gui.GetValue("rbot_smg_hitbox_legs_ps") * 100);
						local smg_autoscale = gui.GetValue("rbot_smg_hitbox_auto_ps");
						local smg_autoscales = (gui.GetValue("rbot_smg_hitbox_auto_ps_max") * 100);
						
						SenseUI.Label("Auto wall type");
						smg_autowall = SenseUI.Combo("smg_autowall", { "Off", "Accurate", "Optimized" }, smg_autowall);
						gui.SetValue("rbot_smg_autowall", smg_autowall-1);
						SenseUI.Label("Auto stop");
						local smg_as = (gui.GetValue("rbot_smg_autostop") + 1);
						smg_as = SenseUI.Combo("smg_as", { "Off", "Full stop", "Minimal speed" }, smg_as);
						gui.SetValue("rbot_smg_autostop", smg_as-1);
						SenseUI.Label("Target selection");
						local smg_ts = (gui.GetValue("rbot_smg_mode") + 1);
						smg_ts = SenseUI.Combo("smg_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, smg_ts);
						gui.SetValue("rbot_smg_mode", smg_ts-1);
						smg_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, smg_hitchance);
						gui.SetValue("rbot_smg_hitchance", smg_hitchance);
						smg_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, smg_mindamage);
						gui.SetValue("rbot_smg_mindamage", smg_mindamage);
						SenseUI.Label("Hitbox priority");
						smg_hitprior = SenseUI.Combo("smg_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, smg_hitprior);
						gui.SetValue("rbot_smg_hitbox", smg_hitprior-1);
						SenseUI.Label("Body aim hitbox");
						smg_bodyaim = SenseUI.Combo("smg_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, smg_bodyaim);
						gui.SetValue("rbot_smg_hitbox_bodyaim", smg_bodyaim-1);
						SenseUI.Label("Hitbox selection method");
						smg_method = SenseUI.Combo("smg_method", { "Damage", "Accuracy" }, smg_method);
						gui.SetValue("rbot_smg_hitbox_method", smg_method-1);
						smg_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, smg_baimX);
						gui.SetValue("rbot_smg_bodyaftershots", smg_baimX);
						smg_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, smg_baimHP);
						gui.SetValue("rbot_smg_bodyifhplower", smg_baimHP);
				
						smg_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, smg_optimization);
						gui.SetValue("rbot_smg_hitbox_adaptive", smg_optimization["Adaptive hitbox"]); 
						gui.SetValue("rbot_smg_hitbox_optpoints", smg_optimization["Nearby points"]);
						gui.SetValue("rbot_smg_hitbox_optbacktrack", smg_optimization["Backtracking"]);
							else if weapon_select == 4 then
							
							local rifle_autowall = (gui.GetValue("rbot_rifle_autowall") + 1);
							local rifle_hitchance = gui.GetValue("rbot_rifle_hitchance");
							local rifle_mindamage = gui.GetValue("rbot_rifle_mindamage");
							local rifle_hitprior = (gui.GetValue("rbot_rifle_hitbox") + 1);
							local rifle_bodyaim = (gui.GetValue("rbot_rifle_hitbox_bodyaim") + 1);
							local rifle_method = (gui.GetValue("rbot_rifle_hitbox_method") + 1);
							local rifle_baimX = gui.GetValue("rbot_rifle_bodyaftershots");
							local rifle_baimHP = gui.GetValue("rbot_rifle_bodyifhplower");
							local rifle_hscale = (gui.GetValue("rbot_rifle_hitbox_head_ps") * 100);
							local rifle_nscale = (gui.GetValue("rbot_rifle_hitbox_neck_ps") * 100);
							local rifle_cscale = (gui.GetValue("rbot_rifle_hitbox_chest_ps") * 100);
							local rifle_sscale = (gui.GetValue("rbot_rifle_hitbox_stomach_ps") * 100);
							local rifle_pscale = (gui.GetValue("rbot_rifle_hitbox_pelvis_ps") * 100);
							local rifle_ascale = (gui.GetValue("rbot_rifle_hitbox_arms_ps") * 100);
							local rifle_lscale = (gui.GetValue("rbot_rifle_hitbox_legs_ps") * 100);
							local rifle_autoscale = gui.GetValue("rbot_rifle_hitbox_auto_ps");
							local rifle_autoscales = (gui.GetValue("rbot_rifle_hitbox_auto_ps_max") * 100);
							
							SenseUI.Label("Auto wall type");
							rifle_autowall = SenseUI.Combo("rifle_autowall", { "Off", "Accurate", "Optimized" }, rifle_autowall);
							gui.SetValue("rbot_rifle_autowall", rifle_autowall-1);
							SenseUI.Label("Auto stop");
							local rifle_as = (gui.GetValue("rbot_rifle_autostop") + 1);
							rifle_as = SenseUI.Combo("rifle_as", { "Off", "Full stop", "Minimal speed" }, rifle_as);
							gui.SetValue("rbot_rifle_autostop", rifle_as-1);
							SenseUI.Label("Target selection");
							local rifle_ts = (gui.GetValue("rbot_rifle_mode") + 1);
							rifle_ts = SenseUI.Combo("rifle_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, rifle_ts);
							gui.SetValue("rbot_rifle_mode", rifle_ts-1);
							rifle_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, rifle_hitchance);
							gui.SetValue("rbot_rifle_hitchance", rifle_hitchance);
							rifle_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, rifle_mindamage);
							gui.SetValue("rbot_rifle_mindamage", rifle_mindamage);
							SenseUI.Label("Hitbox priority");
							rifle_hitprior = SenseUI.Combo("rifle_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, rifle_hitprior);
							gui.SetValue("rbot_rifle_hitbox", rifle_hitprior-1);
							SenseUI.Label("Body aim hitbox");
							rifle_bodyaim = SenseUI.Combo("rifle_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, rifle_bodyaim);
							gui.SetValue("rbot_rifle_hitbox_bodyaim", rifle_bodyaim-1);
							SenseUI.Label("Hitbox selection method");
							rifle_method = SenseUI.Combo("rifle_method", { "Damage", "Accuracy" }, rifle_method);
							gui.SetValue("rbot_rifle_hitbox_method", rifle_method-1);
							rifle_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, rifle_baimX);
							gui.SetValue("rbot_rifle_bodyaftershots", rifle_baimX);
							rifle_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, rifle_baimHP);
							gui.SetValue("rbot_rifle_bodyifhplower", rifle_baimHP);
				
							rifle_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, rifle_optimization);
							gui.SetValue("rbot_rifle_hitbox_adaptive", rifle_optimization["Adaptive hitbox"]); 
							gui.SetValue("rbot_rifle_hitbox_optpoints", rifle_optimization["Nearby points"]);
							gui.SetValue("rbot_rifle_hitbox_optbacktrack", rifle_optimization["Backtracking"]);
								else if weapon_select == 5 then
								
								local shotgun_autowall = (gui.GetValue("rbot_shotgun_autowall") + 1);
								local shotgun_hitchance = gui.GetValue("rbot_shotgun_hitchance");
								local shotgun_mindamage = gui.GetValue("rbot_shotgun_mindamage");
								local shotgun_hitprior = (gui.GetValue("rbot_shotgun_hitbox") + 1);
								local shotgun_bodyaim = (gui.GetValue("rbot_shotgun_hitbox_bodyaim") + 1);
								local shotgun_method = (gui.GetValue("rbot_shotgun_hitbox_method") + 1);
								local shotgun_baimX = gui.GetValue("rbot_shotgun_bodyaftershots");
								local shotgun_baimHP = gui.GetValue("rbot_shotgun_bodyifhplower");
								local shotgun_hscale = (gui.GetValue("rbot_shotgun_hitbox_head_ps") * 100);
								local shotgun_nscale = (gui.GetValue("rbot_shotgun_hitbox_neck_ps") * 100);
								local shotgun_cscale = (gui.GetValue("rbot_shotgun_hitbox_chest_ps") * 100);
								local shotgun_sscale = (gui.GetValue("rbot_shotgun_hitbox_stomach_ps") * 100);
								local shotgun_pscale = (gui.GetValue("rbot_shotgun_hitbox_pelvis_ps") * 100);
								local shotgun_ascale = (gui.GetValue("rbot_shotgun_hitbox_arms_ps") * 100);
								local shotgun_lscale = (gui.GetValue("rbot_shotgun_hitbox_legs_ps") * 100);
								local shotgun_autoscale = gui.GetValue("rbot_shotgun_hitbox_auto_ps");
								local shotgun_autoscales = (gui.GetValue("rbot_shotgun_hitbox_auto_ps_max") * 100);
								
								SenseUI.Label("Auto wall type");
								shotgun_autowall = SenseUI.Combo("shotgun_autowall", { "Off", "Accurate", "Optimized" }, shotgun_autowall);
								gui.SetValue("rbot_shotgun_autowall", shotgun_autowall-1);
								SenseUI.Label("Auto stop");
								local shotgun_as = (gui.GetValue("rbot_shotgun_autostop") + 1);
								shotgun_as = SenseUI.Combo("shotgun_as", { "Off", "Full stop", "Minimal speed" }, shotgun_as);
								gui.SetValue("rbot_shotgun_autostop", shotgun_as-1);
								SenseUI.Label("Target selection");
								local shotgun_ts = (gui.GetValue("rbot_shotgun_mode") + 1);
								shotgun_ts = SenseUI.Combo("shotgun_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, shotgun_ts);
								gui.SetValue("rbot_shotgun_mode", shotgun_ts-1);
								shotgun_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, shotgun_hitchance);
								gui.SetValue("rbot_shotgun_hitchance", shotgun_hitchance);
								shotgun_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, shotgun_mindamage);
								gui.SetValue("rbot_shotgun_mindamage", shotgun_mindamage);
								SenseUI.Label("Hitbox priority");
								shotgun_hitprior = SenseUI.Combo("shotgun_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, shotgun_hitprior);
								gui.SetValue("rbot_shotgun_hitbox", shotgun_hitprior-1);
								SenseUI.Label("Body aim hitbox");
								shotgun_bodyaim = SenseUI.Combo("shotgun_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, shotgun_bodyaim);
								gui.SetValue("rbot_shotgun_hitbox_bodyaim", shotgun_bodyaim-1);
								SenseUI.Label("Hitbox selection method");
								shotgun_method = SenseUI.Combo("shotgun_method", { "Damage", "Accuracy" }, shotgun_method);
								gui.SetValue("rbot_shotgun_hitbox_method", shotgun_method-1);
								shotgun_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, shotgun_baimX);
								gui.SetValue("rbot_shotgun_bodyaftershots", shotgun_baimX);
								shotgun_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, shotgun_baimHP);
								gui.SetValue("rbot_shotgun_bodyifhplower", shotgun_baimHP);
				
								shotgun_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, shotgun_optimization);
								gui.SetValue("rbot_shotgun_hitbox_adaptive", shotgun_optimization["Adaptive hitbox"]); 
								gui.SetValue("rbot_shotgun_hitbox_optpoints", shotgun_optimization["Nearby points"]);
								gui.SetValue("rbot_shotgun_hitbox_optbacktrack", shotgun_optimization["Backtracking"]);
									else if weapon_select == 6 then
									
									local scout_autowall = (gui.GetValue("rbot_scout_autowall") + 1);
									local scout_hitchance = gui.GetValue("rbot_scout_hitchance");
									local scout_mindamage = gui.GetValue("rbot_scout_mindamage");
									local scout_hitprior = (gui.GetValue("rbot_scout_hitbox") + 1);
									local scout_bodyaim = (gui.GetValue("rbot_scout_hitbox_bodyaim") + 1);
									local scout_method = (gui.GetValue("rbot_scout_hitbox_method") + 1);
									local scout_baimX = gui.GetValue("rbot_scout_bodyaftershots");
									local scout_baimHP = gui.GetValue("rbot_scout_bodyifhplower");
									local scout_hscale = (gui.GetValue("rbot_scout_hitbox_head_ps") * 100);
									local scout_nscale = (gui.GetValue("rbot_scout_hitbox_neck_ps") * 100);
									local scout_cscale = (gui.GetValue("rbot_scout_hitbox_chest_ps") * 100);
									local scout_sscale = (gui.GetValue("rbot_scout_hitbox_stomach_ps") * 100);
									local scout_pscale = (gui.GetValue("rbot_scout_hitbox_pelvis_ps") * 100);
									local scout_ascale = (gui.GetValue("rbot_scout_hitbox_arms_ps") * 100);
									local scout_lscale = (gui.GetValue("rbot_scout_hitbox_legs_ps") * 100);
									local scout_autoscale = gui.GetValue("rbot_scout_hitbox_auto_ps");
									local scout_autoscales = (gui.GetValue("rbot_scout_hitbox_auto_ps_max") * 100);
									
									SenseUI.Label("Auto wall type");
									scout_autowall = SenseUI.Combo("scout_autowall", { "Off", "Accurate", "Optimized" }, scout_autowall);
									gui.SetValue("rbot_scout_autowall", scout_autowall-1);
									SenseUI.Label("Auto stop");
									local scout_as = (gui.GetValue("rbot_scout_autostop") + 1);
									scout_as = SenseUI.Combo("scout_as", { "Off", "Full stop", "Minimal speed" }, scout_as);
									gui.SetValue("rbot_scout_autostop", scout_as-1);
									SenseUI.Label("Target selection");
									local scout_ts = (gui.GetValue("rbot_scout_mode") + 1);
									scout_ts = SenseUI.Combo("scout_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, scout_ts);
									gui.SetValue("rbot_scout_mode", scout_ts-1);
									scout_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, scout_hitchance);
									gui.SetValue("rbot_scout_hitchance", scout_hitchance);
									scout_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, scout_mindamage);
									gui.SetValue("rbot_scout_mindamage", scout_mindamage);
									SenseUI.Label("Hitbox priority");
									scout_hitprior = SenseUI.Combo("scout_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, scout_hitprior);
									gui.SetValue("rbot_scout_hitbox", scout_hitprior-1);
									SenseUI.Label("Body aim hitbox");
									scout_bodyaim = SenseUI.Combo("scout_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, scout_bodyaim);
									gui.SetValue("rbot_scout_hitbox_bodyaim", scout_bodyaim-1);
									SenseUI.Label("Hitbox selection method");
									scout_method = SenseUI.Combo("scout_method", { "Damage", "Accuracy" }, scout_method);
									gui.SetValue("rbot_scout_hitbox_method", scout_method-1);
									scout_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, scout_baimX);
									gui.SetValue("rbot_scout_bodyaftershots", scout_baimX);
									scout_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, scout_baimHP);
									gui.SetValue("rbot_scout_bodyifhplower", scout_baimHP);	
				
									scout_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, scout_optimization);
									gui.SetValue("rbot_scout_hitbox_adaptive", scout_optimization["Adaptive hitbox"]); 
									gui.SetValue("rbot_scout_hitbox_optpoints", scout_optimization["Nearby points"]);
									gui.SetValue("rbot_scout_hitbox_optbacktrack", scout_optimization["Backtracking"]);								
										else if weapon_select == 7 then
										
										local autosniper_autowall = (gui.GetValue("rbot_autosniper_autowall") + 1);
										local autosniper_hitchance = gui.GetValue("rbot_autosniper_hitchance");
										local autosniper_mindamage = gui.GetValue("rbot_autosniper_mindamage");
										local autosniper_hitprior = (gui.GetValue("rbot_autosniper_hitbox") + 1);
										local autosniper_bodyaim = (gui.GetValue("rbot_autosniper_hitbox_bodyaim") + 1);
										local autosniper_method = (gui.GetValue("rbot_autosniper_hitbox_method") + 1);
										local autosniper_baimX = gui.GetValue("rbot_autosniper_bodyaftershots");
										local autosniper_baimHP = gui.GetValue("rbot_autosniper_bodyifhplower");
										local autosniper_hscale = (gui.GetValue("rbot_autosniper_hitbox_head_ps") * 100);
										local autosniper_nscale = (gui.GetValue("rbot_autosniper_hitbox_neck_ps") * 100);
										local autosniper_cscale = (gui.GetValue("rbot_autosniper_hitbox_chest_ps") * 100);
										local autosniper_sscale = (gui.GetValue("rbot_autosniper_hitbox_stomach_ps") * 100);
										local autosniper_pscale = (gui.GetValue("rbot_autosniper_hitbox_pelvis_ps") * 100);
										local autosniper_ascale = (gui.GetValue("rbot_autosniper_hitbox_arms_ps") * 100);
										local autosniper_lscale = (gui.GetValue("rbot_autosniper_hitbox_legs_ps") * 100);
										local autosniper_autoscale = gui.GetValue("rbot_autosniper_hitbox_auto_ps");
										local autosniper_autoscales = (gui.GetValue("rbot_autosniper_hitbox_auto_ps_max") * 100);
										
										SenseUI.Label("Auto wall type");
										autosniper_autowall = SenseUI.Combo("autosniper_autowall", { "Off", "Accurate", "Optimized" }, autosniper_autowall);
										gui.SetValue("rbot_autosniper_autowall", autosniper_autowall-1);
										SenseUI.Label("Auto stop");
										local autosniper_as = (gui.GetValue("rbot_autosniper_autostop") + 1);
										autosniper_as = SenseUI.Combo("autosniper_as", { "Off", "Full stop", "Minimal speed" }, autosniper_as);
										gui.SetValue("rbot_autosniper_autostop", autosniper_as-1);
										SenseUI.Label("Target selection");
										local autosniper_ts = (gui.GetValue("rbot_autosniper_mode") + 1);
										autosniper_ts = SenseUI.Combo("autosniper_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, autosniper_ts);
										gui.SetValue("rbot_autosniper_mode", autosniper_ts-1);
										autosniper_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, autosniper_hitchance);
										gui.SetValue("rbot_autosniper_hitchance", autosniper_hitchance);
										autosniper_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, autosniper_mindamage);
										gui.SetValue("rbot_autosniper_mindamage", autosniper_mindamage);
										SenseUI.Label("Hitbox priority");
										autosniper_hitprior = SenseUI.Combo("autosniper_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, autosniper_hitprior);
										gui.SetValue("rbot_autosniper_hitbox", autosniper_hitprior-1);
										SenseUI.Label("Body aim hitbox");
										autosniper_bodyaim = SenseUI.Combo("autosniper_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, autosniper_bodyaim);
										gui.SetValue("rbot_autosniper_hitbox_bodyaim", autosniper_bodyaim-1);
										SenseUI.Label("Hitbox selection method");
										autosniper_method = SenseUI.Combo("autosniper_method", { "Damage", "Accuracy" }, autosniper_method);
										gui.SetValue("rbot_autosniper_hitbox_method", autosniper_method-1);
										autosniper_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, autosniper_baimX);
										gui.SetValue("rbot_autosniper_bodyaftershots", autosniper_baimX);
										autosniper_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, autosniper_baimHP);
										gui.SetValue("rbot_autosniper_bodyifhplower", autosniper_baimHP);
				
										autosniper_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, autosniper_optimization);
										gui.SetValue("rbot_autosniper_hitbox_adaptive", autosniper_optimization["Adaptive hitbox"]); 
										gui.SetValue("rbot_autosniper_hitbox_optpoints", autosniper_optimization["Nearby points"]);
										gui.SetValue("rbot_autosniper_hitbox_optbacktrack", autosniper_optimization["Backtracking"]);										
											else if weapon_select == 8 then
											
											local sniper_autowall = (gui.GetValue("rbot_sniper_autowall") + 1);
											local sniper_hitchance = gui.GetValue("rbot_sniper_hitchance");
											local sniper_mindamage = gui.GetValue("rbot_sniper_mindamage");
											local sniper_hitprior = (gui.GetValue("rbot_sniper_hitbox") + 1);
											local sniper_bodyaim = (gui.GetValue("rbot_sniper_hitbox_bodyaim") + 1);
											local sniper_method = (gui.GetValue("rbot_sniper_hitbox_method") + 1);
											local sniper_baimX = gui.GetValue("rbot_sniper_bodyaftershots");
											local sniper_baimHP = gui.GetValue("rbot_sniper_bodyifhplower");
											local sniper_hscale = (gui.GetValue("rbot_sniper_hitbox_head_ps") * 100);
											local sniper_nscale = (gui.GetValue("rbot_sniper_hitbox_neck_ps") * 100);
											local sniper_cscale = (gui.GetValue("rbot_sniper_hitbox_chest_ps") * 100);
											local sniper_sscale = (gui.GetValue("rbot_sniper_hitbox_stomach_ps") * 100);
											local sniper_pscale = (gui.GetValue("rbot_sniper_hitbox_pelvis_ps") * 100);
											local sniper_ascale = (gui.GetValue("rbot_sniper_hitbox_arms_ps") * 100);
											local sniper_lscale = (gui.GetValue("rbot_sniper_hitbox_legs_ps") * 100);
											local sniper_autoscale = gui.GetValue("rbot_sniper_hitbox_auto_ps");
											local sniper_autoscales = (gui.GetValue("rbot_sniper_hitbox_auto_ps_max") * 100);
											
											SenseUI.Label("Auto wall type");
											sniper_autowall = SenseUI.Combo("sniper_autowall", { "Off", "Accurate", "Optimized" }, sniper_autowall);
											gui.SetValue("rbot_sniper_autowall", sniper_autowall-1);
											SenseUI.Label("Auto stop");
											local sniper_as = (gui.GetValue("rbot_sniper_autostop") + 1);
											sniper_as = SenseUI.Combo("sniper_as", { "Off", "Full stop", "Minimal speed" }, sniper_as);
											gui.SetValue("rbot_sniper_autostop", sniper_as-1);
											SenseUI.Label("Target selection");
											local sniper_ts = (gui.GetValue("rbot_sniper_mode") + 1);
											sniper_ts = SenseUI.Combo("sniper_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, sniper_ts);
											gui.SetValue("rbot_sniper_mode", sniper_ts-1);
											sniper_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, sniper_hitchance);
											gui.SetValue("rbot_sniper_hitchance", sniper_hitchance);
											sniper_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, sniper_mindamage);
											gui.SetValue("rbot_sniper_mindamage", sniper_mindamage);
											SenseUI.Label("Hitbox priority");
											sniper_hitprior = SenseUI.Combo("sniper_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, sniper_hitprior);
											gui.SetValue("rbot_sniper_hitbox", sniper_hitprior-1);
											SenseUI.Label("Body aim hitbox");
											sniper_bodyaim = SenseUI.Combo("sniper_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, sniper_bodyaim);
											gui.SetValue("rbot_sniper_hitbox_bodyaim", sniper_bodyaim-1);
											SenseUI.Label("Hitbox selection method");
											sniper_method = SenseUI.Combo("sniper_method", { "Damage", "Accuracy" }, sniper_method);
											gui.SetValue("rbot_sniper_hitbox_method", sniper_method-1);
											sniper_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, sniper_baimX);
											gui.SetValue("rbot_sniper_bodyaftershots", sniper_baimX);
											sniper_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, sniper_baimHP);
											gui.SetValue("rbot_sniper_bodyifhplower", sniper_baimHP);
				
											sniper_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, sniper_optimization);
											gui.SetValue("rbot_sniper_hitbox_adaptive", sniper_optimization["Adaptive hitbox"]); 
											gui.SetValue("rbot_sniper_hitbox_optpoints", sniper_optimization["Nearby points"]);
											gui.SetValue("rbot_sniper_hitbox_optbacktrack", sniper_optimization["Backtracking"]);
												else if weapon_select == 9 then
												
												local lmg_autowall = (gui.GetValue("rbot_lmg_autowall") + 1);
												local lmg_hitchance = gui.GetValue("rbot_lmg_hitchance");
												local lmg_mindamage = gui.GetValue("rbot_lmg_mindamage");
												local lmg_hitprior = (gui.GetValue("rbot_lmg_hitbox") + 1);
												local lmg_bodyaim = (gui.GetValue("rbot_lmg_hitbox_bodyaim") + 1);
												local lmg_method = (gui.GetValue("rbot_lmg_hitbox_method") + 1);
												local lmg_baimX = gui.GetValue("rbot_lmg_bodyaftershots");
												local lmg_baimHP = gui.GetValue("rbot_lmg_bodyifhplower");
												local lmg_hscale = (gui.GetValue("rbot_lmg_hitbox_head_ps") * 100);
												local lmg_nscale = (gui.GetValue("rbot_lmg_hitbox_neck_ps") * 100);
												local lmg_cscale = (gui.GetValue("rbot_lmg_hitbox_chest_ps") * 100);
												local lmg_sscale = (gui.GetValue("rbot_lmg_hitbox_stomach_ps") * 100);
												local lmg_pscale = (gui.GetValue("rbot_lmg_hitbox_pelvis_ps") * 100);
												local lmg_ascale = (gui.GetValue("rbot_lmg_hitbox_arms_ps") * 100);
												local lmg_lscale = (gui.GetValue("rbot_lmg_hitbox_legs_ps") * 100);
												local lmg_autoscale = gui.GetValue("rbot_lmg_hitbox_auto_ps");
												local lmg_autoscales = (gui.GetValue("rbot_lmg_hitbox_auto_ps_max") * 100);
												
												SenseUI.Label("Auto wall type");
												lmg_autowall = SenseUI.Combo("lmg_autowall", { "Off", "Accurate", "Optimized" }, lmg_autowall);
												gui.SetValue("rbot_lmg_autowall", lmg_autowall-1);
												SenseUI.Label("Auto stop");
												local lmg_as = (gui.GetValue("rbot_lmg_autostop") + 1);
												lmg_as = SenseUI.Combo("lmg_as", { "Off", "Full stop", "Minimal speed" }, lmg_as);
												gui.SetValue("rbot_lmg_autostop", lmg_as-1);
												SenseUI.Label("Target selection");
												local lmg_ts = (gui.GetValue("rbot_lmg_mode") + 1);
												lmg_ts = SenseUI.Combo("lmg_ts", { "FOV", "Distance", "Next shot", "Lowest health", "Highest damage", "Lowest latency" }, lmg_ts);
												gui.SetValue("rbot_lmg_mode", lmg_ts-1);
												lmg_hitchance = SenseUI.Slider("Hit chance", 0, 100, "%", "0%", "100%", false, lmg_hitchance);
												gui.SetValue("rbot_lmg_hitchance", lmg_hitchance);
												lmg_mindamage = SenseUI.Slider("Minimal damage", 0, 100, "", "0", "100", false, lmg_mindamage);
												gui.SetValue("rbot_lmg_mindamage", lmg_mindamage);
												SenseUI.Label("Hitbox priority");
												lmg_hitprior = SenseUI.Combo("lmg_hitprior", { "Head", "Neck", "Check", "Stomach", "Pelvis", "Center" }, lmg_hitprior);
												gui.SetValue("rbot_lmg_hitbox", lmg_hitprior-1);
												SenseUI.Label("Body aim hitbox");
												lmg_bodyaim = SenseUI.Combo("lmg_bodyaim", { "Pelvis", "Pelvis + Edges", "Center" }, lmg_bodyaim);
												gui.SetValue("rbot_lmg_hitbox_bodyaim", lmg_bodyaim-1);
												SenseUI.Label("Hitbox selection method");
												lmg_method = SenseUI.Combo("lmg_method", { "Damage", "Accuracy" }, lmg_method);
												gui.SetValue("rbot_lmg_hitbox_method", lmg_method-1);
												lmg_baimX = SenseUI.Slider("Body aim after X shots", 0, 15, "", "0", "15", false, lmg_baimX);
												gui.SetValue("rbot_lmg_bodyaftershots", lmg_baimX);
												lmg_baimHP = SenseUI.Slider("Body aim if HP lower than", 0, 100, "", "0", "100", false, lmg_baimHP);
												gui.SetValue("rbot_lmg_bodyifhplower", lmg_baimHP);	
				
												lmg_optimization = SenseUI.MultiCombo("Hitscan optimization", { "Adaptive hitbox", "Nearby points", "Backtracking" }, lmg_optimization);
												gui.SetValue("rbot_lmg_hitbox_adaptive", lmg_optimization["Adaptive hitbox"]); 
												gui.SetValue("rbot_lmg_hitbox_optpoints", lmg_optimization["Nearby points"]);
												gui.SetValue("rbot_lmg_hitbox_optbacktrack", lmg_optimization["Backtracking"]);
												end
											end
										end
									end
								end
							end
						end
					end
				end
			SenseUI.EndGroup();
			end
			if SenseUI.BeginGroup( "mainaim", "Rage Aimbot", 285, 350, 235, 275 ) then
				local switch_enabled = gui.GetValue("rbot_active");
				switch_enabled = SenseUI.Checkbox( "Enabled", switch_enabled );
				if switch_enabled then
					gui.SetValue("rbot_active", 1);
					gui.SetValue("rbot_enable", 1);
					else
					gui.SetValue("rbot_enable", 0);
					gui.SetValue("rbot_active", 0);
				end
				local fov_rr = gui.GetValue("rbot_fov");
				fov_rr = SenseUI.Slider("FOV range", 0, 180, "°", "0°", "180°", false, fov_rr);
				gui.SetValue("rbot_fov", fov_rr);
				local s_limit = (gui.GetValue("rbot_speedlimit") + 1);
				SenseUI.Label("Speed limit");
				s_limit = SenseUI.Combo("Speed limit", { "Off", "On", "Auto" }, s_limit);
				gui.SetValue("rbot_speedlimit", s_limit-1);
				SenseUI.Label("Silent aim");
				local sa_rage = (gui.GetValue("rbot_silentaim") + 1);
				sa_rage = SenseUI.Combo("Sa_rage", { "Off", "Client-side", "Server-side" }, sa_rage);
				gui.SetValue("rbot_silentaim", sa_rage-1);
				local ff_rage = gui.GetValue("rbot_team");
				ff_rage = SenseUI.Checkbox("Friendly fire", ff_rage);
				gui.SetValue("rbot_team", ff_rage);
				local aimlock = gui.GetValue("rbot_aimlock");
				aimlock = SenseUI.Checkbox("Aim lock", aimlock);
				gui.SetValue("rbot_aimlock", aimlock);
				SenseUI.Label("Position adjustment");
				local pa_rage = (gui.GetValue("rbot_positionadjustment") + 1);
				pa_rage = SenseUI.Combo("PA_rage", { "Off", "Low", "Medium", "High", "Very high", "Adaptive", "Last record" }, pa_rage);
				gui.SetValue("rbot_positionadjustment", pa_rage-1);
				local override_resolver = gui.GetValue("rbot_resolver_override");
				local resolver = gui.GetValue("rbot_resolver");
				resolver = SenseUI.Checkbox("Resolver", resolver);
				gui.SetValue("rbot_resolver", resolver);
				override_resolver = SenseUI.Bind("rrresolv", true, override_resolver);
				gui.SetValue("rbot_resolver_override", override_resolver);
				local taser_hc = gui.GetValue("rbot_taser_hitchance");
				taser_hc = SenseUI.Slider("Taser hit chance", 0, 100, "%", "0%", "100%", false, taser_hc);
				gui.SetValue("rbot_taser_hitchance", taser_hc);
				SenseUI.EndGroup();
			end
			if SenseUI.BeginGroup( "hitscans", "Hitscan", 285, 25, 235, 300 ) then
				if weapon_select == 1 then
				
				local p_autowall = (gui.GetValue("rbot_pistol_autowall") + 1);
				local p_hitchance = gui.GetValue("rbot_pistol_hitchance");
				local p_mindamage = gui.GetValue("rbot_pistol_mindamage");
				local p_hitprior = (gui.GetValue("rbot_pistol_hitbox") + 1);
				local p_bodyaim = (gui.GetValue("rbot_pistol_hitbox_bodyaim") + 1);
				local p_method = (gui.GetValue("rbot_pistol_hitbox_method") + 1);
				local p_baimX = gui.GetValue("rbot_pistol_bodyaftershots");
				local p_baimHP = gui.GetValue("rbot_pistol_bodyifhplower");
				local p_hscale = (gui.GetValue("rbot_pistol_hitbox_head_ps") * 100);
				local p_nscale = (gui.GetValue("rbot_pistol_hitbox_neck_ps") * 100);
				local p_cscale = (gui.GetValue("rbot_pistol_hitbox_chest_ps") * 100);
				local p_sscale = (gui.GetValue("rbot_pistol_hitbox_stomach_ps") * 100);
				local p_pscale = (gui.GetValue("rbot_pistol_hitbox_pelvis_ps") * 100);
				local p_ascale = (gui.GetValue("rbot_pistol_hitbox_arms_ps") * 100);
				local p_lscale = (gui.GetValue("rbot_pistol_hitbox_legs_ps") * 100);
				local p_autoscale = gui.GetValue("rbot_pistol_hitbox_auto_ps");
				local p_autoscales = (gui.GetValue("rbot_pistol_hitbox_auto_ps_max") * 100);
				
				pistol_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, pistol_hitboxes);
				gui.SetValue("rbot_pistol_hitbox_head", pistol_hitboxes["Head"]);
				gui.SetValue("rbot_pistol_hitbox_neck", pistol_hitboxes["Neck"]);
				gui.SetValue("rbot_pistol_hitbox_chest", pistol_hitboxes["Chest"]);
				gui.SetValue("rbot_pistol_hitbox_stomach", pistol_hitboxes["Stomach"]);
				gui.SetValue("rbot_pistol_hitbox_pelvis", pistol_hitboxes["Pelvis"]);
				gui.SetValue("rbot_pistol_hitbox_arms", pistol_hitboxes["Arms"]);
				gui.SetValue("rbot_pistol_hitbox_legs", pistol_hitboxes["Legs"]);
				
				p_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, p_hscale);
				gui.SetValue("rbot_pistol_hitbox_head_ps", p_hscale / 100);
				p_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, p_nscale);
				gui.SetValue("rbot_pistol_hitbox_neck_ps", p_nscale / 100);
				p_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, p_cscale);
				gui.SetValue("rbot_pistol_hitbox_chest_ps", p_cscale / 100);
				p_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, p_sscale);
				gui.SetValue("rbot_pistol_hitbox_stomach_ps", p_sscale / 100);
				p_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, p_pscale);
				gui.SetValue("rbot_pistol_hitbox_pelvis_ps", p_pscale / 100);
				p_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, p_ascale);
				gui.SetValue("rbot_pistol_hitbox_arms_ps", p_ascale / 100);
				p_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, p_lscale);
				gui.SetValue("rbot_pistol_hitbox_legs_ps", p_lscale / 100);
				p_autoscale = SenseUI.Checkbox("Auto scale", p_autoscale);
				gui.SetValue("rbot_pistol_hitbox_auto_ps", p_autoscale);
				p_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, p_autoscales);
				gui.SetValue("rbot_pistol_hitbox_auto_ps_max", p_autoscales / 100);
					else if weapon_select == 2 then
					
					local rev_autowall = (gui.GetValue("rbot_revolver_autowall") + 1);
					local rev_hitchance = gui.GetValue("rbot_revolver_hitchance");
					local rev_mindamage = gui.GetValue("rbot_revolver_mindamage");
					local rev_hitprior = (gui.GetValue("rbot_revolver_hitbox") + 1);
					local rev_bodyaim = (gui.GetValue("rbot_revolver_hitbox_bodyaim") + 1);
					local rev_method = (gui.GetValue("rbot_revolver_hitbox_method") + 1);
					local rev_baimX = gui.GetValue("rbot_revolver_bodyaftershots");
					local rev_baimHP = gui.GetValue("rbot_revolver_bodyifhplower");
					local rev_hscale = (gui.GetValue("rbot_revolver_hitbox_head_ps") * 100);
					local rev_nscale = (gui.GetValue("rbot_revolver_hitbox_neck_ps") * 100);
					local rev_cscale = (gui.GetValue("rbot_revolver_hitbox_chest_ps") * 100);
					local rev_sscale = (gui.GetValue("rbot_revolver_hitbox_stomach_ps") * 100);
					local rev_pscale = (gui.GetValue("rbot_revolver_hitbox_pelvis_ps") * 100);
					local rev_ascale = (gui.GetValue("rbot_revolver_hitbox_arms_ps") * 100);
					local rev_lscale = (gui.GetValue("rbot_revolver_hitbox_legs_ps") * 100);
					local rev_autoscale = gui.GetValue("rbot_revolver_hitbox_auto_ps");
					local rev_autoscales = (gui.GetValue("rbot_revolver_hitbox_auto_ps_max") * 100);
				
					revolver_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, revolver_hitboxes);
					gui.SetValue("rbot_revolver_hitbox_head", revolver_hitboxes["Head"]);
					gui.SetValue("rbot_revolver_hitbox_neck", revolver_hitboxes["Neck"]);
					gui.SetValue("rbot_revolver_hitbox_chest", revolver_hitboxes["Chest"]);
					gui.SetValue("rbot_revolver_hitbox_stomach", revolver_hitboxes["Stomach"]);
					gui.SetValue("rbot_revolver_hitbox_pelvis", revolver_hitboxes["Pelvis"]);
					gui.SetValue("rbot_revolver_hitbox_arms", revolver_hitboxes["Arms"]);
					gui.SetValue("rbot_revolver_hitbox_legs", revolver_hitboxes["Legs"]);
					
					rev_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, rev_hscale);
					gui.SetValue("rbot_revolver_hitbox_head_ps", rev_hscale / 100);
					rev_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, rev_nscale);
					gui.SetValue("rbot_revolver_hitbox_neck_ps", rev_nscale / 100);
					rev_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, rev_cscale);
					gui.SetValue("rbot_revolver_hitbox_chest_ps", rev_cscale / 100);
					rev_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, rev_sscale);
					gui.SetValue("rbot_revolver_hitbox_stomach_ps", rev_sscale / 100);
					rev_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, rev_pscale);
					gui.SetValue("rbot_revolver_hitbox_pelvis_ps", rev_pscale / 100);
					rev_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, rev_ascale);
					gui.SetValue("rbot_revolver_hitbox_arms_ps", rev_ascale / 100);
					rev_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, rev_lscale);
					gui.SetValue("rbot_revolver_hitbox_legs_ps", rev_lscale / 100);
					rev_autoscale = SenseUI.Checkbox("Auto scale", rev_autoscale);
					gui.SetValue("rbot_revolver_hitbox_auto_ps", rev_autoscale);
					rev_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, rev_autoscales);
					gui.SetValue("rbot_revolver_hitbox_auto_ps_max", rev_autoscales / 100);
						else if weapon_select == 3 then
						
						local smg_autowall = (gui.GetValue("rbot_smg_autowall") + 1);
						local smg_hitchance = gui.GetValue("rbot_smg_hitchance");
						local smg_mindamage = gui.GetValue("rbot_smg_mindamage");
						local smg_hitprior = (gui.GetValue("rbot_smg_hitbox") + 1);
						local smg_bodyaim = (gui.GetValue("rbot_smg_hitbox_bodyaim") + 1);
						local smg_method = (gui.GetValue("rbot_smg_hitbox_method") + 1);
						local smg_baimX = gui.GetValue("rbot_smg_bodyaftershots");
						local smg_baimHP = gui.GetValue("rbot_smg_bodyifhplower");
						local smg_hscale = (gui.GetValue("rbot_smg_hitbox_head_ps") * 100);
						local smg_nscale = (gui.GetValue("rbot_smg_hitbox_neck_ps") * 100);
						local smg_cscale = (gui.GetValue("rbot_smg_hitbox_chest_ps") * 100);
						local smg_sscale = (gui.GetValue("rbot_smg_hitbox_stomach_ps") * 100);
						local smg_pscale = (gui.GetValue("rbot_smg_hitbox_pelvis_ps") * 100);
						local smg_ascale = (gui.GetValue("rbot_smg_hitbox_arms_ps") * 100);
						local smg_lscale = (gui.GetValue("rbot_smg_hitbox_legs_ps") * 100);
						local smg_autoscale = gui.GetValue("rbot_smg_hitbox_auto_ps");
						local smg_autoscales = (gui.GetValue("rbot_smg_hitbox_auto_ps_max") * 100);
				
						smg_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, smg_hitboxes);
						gui.SetValue("rbot_smg_hitbox_head", smg_hitboxes["Head"]);
						gui.SetValue("rbot_smg_hitbox_neck", smg_hitboxes["Neck"]);
						gui.SetValue("rbot_smg_hitbox_chest", smg_hitboxes["Chest"]);
						gui.SetValue("rbot_smg_hitbox_stomach", smg_hitboxes["Stomach"]);
						gui.SetValue("rbot_smg_hitbox_pelvis", smg_hitboxes["Pelvis"]);
						gui.SetValue("rbot_smg_hitbox_arms", smg_hitboxes["Arms"]);
						gui.SetValue("rbot_smg_hitbox_legs", smg_hitboxes["Legs"]);
						
						smg_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, smg_hscale);
						gui.SetValue("rbot_smg_hitbox_head_ps", smg_hscale / 100);
						smg_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, smg_nscale);
						gui.SetValue("rbot_smg_hitbox_neck_ps", smg_nscale / 100);
						smg_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, smg_cscale);
						gui.SetValue("rbot_smg_hitbox_chest_ps", smg_cscale / 100);
						smg_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, smg_sscale);
						gui.SetValue("rbot_smg_hitbox_stomach_ps", smg_sscale / 100);
						smg_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, smg_pscale);
						gui.SetValue("rbot_smg_hitbox_pelvis_ps", smg_pscale / 100);
						smg_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, smg_ascale);
						gui.SetValue("rbot_smg_hitbox_arms_ps", smg_ascale / 100);
						smg_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, smg_lscale);
						gui.SetValue("rbot_smg_hitbox_legs_ps", smg_lscale / 100);
						smg_autoscale = SenseUI.Checkbox("Auto scale", smg_autoscale);
						gui.SetValue("rbot_smg_hitbox_auto_ps", smg_autoscale);
						smg_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, smg_autoscales);
						gui.SetValue("rbot_smg_hitbox_auto_ps_max", smg_autoscales / 100);						
							else if weapon_select == 4 then
							
							local rifle_autowall = (gui.GetValue("rbot_rifle_autowall") + 1);
							local rifle_hitchance = gui.GetValue("rbot_rifle_hitchance");
							local rifle_mindamage = gui.GetValue("rbot_rifle_mindamage");
							local rifle_hitprior = (gui.GetValue("rbot_rifle_hitbox") + 1);
							local rifle_bodyaim = (gui.GetValue("rbot_rifle_hitbox_bodyaim") + 1);
							local rifle_method = (gui.GetValue("rbot_rifle_hitbox_method") + 1);
							local rifle_baimX = gui.GetValue("rbot_rifle_bodyaftershots");
							local rifle_baimHP = gui.GetValue("rbot_rifle_bodyifhplower");
							local rifle_hscale = (gui.GetValue("rbot_rifle_hitbox_head_ps") * 100);
							local rifle_nscale = (gui.GetValue("rbot_rifle_hitbox_neck_ps") * 100);
							local rifle_cscale = (gui.GetValue("rbot_rifle_hitbox_chest_ps") * 100);
							local rifle_sscale = (gui.GetValue("rbot_rifle_hitbox_stomach_ps") * 100);
							local rifle_pscale = (gui.GetValue("rbot_rifle_hitbox_pelvis_ps") * 100);
							local rifle_ascale = (gui.GetValue("rbot_rifle_hitbox_arms_ps") * 100);
							local rifle_lscale = (gui.GetValue("rbot_rifle_hitbox_legs_ps") * 100);
							local rifle_autoscale = gui.GetValue("rbot_rifle_hitbox_auto_ps");
							local rifle_autoscales = (gui.GetValue("rbot_rifle_hitbox_auto_ps_max") * 100);
				
							rifle_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, rifle_hitboxes);
							gui.SetValue("rbot_rifle_hitbox_head", rifle_hitboxes["Head"]);
							gui.SetValue("rbot_rifle_hitbox_neck", rifle_hitboxes["Neck"]);
							gui.SetValue("rbot_rifle_hitbox_chest", rifle_hitboxes["Chest"]);
							gui.SetValue("rbot_rifle_hitbox_stomach", rifle_hitboxes["Stomach"]);
							gui.SetValue("rbot_rifle_hitbox_pelvis", rifle_hitboxes["Pelvis"]);
							gui.SetValue("rbot_rifle_hitbox_arms", rifle_hitboxes["Arms"]);
							gui.SetValue("rbot_rifle_hitbox_legs", rifle_hitboxes["Legs"]);
							
							rifle_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, rifle_hscale);
							gui.SetValue("rbot_rifle_hitbox_head_ps", rifle_hscale / 100);
							rifle_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, rifle_nscale);
							gui.SetValue("rbot_rifle_hitbox_neck_ps", rifle_nscale / 100);
							rifle_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, rifle_cscale);
							gui.SetValue("rbot_rifle_hitbox_chest_ps", rifle_cscale / 100);
							rifle_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, rifle_sscale);
							gui.SetValue("rbot_rifle_hitbox_stomach_ps", rifle_sscale / 100);
							rifle_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, rifle_pscale);
							gui.SetValue("rbot_rifle_hitbox_pelvis_ps", rifle_pscale / 100);
							rifle_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, rifle_ascale);
							gui.SetValue("rbot_rifle_hitbox_arms_ps", rifle_ascale / 100);
							rifle_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, rifle_lscale);
							gui.SetValue("rbot_rifle_hitbox_legs_ps", rifle_lscale / 100);
							rifle_autoscale = SenseUI.Checkbox("Auto scale", rifle_autoscale);
							gui.SetValue("rbot_rifle_hitbox_auto_ps", rifle_autoscale);
							rifle_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, rifle_autoscales);
							gui.SetValue("rbot_rifle_hitbox_auto_ps_max", rifle_autoscales / 100);
								else if weapon_select == 5 then
								
								local shotgun_autowall = (gui.GetValue("rbot_shotgun_autowall") + 1);
								local shotgun_hitchance = gui.GetValue("rbot_shotgun_hitchance");
								local shotgun_mindamage = gui.GetValue("rbot_shotgun_mindamage");
								local shotgun_hitprior = (gui.GetValue("rbot_shotgun_hitbox") + 1);
								local shotgun_bodyaim = (gui.GetValue("rbot_shotgun_hitbox_bodyaim") + 1);
								local shotgun_method = (gui.GetValue("rbot_shotgun_hitbox_method") + 1);
								local shotgun_baimX = gui.GetValue("rbot_shotgun_bodyaftershots");
								local shotgun_baimHP = gui.GetValue("rbot_shotgun_bodyifhplower");
								local shotgun_hscale = (gui.GetValue("rbot_shotgun_hitbox_head_ps") * 100);
								local shotgun_nscale = (gui.GetValue("rbot_shotgun_hitbox_neck_ps") * 100);
								local shotgun_cscale = (gui.GetValue("rbot_shotgun_hitbox_chest_ps") * 100);
								local shotgun_sscale = (gui.GetValue("rbot_shotgun_hitbox_stomach_ps") * 100);
								local shotgun_pscale = (gui.GetValue("rbot_shotgun_hitbox_pelvis_ps") * 100);
								local shotgun_ascale = (gui.GetValue("rbot_shotgun_hitbox_arms_ps") * 100);
								local shotgun_lscale = (gui.GetValue("rbot_shotgun_hitbox_legs_ps") * 100);
								local shotgun_autoscale = gui.GetValue("rbot_shotgun_hitbox_auto_ps");
								local shotgun_autoscales = (gui.GetValue("rbot_shotgun_hitbox_auto_ps_max") * 100);
				
								shotgun_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, shotgun_hitboxes);
								gui.SetValue("rbot_shotgun_hitbox_head", shotgun_hitboxes["Head"]);
								gui.SetValue("rbot_shotgun_hitbox_neck", shotgun_hitboxes["Neck"]);
								gui.SetValue("rbot_shotgun_hitbox_chest", shotgun_hitboxes["Chest"]);
								gui.SetValue("rbot_shotgun_hitbox_stomach", shotgun_hitboxes["Stomach"]);
								gui.SetValue("rbot_shotgun_hitbox_pelvis", shotgun_hitboxes["Pelvis"]);
								gui.SetValue("rbot_shotgun_hitbox_arms", shotgun_hitboxes["Arms"]);
								gui.SetValue("rbot_shotgun_hitbox_legs", shotgun_hitboxes["Legs"]);
								
								shotgun_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, shotgun_hscale);
								gui.SetValue("rbot_shotgun_hitbox_head_ps", shotgun_hscale / 100);
								shotgun_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, shotgun_nscale);
								gui.SetValue("rbot_shotgun_hitbox_neck_ps", shotgun_nscale / 100);
								shotgun_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, shotgun_cscale);
								gui.SetValue("rbot_shotgun_hitbox_chest_ps", shotgun_cscale / 100);
								shotgun_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, shotgun_sscale);
								gui.SetValue("rbot_shotgun_hitbox_stomach_ps", shotgun_sscale / 100);
								shotgun_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, shotgun_pscale);
								gui.SetValue("rbot_shotgun_hitbox_pelvis_ps", shotgun_pscale / 100);
								shotgun_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, shotgun_ascale);
								gui.SetValue("rbot_shotgun_hitbox_arms_ps", shotgun_ascale / 100);
								shotgun_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, shotgun_lscale);
								gui.SetValue("rbot_shotgun_hitbox_legs_ps", shotgun_lscale / 100);
								shotgun_autoscale = SenseUI.Checkbox("Auto scale", shotgun_autoscale);
								gui.SetValue("rbot_shotgun_hitbox_auto_ps", shotgun_autoscale);
								shotgun_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, shotgun_autoscales);
								gui.SetValue("rbot_shotgun_hitbox_auto_ps_max", shotgun_autoscales / 100);
									else if weapon_select == 6 then
									
									local scout_autowall = (gui.GetValue("rbot_scout_autowall") + 1);
									local scout_hitchance = gui.GetValue("rbot_scout_hitchance");
									local scout_mindamage = gui.GetValue("rbot_scout_mindamage");
									local scout_hitprior = (gui.GetValue("rbot_scout_hitbox") + 1);
									local scout_bodyaim = (gui.GetValue("rbot_scout_hitbox_bodyaim") + 1);
									local scout_method = (gui.GetValue("rbot_scout_hitbox_method") + 1);
									local scout_baimX = gui.GetValue("rbot_scout_bodyaftershots");
									local scout_baimHP = gui.GetValue("rbot_scout_bodyifhplower");
									local scout_hscale = (gui.GetValue("rbot_scout_hitbox_head_ps") * 100);
									local scout_nscale = (gui.GetValue("rbot_scout_hitbox_neck_ps") * 100);
									local scout_cscale = (gui.GetValue("rbot_scout_hitbox_chest_ps") * 100);
									local scout_sscale = (gui.GetValue("rbot_scout_hitbox_stomach_ps") * 100);
									local scout_pscale = (gui.GetValue("rbot_scout_hitbox_pelvis_ps") * 100);
									local scout_ascale = (gui.GetValue("rbot_scout_hitbox_arms_ps") * 100);
									local scout_lscale = (gui.GetValue("rbot_scout_hitbox_legs_ps") * 100);
									local scout_autoscale = gui.GetValue("rbot_scout_hitbox_auto_ps");
									local scout_autoscales = (gui.GetValue("rbot_scout_hitbox_auto_ps_max") * 100);
				
									scout_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, scout_hitboxes);
									gui.SetValue("rbot_scout_hitbox_head", scout_hitboxes["Head"]);
									gui.SetValue("rbot_scout_hitbox_neck", scout_hitboxes["Neck"]);
									gui.SetValue("rbot_scout_hitbox_chest", scout_hitboxes["Chest"]);
									gui.SetValue("rbot_scout_hitbox_stomach", scout_hitboxes["Stomach"]);
									gui.SetValue("rbot_scout_hitbox_pelvis", scout_hitboxes["Pelvis"]);
									gui.SetValue("rbot_scout_hitbox_arms", scout_hitboxes["Arms"]);
									gui.SetValue("rbot_scout_hitbox_legs", scout_hitboxes["Legs"]);
									
									scout_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, scout_hscale);
									gui.SetValue("rbot_scout_hitbox_head_ps", scout_hscale / 100);
									scout_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, scout_nscale);
									gui.SetValue("rbot_scout_hitbox_neck_ps", scout_nscale / 100);
									scout_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, scout_cscale);
									gui.SetValue("rbot_scout_hitbox_chest_ps", scout_cscale / 100);
									scout_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, scout_sscale);
									gui.SetValue("rbot_scout_hitbox_stomach_ps", scout_sscale / 100);
									scout_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, scout_pscale);
									gui.SetValue("rbot_scout_hitbox_pelvis_ps", scout_pscale / 100);
									scout_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, scout_ascale);
									gui.SetValue("rbot_scout_hitbox_arms_ps", scout_ascale / 100);
									scout_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, scout_lscale);
									gui.SetValue("rbot_scout_hitbox_legs_ps", scout_lscale / 100);
									scout_autoscale = SenseUI.Checkbox("Auto scale", scout_autoscale);
									gui.SetValue("rbot_scout_hitbox_auto_ps", scout_autoscale);
									scout_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, scout_autoscales);
									gui.SetValue("rbot_scout_hitbox_auto_ps_max", scout_autoscales / 100);
										else if weapon_select == 7 then
										
										local autosniper_autowall = (gui.GetValue("rbot_autosniper_autowall") + 1);
										local autosniper_hitchance = gui.GetValue("rbot_autosniper_hitchance");
										local autosniper_mindamage = gui.GetValue("rbot_autosniper_mindamage");
										local autosniper_hitprior = (gui.GetValue("rbot_autosniper_hitbox") + 1);
										local autosniper_bodyaim = (gui.GetValue("rbot_autosniper_hitbox_bodyaim") + 1);
										local autosniper_method = (gui.GetValue("rbot_autosniper_hitbox_method") + 1);
										local autosniper_baimX = gui.GetValue("rbot_autosniper_bodyaftershots");
										local autosniper_baimHP = gui.GetValue("rbot_autosniper_bodyifhplower");
										local autosniper_hscale = (gui.GetValue("rbot_autosniper_hitbox_head_ps") * 100);
										local autosniper_nscale = (gui.GetValue("rbot_autosniper_hitbox_neck_ps") * 100);
										local autosniper_cscale = (gui.GetValue("rbot_autosniper_hitbox_chest_ps") * 100);
										local autosniper_sscale = (gui.GetValue("rbot_autosniper_hitbox_stomach_ps") * 100);
										local autosniper_pscale = (gui.GetValue("rbot_autosniper_hitbox_pelvis_ps") * 100);
										local autosniper_ascale = (gui.GetValue("rbot_autosniper_hitbox_arms_ps") * 100);
										local autosniper_lscale = (gui.GetValue("rbot_autosniper_hitbox_legs_ps") * 100);
										local autosniper_autoscale = gui.GetValue("rbot_autosniper_hitbox_auto_ps");
										local autosniper_autoscales = (gui.GetValue("rbot_autosniper_hitbox_auto_ps_max") * 100);
				
										autosniper_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, autosniper_hitboxes);
										gui.SetValue("rbot_autosniper_hitbox_head", autosniper_hitboxes["Head"]);
										gui.SetValue("rbot_autosniper_hitbox_neck", autosniper_hitboxes["Neck"]);
										gui.SetValue("rbot_autosniper_hitbox_chest", autosniper_hitboxes["Chest"]);
										gui.SetValue("rbot_autosniper_hitbox_stomach", autosniper_hitboxes["Stomach"]);
										gui.SetValue("rbot_autosniper_hitbox_pelvis", autosniper_hitboxes["Pelvis"]);
										gui.SetValue("rbot_autosniper_hitbox_arms", autosniper_hitboxes["Arms"]);
										gui.SetValue("rbot_autosniper_hitbox_legs", autosniper_hitboxes["Legs"]);
										
										autosniper_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, autosniper_hscale);
										gui.SetValue("rbot_autosniper_hitbox_head_ps", autosniper_hscale / 100);
										autosniper_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, autosniper_nscale);
										gui.SetValue("rbot_autosniper_hitbox_neck_ps", autosniper_nscale / 100);
										autosniper_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, autosniper_cscale);
										gui.SetValue("rbot_autosniper_hitbox_chest_ps", autosniper_cscale / 100);
										autosniper_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, autosniper_sscale);
										gui.SetValue("rbot_autosniper_hitbox_stomach_ps", autosniper_sscale / 100);
										autosniper_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, autosniper_pscale);
										gui.SetValue("rbot_autosniper_hitbox_pelvis_ps", autosniper_pscale / 100);
										autosniper_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, autosniper_ascale);
										gui.SetValue("rbot_autosniper_hitbox_arms_ps", autosniper_ascale / 100);
										autosniper_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, autosniper_lscale);
										gui.SetValue("rbot_autosniper_hitbox_legs_ps", autosniper_lscale / 100);
										autosniper_autoscale = SenseUI.Checkbox("Auto scale", autosniper_autoscale);
										gui.SetValue("rbot_autosniper_hitbox_auto_ps", autosniper_autoscale);
										autosniper_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, autosniper_autoscales);
										gui.SetValue("rbot_autosniper_hitbox_auto_ps_max", autosniper_autoscales / 100);									
											else if weapon_select == 8 then
											
											local sniper_autowall = (gui.GetValue("rbot_sniper_autowall") + 1);
											local sniper_hitchance = gui.GetValue("rbot_sniper_hitchance");
											local sniper_mindamage = gui.GetValue("rbot_sniper_mindamage");
											local sniper_hitprior = (gui.GetValue("rbot_sniper_hitbox") + 1);
											local sniper_bodyaim = (gui.GetValue("rbot_sniper_hitbox_bodyaim") + 1);
											local sniper_method = (gui.GetValue("rbot_sniper_hitbox_method") + 1);
											local sniper_baimX = gui.GetValue("rbot_sniper_bodyaftershots");
											local sniper_baimHP = gui.GetValue("rbot_sniper_bodyifhplower");
											local sniper_hscale = (gui.GetValue("rbot_sniper_hitbox_head_ps") * 100);
											local sniper_nscale = (gui.GetValue("rbot_sniper_hitbox_neck_ps") * 100);
											local sniper_cscale = (gui.GetValue("rbot_sniper_hitbox_chest_ps") * 100);
											local sniper_sscale = (gui.GetValue("rbot_sniper_hitbox_stomach_ps") * 100);
											local sniper_pscale = (gui.GetValue("rbot_sniper_hitbox_pelvis_ps") * 100);
											local sniper_ascale = (gui.GetValue("rbot_sniper_hitbox_arms_ps") * 100);
											local sniper_lscale = (gui.GetValue("rbot_sniper_hitbox_legs_ps") * 100);
											local sniper_autoscale = gui.GetValue("rbot_sniper_hitbox_auto_ps");
											local sniper_autoscales = (gui.GetValue("rbot_sniper_hitbox_auto_ps_max") * 100);
				
											sniper_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, sniper_hitboxes);
											gui.SetValue("rbot_sniper_hitbox_head", sniper_hitboxes["Head"]);
											gui.SetValue("rbot_sniper_hitbox_neck", sniper_hitboxes["Neck"]);
											gui.SetValue("rbot_sniper_hitbox_chest", sniper_hitboxes["Chest"]);
											gui.SetValue("rbot_sniper_hitbox_stomach", sniper_hitboxes["Stomach"]);
											gui.SetValue("rbot_sniper_hitbox_pelvis", sniper_hitboxes["Pelvis"]);
											gui.SetValue("rbot_sniper_hitbox_arms", sniper_hitboxes["Arms"]);
											gui.SetValue("rbot_sniper_hitbox_legs", sniper_hitboxes["Legs"]);
											
											sniper_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, sniper_hscale);
											gui.SetValue("rbot_sniper_hitbox_head_ps", sniper_hscale / 100);
											sniper_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, sniper_nscale);
											gui.SetValue("rbot_sniper_hitbox_neck_ps", sniper_nscale / 100);
											sniper_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, sniper_cscale);
											gui.SetValue("rbot_sniper_hitbox_chest_ps", sniper_cscale / 100);
											sniper_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, sniper_sscale);
											gui.SetValue("rbot_sniper_hitbox_stomach_ps", sniper_sscale / 100);
											sniper_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, sniper_pscale);
											gui.SetValue("rbot_sniper_hitbox_pelvis_ps", sniper_pscale / 100);
											sniper_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, sniper_ascale);
											gui.SetValue("rbot_sniper_hitbox_arms_ps", sniper_ascale / 100);
											sniper_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, sniper_lscale);
											gui.SetValue("rbot_sniper_hitbox_legs_ps", sniper_lscale / 100);
											sniper_autoscale = SenseUI.Checkbox("Auto scale", sniper_autoscale);
											gui.SetValue("rbot_sniper_hitbox_auto_ps", sniper_autoscale);
											sniper_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, sniper_autoscales);
											gui.SetValue("rbot_sniper_hitbox_auto_ps_max", sniper_autoscales / 100);										
												else if weapon_select == 9 then
												
												local lmg_autowall = (gui.GetValue("rbot_lmg_autowall") + 1);
												local lmg_hitchance = gui.GetValue("rbot_lmg_hitchance");
												local lmg_mindamage = gui.GetValue("rbot_lmg_mindamage");
												local lmg_hitprior = (gui.GetValue("rbot_lmg_hitbox") + 1);
												local lmg_bodyaim = (gui.GetValue("rbot_lmg_hitbox_bodyaim") + 1);
												local lmg_method = (gui.GetValue("rbot_lmg_hitbox_method") + 1);
												local lmg_baimX = gui.GetValue("rbot_lmg_bodyaftershots");
												local lmg_baimHP = gui.GetValue("rbot_lmg_bodyifhplower");
												local lmg_hscale = (gui.GetValue("rbot_lmg_hitbox_head_ps") * 100);
												local lmg_nscale = (gui.GetValue("rbot_lmg_hitbox_neck_ps") * 100);
												local lmg_cscale = (gui.GetValue("rbot_lmg_hitbox_chest_ps") * 100);
												local lmg_sscale = (gui.GetValue("rbot_lmg_hitbox_stomach_ps") * 100);
												local lmg_pscale = (gui.GetValue("rbot_lmg_hitbox_pelvis_ps") * 100);
												local lmg_ascale = (gui.GetValue("rbot_lmg_hitbox_arms_ps") * 100);
												local lmg_lscale = (gui.GetValue("rbot_lmg_hitbox_legs_ps") * 100);
												local lmg_autoscale = gui.GetValue("rbot_lmg_hitbox_auto_ps");
												local lmg_autoscales = (gui.GetValue("rbot_lmg_hitbox_auto_ps_max") * 100);
				
												lmg_hitboxes = SenseUI.MultiCombo("Hitbox filter", { "Head", "Neck", "Chest", "Stomach", "Pelvis", "Arms", "Legs" }, lmg_hitboxes);
												gui.SetValue("rbot_lmg_hitbox_head", lmg_hitboxes["Head"]);
												gui.SetValue("rbot_lmg_hitbox_neck", lmg_hitboxes["Neck"]);
												gui.SetValue("rbot_lmg_hitbox_chest", lmg_hitboxes["Chest"]);
												gui.SetValue("rbot_lmg_hitbox_stomach", lmg_hitboxes["Stomach"]);
												gui.SetValue("rbot_lmg_hitbox_pelvis", lmg_hitboxes["Pelvis"]);
												gui.SetValue("rbot_lmg_hitbox_arms", lmg_hitboxes["Arms"]);
												gui.SetValue("rbot_lmg_hitbox_legs", lmg_hitboxes["Legs"]);
												
												lmg_hscale = SenseUI.Slider("Head scale", 0, 100, "%", "0%", "100%", false, lmg_hscale);
												gui.SetValue("rbot_lmg_hitbox_head_ps", lmg_hscale / 100);
												lmg_nscale = SenseUI.Slider("Neck scale", 0, 100, "%", "0%", "100%", false, lmg_nscale);
												gui.SetValue("rbot_lmg_hitbox_neck_ps", lmg_nscale / 100);
												lmg_cscale = SenseUI.Slider("Chest scale", 0, 100, "%", "0%", "100%", false, lmg_cscale);
												gui.SetValue("rbot_lmg_hitbox_chest_ps", lmg_cscale / 100);
												lmg_sscale = SenseUI.Slider("Stomach scale", 0, 100, "%", "0%", "100%", false, lmg_sscale);
												gui.SetValue("rbot_lmg_hitbox_stomach_ps", lmg_sscale / 100);
												lmg_pscale = SenseUI.Slider("Pelvis scale", 0, 100, "%", "0%", "100%", false, lmg_pscale);
												gui.SetValue("rbot_lmg_hitbox_pelvis_ps", lmg_pscale / 100);
												lmg_ascale = SenseUI.Slider("Arms scale", 0, 100, "%", "0%", "100%", false, lmg_ascale);
												gui.SetValue("rbot_lmg_hitbox_arms_ps", lmg_ascale / 100);
												lmg_lscale = SenseUI.Slider("Legs scale", 0, 100, "%", "0%", "100%", false, lmg_lscale);
												gui.SetValue("rbot_lmg_hitbox_legs_ps", lmg_lscale / 100);
												lmg_autoscale = SenseUI.Checkbox("Auto scale", lmg_autoscale);
												gui.SetValue("rbot_lmg_hitbox_auto_ps", lmg_autoscale);
												lmg_autoscales = SenseUI.Slider("Auto scale Max", 0, 100, "%", "0%", "100%", false, lmg_autoscales);
												gui.SetValue("rbot_lmg_hitbox_auto_ps_max", lmg_autoscales / 100);											
												end
											end
										end
									end
								end
							end
						end
					end
				end
			SenseUI.EndGroup();
			end
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "vissettings", SenseUI.Icons.visuals ) then			
			if SenseUI.BeginGroup( "visual1", "Visuals", 25, 25, 235, 630 ) then
				SenseUI.Label("Player Select");
				pselect = SenseUI.Combo("pselect", { "Enemy", "Team", "Yourself", "Weapons", "Other", "Miscellaneous" }, pselect);
				if pselect == 1 then
					local enemy_filter = gui.GetValue("esp_filter_enemy");
					enemy_filter = SenseUI.Checkbox("Enable", enemy_filter);
					gui.SetValue("esp_filter_enemy", enemy_filter);
					local enemy_dormant = gui.GetValue("esp_dormant_enemy");
					enemy_dormant = SenseUI.Checkbox("Dormant", enemy_dormant);
					gui.SetValue("esp_dormant_enemy", enemy_dormant);
					SenseUI.Label("Bounding box");
					local enemy_box = (gui.GetValue("esp_enemy_box") + 1);
					enemy_box = SenseUI.Combo("enemy_box", { "Off", "2D", "3D", "Edges", "Machine", "Pentagon", "Hexagon" }, enemy_box);
					gui.SetValue("esp_enemy_box", enemy_box-1);
					local enemy_outline = gui.GetValue("esp_enemy_box_outline");
					enemy_outline = SenseUI.Checkbox("Box outline", enemy_outline);
					gui.SetValue("esp_enemy_box_outline", enemy_outline);
					local enemy_precision = gui.GetValue("esp_enemy_box_precise");
					enemy_precision = SenseUI.Checkbox("Box precision", enemy_precision);
					gui.SetValue("esp_enemy_box_precise", enemy_precision);
					local enemy_name = gui.GetValue("esp_enemy_name");
					enemy_name = SenseUI.Checkbox("Box name", enemy_name);
					gui.SetValue("esp_enemy_name", enemy_name);
					SenseUI.Label("Box health");
					local enemy_health = (gui.GetValue("esp_enemy_health") + 1);
					enemy_health = SenseUI.Combo("esp_enemy_health", { "Off", "Bar", "Number", "Both" }, enemy_health);
					gui.SetValue("esp_enemy_health", enemy_health-1);
					local enemy_armor = gui.GetValue("esp_enemy_armor");
					enemy_armor = SenseUI.Checkbox("Box armor", enemy_armor);
					gui.SetValue("esp_enemy_armor", enemy_armor);
					SenseUI.Label("Box weapon");
					local enemy_weapon = (gui.GetValue("esp_enemy_weapon") + 1);
					enemy_weapon = SenseUI.Combo("esp_enemy_weapon", { "Off", "Show Active", "Show All" }, enemy_weapon);
					gui.SetValue("esp_enemy_weapon", enemy_weapon-1);
					local enemy_skeleton = gui.GetValue("esp_enemy_skeleton");
					enemy_skeleton = SenseUI.Checkbox("Skeleton", enemy_skeleton);
					gui.SetValue("esp_enemy_skeleton", enemy_skeleton);
					SenseUI.Label("Hitbox model");
					local enemy_hmodel = (gui.GetValue("esp_enemy_hitbox") + 1);
					enemy_hmodel = SenseUI.Combo("esp_enemy_hitbox", { "Off", "White", "Color" }, enemy_hmodel);
					gui.SetValue("esp_enemy_hitbox", enemy_hmodel-1);
					local enemy_hs = gui.GetValue("esp_enemy_headspot");
					enemy_hs = SenseUI.Checkbox("Headspot", enemy_hs);
					gui.SetValue("esp_enemy_headspot", enemy_hs);
					local enemy_aimpoints = gui.GetValue("esp_enemy_aimpoints");
					enemy_aimpoints = SenseUI.Checkbox("Aim points", enemy_aimpoints);
					gui.SetValue("esp_enemy_aimpoints", enemy_aimpoints);
					SenseUI.Label("Glow");
					local enemy_glow = (gui.GetValue("esp_enemy_glow") + 1);
					enemy_glow = SenseUI.Combo("esp_enemy_glow", { "Off", "Normal", "Health" }, enemy_glow);
					gui.SetValue("esp_enemy_glow", enemy_glow-1);
					SenseUI.Label("Chams");
					local enemy_chams = (gui.GetValue("esp_enemy_chams") + 1);
					enemy_chams = SenseUI.Combo("esp_enemy_chams", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, enemy_chams);
					gui.SetValue("esp_enemy_chams", enemy_chams-1);
					local enemy_xqz = gui.GetValue("esp_enemy_xqz");
					enemy_xqz = SenseUI.Checkbox("Chams through wall", enemy_xqz);
					gui.SetValue("esp_enemy_xqz", enemy_xqz);
					enemy_flags = SenseUI.MultiCombo("Flags", { "Has C4", "Has Defuser", "Is Defusing", "Is Flashed", "Is Scoped", "Is Reloading", "Competitive Rank", "Money" }, enemy_flags);
					gui.SetValue("esp_enemy_hasc4", enemy_flags["Has C4"]);
					gui.SetValue("esp_enemy_hasdefuser", enemy_flags["Has Defuser"]);
					gui.SetValue("esp_enemy_defusing", enemy_flags["Is Defusing"]);
					gui.SetValue("esp_enemy_flashed", enemy_flags["Is Flashed"]);
					gui.SetValue("esp_enemy_scoped", enemy_flags["Is Scoped"]);
					gui.SetValue("esp_enemy_reloading", enemy_flags["Is Reloading"]);
					gui.SetValue("esp_enemy_comprank", enemy_flags["Competitive Rank"]);
					gui.SetValue("esp_enemy_money", enemy_flags["Money"]);
					local enemy_barrel = gui.GetValue("esp_enemy_barrel");
					enemy_barrel = SenseUI.Checkbox("Line of sight", enemy_barrel);
					gui.SetValue("esp_enemy_barrel", enemy_barrel);
					SenseUI.Label("Ammo");
					local enemy_ammo = (gui.GetValue("esp_enemy_ammo") + 1);
					enemy_ammo = SenseUI.Combo("esp_enemy_ammo", { "Off", "Number", "Bar" }, enemy_ammo);
					gui.SetValue("esp_enemy_ammo", enemy_ammo-1);
					local enemy_damage = gui.GetValue("esp_enemy_damage");
					enemy_damage = SenseUI.Checkbox("Hit damage", enemy_damage);
					gui.SetValue("esp_enemy_damage", enemy_damage);
					
					elseif pselect == 2 then
						local team_filter = gui.GetValue("esp_filter_team");
						team_filter = SenseUI.Checkbox("Enable", team_filter);
						gui.SetValue("esp_filter_team", team_filter);
						local team_dormant = gui.GetValue("esp_dormant_team");
						team_dormant = SenseUI.Checkbox("Dormant", team_dormant);
						gui.SetValue("esp_dormant_team", team_dormant);
						SenseUI.Label("Bounding box");
						local team_box = (gui.GetValue("esp_team_box") + 1);
						team_box = SenseUI.Combo("team_box", { "Off", "2D", "3D", "Edges", "Machine", "Pentagon", "Hexagon" }, team_box);
						gui.SetValue("esp_team_box", team_box-1);
						local team_outline = gui.GetValue("esp_team_box_outline");
						team_outline = SenseUI.Checkbox("Box outline", team_outline);
						gui.SetValue("esp_team_box_outline", team_outline);
						local team_precision = gui.GetValue("esp_team_box_precise");
						team_precision = SenseUI.Checkbox("Box precision", team_precision);
						gui.SetValue("esp_team_box_precise", team_precision);
						local team_name = gui.GetValue("esp_team_name");
						team_name = SenseUI.Checkbox("Box name", team_name);
						gui.SetValue("esp_team_name", team_name);
						SenseUI.Label("Box health");
						local team_health = (gui.GetValue("esp_team_health") + 1);
						team_health = SenseUI.Combo("esp_team_health", { "Off", "Bar", "Number", "Both" }, team_health);
						gui.SetValue("esp_team_health", team_health-1);
						local team_armor = gui.GetValue("esp_team_armor");
						team_armor = SenseUI.Checkbox("Box armor", team_armor);
						gui.SetValue("esp_team_armor", team_armor);
						SenseUI.Label("Box weapon");
						local team_weapon = (gui.GetValue("esp_team_weapon") + 1);
						team_weapon = SenseUI.Combo("esp_team_weapon", { "Off", "Show Active", "Show All" }, team_weapon);
						gui.SetValue("esp_team_weapon", team_weapon-1);
						local team_skeleton = gui.GetValue("esp_team_skeleton");
						team_skeleton = SenseUI.Checkbox("Skeleton", team_skeleton);
						gui.SetValue("esp_team_skeleton", team_skeleton);
						SenseUI.Label("Hitbox model");
						local team_hmodel = (gui.GetValue("esp_team_hitbox") + 1);
						team_hmodel = SenseUI.Combo("esp_team_hitbox", { "Off", "White", "Color" }, team_hmodel);
						gui.SetValue("esp_team_hitbox", team_hmodel-1);
						local team_hs = gui.GetValue("esp_team_headspot");
						team_hs = SenseUI.Checkbox("Headspot", team_hs);
						gui.SetValue("esp_team_headspot", team_hs);
						local team_aimpoints = gui.GetValue("esp_team_aimpoints");
						team_aimpoints = SenseUI.Checkbox("Aim points", team_aimpoints);
						gui.SetValue("esp_team_aimpoints", team_aimpoints);
						SenseUI.Label("Glow");
						local team_glow = (gui.GetValue("esp_team_glow") + 1);
						team_glow = SenseUI.Combo("esp_team_glow", { "Off", "Normal", "Health" }, team_glow);
						gui.SetValue("esp_team_glow", team_glow-1);
						SenseUI.Label("Chams");
						local team_chams = (gui.GetValue("esp_team_chams") + 1);
						team_chams = SenseUI.Combo("esp_team_chams", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, team_chams);
						gui.SetValue("esp_team_chams", team_chams-1);
						local team_xqz = gui.GetValue("esp_team_xqz");
						team_xqz = SenseUI.Checkbox("Chams through wall", team_xqz);
						gui.SetValue("esp_team_xqz", team_xqz);
						team_flags = SenseUI.MultiCombo("Flags", { "Has C4", "Has Defuser", "Is Defusing", "Is Flashed", "Is Scoped", "Is Reloading", "Competitive Rank", "Money" }, team_flags);
						gui.SetValue("esp_team_hasc4", team_flags["Has C4"]);
						gui.SetValue("esp_team_hasdefuser", team_flags["Has Defuser"]);
						gui.SetValue("esp_team_defusing", team_flags["Is Defusing"]);
						gui.SetValue("esp_team_flashed", team_flags["Is Flashed"]);
						gui.SetValue("esp_team_scoped", team_flags["Is Scoped"]);
						gui.SetValue("esp_team_reloading", team_flags["Is Reloading"]);
						gui.SetValue("esp_team_comprank", team_flags["Competitive Rank"]);
						gui.SetValue("esp_team_money", team_flags["Money"]);
						local team_barrel = gui.GetValue("esp_team_barrel");
						team_barrel = SenseUI.Checkbox("Line of sight", team_barrel);
						gui.SetValue("esp_team_barrel", team_barrel);
						SenseUI.Label("Ammo");
						local team_ammo = (gui.GetValue("esp_team_ammo") + 1);
						team_ammo = SenseUI.Combo("esp_team_ammo", { "Off", "Number", "Bar" }, team_ammo);
						gui.SetValue("esp_team_ammo", team_ammo-1);
						local team_damage = gui.GetValue("esp_team_damage");
						team_damage = SenseUI.Checkbox("Hit damage", team_damage);
						gui.SetValue("esp_team_damage", team_damage);
						
						elseif pselect == 3 then
							local self_filter = gui.GetValue("esp_filter_self");
							self_filter = SenseUI.Checkbox("Enable", self_filter);
							gui.SetValue("esp_filter_self", self_filter);
							SenseUI.Label("Bounding box");
							local self_box = (gui.GetValue("esp_self_box") + 1);
							self_box = SenseUI.Combo("self_box", { "Off", "2D", "3D", "Edges", "Machine", "Pentagon", "Hexagon" }, self_box);
							gui.SetValue("esp_self_box", self_box-1);
							local self_outline = gui.GetValue("esp_self_box_outline");
							self_outline = SenseUI.Checkbox("Box outline", self_outline);
							gui.SetValue("esp_self_box_outline", self_outline);
							local self_precision = gui.GetValue("esp_self_box_precise");
							self_precision = SenseUI.Checkbox("Box precision", self_precision);
							gui.SetValue("esp_self_box_precise", self_precision);
							local self_name = gui.GetValue("esp_self_name");
							self_name = SenseUI.Checkbox("Box name", self_name);
							gui.SetValue("esp_self_name", self_name);
							SenseUI.Label("Box health");
							local self_health = (gui.GetValue("esp_self_health") + 1);
							self_health = SenseUI.Combo("esp_self_health", { "Off", "Bar", "Number", "Both" }, self_health);
							gui.SetValue("esp_self_health", self_health-1);
							local self_armor = gui.GetValue("esp_self_armor");
							self_armor = SenseUI.Checkbox("Box armor", self_armor);
							gui.SetValue("esp_self_armor", self_armor);
							SenseUI.Label("Box weapon");
							local self_weapon = (gui.GetValue("esp_self_weapon") + 1);
							self_weapon = SenseUI.Combo("esp_self_weapon", { "Off", "Show Active", "Show All" }, self_weapon);
							gui.SetValue("esp_self_weapon", self_weapon-1);
							local self_skeleton = gui.GetValue("esp_self_skeleton");
							self_skeleton = SenseUI.Checkbox("Skeleton", self_skeleton);
							gui.SetValue("esp_self_skeleton", self_skeleton);
							SenseUI.Label("Hitbox model");
							local self_hmodel = (gui.GetValue("esp_self_hitbox") + 1);
							self_hmodel = SenseUI.Combo("esp_self_hitbox", { "Off", "White", "Color" }, self_hmodel);
							gui.SetValue("esp_self_hitbox", self_hmodel-1);
							local self_hs = gui.GetValue("esp_self_headspot");
							self_hs = SenseUI.Checkbox("Headspot", self_hs);
							gui.SetValue("esp_self_headspot", self_hs);
							local self_aimpoints = gui.GetValue("esp_self_aimpoints");
							self_aimpoints = SenseUI.Checkbox("Aim points", self_aimpoints);
							gui.SetValue("esp_self_aimpoints", self_aimpoints);
							SenseUI.Label("Glow");
							local self_glow = (gui.GetValue("esp_self_glow") + 1);
							self_glow = SenseUI.Combo("esp_self_glow", { "Off", "Normal", "Health" }, self_glow);
							gui.SetValue("esp_self_glow", self_glow-1);
							SenseUI.Label("Chams");
							local self_chams = (gui.GetValue("esp_self_chams") + 1);
							self_chams = SenseUI.Combo("esp_self_chams", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, self_chams);
							gui.SetValue("esp_self_chams", self_chams-1);
							local self_xqz = gui.GetValue("esp_self_xqz");
							self_xqz = SenseUI.Checkbox("Chams through wall", self_xqz);
							gui.SetValue("esp_self_xqz", self_xqz);
							self_flags = SenseUI.MultiCombo("Flags", { "Has C4", "Has Defuser", "Is Defusing", "Is Flashed", "Is Scoped", "Is Reloading", "Competitive Rank", "Money" }, self_flags);
							gui.SetValue("vis_noflash", self_flags["Has C4"]);--gui.SetValue("esp_self_hasc4", removals["NoFlash"]);
							gui.SetValue("esp_self_hasdefuser", self_flags["Has Defuser"]);
							gui.SetValue("esp_self_defusing", self_flags["Is Defusing"]);
							gui.SetValue("esp_self_flashed", self_flags["Is Flashed"]);
							gui.SetValue("esp_self_scoped", self_flags["Is Scoped"]);
							gui.SetValue("esp_self_reloading", self_flags["Is Reloading"]);
							gui.SetValue("esp_self_comprank", self_flags["Competitive Rank"]);
							gui.SetValue("esp_self_money", self_flags["Money"]);
							local self_barrel = gui.GetValue("esp_self_barrel");
							self_barrel = SenseUI.Checkbox("Line of sight", self_barrel);
							gui.SetValue("esp_self_barrel", self_barrel);
							SenseUI.Label("Ammo");
							local self_ammo = (gui.GetValue("esp_self_ammo") + 1);
							self_ammo = SenseUI.Combo("esp_self_ammo", { "Off", "Number", "Bar" }, self_ammo);
							gui.SetValue("esp_self_ammo", self_ammo-1);
							local self_damage = gui.GetValue("esp_self_damage");
							self_damage = SenseUI.Checkbox("Hit damage", self_damage);
							gui.SetValue("esp_self_damage", self_damage);
							
							elseif pselect == 4 then
								local weapon_filter = gui.GetValue("esp_filter_weapon");
								weapon_filter = SenseUI.Checkbox("Enable", weapon_filter);
								gui.SetValue("esp_filter_weapon", weapon_filter);
								SenseUI.Label("Bounding box");
								local weapon_box = (gui.GetValue("esp_weapon_box") + 1);
								weapon_box = SenseUI.Combo("weapon_box", { "Off", "2D", "3D", "Edges", "Machine", "Pentagon", "Hexagon" }, weapon_box);
								gui.SetValue("esp_weapon_box", weapon_box-1);
								local weapon_outline = gui.GetValue("esp_weapon_box_outline");
								weapon_outline = SenseUI.Checkbox("Box outline", weapon_outline);
								gui.SetValue("esp_weapon_box_outline", weapon_outline);
								local weapon_precision = gui.GetValue("esp_weapon_box_precise");
								weapon_precision = SenseUI.Checkbox("Box precision", weapon_precision);
								gui.SetValue("esp_weapon_box_precise", weapon_precision);
								local weapon_name = gui.GetValue("esp_weapon_name");
								weapon_name = SenseUI.Checkbox("Box name", weapon_name);
								gui.SetValue("esp_weapon_name", weapon_name);
								SenseUI.Label("Glow");
								local weapon_glow = (gui.GetValue("esp_weapon_glow") + 1);
								weapon_glow = SenseUI.Combo("esp_weapon_glow", { "Off", "Normal", "Health" }, weapon_glow);
								gui.SetValue("esp_weapon_glow", weapon_glow-1);
								SenseUI.Label("Chams");
								local weapon_chams = (gui.GetValue("esp_weapon_chams") + 1);
								weapon_chams = SenseUI.Combo("esp_weapon_chams", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, weapon_chams);
								gui.SetValue("esp_weapon_chams", weapon_chams-1);
								local weapon_xqz = gui.GetValue("esp_weapon_xqz");
								weapon_xqz = SenseUI.Checkbox("Chams through wall", weapon_xqz);
								gui.SetValue("esp_weapon_xqz", weapon_xqz);
								SenseUI.Label("Ammo");
								local weapon_ammo = (gui.GetValue("esp_weapon_ammo") + 1);
								weapon_ammo = SenseUI.Combo("esp_weapon_ammo", { "Off", "Number", "Bar" }, weapon_ammo);
								gui.SetValue("esp_weapon_ammo", weapon_ammo-1);
								
								elseif pselect == 5 then
									local other_pc4 = gui.GetValue("esp_filter_plantedc4");
									other_pc4 = SenseUI.Checkbox("Planted C4", other_pc4);
									gui.SetValue("esp_filter_plantedc4", other_pc4);
									local other_nade = gui.GetValue("esp_filter_grenades");
									other_nade = SenseUI.Checkbox("Nades", other_nade);
									gui.SetValue("esp_filter_grenades", other_nade);
									local other_chick = gui.GetValue("esp_filter_chickens");
									other_chick = SenseUI.Checkbox("Chickens", other_chick);
									gui.SetValue("esp_filter_chickens", other_chick);
									local other_host = gui.GetValue("esp_filter_hostages");
									other_host = SenseUI.Checkbox("Hostages", other_host);
									gui.SetValue("esp_filter_hostages", other_host);
									local other_items = gui.GetValue("esp_filter_items");
									other_items = SenseUI.Checkbox("Items", other_items);
									gui.SetValue("esp_filter_items", other_items);
									SenseUI.Label("Bounding box");
									local other_box = (gui.GetValue("esp_other_box") + 1);
									other_box = SenseUI.Combo("other_box", { "Off", "2D", "3D", "Edges", "Machine", "Pentagon", "Hexagon" }, other_box);
									gui.SetValue("esp_other_box", other_box-1);
									local other_outline = gui.GetValue("esp_other_box_outline");
									other_outline = SenseUI.Checkbox("Box outline", other_outline);
									gui.SetValue("esp_other_box_outline", other_outline);
									local other_precision = gui.GetValue("esp_other_box_precise");
									other_precision = SenseUI.Checkbox("Box precision", other_precision);
									gui.SetValue("esp_other_box_precise", other_precision);
									local other_name = gui.GetValue("esp_other_name");
									other_name = SenseUI.Checkbox("Box name", other_name);
									gui.SetValue("esp_other_name", other_name);
									SenseUI.Label("Glow");
									local other_glow = (gui.GetValue("esp_other_glow") + 1);
									other_glow = SenseUI.Combo("esp_other_glow", { "Off", "Normal", "Health" }, other_glow);
									gui.SetValue("esp_other_glow", other_glow-1);
									SenseUI.Label("Chams");
									local other_chams = (gui.GetValue("esp_other_chams") + 1);
									other_chams = SenseUI.Combo("esp_other_chams", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, other_chams);
									gui.SetValue("esp_other_chams", other_chams-1);
									local other_xqz = gui.GetValue("esp_other_xqz");
									other_xqz = SenseUI.Checkbox("Chams through wall", other_xqz);
									gui.SetValue("esp_other_xqz", other_xqz);
									local other_name = gui.GetValue("esp_other_name");
									other_name = SenseUI.Checkbox("Box name", other_name);
									gui.SetValue("esp_other_name", other_name);
									
									elseif pselect == 6 then
										local vfov = gui.GetValue("vis_view_fov");
										vfov = SenseUI.Slider("Override FOV", 0, 120, "°", "0°", "120°", false, vfov);
										gui.SetValue("vis_view_fov", vfov);
										local vfovm = gui.GetValue("vis_view_model_fov");
										vfovm = SenseUI.Slider("Override model FOV", 0, 120, "°", "0°", "120°", false, vfovm);
										gui.SetValue("vis_view_model_fov", vfovm);
										SenseUI.Label("Hand chams");
										local hand_chams = (gui.GetValue("vis_chams_hands") + 1);
										hand_chams = SenseUI.Combo("vis_chams_hands", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, hand_chams);
										gui.SetValue("vis_chams_hands", hand_chams-1);
										SenseUI.Label("Weapon chams");
										local weapon_chams = (gui.GetValue("vis_chams_weapon") + 1);
										weapon_chams = SenseUI.Combo("vis_chams_weapon", { "Off", "Color", "Material", "Color Wireframe", "Mat Wireframe", "Invisible", "Metallic", "Flat" }, weapon_chams);
										gui.SetValue("vis_chams_weapon", weapon_chams-1);
										SenseUI.Label("Fake chams");
										local fakeghost = (gui.GetValue("vis_fakeghost") + 1);
										fakeghost = SenseUI.Combo("vis_fakeghost", { "Off", "Client", "Server", "Both" }, fakeghost);
										gui.SetValue("vis_fakeghost", fakeghost-1);
										removals = SenseUI.MultiCombo("Removals", { "Flash", "Smoke", "Recoil" }, removals);
										gui.SetValue("vis_noflash", removals["Flash"]);
										gui.SetValue("vis_nosmoke", removals["Smoke"]);
										gui.SetValue("vis_norecoil", removals["Recoil"]);
										SenseUI.Label("Scope remove");
										local scoperem = (gui.GetValue("vis_scoperemover") + 1);				
										scoperem = SenseUI.Combo("vis_scoperemover", { "Off", "On", "On + Lines" }, scoperem);
										gui.SetValue("vis_scoperemover", scoperem-1);
										local transparentwalls = (gui.GetValue("vis_asus") * 100);
										transparentwalls = SenseUI.Slider("Transparent walls", 0, 100, "%", "0%", "100%", false, transparentwalls);
										gui.SetValue("vis_asus", transparentwalls/100);
										gui.SetValue("vis_asustype", 0);
										local nightmode = (gui.GetValue("vis_nightmode") * 100);
										nightmode = SenseUI.Slider("Night mode", 0, 100, "%", "0%", "100%", false, nightmode);
										gui.SetValue("vis_nightmode", nightmode/100);
										local sbox = (gui.GetValue("vis_skybox") + 1);
										sbox = SenseUI.Combo("Skybox changer", { "Default", "cs_tibet", "embassy", "italy", "jungle", "office", "sky_cs15_daylight01_hdr", "sky_csgo_cloudy1", "sky_csgo_night02", "sky_csgo_night02b", "sky_day02_05_hdr", "sky_day02_05", "sky_dust", "vertigo_hdr", "vertigoblue_hdr", "vertigo", "vietnam" }, sbox);
										gui.SetValue("vis_skybox", sbox-1);
										local ch = gui.GetValue("esp_crosshair");
										ch = SenseUI.Checkbox("Crosshair", ch);
										gui.SetValue("esp_crosshair", ch);
										local gtrace = gui.GetValue("esp_nadetracer");
										gtrace = SenseUI.Checkbox("Grenade trajectory", gtrace);
										gui.SetValue("esp_nadetracer", gtrace);
										local gdamage = gui.GetValue("esp_nadedamage");
										gdamage = SenseUI.Checkbox("Grenade damage", gdamage);
										gui.SetValue("esp_nadedamage", gdamage);
										SenseUI.Label("Bullet tracers");
										local btracer = (gui.GetValue("vis_bullet_tracer") + 1);				
										btracer = SenseUI.Combo("vis_bullet_tracer", { "Off", "Everyone", "Enemy", "Team", "Yourself"}, btracer);
										gui.SetValue("vis_bullet_tracer", btracer-1);
										local wbdamage = gui.GetValue("esp_wallbangdmg");
										wbdamage = SenseUI.Checkbox("Wallbang damage", wbdamage);
										gui.SetValue("esp_wallbangdmg", wbdamage);
										local oof = gui.GetValue("esp_outofview"); --- REEEEEEEEEEEEEEEEEE oof
										oof = SenseUI.Checkbox("Out of FOV arrow", oof);
										gui.SetValue("esp_outofview", oof);
										render = SenseUI.MultiCombo("Disable rendering", { "Teammate", "Enemy", "Weapon", "Ragdoll" }, render);
										gui.SetValue("vis_norender_teammates", render["Teammate"]);
										gui.SetValue("vis_norender_enemies", render["Enemy"]);
										gui.SetValue("vis_norender_weapons", render["Weapon"]);
										gui.SetValue("vis_norender_ragdolls", render["Ragdoll"]);
										local hitmarker = gui.GetValue("msc_hitmarker_enable");
										hitmarker = SenseUI.Checkbox("Hit marker", hitmarker);
										gui.SetValue("msc_hitmarker_enable", hitmarker);
				end
				SenseUI.EndGroup();
			end
			if SenseUI.BeginGroup( "visual2", "Other", 285, 25, 235, 315 ) then
				local visenable = gui.GetValue("esp_active");
				visenable = SenseUI.Checkbox("Enable", visenable);
				gui.SetValue("esp_active", visenable);
				local vishotkey = gui.GetValue("vis_togglekey");
				vishotkey = SenseUI.Bind("tkeyvis", true, vishotkey);
				gui.SetValue("vis_togglekey", vishotkey);
				SenseUI.Label("Backtrack chams");
				local btrackchams = (gui.GetValue("vis_historyticks") + 1);
				btrackchams = SenseUI.Combo("btrack", { "Off", "All ticks", "Last tick" }, btrackchams);
				gui.SetValue("vis_historyticks", btrackchams-1);
				SenseUI.Label("Backtrack chams style");
				local btrackchamss = (gui.GetValue("vis_historyticks_style") + 1);
				btrackchamss = SenseUI.Combo("btrack2", { "Model", "Flat", "Hitbox" }, btrackchamss);
				gui.SetValue("vis_historyticks_style", btrackchamss-1);
				local glowalpha = (gui.GetValue("vis_glowalpha") * 100);
				glowalpha = SenseUI.Slider("Glow alpha", 0, 100, "", "0", "10", false, glowalpha);
				gui.SetValue("vis_glowalpha", glowalpha/100);
				local rfarmodels = gui.GetValue("vis_farmodels");
				rfarmodels = SenseUI.Checkbox("Far models", rfarmodels);
				gui.SetValue("vis_farmodels", rfarmodels);
				local tbasec = gui.GetValue("esp_teambasedcolors");
				tbasec = SenseUI.Checkbox("Team based colors", tbasec);
				gui.SetValue("esp_teambasedcolors", tbasec);
				SenseUI.Label("Team based text color");
				local tbasedtc = (gui.GetValue("esp_teambasedtextcolor") + 1);
				tbasedtc = SenseUI.Combo("tbasedtc", { "Off", "Box color", "Visible color", "Invisible color"}, tbasedtc);
				gui.SetValue("esp_teambasedtextcolor", tbasedtc-1);
				SenseUI.Label("Weapon style");
				local wstyle = (gui.GetValue("esp_weaponstyle") + 1);
				wstyle = SenseUI.Combo("wstyle", { "Icon", "Name" }, wstyle);
				gui.SetValue("esp_weaponstyle", wstyle-1);
				local ascreen = gui.GetValue("vis_antiscreenshot");
				ascreen = SenseUI.Checkbox("Anti-screenshot", ascreen);
				gui.SetValue("vis_antiscreenshot", ascreen);
				local aobs = gui.GetValue("vis_antiobs");
				aobs = SenseUI.Checkbox("Anti-obs", aobs);
				gui.SetValue("vis_antiobs", aobs);
				SenseUI.EndGroup();
			end
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "miscsettings", SenseUI.Icons.settings ) then
			if SenseUI.BeginGroup("grpsasss", "CFG Load", 285, 355, 205, 290) then
				selected, scroll = SenseUI.Listbox(configs, 5, false, selected, nil, scroll)
				
				load_pressed = SenseUI.Button("Load", 155, 25)
				save_pressed = SenseUI.Button("Save", 155, 25)
				configname = SenseUI.Textbox("ncfgtb", "Config name", configname)
				add_pressed = SenseUI.Button("Add config", 155, 25)
				remove_pressed = SenseUI.Button("Remove config", 155, 25)
			end
			SenseUI.EndGroup();

			if SenseUI.BeginGroup( "otheraim", "Other", 285, 25, 235, 320 ) then
				local autorevolver = gui.GetValue("rbot_revolver_autocock");
				local autoawpbody = gui.GetValue("rbot_sniper_autoawp");
				local autopistol = gui.GetValue("rbot_pistol_autopistol");
				local autoscope = (gui.GetValue("rbot_autosniper_autoscope") + 1);
				local nospread = gui.GetValue("rbot_antispread");
				nospread = SenseUI.Checkbox("Remove spread", nospread, true);
				gui.SetValue("rbot_antispread", nospread);
				local norecoil = gui.GetValue("rbot_antirecoil");
				norecoil = SenseUI.Checkbox("Remove recoil", norecoil);
				gui.SetValue("rbot_antirecoil", norecoil);
				SenseUI.Label("Accuracy boost");	
				local delayshot = (gui.GetValue("rbot_delayshot") + 1);				
				delayshot = SenseUI.Combo("DS_rage", { "Off", "Accurate unlag", "Accurate history" }, delayshot);
				gui.SetValue("rbot_delayshot", delayshot-1);
				SenseUI.Label("Double tap", true);
				local doubletap = gui.GetValue("rbot_chargerapidfire");
				doubletap = SenseUI.Bind("doubletapss", true, doubletap);
				gui.SetValue("rbot_chargerapidfire", doubletap);
				SenseUI.Label("Auto scope");
				autoscope = SenseUI.Combo("az_rage", { "Off", "On - auto unzoom", "On - no unzoom" }, autoscope);
				gui.SetValue("rbot_autosniper_autoscope", autoscope-1);
				gui.SetValue("rbot_sniper_autoscope", autoscope-1);
				gui.SetValue("rbot_scout_autoscope", autoscope-1);
				autorevolver = SenseUI.Checkbox("Auto revolver", autorevolver);
				gui.SetValue("rbot_revolver_autocock", autorevolver);
				autoawpbody = SenseUI.Checkbox("AWP body", autoawpbody);
				gui.SetValue("rbot_sniper_autoawp", autoawpbody);
				autopistol = SenseUI.Checkbox("Auto pistol", autopistol);
				gui.SetValue("rbot_pistol_autopistol", autopistol);
			
				SenseUI.Label("Block Bot");
				local blockbotmode = (gui.GetValue("msc_blockbot_mode") + 1);				
				blockbotmode = SenseUI.Combo("block_bot", { "Match Speed", "Max Speed" }, blockbotmode);
				gui.SetValue("msc_blockbot_mode", blockbotmode-1);
				
				local blockbotkey = gui.GetValue("msc_blockbot");
				blockbotkey = SenseUI.Bind("blockbotkey", true, blockbotkey);
				gui.SetValue("msc_blockbot", blockbotkey);
				
				local autozues = (gui.GetValue("lua_autozeus") + 1);
				SenseUI.Label("Auto Zues");
				autozues = SenseUI.Combo("AutoZues", {"Off", "Legit", "Rage"}, autozues);
				gui.SetValue("lua_autozeus", autozues - 1);
				
				local speclist = gui.GetValue("rab_material_spec_masterswitch");
				speclist = SenseUI.Checkbox("Spectators", speclist);
				gui.SetValue("rab_material_spec_masterswitch", speclist);
				end
				SenseUI.EndGroup();
				
			if SenseUI.BeginGroup( "misc", "Miscellaneous", 25, 25, 235, 565 ) then
				local msc_active = gui.GetValue("msc_active");
				msc_active = SenseUI.Checkbox("Enable", msc_active);
				gui.SetValue("msc_active", msc_active);
				SenseUI.Label("Bunny hop");
				local bunnyhop = (gui.GetValue("msc_autojump") + 1);
				bunnyhop = SenseUI.Combo("bhop", { "Off", "Rage", "Legit" }, bunnyhop);
				gui.SetValue("msc_autojump", bunnyhop-1);
				local astrafe = gui.GetValue("msc_autostrafer_enable");
				astrafe = SenseUI.Checkbox("Air strafe", astrafe);
				gui.SetValue("msc_autostrafer_enable", astrafe);
				gui.SetValue("msc_autostrafer_airstrafe", astrafe);
				local wasdstrafe = gui.GetValue("msc_autostrafer_wasd");
				wasdstrafe = SenseUI.Checkbox("WASD strafe", wasdstrafe);
				gui.SetValue("msc_autostrafer_wasd", wasdstrafe);
				local antisp = gui.GetValue("msc_antisp");
				antisp = SenseUI.Checkbox("Anti spawn protection", antisp);
				gui.SetValue("msc_antisp", antisp);
				local revealranks = gui.GetValue("msc_revealranks");
				revealranks = SenseUI.Checkbox("Reveal competitive ranks", revealranks);
				gui.SetValue("msc_revealranks", revealranks);
				local weaplog = gui.GetValue("msc_logevents_purchases");
				weaplog = SenseUI.Checkbox("Purchases logs", weaplog);
				gui.SetValue("msc_logevents_purchases", weaplog);
				gui.SetValue("msc_logevents", 1);
				local damagelog = gui.GetValue("msc_logevents_damage");
				damagelog = SenseUI.Checkbox("Damage logs", damagelog);
				gui.SetValue("msc_logevents_damage", damagelog);
				gui.SetValue("msc_logevents", 1);
				local duckjump = gui.GetValue("msc_duckjump");
				duckjump = SenseUI.Checkbox("Duck jump", duckjump);
				gui.SetValue("msc_duckjump", duckjump);
				local fastduck = gui.GetValue("msc_fastduck");
				fastduck = SenseUI.Checkbox("Fast duck", fastduck);
				gui.SetValue("msc_fastduck", fastduck);
				local slidewalk = gui.GetValue("msc_slidewalk");
				slidewalk = SenseUI.Checkbox("Slide walk", slidewalk);
				gui.SetValue("msc_slidewalk", slidewalk);
				SenseUI.Label("Slow walk");
				local slowwalk = gui.GetValue("msc_slowwalk");
				slowwalk = SenseUI.Bind("sw", true, slowwalk);
				gui.SetValue("msc_slowwalk", slowwalk);
				local slowslider = (gui.GetValue("msc_slowwalkspeed") * 100);
				slowslider = SenseUI.Slider("Slow walk speed", 0, 100, "%", "0%", "100%", false, slowslider);
				gui.SetValue("msc_slowwalkspeed", slowslider / 100);
				local autoaccept = gui.GetValue("msc_autoaccept");
				autoaccept = SenseUI.Checkbox("Auto-accept match", autoaccept);
				gui.SetValue("msc_autoaccept", autoaccept);
				SenseUI.Label("Knifebot");
				local knifebot = (gui.GetValue("msc_knifebot") + 1);
				knifebot = SenseUI.Combo("combo1212", { "Off", "On", "Backstab only", "Trigger", "Quick" }, knifebot);
				gui.SetValue("msc_knifebot", knifebot-1);
				local clantag = gui.GetValue("msc_clantag");
				clantag = SenseUI.Checkbox("Clan-tag spammer", clantag);
				gui.SetValue("msc_clantag", clantag);
				local namespam = gui.GetValue("msc_namespam");
				namespam = SenseUI.Checkbox("Name spammer", namespam);
				gui.SetValue("msc_namespam", namespam);
				local invisiblename = gui.GetValue("msc_invisiblename");
				invisiblename = SenseUI.Checkbox("Invisible name", invisiblename);
				gui.SetValue("msc_invisiblename", invisiblename);
				SenseUI.Label( "Menu key" );
				window_bkey, window_bact, window_bdet = SenseUI.Bind( "wndToggle", false, window_bkey, window_bact, window_bdet );
				SenseUI.Label("Namestealer");
				local namesteal = (gui.GetValue("msc_namestealer_enable") + 1);
				namesteal = SenseUI.Combo("asdas", { "Off", "Team only", "Enemy only", "All" }, namesteal);
				gui.SetValue("msc_namestealer_enable", namesteal-1);
				SenseUI.Label("Menu color");
				local mcolor = (gui.GetValue("senseui_color") + 1);
				mcolor = SenseUI.Combo("uau", { "Green", "Blue", "Red", "Purple", "Orange", "Pink" }, mcolor);
				gui.SetValue("senseui_color", mcolor-1);
				local quickstop = gui.GetValue("msc_quickstop");
				quickstop = SenseUI.Checkbox("Quickstop", quickstop);
				gui.SetValue("msc_quickstop", quickstop);
				local bypasscl = gui.GetValue("msc_bypasscl");
				bypasscl = SenseUI.Checkbox("Bypass Client-side", bypasscl);
				gui.SetValue("msc_bypasscl", bypasscl);
				local bypasspure = gui.GetValue("msc_bypasspure");
				bypasspure = SenseUI.Checkbox("Bypass sv_pure", bypasspure);
				gui.SetValue("msc_bypasspure", bypasspure);
				gehelper = SenseUI.Combo("More MiSC", { "Show Less Misc", "Show More Misc" }, gehelper );
			end
			SenseUI.EndGroup();
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "skinc", SenseUI.Icons.skinchanger ) then
			if SenseUI.BeginGroup( "Skin Changer", "Skin Changer", 25, 25, 235, 70 ) then
				local skinc = gui.GetValue("msc_skinchanger");
				skinc = SenseUI.Checkbox("Skin changer", skinc);
				gui.SetValue("msc_skinchanger", skinc);
				knifeenable = SenseUI.Checkbox("Knife Enable", knifeenable);
				gui.SetValue("skin_knife_enable", knifeenable);
				knife_select = SenseUI.Combo("nvmd_skinchanger", { "Bayonet", "Flip", "Gut", "Karambit", "M9 Bayonet", "HuntsMan", "Falcion", "Bowie", "Butterfly", "Shadow Daggers", "Ursus", "Navaja", "Stilleto", "Talon"}, knife_select );
				if knife_select == 1 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 2 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 3 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 4 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 5 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 6 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 7 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 8 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 9 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 10 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 11 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 12 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 13 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 14 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 15 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 16 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 17 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
				if knife_select == 18 then
					gui.SetValue("skin_knife", knife_select - 1)
					end
					
			end
			SenseUI.EndGroup();
		end
		SenseUI.EndTab();
		if SenseUI.BeginTab( "players", SenseUI.Icons.playerlist ) then
			if SenseUI.BeginGroup( "Credits", "Credits", 25, 120, 335, 245) then
				SenseUI.Label("ＵＧＬＹＣＨ - creator of SenseUI Menu", true);
				SenseUI.Label("Ruppet - creator of SenseUI", true);
				SenseUI.Label("HappyDOGE - creator of CFG Loader", true);
				SenseUI.Label("Brotgeschmack - creator of texture optimization in SenseUI", true);
				SenseUI.Label("ambien55 - creator of cursor calling", true);
				SenseUI.Label("Quit - creator of font fix", true);
				SenseUI.Label("Yipp - added shit to it", true);
				SenseUI.Label("", true);
				SenseUI.Label("Guys my sub ends 31.03.19 and I wont buy it anymore", true);
				SenseUI.Label("I leave from hvh and this game (nobody cares about that)", true);
				SenseUI.Label("But still goodbye guys! Ill miss ;( - uglych's last words", true);
				SenseUI.Label("Steam: steamcommunity.com/id/uglychofficial", true);
				SenseUI.Label("Discord: Uglych#1515", true);
				SenseUI.Label("VK: vk.com/a1b2c1", true);
			end
			SenseUI.EndGroup();
			if SenseUI.BeginGroup( "Ps", "Player List", 25, 25, 235, 70 ) then
				local playerlist = gui.GetValue("msc_playerlist");
				playerlist = SenseUI.Checkbox("Player list", playerlist);
				gui.SetValue("msc_playerlist", playerlist);
				SenseUI.Label("You need to open original menu of AW", true);
				SenseUI.Label("For change priorities in player list", true);
			end
			SenseUI.EndGroup();
			
		end
		SenseUI.EndTab();
		if client.GetConVar("cl_mouseenable") ~= 0 then
			client.SetConVar("cl_mouseenable", 0, true)
		local mouse_x, mouse_y = input.GetMousePos()
		draw.Color( 255, 255, 255, 255 )
		draw.SetFont(draw.CreateFont("Tahoma", 24));
		draw.Text(mouse_x-7, mouse_y-10, "+")
		end
		SenseUI.EndWindow();
		if gehelper == 2 then
			if SenseUI.BeginWindow( "wnd2", 700, 75, 500, 570) then
				SenseUI.DrawTabBar();
				if show_gradient then
					SenseUI.AddGradient();
				end
				SenseUI.SetWindowDrawTexture( true );
				SenseUI.SetWindowMoveable( window_moveable );
				if SenseUI.BeginTab( "More MISC", SenseUI.Icons.settings ) then
					if SenseUI.BeginGroup("moremisc", "Grenade", 25, 25, 305, 305) then
						local gehelperenabled = gui.GetValue("GH_HELPER_ENABLED");
						local gehelperdist = gui.GetValue("GH_VISUALS_DISTANCE_SL");
					
						
						gehelperenabled = SenseUI.Checkbox("Grenade Helper", gehelperenabled);
						gui.SetValue("GH_HELPER_ENABLED", gehelperenabled);
						
						if gehelperenabled == true then
							gehelperdist = SenseUI.Slider("View Distance", 0, 9999, "", "0", "9999", false, gehelperdist);
							gui.SetValue("GH_VISUALS_DISTANCE_SL", gehelperdist);
						end
					end
					SenseUI.EndGroup();
				end
				SenseUI.EndTab();
			local mouse_x, mouse_y = input.GetMousePos()
			draw.Color( 255, 255, 255, 255 )
			draw.SetFont(draw.CreateFont("Tahoma", 24));
			draw.Text(mouse_x-7, mouse_y-10, "+")
			end
			SenseUI.EndWindow();
		end
	end

	if (load_pressed ~= old_load_pressed) and (#configs >= selected) then
        gui.Command("load " .. configs[selected], true)
    end
    
    if (save_pressed ~= old_save_pressed) and (#configs >= selected) then
        gui.Command("save " .. configs[selected], true)
    end
    
    if (add_pressed ~= old_add_pressed) and (configname ~= "") then
        table.insert(configs, configname)
        configname = ""
    end
    
    if (remove_pressed ~= old_remove_pressed) and (#configs >= selected) then
        configs[selected] = nil
    end
    
    old_load_pressed = load_pressed
    old_save_pressed = save_pressed
    old_add_pressed = add_pressed
    old_remove_pressed = remove_pressed

end

callbacks.Register( "Draw", "suitest", draw_callback );--- SenseUI Menu by uglych discord is Uglych#1515

local function OnFrameWarning()
	if math.floor(common.Time()) % 2 > 0 then
		draw.Color(0, 0, 255, 255)
	else
		draw.Color(255, 0, 0, 255)
	end
	draw.SetFont(font_warning)
	draw.Text(0, 0, "[Lua Scripting] Please enable Lua HTTP and Lua script/config and reload script")
	draw.Text(0, 10, "[Skillmeister] Changelog(Most Recent): Aimware updated and removed Callbacks, Should be fixed now")
end


if gui.GetValue("lua_allow_http") and gui.GetValue("lua_allow_cfg") then
	git_update()
	
	callbacks.Register("Draw", OnFrameMain)
	callbacks.Register("CreateMove", OnCreateMoveMain)
	callbacks.Register("FireGameEvent", OnEventMain)
	
	client.AllowListener("round_prestart")
else
	print("[Lua Scripting] Please enable Lua HTTP and Lua script/config and reload script")
	callbacks.Register("Draw", OnFrameWarning)
end

