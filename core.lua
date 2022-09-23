local GameTooltip = _G.GameTooltip ---@diagnostic disable-line: undefined-field
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory ---@diagnostic disable-line: undefined-field
local InterfaceOptionsFramePanelContainer = _G.InterfaceOptionsFramePanelContainer or _G.SettingsPanel ---@diagnostic disable-line: undefined-field
local ReloadUI = _G.ReloadUI ---@diagnostic disable-line: undefined-field

local addonName = ... ---@type string

local Color do

	---@param r number|ColorMixin
	---@param g? number
	---@param b? number
	local function ColorToHex(r, g, b)
		if type(r) == "table" then
			if r.r then
				r, g, b = r.r, r.g, r.b
			else
				r, g, b = unpack(r)
			end
		end
		if not r then
			return "ffffff"
		end
		return format("%02X%02X%02X", floor(r * 255), floor(g * 255), floor(b * 255))
	end

	---@type table<string, string>
	local cache do

		cache = {}

		---@diagnostic disable-next-line: undefined-field
		local colors = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)

		---@diagnostic disable-next-line: undefined-field
		for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do cache[v] = ColorToHex(colors[k]) end

		---@diagnostic disable-next-line: undefined-field
		for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do cache[v] = ColorToHex(colors[k]) end

		if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
			cache.Evoker = "33937F"
			cache.Monk = "00FF98"
			cache.Paladin = "F48CBA"
			cache.Shaman = "0070DD"
		end

	end

	Color = {}

	Color.From = ColorToHex

	Color.Gray = Color.From(_G.FRIENDS_GRAY_COLOR) ---@diagnostic disable-line: undefined-field
	Color.BNet = Color.From(_G.FRIENDS_BNET_NAME_COLOR) ---@diagnostic disable-line: undefined-field
	Color.WoW = Color.From(_G.FRIENDS_WOW_NAME_COLOR) ---@diagnostic disable-line: undefined-field

	---@param query any
	---@return string?
	function Color.ForClass(query)
		return cache[query]
	end

	---@param level any
	---@return string?
	function Color.ForLevel(level)
		if level and type(level) ~= "number" then
			level = tonumber(level, 10)
		end
		if not level then
			return
		end
		local color = _G.GetQuestDifficultyColor(level) ---@diagnostic disable-line: undefined-field
		return Color.From(color.r, color.g, color.b)
	end

end

local Util do

	Util = {}

	---@generic K, V
	---@param destination K
	---@param source V
	---@return K
	function Util.MergeTable(destination, source)
		for k, v in pairs(source) do
			destination[k] = v
		end
		return destination
	end

	---@param text string
	function Util.EscapePattern(text)
		if type(text) ~= "string" then
			return
		end
		return (
			text
				:gsub("%%", "%%%%")
				:gsub("%|", "%%|")
				:gsub("%?", "%%?")
				:gsub("%.", "%%.")
				:gsub("%-", "%%-")
				:gsub("%_", "%%_")
				:gsub("%[", "%%[")
				:gsub("%]", "%%]")
				:gsub("%(", "%%(")
				:gsub("%)", "%%)")
				:gsub("%*", "%%*")
		)
	end

	---@param a any
	---@param b any
	---@param c any
	function Util.SafeReplace(a, b, c)
		if type(a) == "string" and type(b) == "string" and type(c) == "string" then
			a = a:gsub(b, c)
		end
		return a
	end

	---@param oldName string
	---@param newName string
	---@param lineID? number
	---@param bnetIDAccount? number
	function Util.SafeReplaceName(oldName, newName, lineID, bnetIDAccount)
		if bnetIDAccount then
			-- HOTFIX: Disable custom names when handling chat messages from BNet friends until we figure out a possible workaround.
			-- `GetBNPlayerLink` is not working well when used to replace the real BNet name with an alias in the chat the name gets mangled something fierce.
			if lineID then
				return oldName
			end
			return _G.GetBNPlayerLink(newName, newName, bnetIDAccount, lineID) ---@diagnostic disable-line: undefined-field
		end
		return newName
	end

end

local Parse do

	Parse = {}

	---@param note any
	---@return string?
	function Parse.Note(note)
		if type(note) ~= "string" then
			return
		end
		local alias = note:match("%^(.-)%$")
		if alias and alias ~= "" then
			return alias
		end
	end

	---@param friendWrapper FriendWrapper
	---@param field string
	function Parse.Color(friendWrapper, field)

		---@type string|number|boolean|nil
		local out

		---@type string|number|boolean|nil
		local value = friendWrapper.data[field]

		if field == "level" or field == "characterLevel" then
			out = Color.ForLevel(value)
		elseif field == "className" or field == "class" then
			out = Color.ForClass(value)
		end

		if not out then
			local r, g, b = field:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$") ---@type string?, string?, string?
			if r then
				out = Color.From(r/255, g/255, b/255)
			else
				local hex = field:match("^%s*([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])%s*$") ---@type string?
				if hex then
					out = hex
				end
			end
		end

		if not out then
			---@diagnostic disable-next-line: undefined-field
			local offline = not friendWrapper.data[friendWrapper.type == _G.FRIENDS_BUTTON_TYPE_BNET and "isOnline" or "connected"]
			if offline then
				out = Color.Gray
			elseif friendWrapper.type == _G.FRIENDS_BUTTON_TYPE_BNET then ---@diagnostic disable-line: undefined-field
				out = Color.BNet
			else
				out = Color.WoW
			end
		end

		if not out then
			out = "ffffff"
		end

		return out

	end

	---@param friendWrapper FriendWrapper
	---@param text string
	---@param content? string
	---@param reverseLogic? boolean
	function Parse.Logic(friendWrapper, text, content, reverseLogic)

		---@type string|number|boolean|nil
		local out

		---@type string[]
		local fields = {strsplit("|", text)}

		if not fields[1] then
			fields = {text}
		end

		for i = 1, #fields do

			local field = fields[i]
			local value = friendWrapper.data[field] ---@type string|number|boolean|nil

			if value ~= nil then

				if field == "accountName" or field == "name" then

					---@diagnostic disable-next-line: undefined-field
					local note = friendWrapper.data[friendWrapper.type == _G.FRIENDS_BUTTON_TYPE_BNET and "note" or "notes"] ---@type string?
					local alias = Parse.Note(note)

					if alias then
						out = alias
					end

				end

				if not out then
					out = value
				end

				if (not out) or out == "" or out == 0 or out == "0" then
					out = nil
				end

				if out ~= nil then
					out = tostring(out)
					break
				end

			end

		end

		if content and content ~= "" then
			if reverseLogic then
				if out ~= nil then
					out = nil
				else
					out = content
				end
			end
			if out ~= nil then
				return Parse.Format(friendWrapper, content)
			end
			return ""
		end

		if out == nil then
			return ""
		elseif type(out) == "string" then
			return out
		else
			return tostring(out)
		end

	end

	---@param friendWrapper FriendWrapper
	---@param text string
	function Parse.Format(friendWrapper, text)

		-- [=X|Y|Z|...]
		for matched, logic in text:gmatch("(%[=(.-)%])") do
			text = Util.SafeReplace(
				text,
				Util.EscapePattern(matched),
				Parse.Logic(friendWrapper, logic)
			)
		end

		-- [color=X]Y[/color]
		for matched, blockText, content in text:gmatch("(%[[cC][oO][lL][oO][rR]=(.-)%](.-)%[%/[cC][oO][lL][oO][rR]%])") do
			text = Util.SafeReplace(
				text,
				Util.EscapePattern(matched),
				format("|cff%s%s|r", Parse.Color(friendWrapper, blockText), Parse.Format(friendWrapper, content))
			)
		end

		-- [if=X]Y[/if]
		for matched, logic, content in text:gmatch("(%[[iI][fF]=(.-)%](.-)%[%/[iI][fF]%])") do
			text = Util.SafeReplace(
				text,
				Util.EscapePattern(matched),
				Parse.Logic(friendWrapper, logic, content)
			)
		end

		-- [if~=X]Y[/if]
		for matched, logic, content in text:gmatch("(%[[iI][fF][%~%!]=(.-)%](.-)%[%/[iI][fF]%])") do
			text = Util.SafeReplace(
				text,
				Util.EscapePattern(matched),
				Parse.Logic(friendWrapper, logic, content, true)
			)
		end

		return text

	end

end

local Friends do

	---@class BNetAccountInfoExtended : BNetGameAccountInfo, BNetAccountInfo

	Friends = {}

	---@param friendIndex number
	---@param accountIndex number
	---@param wowAccountGUID? string
	---@return BNetAccountInfoExtended?
	function Friends.BNGetFriendGameAccountInfo(friendIndex, accountIndex, wowAccountGUID)
		local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
		local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex, wowAccountGUID)
		if not gameAccountInfo and not accountInfo then
			return
		end
		return Util.MergeTable(gameAccountInfo or {}, accountInfo or {}) ---@diagnostic disable-line: return-type-mismatch
	end

	---@param friendIndex number
	---@param wowAccountGUID? string
	function Friends.BNGetFriendInfo(friendIndex, wowAccountGUID)
		return C_BattleNet.GetFriendAccountInfo(friendIndex, wowAccountGUID)
	end

	---@param id number
	---@param wowAccountGUID? string
	function Friends.BNGetFriendInfoByID(id, wowAccountGUID)
		return C_BattleNet.GetAccountInfoByID(id, wowAccountGUID)
	end

	---@param friendIndex number
	function Friends.BNGetNumFriendGameAccounts(friendIndex)
		return C_BattleNet.GetFriendNumGameAccounts(friendIndex)
	end

	---@param query number|string
	function Friends.GetFriendInfo(query)
		local info ---@type FriendInfo?
		if type(query) == "number" then
			info = C_FriendList.GetFriendInfoByIndex(query)
		end
		if type(query) == "string" then
			info = C_FriendList.GetFriendInfo(query)
		end
		if not info then
			return
		end
		Friends.AddFieldAlias(info)
		return info
	end

	---@param data BNetAccountInfoExtended|BNetAccountInfo
	---@param id number
	function Friends.PackageFriendBNetCharacter(data, id)
		for i = 1, Friends.BNGetNumFriendGameAccounts(id) do
			local temp = Friends.BNGetFriendGameAccountInfo(id, i)
			if temp and temp.clientProgram == _G.BNET_CLIENT_WOW then ---@diagnostic disable-line: undefined-field
				for k, v in pairs(temp) do
					data[k] = v
				end
				break
			end
		end
		Friends.AddFieldAlias(data, true)
		return data
	end

	---@param data BNetAccountInfoExtended|BNetAccountInfo|FriendInfo
	---@param isBNet? boolean
	function Friends.AddFieldAlias(data, isBNet)
		if isBNet then
			-- data.name = data.characterName
			data.characterLevel = data.level
			data.area = data.areaName
		else
			-- data.characterName = data.name
			data.level = data.characterLevel
			data.areaName = data.area
		end
		data.class = data.className
		data.race = data.raceName
	end

	---@alias FriendType number `2`=`FRIENDS_BUTTON_TYPE_BNET` and `3`=`FRIENDS_BUTTON_TYPE_WOW`

	---@class FriendWrapper
	---@field public type FriendType
	---@field public data? BNetAccountInfoExtended|BNetAccountInfo|FriendInfo

	---@param buttonType FriendType
	---@param id number
	---@return FriendWrapper?
	function Friends.PackageFriend(buttonType, id)
		local temp ---@type FriendWrapper
		if buttonType == _G.FRIENDS_BUTTON_TYPE_BNET then ---@diagnostic disable-line: undefined-field
			temp = {
				type = buttonType,
				data = Friends.PackageFriendBNetCharacter(Friends.BNGetFriendInfo(id), id),
			}
		elseif buttonType == _G.FRIENDS_BUTTON_TYPE_WOW then ---@diagnostic disable-line: undefined-field
			temp = {
				type = buttonType,
				data = Friends.GetFriendInfo(id),
			}
		end
		if not temp.data then
			return
		end
		return temp
	end

	---@param chatType ChatType
	---@param name string
	---@param lineID? number
	function Friends.GetAlias(chatType, name, lineID)
		if chatType == "WHISPER" then
			local friendInfo = Friends.GetFriendInfo(name)
			if friendInfo then
				local newName = Parse.Note(friendInfo.notes)
				if newName then
					return Util.SafeReplaceName(name, newName, lineID)
				end
			end
		elseif chatType == "BN_WHISPER" then
			local presenceID = GetAutoCompletePresenceID(name)
			if presenceID then
				local friendInfo = Friends.BNGetFriendInfoByID(presenceID)
				if friendInfo then
					local newName = Parse.Note(friendInfo.note)
					if newName then
						return Util.SafeReplaceName(name, newName, lineID, presenceID)
					end
				end
			end
		end
		return name
	end

	---@param text string
	function Friends.ReplaceName(text)
		if type(text) ~= "string" then
			return text
		end
		return (text:gsub("|HBNplayer:(.-)|h(.-)|h", function(data, displayText) return format("|HBNplayer:%s|h%s|h", data, (Friends.GetAlias("BN_WHISPER", displayText))) end))
	end

end

local Config = {
	format = "[if=level][color=level]L[=level][/color] [/if][color=class][=accountName|name][if=characterName] ([=characterName])[/if][/color]",
	-- format = "[if=level][color=level]L[=level][/color] [/if][color=class][=accountName|characterName|name][/color]",
	-- format = "[if=level][color=level]Lv. [=level][/color] [/if][color=class][if=characterName][=characterName] ([=accountName|battleTag])[/if][if~=characterName][=accountName|battleTag|name][/if][if=race] [=race][/if][if=class] [=class][/if][/color]",
}

local Init do

	local function InitConfig()
		local name = format("%sDB", addonName)
		Config = _G[name] or Config
		_G[name] = Config
	end

	local function InitAPI()

		local SetText ---@type fun(self: Button, text?: any)

		---@class ListFrameButton : Button
		---@field buttonType number
		---@field id number
		---@field gameIcon Texture
		---@field name FontString

		---@param self ListFrameButton
		---@param ... any
		local function UpdateButtonName(self, ...)
			---@diagnostic disable-next-line: assign-type-mismatch
			local button = self:GetParent() ---@type ListFrameButton
			local buttonType, id = button.buttonType, button.id
			if buttonType == _G.FRIENDS_BUTTON_TYPE_BNET or buttonType == _G.FRIENDS_BUTTON_TYPE_WOW then ---@diagnostic disable-line: undefined-field
				local friendWrapper = Friends.PackageFriend(buttonType, id)
				if friendWrapper then
					-- button.gameIcon:SetTexture("Interface\\Buttons\\ui-paidcharactercustomization-button")
					-- button.gameIcon:SetTexCoord(8/128, 55/128, 72/128, 119/128)
					return SetText(self, Parse.Format(friendWrapper, Config.format))
				end
			end
			return SetText(self, ...)
		end

		local HookButtons do
			---@type table<ListFrameButton, boolean>
			local hookedButtons = {}
			---@param buttons ListFrameButton[]
			function HookButtons(buttons)
				for i = 1, #buttons do
					local button = buttons[i]
					if not hookedButtons[button] then
						hookedButtons[button] = true
						if not SetText then
							SetText = button.name.SetText
						end
						button.name.SetText = UpdateButtonName
					end
				end
			end
		end

		---@class ListFrame : Frame
		---@field ScrollBox? ScrollFrame
		---@field buttons? ListFrameButton[]

		---@type ListFrame
		local scrollFrame = _G.FriendsListFrameScrollFrame or _G.FriendsFrameFriendsScrollFrame or _G.FriendsListFrame ---@diagnostic disable-line: undefined-field

		if scrollFrame.ScrollBox then
			scrollFrame.ScrollBox:GetView():RegisterCallback(_G.ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, button, created) if created then HookButtons({button}) end end) ---@diagnostic disable-line: undefined-field
		end

		if scrollFrame.buttons then
			HookButtons(scrollFrame.buttons)
		end

		if _G.ChatEdit_UpdateHeader then ---@diagnostic disable-line: undefined-field

			---@param editBox EditBox
			local function ChatEdit_UpdateHeader(editBox)

				---@diagnostic disable-next-line: assign-type-mismatch
				local chatType = editBox:GetAttribute("chatType") ---@type ChatType
				if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
					return
				end

				local header = _G[format("%sHeader", editBox:GetName())] ---@type Button
				if not header then
					return
				end

				---@diagnostic disable-next-line: assign-type-mismatch
				local name = editBox:GetAttribute("tellTarget") ---@type string
				if not name then
					return
				end

				local newName = Friends.GetAlias(chatType, name)
				header:SetFormattedText(_G[format("CHAT_%s_SEND", chatType)], newName)

				local headerSuffix = _G[format("%sHeaderSuffix", editBox:GetName())] ---@type Frame
				local headerWidth = (header:GetRight() or 0) - (header:GetLeft() or 0)
				local editBoxWidth = editBox:GetRight() - editBox:GetLeft()

				if headerWidth > editBoxWidth / 2 then
					header:SetWidth(editBoxWidth / 2)
					headerSuffix:Show()
				end

				editBox:SetTextInsets(15 + header:GetWidth() + (headerSuffix:IsShown() and headerSuffix:GetWidth() or 0), 13, 0, 0)

			end

			hooksecurefunc("ChatEdit_UpdateHeader", ChatEdit_UpdateHeader)

		end

		if _G.ChatFrame_AddMessageEventFilter then ---@diagnostic disable-line: undefined-field

			---@param self Frame
			---@param event WowEvent
			---@param text string
			---@param name string
			---@param ... any
			local function ChatFilter_AddMessage(self, event, text, name, ...)
				local chatType ---@type ChatType
				if event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
					chatType = "WHISPER"
				elseif event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
					chatType = "BN_WHISPER"
				end
				if not chatType then
					return false
				end
				local lineID = select(9, ...)
				local newName = Friends.GetAlias(chatType, name, lineID)
				return false, text, newName, ...
			end

			_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_AFK", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field
			_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_DND", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field
			_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field
			_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field

			-- bnet names can't be modified with a simple chat event filter, and there are also issues when doing it the hard-way
			-- as replacing the special escape patterns used for bnet names can also malform the chat frame irreversably...

			-- _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field
			-- _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatFilter_AddMessage) ---@diagnostic disable-line: undefined-field

			-- if _G.FCF_OpenTemporaryWindow then ---@diagnostic disable-line: undefined-field

			-- 	---@class HistoryBufferElement
			-- 	---@field message string

			-- 	---@class HistoryBuffer
			-- 	---@field headIndex number
			-- 	---@field maxElements number
			-- 	---@field elements HistoryBufferElement[]
			-- 	---@field PushFront fun(self: HistoryBuffer)

			-- 	---@class ChatFrame : Frame
			-- 	---@field historyBuffer HistoryBuffer

			-- 	---@param self HistoryBuffer
			-- 	local function PushFront(self)
			-- 		local count = self.headIndex
			-- 		if count == 0 then
			-- 			count = self.maxElements
			-- 		end
			-- 		local element = self.elements[count]
			-- 		if not element then
			-- 			return
			-- 		end
			-- 		local text = element.message
			-- 		if not text or text == "" then
			-- 			return
			-- 		end
			-- 		element.message = Util.EditTextReplaceNames(text)
			-- 	end

			-- 	---@type table<ChatFrame, boolean>
			-- 	local chatFrameHooks = {}
			-- 	local lastChatFrameHookIndex = 1

			-- 	for i = 1, 100 do

			-- 		local chatFrame = _G[format("ChatFrame%d", i)] ---@type ChatFrame
			-- 		if not chatFrame then
			-- 			lastChatFrameHookIndex = i
			-- 			break
			-- 		end

			-- 		if i ~= 2 and (not chatFrameHooks[chatFrame]) then
			-- 			chatFrameHooks[chatFrame] = true
			-- 			local historyBuffer = chatFrame.historyBuffer
			-- 			hooksecurefunc(historyBuffer, "PushFront", PushFront)
			-- 			-- local count = historyBuffer.headIndex
			-- 			-- for j = 1, count do
			-- 			-- 	local element = historyBuffer.elements[j]
			-- 			-- 	local text = element and element.message
			-- 			-- 	if text and text ~= "" then
			-- 			-- 		element.message = Friends.EditTextReplaceNames(text)
			-- 			-- 	end
			-- 			-- end
			-- 		end

			-- 	end

			-- 	local function FCF_OpenTemporaryWindow()
			-- 		for i = lastChatFrameHookIndex, 100 do

			-- 			local chatFrame = _G[format("ChatFrame%d", i)] ---@type ChatFrame
			-- 			if not chatFrame then
			-- 				lastChatFrameHookIndex = i
			-- 				break
			-- 			end

			-- 			if not chatFrameHooks[chatFrame] then
			-- 				chatFrameHooks[chatFrame] = true
			-- 				hooksecurefunc(chatFrame.historyBuffer, "PushFront", PushFront)
			-- 			end

			-- 		end
			-- 	end

			-- 	hooksecurefunc("FCF_OpenTemporaryWindow", FCF_OpenTemporaryWindow)

			-- end

		end

		if _G.QuickJoinToastButton then ---@diagnostic disable-line: undefined-field

			---@diagnostic disable-next-line: undefined-field
			local SetText = getmetatable(_G.QuickJoinToastButton.Toast.Text).__index.SetText ---@type fun(self: Button, text: string)

			---@class QuickJoinFrameButtonEntryDisplayMember : Button

			---@class QuickJoinFrameButtonEntry
			---@field displayedMembers QuickJoinFrameButtonEntryDisplayMember[]

			---@class QuickJoinFrameButtonMember : Button

			---@class QuickJoinFrameButton : Button
			---@field SetEntry fun(self: QuickJoinFrameButton)
			---@field entry QuickJoinFrameButtonEntry
			---@field Members QuickJoinFrameButtonMember[]

			---@param self QuickJoinFrameButton
			local function QuickJoinButtonSetEntry(self)
				if not self.entry then
					return
				end
				for i = 1, #self.entry.displayedMembers do
					local member = self.Members[i]
					local text = member:GetText()
					if text and text ~= "" then
						local newText = Friends.ReplaceName(text)
						SetText(member, newText)
					end
				end
			end

			local QuickJoinHookButtons do
				---@type table<QuickJoinFrameButton, boolean>
				local hookedButtons = {}
				---@param buttons QuickJoinFrameButton[]
				function QuickJoinHookButtons(buttons)
					for i = 1, #buttons do
						local button = buttons[i]
						if not hookedButtons[button] then
							hookedButtons[button] = true
							hooksecurefunc(button, "SetEntry", QuickJoinButtonSetEntry)
						end
					end
				end
			end

			---@class QuickJoinFrame : Frame
			---@field ScrollBox? ScrollFrame
			---@field buttons? QuickJoinFrameButton[]

			---@type QuickJoinFrame
			local quickJoinScrollFrame = _G.QuickJoinFrame ---@diagnostic disable-line: undefined-field

			if quickJoinScrollFrame.ScrollBox then
				quickJoinScrollFrame.ScrollBox:GetView():RegisterCallback(_G.ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, button, created) if created then QuickJoinHookButtons({button}) end end) ---@diagnostic disable-line: undefined-field
			end

			if quickJoinScrollFrame.buttons then
				QuickJoinHookButtons(quickJoinScrollFrame.buttons)
			end

			---@param self Button
			---@param text string
			local function ToastSetText(self, text)
				if not text or text == "" then
					return
				end
				local newText = Friends.ReplaceName(text)
				SetText(self, newText)
			end

			hooksecurefunc(_G.QuickJoinToastButton.Toast.Text, "SetText", ToastSetText) ---@diagnostic disable-line: undefined-field
			hooksecurefunc(_G.QuickJoinToastButton.Toast2.Text, "SetText", ToastSetText) ---@diagnostic disable-line: undefined-field

		end

	end

	local function InitUI()

		local ui
		local unique = 1

		---@param format string
		---@param isBNet? boolean
		local function ExampleFriend(format, isBNet)
			local friendWrapper = {} ---@type FriendWrapper
			local maxLevel = GetMaxLevelForExpansionLevel(GetExpansionLevel())
			if isBNet then
				---@type BNetAccountInfoExtended
				local data = {
					accountName = "Ola Nordmann",
					appearOffline = false,
					battleTag = "Ola#1234",
					bnetAccountID = 1234,
					customMessage = "Hello World!",
					customMessageTime = 0,
					isAFK = false,
					isBattleTagFriend = false,
					isDND = false,
					isFavorite = true,
					isFriend = true,
					lastOnlineTime = 0,
					note = "This is a sample bnet note.",
					rafLinkType = _G.Enum.RafLinkType.Friend,
					-- BNetGameAccountInfo (gameAccountInfo)
					areaName = "Oribos",
					canSummon = false,
					characterLevel = maxLevel,
					characterName = "Carl",
					className = "Mage",
					clientProgram = "BNET_CLIENT_WOW",
					factionName = "Horde",
					gameAccountID = 5678,
					hasFocus = true,
					isGameAFK = false,
					isGameBusy = false,
					isInCurrentRegion = false,
					isOnline = true,
					isWowMobile = false,
					playerGuid = "Example12345678",
					raceName = "Blood Elf",
					realmDisplayName = "Tarren Mill",
					realmID = 1,
					realmName = "TarrenMill",
					regionID = 1,
					richPresence = "Oribos - TarrenMill",
					wowProjectID = _G.WOW_PROJECT_MAINLINE,
				}
				friendWrapper.type = _G.FRIENDS_BUTTON_TYPE_BNET ---@diagnostic disable-line: undefined-field
				friendWrapper.data = data
			else
				---@type FriendInfo
				local data = {
					-- FriendInfo
					afk = false,
					area = "Oribos",
					className = "Mage",
					connected = true,
					dnd = false,
					guid = "Example12345678",
					level = maxLevel,
					mobile = false,
					name = "Carl",
					notes = "This is a sample friend note.",
					rafLinkType = _G.Enum.RafLinkType.Friend,
				}
				friendWrapper.type = _G.FRIENDS_BUTTON_TYPE_WOW ---@diagnostic disable-line: undefined-field
				friendWrapper.data = data
			end
			return Parse.Format(friendWrapper, format)
		end

		---@param raw string
		---@return string
		local function ConvertToText(raw)
			return (raw:gsub("|", "||"))
		end

		---@param raw string
		---@return string
		local function ConvertToFormat(raw)
			return (raw:gsub("||", "|"))
		end

		local varNamesBNet = {
			"accountName",
			"battleTag",
			"characterName",
			"characterLevel",
			"className",
			"areaName",
			"note",
			"customMessage",
			"richPresence",
			"raceName",
			"factionName",
			"realmName",
			"realmDisplayName",
			"canSummon",
			"isInCurrentRegion",
			"isFavorite",
			"isBattleTagFriend",
			"appearOffline",
			"isOnline",
			"isWowMobile",
			"isGameAFK",
			"isGameBusy",
			"isAFK",
			"isDND",
		}

		local varNamesWoW = {
			"name",
			"level",
			"className",
			"area",
			"notes",
			"connected",
			"mobile",
			"afk",
			"dnd",
		}

		local optionGroups = {
			{
				label = "Format",
				description = "Customize the appearance of your friends list.\n\nList of variables for BNet friends:  " ..
					"|cffFFFF00" .. table.concat(varNamesBNet, "|r  |cffFFFF00") .. "|r" ..
					"\n\nList of variables for World of Warcraft friends:  " ..
					"|cffFFFF00" .. table.concat(varNamesWoW, "|r  |cffFFFF00") .. "|r" ..
					"\n\nSyntax examples:\n  [=accountName||name]\n  [if=battleTag][=battleTag][if=characterName] - [=characterName][/if][/if]\n  [color=class][=characterName||name][/color]\n  [color=level][=level][/color]\n",
				options = {
					{
						text = true,
						label = "",
						description = "",
						key = "format"
					},
					{
						paragraph = true,
						example1 = true,
						label = "",
						description = ""
					},
					{
						paragraph = true,
						example2 = true,
						label = "",
						description = ""
					}
				}
			}
		}

		local handlers

		handlers = {
			panel = {
				okay = function()
				end,
				cancel = function()
				end,
				default = function()
					_G[format("%sDB", addonName)] = nil
					ReloadUI()
				end,
				refresh = function()
					for i = 1, #ui.widgets do
						local widget = ui.widgets[i]
						if type(widget.refresh) == "function" then
							widget.refresh(widget)
						end
					end
				end
			},
			option = {
				default = {
					update = function(self)
					end,
					click = function(self)
						handlers.panel.refresh()
					end,
				},
				number = {
					update = function(self)
					end,
					save = function(self)
						handlers.panel.refresh()
					end
				},
				text = {
					update = function(self)
						if self:HasFocus() then
							return
						end
						self:SetText(ConvertToText(Config.format))
						self:SetCursorPosition(0)
					end,
					save = function(self)
						Config.format = ConvertToFormat(self:GetText())
						handlers.panel.refresh()
					end,
					example = function(self)
						local temp = "\n"
						if self.option.example1 then
							temp = temp .. "\n"
						end
						local format = self:GetParent():GetParent():GetParent().widgets[1]
						temp = temp .. ExampleFriend(ConvertToFormat(format:GetText()), self.option.example1)
						self:SetText(temp)
					end
				},
			},
			group = {
				update = function(self)
				end,
				click = function(self)
					handlers.panel.refresh()
				end
			},
		}

		---@class PanelWidget : Frame

		---@class PanelTitle : PanelWidget

		---@param panel Frame
		---@param name string
		---@param version? string
		local function CreateTitle(panel, name, version)

			---@type PanelTitle
			local title = CreateFrame("Frame", "$parentTitle" .. unique, panel) ---@diagnostic disable-line: assign-type-mismatch
			unique = unique + 1
			title:SetPoint("TOPLEFT", panel, "TOPLEFT")
			title:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
			title:SetHeight(70)

			title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			title.text:SetJustifyH("CENTER")
			title.text:SetPoint("TOP", title, "TOP", 0, -20)
			title.text:SetText(name)

			title.version = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			title.version:SetJustifyH("CENTER");
			title.version:SetPoint("TOP", title, "TOP", 0, -46)
			title.version:SetText(version)

			return title

		end

		---@class PanelHeader : PanelWidget

		---@param panel Frame
		---@param anchor PanelWidget
		---@param text string
		local function CreateHeader(panel, anchor, text)

			---@type PanelHeader
			local header = CreateFrame("Frame", "$parentHeader" .. unique, anchor:GetParent() or anchor) ---@diagnostic disable-line: assign-type-mismatch
			unique = unique + 1
			header:SetHeight(18)

			if anchor:GetObjectType() == "Frame" then
				header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
				header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")
			else
				header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -10, 0)
				header:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT")
			end

			header.label = header:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
			header.label:SetPoint("TOP")
			header.label:SetPoint("BOTTOM")
			header.label:SetJustifyH("CENTER")
			header.label:SetText(text)

			header.left = header:CreateTexture(nil, "BACKGROUND")
			header.left:SetHeight(8)
			header.left:SetPoint("LEFT", 10, 0)
			header.left:SetPoint("RIGHT", header.label, "LEFT", -5, 0) -- TODO: repeat at the end?
			header.left:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
			header.left:SetTexCoord(.81, .94, .5, 1)

			header.right = header:CreateTexture(nil, "BACKGROUND")
			header.right:SetHeight(8)
			header.right:SetPoint("RIGHT", -10, 0)
			header.right:SetPoint("LEFT", header.label, "RIGHT", 5, 0)
			header.right:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
			header.right:SetTexCoord(.81, .94, .5, 1)

			return header

		end

		---@class PanelParagraph : PanelWidget

		---@param anchor PanelWidget
		---@param text string
		local function CreateParagraph(anchor, text)

			local MAX_HEIGHT = 255

			---@type PanelParagraph
			local header = CreateFrame("Frame", "$parentParagraph" .. unique, anchor:GetParent() or anchor) ---@diagnostic disable-line: assign-type-mismatch
			unique = unique + 1
			header:SetHeight(MAX_HEIGHT)

			header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
			header:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT")

			header.label = header:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
			header.label:SetPoint("TOPLEFT", 10, -5)
			header.label:SetPoint("BOTTOMRIGHT", -10, 5)
			header.label:SetJustifyH("LEFT")
			header.label:SetJustifyV("TOP")
			header.label:SetText(text)
			header.label:SetHeight(MAX_HEIGHT)

			header.label:SetWordWrap(true) ---@diagnostic disable-line: redundant-parameter
			header.label:SetNonSpaceWrap(true)
			header.label:SetMaxLines(20)

			header:SetScript("OnUpdate", function()
				if header:GetHeight() < MAX_HEIGHT and header.label:GetHeight() == header:GetHeight() then
					header:SetScript("OnUpdate", nil) ---@diagnostic disable-line: param-type-mismatch
				end
				local height = header.label:GetStringHeight() + 5
				header.label:SetHeight(height)
				header:SetHeight(height)
			end)

			-- TODO: OBSCOLETE?
			header:SetScript("OnSizeChanged", function()
				local height = header.label:GetStringHeight() + 5
				header.label:SetHeight(height)
				header:SetHeight(height)
			end)

			-- header:SetScript("OnHide", function()
			-- 	header:SetHeight(MAX_HEIGHT)
			-- 	header.label:SetHeight(MAX_HEIGHT)
			-- end)

			return header

		end

		---@class PanelEditBox : PanelWidget, EditBox
		---@field Left Frame
		---@field Middle Frame
		---@field Right Frame
		---@field Backdrop Frame|BackdropTemplate

		---@param anchor PanelWidget
		---@param kind? "number"|"text"
		---@param text? string
		---@param tooltip? string
		local function CreateInput(anchor, kind, text, tooltip)

			---@type PanelEditBox
			local editbox = CreateFrame("EditBox", "$parentEditBox" .. unique, anchor:GetParent() or anchor, "InputBoxTemplate") ---@diagnostic disable-line: assign-type-mismatch
			unique = unique + 1
			editbox:SetFontObject("GameFontHighlight")
			editbox:SetSize(160, 22)
			editbox:SetAutoFocus(false)
			editbox:SetHyperlinksEnabled(false) ---@diagnostic disable-line: redundant-parameter
			editbox:SetMultiLine(false)
			editbox:SetIndentedWordWrap(false) ---@diagnostic disable-line: redundant-parameter
			editbox:SetMaxLetters(255)
			editbox.tooltipText = tooltip

			if kind == "number" then
				editbox:SetMaxLetters(4)
				editbox:SetNumeric(true)
				editbox:SetNumber(text)
			else
				editbox:SetText(text)
			end

			editbox:SetScript("OnEscapePressed", function() editbox:ClearFocus() end)
			editbox:SetScript("OnEnterPressed", function() editbox:ClearFocus() end)
			editbox:SetScript("OnEditFocusLost", handlers.panel.refresh)

			editbox:SetScript("OnEnter", function() if editbox.tooltipText then GameTooltip:SetOwner(editbox, "ANCHOR_RIGHT") GameTooltip:SetText(editbox.tooltipText, nil, nil, nil, nil, true) GameTooltip:Show() end end)
			editbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

			if anchor:GetObjectType() == "Frame" then
				editbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, -10)
			else
				editbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
			end

			if kind == "text" then
				editbox:SetHeight(200)
				editbox:SetMultiLine(true)
				editbox:SetMaxLetters(1024)

				editbox:SetPoint("RIGHT", -8, 0)

				editbox.Left:Hide()
				editbox.Middle:Hide()
				editbox.Right:Hide()

				editbox.Backdrop = CreateFrame("Frame", nil, editbox, false and BackdropTemplateMixin and "BackdropTemplate") -- TODO: 9.0
				editbox.Backdrop:SetPoint("TOPLEFT", editbox, "TOPLEFT", -8, 8)
				editbox.Backdrop:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", 4, -10)

				if editbox.Backdrop.SetBackdrop then
					editbox.Backdrop:SetBackdrop({
						bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						tile = true, tileSize = 16, edgeSize = 16,
						insets = { left = 4, right = 4, top = 4, bottom = 4 }
					})
					editbox.Backdrop:SetBackdropColor(0, 0, 0, 1)
				end

				editbox.Backdrop:SetFrameLevel(5)
				editbox:SetFrameLevel(10)
			end

			return editbox

		end

		local function CreatePanel()

			local panel = CreateFrame("Frame", addonName .. "Panel" .. unique, InterfaceOptionsFramePanelContainer)
			unique = unique + 1
			panel.widgets = {} ---@type PanelWidget[]
			panel.name = addonName

			-- add the standard interface buttons
			for key, func in pairs(handlers.panel) do
				panel[key] = func
			end

			-- create scroll, bar, and content frame
			do

				local PANEL_SCROLL_HEIGHT = 0 -- TODO: dynamic max?

				panel.scroll = CreateFrame("ScrollFrame", nil, panel)
				panel.scroll:SetPoint("TOPLEFT", 10, -10)
				panel.scroll:SetPoint("BOTTOMRIGHT", -26, 10)

				panel.scroll.bar = CreateFrame("Slider", nil, panel.scroll, "UIPanelScrollBarTemplate")
				panel.scroll.bar.scrollStep = 50
				panel.scroll.bar:SetPoint("TOPLEFT", panel, "TOPRIGHT", -22, -26)
				panel.scroll.bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 22, 26)
				panel.scroll.bar:SetMinMaxValues(0, PANEL_SCROLL_HEIGHT)
				panel.scroll.bar:SetValueStep(panel.scroll.bar.scrollStep)
				panel.scroll.bar:SetValue(0)
				panel.scroll.bar:SetWidth(16)
				panel.scroll.bar:SetScript("OnValueChanged", function(_, value) panel.scroll:SetVerticalScroll(value) end)

				panel.scroll:EnableMouse(true)
				panel.scroll:EnableMouseWheel(true)
				panel.scroll:SetScript("OnMouseWheel", function(_, delta) local a, b = panel.scroll.bar:GetMinMaxValues() local value = min(b, max(a, panel.scroll:GetVerticalScroll() - (delta * panel.scroll.bar.scrollStep))) panel.scroll:SetVerticalScroll(value) panel.scroll.bar:SetValue(value) end)

				panel.content = CreateFrame("Frame", nil, panel.scroll)
				panel.scroll:SetScript("OnSizeChanged", function(_, width, height) panel.content:SetSize(width, height) end)

				panel.scroll:SetScrollChild(panel.content)

				if PANEL_SCROLL_HEIGHT <= 0 then
					panel.scroll.bar:Hide()
				end

			end

			-- add widgets to the content frame
			do

				---@type PanelWidget
				local last

				last = CreateTitle(panel.content, addonName, GetAddOnMetadata(addonName, "Version"))

				-- add options
				do

					for i = 1, #optionGroups do

						local optionGroup = optionGroups[i]

						last = CreateHeader(panel.content, last, optionGroup.label)

						if optionGroup.description then
							last = CreateParagraph(last, optionGroup.description)
						end

						for j = 1, #optionGroup.options do

							local option = optionGroup.options[j]

							if option.text then
								last = CreateInput(last, "text", option.label, option.description)
								last.option = option
								last.refresh = handlers.option.text.update
								last:SetScript("OnEnterPressed", function(self, ...) handlers.option.text.save(self, ...) self:ClearFocus() end)
								last:SetScale(1.5)
								table.insert(panel.widgets, last)

							elseif option.paragraph then
								last = CreateInput(last, "text", option.label, option.description)
								last.option = option
								last:SetScale(1.5)
								last.Backdrop:Hide()
								last:Disable()
								last:SetScript("OnUpdate", handlers.option.text.example)
								table.insert(panel.widgets, last)
							end

						end

					end

				end

			end

			-- refresh when panel is shown
			panel:SetScript("OnShow", handlers.panel.refresh)

			return panel

		end

		ui = CreatePanel()
		InterfaceOptions_AddCategory(ui)

	end

	function Init()
		InitConfig()
		InitAPI()
		InitUI()
	end

end

local Frame do

	---@class AddOnFrame : Frame

	Frame = CreateFrame("Frame") ---@type AddOnFrame
	Frame:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)

	local loaded = false

	---@param event string
	---@param name string
	function Frame:ADDON_LOADED(event, name)
		if loaded or name ~= addonName then
			return
		end
		loaded = true
		Frame:UnregisterEvent(event)
		Init()
	end

	function Frame:Init()
		if _G.IsLoggedIn() then
			Frame:ADDON_LOADED("ADDON_LOADED", addonName)
		else
			Frame:RegisterEvent("ADDON_LOADED")
		end
	end

end

Frame:Init()
