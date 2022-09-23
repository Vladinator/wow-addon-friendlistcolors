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
			cache.EVOKER = "33937F"
			cache.MONK = "00FF98"
			cache.PALADIN = "F48CBA"
			cache.SHAMAN = "0070DD"
		end

	end

	Color = {}

	Color.Gray = Color.From(_G.FRIENDS_GRAY_COLOR) ---@diagnostic disable-line: undefined-field
	Color.BNet = Color.From(_G.FRIENDS_BNET_NAME_COLOR) ---@diagnostic disable-line: undefined-field
	Color.WoW = Color.From(_G.FRIENDS_WOW_NAME_COLOR) ---@diagnostic disable-line: undefined-field

	Color.From = ColorToHex

	---@param query any
	---@return string?
	function Color.ForClass(query)
		if type(query) == "string" then
			query = query:upper()
		end
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
		-- TODO: NYI
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
		-- TODO: NYI
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

	---@param event string
	---@param name string
	function Frame:ADDON_LOADED(event, name)
		if name ~= addonName then
			return
		end
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
