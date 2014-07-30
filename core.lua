local addonName, ns = ...

ns.frame = CreateFrame("Frame")
ns.frame:SetScript("OnEvent", function (self, event, ...) ns[event](ns, event, ...) end)
ns.frame:RegisterEvent("ADDON_LOADED")

function ns:ADDON_LOADED(event, name)
	if name == addonName then
		ns.frame:UnregisterEvent(event)
		ns.ADDON_LOADED = nil
		FriendListColorsDB = FriendListColorsDB or {}
		ns:CreateOptions()
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
end
