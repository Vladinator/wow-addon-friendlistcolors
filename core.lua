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
local UNKNOWN = UNKNOWN

local addonName, ns = ...

local defaults = {
	format = "{color=level}[isOnline?\"L\"][isOnline?level]{/color} {color=class}[aliasName|realName]{/color}"
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

ns.frame = CreateFrame("Frame")
ns.frame:SetScript("OnEvent", function (self, event, ...) ns[event](ns, event, ...) end)
ns.frame:RegisterEvent("ADDON_LOADED")

function ns:ADDON_LOADED(event, name)
	if name == addonName then
		ns.frame:UnregisterEvent(event)
		ns.ADDON_LOADED = nil
		FriendListColorsDB = FriendListColorsDB or defaults
		FriendListColorsDB = defaults -- DEBUG
		ns:CreateOptions()
		ns:OverrideAPI()
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

			group.option = meta.createOption(meta, group.icon, group.label)

			group:AddChild(group.label)
			group:AddChild(group.option)

			--if meta.helpText then
			--	group:AddChild(group.icon)
			--end

			group.line = group.frame:CreateTexture(nil, "ARTWORK")
			group.line:SetHeight(1)
			group.line:SetPoint("BOTTOMLEFT", 0, -4)
			group.line:SetPoint("BOTTOMRIGHT", 0, -4)
			group.line:SetTexture(1, 1, 1, .2)
			group.frame.underline = group.line
		end

		container:AddChild(group)
	end

	local function OptionDefaults()
		-- TODO
	end

	-- create interface panel
	ns.panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
	ns.panel:Hide()
	ns.panel.name = addonName
	ns.panel.title = CreatePanelText(ns.panel, addonName)
	ns.panel.desc = CreatePanelText(ns.panel, ns.L.OPT_DESC, ns.panel.title)
	ns.panel.default = OptionDefaults
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
	CreateOption(scroll, {
		title = ns.L.OPT_FEATURES_TITLE,
		desc = ns.L.OPT_FEATURES_DESC,
		noHR = true
	})

	CreateOption(scroll, {
		label = ns.L.OPT_FEATURE1_TITLE,
		helpText = ns.L.OPT_FEATURE1_DESC,
		createOption = function(meta, icon, label)
			local option = Ace:Create("EditBox")
			-- TODO
			return option
		end
	})

	CreateOption(scroll, {
		label = ns.L.OPT_FEATURE2_TITLE,
		helpText = ns.L.OPT_FEATURE2_DESC,
		createOption = function(meta, icon, label)
			local option = Ace:Create("EditBox")
			-- TODO
			return option
		end
	})

	CreateOption(scroll, {
		label = ns.L.OPT_FEATURE3_TITLE,
		helpText = ns.L.OPT_FEATURE3_DESC,
		createOption = function(meta, icon, label)
			local option = Ace:Create("EditBox")
			-- TODO
			return option
		end
	})
end

function ns:OverrideAPI()
	ns.OverrideAPI = nil

	local hookFunctions = {
		"FriendsList_Update",
		"FriendsFrame_UpdateFriends",
		"FriendsFramePendingScrollFrame_AdjustScroll",
	}

	local scrollPosition

	local function GetClassColor(class)
		local classKey
		for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
			if v == class then
				classKey = k
				break
			end
		end
		if not classKey then
			for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
				if v == class then
					classKey = k
					break
				end
			end
		end
		if classKey then
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classKey]
			if color then
				return "|c" .. color.colorStr
			end
		end
		return "|cffFFFFFF"
	end

	local function GetDifficulty(level)
		level = tonumber(level or 0, 16) or 0
		local t, r, g, b, hex
		if level > 0 then
			t = GetQuestDifficultyColor(level)
			r, g, b = t.r, t.g, t.b
		end
		if not r then
			r, g, b = 1, 1, 1
		end
		hex = format("%02X%02X%02X", floor(r*255), floor(g*255), floor(b*255))
		return "|cff" .. hex, hex, r, g, b
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
			text = text:gsub("%|", "%%|")
			text = text:gsub("%?", "%%?")
			text = text:gsub("%.", "%%.")
			text = text:gsub("%_", "%%_")
			text = text:gsub("%[", "%%[")
			text = text:gsub("%]", "%%]")
			text = text:gsub("%*", "%%*")
		end
		return text
	end

	local function FormatName(meta)
		local format = FriendListColorsDB.format
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
						if not part:match("^(%!?)([%w\"]+)$") then
							break
						end
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
		local meta = {
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
		button.name.realName = realName
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

	FriendsFrameFriendsScrollFrameScrollBar:HookScript("OnValueChanged", function(self, position)
		position = floor(position + .5)
		if not scrollPosition or abs(scrollPosition - position) > 2 then
			scrollPosition = position
			UpdateFriendsScrollFrame()
		end
	end)
end
