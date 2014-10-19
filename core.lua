local _G = _G
local abs = abs
local AFK = AFK
local BNET_CLIENT_WOW = BNET_CLIENT_WOW
local BNGetFriendInfo = BNGetFriendInfo
local BNGetFriendToonInfo = BNGetFriendToonInfo
local BNGetNumFriendToons = BNGetNumFriendToons
local DND = DND
local floor = floor
local format = format
local FRIENDS_BUTTON_TYPE_BNET = FRIENDS_BUTTON_TYPE_BNET
local FRIENDS_BUTTON_TYPE_WOW = FRIENDS_BUTTON_TYPE_WOW
local FRIENDS_FRIENDS_TO_DISPLAY = FRIENDS_FRIENDS_TO_DISPLAY
local FRIENDS_GRAY_COLOR = FRIENDS_GRAY_COLOR
local FRIENDS_WOW_NAME_COLOR = FRIENDS_WOW_NAME_COLOR
local GetFriendInfo = GetFriendInfo
local GetQuestDifficultyColor = GetQuestDifficultyColor
local GetTime = GetTime
local ipairs = ipairs
local LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_FEMALE
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local pairs = pairs
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local table = table
local table_insert = table.insert
local tonumber = tonumber
local tostring = tostring
local type = type
local UnitLevel = UnitLevel
local UNKNOWN = UNKNOWN

local addonName, ns = ...

local defaults = {
	format = "{color=level}[isOnline?\"L\"][isOnline?level]{/color} {color=class}[aliasName|realName]{/color}",
}

local META_MAP = setmetatable({
	bnetID = 1,
	bnetName = 2,
	battleTag = 3,
	isBattleTag = 4,
	toonName = 5,
	toonID = 6,
	client = 7,
	isOnline = 8,
	lastOnline = 9,
	isAFK = 10,
	isDND = 11,
	broadcast = 12,
	note = 13,
	isRealID = 14,
	broadcastTime = 15,
	canSoR = 16,
	hasFocus = 17,
	realmName = 18,
	realmID = 19,
	faction = 20,
	race = 21,
	class = 22,
	guild = 23,
	zone = 24,
	level = 25,
	game = 26,
	status = 27,
	numToons = 28,
	aliasName = 29,
	realName = 30,
}, {
	__index = function()
		return 0
	end
})

local CLASS_COLORS = {}

ns.frame = CreateFrame("Frame")
ns.frame:SetScript("OnEvent", function (self, event, ...) ns[event](ns, event, ...) end)
ns.frame:RegisterEvent("ADDON_LOADED")
ns.frame:RegisterEvent("PLAYER_LOGIN")

function ns:ADDON_LOADED(event, name)
	if name == addonName then
		ns.frame:UnregisterEvent(event)
		ns[event] = nil
		FriendListColorsDB = type(FriendListColorsDB) == "table" and FriendListColorsDB or defaults
		ns:OverrideAPI()
		ns:CreateOptions()
	end
end

function ns:PLAYER_LOGIN(event)
	ns.frame:UnregisterEvent(event)
	ns[event] = nil
	local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
	for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		CLASS_COLORS[v] = colors[k]
	end
	for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		CLASS_COLORS[v] = colors[k]
	end
end

function ns:CreateOptions()
	ns.CreateOptions = nil

	-- helper functions
	local Ace = LibStub("AceGUI-3.0")

	local function CreatePanelText(panel, text, titleWidget)
		local widget = panel:CreateFontString()

		if not titleWidget then
			widget:SetFont(STANDARD_TEXT_FONT, 16, "")
			widget:SetTextColor(1, .82, 0, 1)
			widget:SetPoint("TOPLEFT", 16, -16)
			widget:SetHeight(16)
		else
			widget:SetFont(STANDARD_TEXT_FONT, 10, "")
			widget:SetTextColor(1, 1, 1, 1)
			widget:SetPoint("TOPLEFT", titleWidget, 0, titleWidget:GetText() and -24 or -16)
			widget:SetHeight(32)
		end

		widget:SetShadowColor(0, 0, 0, 1)
		widget:SetShadowOffset(1, -1)
		widget:SetJustifyH("LEFT")
		widget:SetJustifyV("TOP")
		widget:SetText(text)

		return widget
	end

	local function CreateOption(container, meta)
		if type(meta) ~= "table" then
			meta = {label = " ", noUL = 1}
		end

		local group = Ace:Create("SimpleGroup")
		group:SetFullWidth(true)
		group:SetLayout("Flow")

		if meta.title and meta.desc then
			group.title = Ace:Create("Label")
			group.title:SetFullWidth(true)
			group.title:SetFont(STANDARD_TEXT_FONT, 16, "")
			group.title:SetColor(1, .82, 0, 1)
			group.title:SetText(meta.title)
			group.title.frame.obj.label:SetShadowColor(0, 0, 0, 1)
			group.title.frame.obj.label:SetShadowOffset(1, -1)
			group.title.frame.obj.label:SetJustifyH("LEFT")
			group.title.frame.obj.label:SetJustifyV("CENTER")
			group.title.frame.obj.label:SetHeight(32)

			group.desc = Ace:Create("Label")
			group.desc:SetFullWidth(true)
			group.desc:SetFont(STANDARD_TEXT_FONT, 10, "")
			group.desc:SetColor(1, 1, 1, 1)
			group.desc:SetText(meta.desc)
			group.desc.frame.obj.label:SetShadowColor(0, 0, 0, 1)
			group.desc.frame.obj.label:SetShadowOffset(1, -1)
			group.desc.frame.obj.label:SetJustifyH("LEFT")
			group.desc.frame.obj.label:SetJustifyV("TOP")
			group.desc.frame.obj.label:SetHeight(20)

			group:SetLayout("List")
			if not meta.noHR then
				local hr = Ace:Create("Heading")
				hr:SetText("")
				group:AddChild(hr)
			end

			group:AddChild(group.title)
			group:AddChild(group.desc)

		else
			group.icon = Ace:Create("Icon")
			group.icon.frame:SetMotionScriptsWhileDisabled(true)
			group.icon.frame:SetEnabled(false)
			group.icon:SetWidth(meta.iconWidth or 18)
			group.icon:SetImage(meta.icon or "Interface\\HelpFrame\\HelpIcon-KnowledgeBase") -- "Interface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon"
			group.icon:SetImageSize(meta.iconSize or 16, meta.iconSize or 16)

			--if meta.helpText then
			--	group.icon:SetCallback("OnEnter", function(self) ShowHelpTooltip(self.frame, meta.helpText) end)
			--	group.icon:SetCallback("OnLeave", function() tip:Hide() end)
			--end

			group.label = Ace:Create("InteractiveLabel")
			group.label:SetWidth(250)
			group.label:SetFont(STANDARD_TEXT_FONT, 12, "")
			group.label:SetText(meta.label)

			group:AddChild(group.label)

			if type(meta.createOption) == "function" then
				group.option = meta.createOption(meta, group.icon, group.label)
				group:AddChild(group.option)
			end

			--if meta.helpText then
			--	group:AddChild(group.icon)
			--end

			group.line = group.frame:CreateTexture(nil, "ARTWORK")
			group.line:SetHeight(1)
			group.line:SetPoint("BOTTOMLEFT", 0, -4)
			group.line:SetPoint("BOTTOMRIGHT", 0, -4)
			group.line:SetTexture(1, 1, 1, .2)
			group.frame.underline = group.line

			if meta.noUL then
				group.line:Hide()
			end
		end

		container:AddChild(group)
	end

	local function StoragePipes(text)
		local count
		repeat
			text, count = text:gsub("%|%|", "%|")
		until not count or count == 0
		return text
	end

	local function DisplayPipes(text)
		text = StoragePipes(text)
		text = text:gsub("%|", "%|%|")
		return text
	end

	-- create interface panel
	ns.panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
	ns.panel:Hide()
	ns.panel.name = addonName
	ns.panel.title = CreatePanelText(ns.panel, addonName)
	ns.panel.desc = CreatePanelText(ns.panel, ns.L.OPT_DESC, ns.panel.title)
	InterfaceOptions_AddCategory(ns.panel)

	-- create scrolling frame
	local scroll = Ace:Create("ScrollFrame")
	scroll:SetLayout("List")
	local group = Ace:Create("SimpleGroup")
	group:SetFullWidth(true)
	group:SetFullHeight(true)
	group:SetLayout("Fill")
	if ns.panel.desc or ns.panel.title then
		group:SetPoint("TOPLEFT", ns.panel.desc or ns.panel.title, "TOPLEFT", 0, -16)
	else
		group:SetPoint("TOPLEFT", ns.panel, "TOPLEFT", 16, -16)
	end
	group:SetPoint("BOTTOMRIGHT", ns.panel, "BOTTOMRIGHT", -16, 16)
	group:AddChild(scroll)
	ns.panel:HookScript("OnShow", function() group.frame:Show() end)
	ns.panel:HookScript("OnHide", function() group.frame:Hide() end)

	-- create options
	local formatEditBox
	local formatPreviews = {}

	CreateOption(scroll, {
		label = ns.L.OPT_FORMAT_TITLE,
		createOption = function(meta, icon, label)
			local option = Ace:Create("MultiLineEditBox")
			option:SetLabel("")
			option:SetRelativeWidth(1)
			option:SetNumLines(10)
			formatEditBox = option
			return option
		end
	})

	do
		local varList = ""
		local temp = {}

		for k, v in pairs(META_MAP) do
			temp[v] = k
		end
		table.sort(temp)

		if #temp > 0 then
			for k, v in ipairs(temp) do
				varList = varList .. v .. ", "
			end
			varList = varList:sub(1, -3)
		else
			varList = "..."
		end

		CreateOption(scroll, {
			createOption = function(meta, icon, label)
				local option = Ace:Create("Label")
				option:SetFont(STANDARD_TEXT_FONT, 12, "")
				option:SetRelativeWidth(1)
				option:SetText("Variables: " .. varList)
				return option
			end
		})
	end

	CreateOption(scroll)

	CreateOption(scroll, {
		label = ns.L.OPT_PREVIEW_ONLINE_TITLE
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {1, "RealIDName", "BattleTag", false, "CharacterName", 1, BNET_CLIENT_WOW, true, nil, false, false, nil, "This friend has a note.", true, 0, false, true, "RealmName", 1, "Alliance", "Night Elf", "Hunter", "GuildName", "ZoneName", UnitLevel("player") + 5, "ZoneName - RealmName", "", 1, "AliasName", "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {1, nil, "BattleTag", true, "CharacterName", 1, BNET_CLIENT_WOW, true, nil, false, false, nil, "This friend has a note.", nil, 0, false, true, "RealmName", 1, "Horde", "Blood Elf", "Death Knight", "GuildName", "ZoneName", UnitLevel("player"), "ZoneName - RealmName", "", 1, nil, "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {nil, nil, nil, nil, "CharacterName", 1, BNET_CLIENT_WOW, true, nil, false, false, nil, "This friend has a note.", nil, nil, false, true, "RealmName", 1, "Alliance", "Human", "Mage", "GuildName", "ZoneName", UnitLevel("player") - 5, "ZoneName - RealmName", "", 1, nil, "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	CreateOption(scroll)

	CreateOption(scroll, {
		label = ns.L.OPT_PREVIEW_OFFLINE_TITLE
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {1, "RealIDName", "BattleTag", false, "CharacterName", 1, nil, nil, nil, false, false, nil, "This friend has a note.", true, 0, false, true, "RealmName", 1, "Alliance", "Night Elf", "Hunter", "GuildName", "ZoneName", UnitLevel("player") + 5, "ZoneName - RealmName", "", 1, "AliasName", "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {1, nil, "BattleTag", true, "CharacterName", 1, nil, nil, nil, false, false, nil, "This friend has a note.", nil, 0, false, true, "RealmName", 1, "Horde", "Blood Elf", "Death Knight", "GuildName", "ZoneName", UnitLevel("player"), "ZoneName - RealmName", "", 1, nil, "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	CreateOption(scroll, {
		createOption = function(meta, icon, label)
			local option = Ace:Create("Label")
			option:SetFont(STANDARD_TEXT_FONT, 14, "")
			option:SetRelativeWidth(1)
			option.example = {nil, nil, nil, nil, "CharacterName", 1, nil, nil, nil, false, false, nil, "This friend has a note.", nil, nil, false, true, "RealmName", 1, "Alliance", "Human", "Mage", "GuildName", "ZoneName", UnitLevel("player") - 5, "ZoneName - RealmName", "", 1, nil, "RealName"}
			function option:UpdateExample()
				local format = (formatEditBox:GetText() or ""):gsub("%|%|", "%|")
				local formattedString, r, g, b = ns.FormatName(option.example, format)
				if not formattedString or formattedString:len() == 0 then
					option:SetText(" ")
				else
					option:SetText(formattedString)
				end
				if r then
					option:SetColor(r, g, b)
				else
					option:SetColor(1, 1, 1)
				end
			end
			option:UpdateExample()
			table.insert(formatPreviews, option)
			return option
		end
	})

	-- handle updating and saving
	formatEditBox:SetCallback("OnTextChanged", function(self, event, text)
		local replacement, count = (text or ""):gsub("[\r\n]", "")
		-- remove new lines if any
		if count and count > 0 then
			local position = formatEditBox.frame.obj.editBox:GetUTF8CursorPosition()
			formatEditBox:SetText(DisplayPipes(replacement):trim())
			formatEditBox.frame.obj.editBox:SetCursorPosition(position - 1)
			return
		end
		-- update the previews
		for _, option in ipairs(formatPreviews) do
			option:UpdateExample()
		end
	end)

	formatEditBox:SetCallback("OnEnterPressed", function(self, event, text)
		FriendListColorsDB.format = StoragePipes(text or ""):trim()
		ns.panel.refresh()
	end)

	ns.panel.refresh = function()
		formatEditBox:SetText(DisplayPipes(FriendListColorsDB.format))
		-- update the previews
		for _, option in ipairs(formatPreviews) do
			option:UpdateExample()
		end
	end

	group.frame:HookScript("OnShow", ns.panel.refresh)

	ns.panel.default = function()
		FriendListColorsDB = defaults
		ns.panel.refresh()
	end
end

function ns:OverrideAPI()
	ns.OverrideAPI = nil

	local hookFunctions = {
		"FriendsList_Update",
		"FriendsFrame_UpdateFriends",
		"FriendsFramePendingScrollFrame_AdjustScroll",
	}

	local function GetClassColor(class)
		local color = CLASS_COLORS[class]
		if color then
			return "|c" .. color.colorStr
		end
		return "|cffFFFFFF"
	end

	local function GetDifficulty(level)
		local color = GetQuestDifficultyColor(tonumber(level or 0, 10) or 0)
		local hex = format("%02X%02X%02X", floor(color.r * 255), floor(color.g * 255), floor(color.b * 255))
		return "|cff" .. hex, hex, color.r, color.g, color.b
	end

	local function ExtractAlias(note)
		if type(note) == "string" then
			note = (note:match("%^(.-)%$") or ""):trim()
			if note:len() > 0 then
				return note
			end
		end
	end

	local function EscapePattern(text)
		if type(text) == "string" then
			text = text:gsub("%%", "%%%%")
			text = text:gsub("%|", "%%|")
			text = text:gsub("%?", "%%?")
			text = text:gsub("%.", "%%.")
			text = text:gsub("%-", "%%-")
			text = text:gsub("%_", "%%_")
			text = text:gsub("%[", "%%[")
			text = text:gsub("%]", "%%]")
			text = text:gsub("%(", "%%(")
			text = text:gsub("%)", "%%)")
			text = text:gsub("%*", "%%*")
		end
		return text
	end

	local function FormatName(meta, overrideFormat)
		local format = overrideFormat or FriendListColorsDB.format
		local r, g, b

		if meta[META_MAP.isOnline] then
			if meta[META_MAP.hasFocus] then
				r, g, b = FRIENDS_WOW_NAME_COLOR.r, FRIENDS_WOW_NAME_COLOR.g, FRIENDS_WOW_NAME_COLOR.b
			end
		else
			r, g, b = FRIENDS_GRAY_COLOR.r, FRIENDS_GRAY_COLOR.g, FRIENDS_GRAY_COLOR.b
			format = format:gsub("%{[Cc][Oo][Ll][Oo][Rr]=.-%}", "")
			format = format:gsub("%{%/[Cc][Oo][Ll][Oo][Rr]%}", "")
		end

		-- color opening tags
		for key, value in format:gmatch("%{([Cc][Oo][Ll][Oo][Rr])=(.-)%}") do
			local replace
			if value:match("[Cc][Ll][Aa][Ss][Ss]") then
				replace = GetClassColor(meta[META_MAP.class])
			elseif value:match("[Ll][Ee][Vv][Ee][Ll]") then
				replace = GetDifficulty(meta[META_MAP.level])
			else
				local r, g, b = value:match("([a-fA-F0-9][a-fA-F0-9])([a-fA-F0-9][a-fA-F0-9])([a-fA-F0-9][a-fA-F0-9])")
				if r and g and b then
					replace = "|cff" .. r .. g .. b
				end
			end
			if replace then
				format = format:gsub("%{[Cc][Oo][Ll][Oo][Rr]=" .. EscapePattern(value) .. "%}", EscapePattern(replace))
			end
		end

		-- color closing tags
		for closing, key in format:gmatch("%{(/)([Cc][Oo][Ll][Oo][Rr])%}") do
			if closing == "/" then
				format = format:gsub("%{/[Cc][Oo][Ll][Oo][Rr]%}", "|r")
			end
		end

		-- bracket tags
		for tag in format:gmatch("%[(.-)%]") do
			local singleVariable = tag:match("^([%w\"]+)$")
			-- [var]
			if singleVariable then
				format = format:gsub("%[" .. EscapePattern(tag) .. "%]", EscapePattern(tostring(meta[META_MAP[singleVariable]])))
			else
				-- [var1|var2|...]
				local orVariables = {}
				for part in tag:gmatch("[^%|]+") do
					if not part:match("^([%w\"]+)$") then
						break
					end
					singleVariable = meta[META_MAP[part]]
					singleVariable = singleVariable ~= nil and tostring(singleVariable) or ""
					table_insert(orVariables, singleVariable)
				end
				if #orVariables > 0 then
					singleVariable = ""
					for _, value in ipairs(orVariables) do
						if singleVariable == "" then
							singleVariable = value
						end
						if type(singleVariable) == "string" and singleVariable ~= "" then
							break
						end
					end
					format = format:gsub("%[" .. EscapePattern(tag) .. "%]", EscapePattern(singleVariable))
				else
					-- [!var1?var2]
					-- [var1?var2]
					local elseVariables = {}
					local inverseBoolean
					for part in tag:gmatch("[^%?]+") do
						inverseBoolean = part:match("^%!(.+)$")
						if inverseBoolean then
							elseVariables[1] = not meta[META_MAP[inverseBoolean]]
						elseif #elseVariables == 0 then
							elseVariables[1] = not not meta[META_MAP[part]]
						elseif #elseVariables == 1 then
							local literal = part:match("^\"(.+)\"$")
							if literal then
								elseVariables[2] = literal
							else
								singleVariable = meta[META_MAP[part]]
								singleVariable = singleVariable ~= nil and tostring(singleVariable) or ""
								elseVariables[2] = singleVariable
							end
						end
						if elseVariables[2] ~= nil then
							break
						end
					end
					inverseBoolean = inverseBoolean and "%!" or ""
					if elseVariables[1] == true then
						format = format:gsub("%[" .. inverseBoolean .. EscapePattern(tag) .. "%]", EscapePattern(elseVariables[2] ~= nil and tostring(elseVariables[2]) or ""))
					elseif elseVariables[1] == false then
						format = format:gsub("%[" .. inverseBoolean .. EscapePattern(tag) .. "%]", "")
					end
				end
			end
		end

		return format:trim(), r, g, b
	end

	local function ApplyStyle(button, isBNet)
		local bnetID, bnetName, battleTag, isBattleTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcast, note, isRealID, broadcastTime, canSoR -- bnet
		local hasFocus, realmName, realmID, faction, race, class, guild, zone, level, game -- toon
		local status -- friend
		local realName, numToons
		if isBNet then
			bnetID, bnetName, battleTag, isBattleTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcast, note, isRealID, broadcastTime, canSoR = BNGetFriendInfo(button.id)
			realName = (isRealID and bnetName) or (isBattleTag and battleTag) or bnetName or battleTag or toonName or UNKNOWN
			numToons = BNGetNumFriendToons(button.id) or 0
			for index = 1, numToons do
				hasFocus, toonName, client, realmName, realmID, faction, race, class, guild, zone, level, game, broadcast, broadcastTime, canSoR, toonID = BNGetFriendToonInfo(button.id, index)
				if hasFocus then
					break
				end
			end
		else
			toonName, level, class, zone, isOnline, status, note = GetFriendInfo(button.id)
			realName = toonName or UNKNOWN
			if status then
				if status:find(AFK, nil, 1) then
					isAFK, isDND = 1
				elseif status:find(DND, nil, 1) then
					isDND, isAFK = 1
				end
			end
		end
		local aliasName = ExtractAlias(note) or realName
		local meta = { -- follows META_MAP ordering
			bnetID, bnetName, battleTag, isBattleTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcast, note, isRealID, broadcastTime, canSoR,
			hasFocus, realmName, realmID, faction, race, class, guild, zone, level, game, status,
			numToons, aliasName, realName}
		local formattedText, r, g, b = FormatName(meta)
		if formattedText then
			button.name:SetText(formattedText)
		end
		if r and g and b then
			button.name:SetTextColor(r, g, b)
		end
		--button.name.realName = realName -- TODO: DEPRECATED?
	end

	local function UpdateFriendsScrollFrame()
		for index = 1, FRIENDS_FRIENDS_TO_DISPLAY do
			local button = _G["FriendsFrameFriendsScrollFrameButton" .. index]
			if button and type(button.id) == "number" and (button.buttonType == FRIENDS_BUTTON_TYPE_BNET or button.buttonType == FRIENDS_BUTTON_TYPE_WOW) then
				if button.buttonType == FRIENDS_BUTTON_TYPE_BNET then
					local _, _, _, _, _, _, client, isOnline = BNGetFriendInfo(button.id)
					if not isOnline or client == BNET_CLIENT_WOW then
						ApplyStyle(button, true)
					end
				elseif button.buttonType == FRIENDS_BUTTON_TYPE_WOW then
					local name = GetFriendInfo(button.id)
					if name then
						ApplyStyle(button, false)
					end
				end
			end
		end
	end

	for k, v in ipairs(hookFunctions) do
		hooksecurefunc(v, UpdateFriendsScrollFrame)
	end

	local scrollPosition

	FriendsFrameFriendsScrollFrameScrollBar:HookScript("OnValueChanged", function(self, position)
		position = floor(position + .5)
		if not scrollPosition or abs(scrollPosition - position) > 2 then
			scrollPosition = position
			UpdateFriendsScrollFrame()
		end
	end)

	ns.FormatName = FormatName
end
