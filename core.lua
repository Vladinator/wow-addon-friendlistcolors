local InterfaceOptionsFramePanelContainer = InterfaceOptionsFramePanelContainer or SettingsPanel ---@type Frame
local ReloadUI = ReloadUI or C_UI.Reload ---@type fun()
local FRIENDS_BUTTON_TYPE_BNET = FRIENDS_BUTTON_TYPE_BNET ---@type 2
local FRIENDS_BUTTON_TYPE_WOW = FRIENDS_BUTTON_TYPE_WOW ---@type 3

local addonName = ... ---@type string

local TIMERUNNING_MARKUP = CreateAtlasMarkup and CreateAtlasMarkup("timerunning-glues-icon-small", 9, 12) ---@type string?

---@alias ChatTypeExtended ChatType|"BN_WHISPER"

---@class ColorNS
local Color do

	Color = {}

	---@param r number|ColorMixin
	---@param g? number
	---@param b? number
	function Color.From(r, g, b)
		if type(r) == "table" then
			if r.r then
				r, g, b = r.r, r.g, r.b ---@diagnostic disable-line: undefined-field
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

		local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS ---@type table<string, ColorMixin>

		for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
			cache[v] = Color.From(colors[k])
		end

		for k, v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
			cache[v] = Color.From(colors[k])
		end

		if WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
			cache.Evoker = cache.Evoker or "33937F"
			cache.Monk = cache.Monk or "00FF98"
			cache.Paladin = cache.Paladin or "F48CBA"
			cache.Shaman = cache.Shaman or "0070DD"
		end

	end

	Color.Gray = Color.From(FRIENDS_GRAY_COLOR)
	Color.BNet = Color.From(FRIENDS_BNET_NAME_COLOR)
	Color.WoW = Color.From(FRIENDS_WOW_NAME_COLOR)

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
		local color = GetQuestDifficultyColor(level)
		return Color.From(color.r, color.g, color.b)
	end

end

---@class UtilNS
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
			return GetBNPlayerLink(newName, newName, bnetIDAccount, lineID) ---@type string
		end
		return newName
	end

end

---@class ParseNS
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
			local offline = not friendWrapper.data[friendWrapper.type == FRIENDS_BUTTON_TYPE_BNET and "isOnline" or "connected"]
			if offline then
				out = Color.Gray
			elseif friendWrapper.type == FRIENDS_BUTTON_TYPE_BNET then
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

					local note = friendWrapper.data[friendWrapper.type == FRIENDS_BUTTON_TYPE_BNET and "note" or "notes"] ---@type string?
					local alias = Parse.Note(note)

					if alias then
						out = alias
					end

				end

				if not out then
					out = value
				end

				if not out or out == "" or out == 0 or out == "0" then
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

---@class FriendsNS
local Friends do

	---@alias FriendKey
	---| "accountName"
	---| "afk"
	---| "appearOffline"
	---| "area"
	---| "areaName"
	---| "battleTag"
	---| "bnet"
	---| "bnetAccountID"
	---| "canSummon"
	---| "characterLevel"
	---| "characterName"
	---| "class"
	---| "className"
	---| "clientProgram"
	---| "connected"
	---| "customMessage"
	---| "customMessageTime"
	---| "dnd"
	---| "faction"
	---| "factionName"
	---| "gameAccountID"
	---| "gameAccountInfo"
	---| "guid"
	---| "hasFocus"
	---| "isAFK"
	---| "isBattleTagFriend"
	---| "isBNet"
	---| "isDND"
	---| "isFavorite"
	---| "isFriend"
	---| "isGameAFK"
	---| "isGameBusy"
	---| "isInCurrentRegion"
	---| "isOnline"
	---| "isWowMobile"
	---| "lastOnlineTime"
	---| "level"
	---| "mobile"
	---| "name"
	---| "note"
	---| "notes"
	---| "playerGuid"
	---| "race"
	---| "raceName"
	---| "rafLinkType"
	---| "realmDisplayName"
	---| "realmID"
	---| "realmName"
	---| "regionID"
	---| "richPresence"
	---| "timerunner"
	---| "timerunnerIcon"
	---| "timerunningSeasonID"
	---| "wowProjectID"

	---@class BNetAccountInfoExtended : BNetGameAccountInfo, BNetAccountInfo
	---@field public bnet boolean
	---@field public isBNet boolean
	---@field public class number
	---@field public className string
	---@field public race number
	---@field public raceName string
	---@field public faction number
	---@field public timerunner? number
	---@field public timerunnerIcon? string
	---@field public mobile boolean
	---@field public isWowMobile boolean

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
		return Util.MergeTable(gameAccountInfo or {}, accountInfo or {}) ---@type BNetAccountInfoExtended
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
			if temp and temp.clientProgram == BNET_CLIENT_WOW then
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
		---@param ... FriendKey
		---@return any, any, any
		local function first(...)
			local temp
			for _, v in ipairs({...}) do
				temp = data[v]
				if temp ~= nil then
					return temp, temp, temp
				end
			end
			return temp, temp, temp
		end
		isBNet = not not isBNet
		data.bnet = isBNet
		data.isBNet = isBNet
		-- data.name, data.characterName = first("characterName", "name")
		data.level, data.characterLevel = first("characterLevel", "level")
		data.class, data.className = first("className", "class")
		data.race, data.raceName = first("raceName", "race")
		data.faction, data.factionName = first("factionName", "faction")
		data.area, data.areaName = first("areaName", "area")
		data.connected, data.isOnline = first("isOnline", "connected")
		data.mobile, data.isWowMobile = first("isWowMobile", "mobile")
		data.afk, data.isAFK, data.isGameAFK = first("isGameAFK", "isAFK", "afk")
		data.dnd, data.isDND, data.isGameBusy = first("isGameBusy", "isDND", "dnd")
		data.timerunner = first("timerunningSeasonID")
		data.timerunnerIcon = data.timerunner and TIMERUNNING_MARKUP
	end

	---@alias FriendType
	---| 2 `FRIENDS_BUTTON_TYPE_BNET`
	---| 3 `FRIENDS_BUTTON_TYPE_WOW`

	---@class FriendWrapper
	---@field public type FriendType
	---@field public data? BNetAccountInfoExtended|BNetAccountInfo|FriendInfo

	---@param buttonType FriendType
	---@param id number
	---@return FriendWrapper?
	function Friends.PackageFriend(buttonType, id)
		local temp ---@type FriendWrapper
		if buttonType == FRIENDS_BUTTON_TYPE_BNET then
			temp = {
				type = buttonType,
				data = Friends.PackageFriendBNetCharacter(Friends.BNGetFriendInfo(id), id),
			}
		elseif buttonType == FRIENDS_BUTTON_TYPE_WOW then
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

	---@param chatType ChatTypeExtended
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
		return (
			text:gsub(
				"|HBNplayer:(.-)|h(.-)|h",
				---@param data string
				---@param displayText string
				function(data, displayText)
					return format("|HBNplayer:%s|h%s|h", data, Friends.GetAlias("BN_WHISPER", displayText))
				end
			)
		)
	end

end

---@class Config
local Config = {
	format = "[if=level][color=level]L[=level] [/color][/if][=timerunnerIcon][color=class][=accountName|name][if=characterName] ([=characterName])[/if][/color]",
	-- format = "[if=level][color=level]L[=level] [/color][/if][color=class][=accountName|characterName|name][/color]",
	-- format = "[if=level][color=level]Lv. [=level] [/color][/if][color=class][if=characterName][=characterName] ([=accountName|battleTag])[/if][if~=characterName][=accountName|battleTag|name][/if][if=race] [=race][/if][if=class] [=class][/if][/color]",
}

local Init do

	local function InitConfig()
		local name = format("%sDB", addonName)
		Config = _G[name] or Config
		_G[name] = Config
	end

	local function InitAPI()

		-- mutex lock when setting text to avoid recursion
		local isSettingText = false

		---@class ListFrameButton : Button
		---@field public buttonType number
		---@field public id number
		---@field public gameIcon Texture
		---@field public name FontString

		---@param self ListFrameButton
		---@param ... any
		local function SetTextHook(self, ...)
			if isSettingText then
				return
			end
			---@type ListFrameButton
			---@diagnostic disable-next-line: assign-type-mismatch
			local button = self:GetParent()
			local buttonType, id = button.buttonType, button.id
			if buttonType ~= FRIENDS_BUTTON_TYPE_BNET and buttonType ~= FRIENDS_BUTTON_TYPE_WOW then
				return
			end
			local friendWrapper = Friends.PackageFriend(buttonType, id)
			if not friendWrapper then
				return
			end
			-- button.gameIcon:SetTexture("Interface\\Buttons\\ui-paidcharactercustomization-button")
			-- button.gameIcon:SetTexCoord(8/128, 55/128, 72/128, 119/128)
			local text = Parse.Format(friendWrapper, Config.format)
			isSettingText = true
			self:SetText(text)
			isSettingText = false
		end

		local HookButtons do

			---@type table<ListFrameButton, true?>
			local hookedButtons = {}

			---@param buttons ListFrameButton[]
			function HookButtons(buttons)
				for i = 1, #buttons do
					local button = buttons[i]
					if button.name and not hookedButtons[button] then
						hookedButtons[button] = true
						hooksecurefunc(button.name, "SetText", SetTextHook)
					end
				end
			end

		end

		---@alias ScrollBoxPolyfill { GetView: fun(): { RegisterCallback: fun(self, event: string, callback: fun(event: number, widget: any, created: boolean)) } }

		---@class ListFrame : Frame
		---@field public ScrollBox? ScrollFrame | ScrollBoxPolyfill
		---@field public buttons? ListFrameButton[]

		---@type ListFrame
		local scrollFrame = FriendsListFrameScrollFrame or FriendsFrameFriendsScrollFrame or FriendsListFrame

		if scrollFrame.ScrollBox then
			scrollFrame.ScrollBox:GetView():RegisterCallback(
				ScrollBoxListMixin.Event.OnAcquiredFrame,
				function(_, button, created)
					if created then
						HookButtons({ button })
					end
				end
			)
		end

		if scrollFrame.buttons then
			HookButtons(scrollFrame.buttons)
		end

		if ChatEdit_UpdateHeader then

			---@param editBox EditBox
			local function ChatEdit_UpdateHeader(editBox)

				local chatType = editBox:GetAttribute("chatType") ---@type ChatType
				if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
					return
				end

				local editBoxName = editBox:GetName() ---@type string?
				if not editBoxName then
					return
				end

				local header = _G[format("%sHeader", editBoxName)] ---@type Button?
				if not header then
					return
				end

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

		---@type fun(event: WowEvent, filter: fun(self: Frame, event: WowEvent, text: string, name: string, ...: any))
		local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter or ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter

		if ChatFrame_AddMessageEventFilter then

			---@param self Frame
			---@param event WowEvent
			---@param text string
			---@param name string
			---@param ... any
			local function ChatFilter_AddMessage(self, event, text, name, ...)
				local chatType ---@type ChatTypeExtended
				if event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
					chatType = "WHISPER"
				elseif event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
					chatType = "BN_WHISPER"
				end
				if not chatType then
					return false
				end
				local lineID = select(9, ...) ---@type number?
				local newName = Friends.GetAlias(chatType, name, lineID)
				return false, text, newName, ...
			end

			ChatFrame_AddMessageEventFilter("CHAT_MSG_AFK", ChatFilter_AddMessage)
			ChatFrame_AddMessageEventFilter("CHAT_MSG_DND", ChatFilter_AddMessage)
			ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatFilter_AddMessage)
			ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatFilter_AddMessage)

			-- bnet names can't be modified with a simple chat event filter, and there are also issues when doing it the hard-way
			-- as replacing the special escape patterns used for bnet names can also malform the chat frame irreversably...

			-- ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", ChatFilter_AddMessage)
			-- ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", ChatFilter_AddMessage)

			--[[

			---@type fun(chatType: ChatTypeExtended, chatTarget: string, sourceChatFrame: Frame, selectWindow: Frame)
			local FCF_OpenTemporaryWindow = FCF_OpenTemporaryWindow

			if FCF_OpenTemporaryWindow then

				---@class HistoryBufferElement
				---@field public message string

				---@class HistoryBuffer
				---@field public headIndex number
				---@field public maxElements number
				---@field public elements HistoryBufferElement[]
				---@field public PushFront fun(self: HistoryBuffer)

				---@class ChatFrame : Frame
				---@field public historyBuffer HistoryBuffer

				---@param self HistoryBuffer
				local function PushFront(self)
					local count = self.headIndex
					if count == 0 then
						count = self.maxElements
					end
					local element = self.elements[count]
					if not element then
						return
					end
					local text = element.message
					if not text or text == "" then
						return
					end
					element.message = Util.EditTextReplaceNames(text)
				end

				---@type table<ChatFrame, boolean>
				local chatFrameHooks = {}
				local lastChatFrameHookIndex = 1

				for i = 1, 100 do

					local chatFrame = _G[format("ChatFrame%d", i)] ---@type ChatFrame
					if not chatFrame then
						lastChatFrameHookIndex = i
						break
					end

					if i ~= 2 and not chatFrameHooks[chatFrame] then
						chatFrameHooks[chatFrame] = true
						local historyBuffer = chatFrame.historyBuffer
						hooksecurefunc(historyBuffer, "PushFront", PushFront)
						-- local count = historyBuffer.headIndex
						-- for j = 1, count do
						-- 	local element = historyBuffer.elements[j]
						-- 	local text = element and element.message
						-- 	if text and text ~= "" then
						-- 		element.message = Friends.EditTextReplaceNames(text)
						-- 	end
						-- end
					end

				end

				local function _FCF_OpenTemporaryWindow()
					for i = lastChatFrameHookIndex, 100 do

						local chatFrame = _G[format("ChatFrame%d", i)] ---@type ChatFrame
						if not chatFrame then
							lastChatFrameHookIndex = i
							break
						end

						if not chatFrameHooks[chatFrame] then
							chatFrameHooks[chatFrame] = true
							hooksecurefunc(chatFrame.historyBuffer, "PushFront", PushFront)
						end

					end
				end

				hooksecurefunc("FCF_OpenTemporaryWindow", _FCF_OpenTemporaryWindow)

			end

			--]]

		end

		---@type { Toast: { Text: FontString }, Toast2: { Text: FontString } }
		local QuickJoinToastButton = QuickJoinToastButton

		if QuickJoinToastButton then

			---@class QuickJoinFrameButtonEntryDisplayMember : Button

			---@class QuickJoinFrameButtonEntry
			---@field public displayedMembers QuickJoinFrameButtonEntryDisplayMember[]

			---@class QuickJoinFrameButtonMember : Button

			---@class QuickJoinFrameButton : Button
			---@field public SetEntry fun(self: QuickJoinFrameButton)
			---@field public entry QuickJoinFrameButtonEntry
			---@field public Members QuickJoinFrameButtonMember[]

			---@param self QuickJoinFrameButton
			local function QuickJoinButtonSetEntry(self)
				if not self.entry then
					return
				end
				for i = 1, #self.entry.displayedMembers do
					local member = self.Members[i]
					local text = member:GetText()
					if text and text ~= "" then
						text = Friends.ReplaceName(text)
						member:SetText(text)
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
			---@field public ScrollBox? ScrollFrame | ScrollBoxPolyfill
			---@field public buttons? QuickJoinFrameButton[]

			---@type QuickJoinFrame
			local quickJoinScrollFrame = QuickJoinFrame

			if quickJoinScrollFrame.ScrollBox then
				quickJoinScrollFrame.ScrollBox:GetView():RegisterCallback(
					ScrollBoxListMixin.Event.OnAcquiredFrame,
					function(_, button, created)
						if created then
							QuickJoinHookButtons({ button })
						end
					end
				)
			end

			if quickJoinScrollFrame.buttons then
				QuickJoinHookButtons(quickJoinScrollFrame.buttons)
			end

			-- mutex lock when setting text to avoid recursion
			local isToastSettingText = false

			---@param self Button
			---@param text string
			local function ToastSetTextHook(self, text)
				if isToastSettingText or not text or text == "" then
					return
				end
				text = Friends.ReplaceName(text)
				isToastSettingText = true
				self:SetText(text)
				isToastSettingText = false
			end

			hooksecurefunc(QuickJoinToastButton.Toast.Text, "SetText", ToastSetTextHook)
			hooksecurefunc(QuickJoinToastButton.Toast2.Text, "SetText", ToastSetTextHook)

		end

	end

	local function InitUI()

		local ui
		local unique = 1

		---@param format string
		---@param isBNet? boolean
		local function ExampleFriend(format, isBNet)
			---@type FriendWrapper
			---@diagnostic disable-next-line: missing-fields
			local friendWrapper = {}
			local maxLevel = GetMaxLevelForExpansionLevel(GetExpansionLevel())
			if isBNet then
				---@type BNetAccountInfoExtended
				---@diagnostic disable-next-line: missing-fields
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
					rafLinkType = Enum.RafLinkType.Friend,
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
					wowProjectID = WOW_PROJECT_MAINLINE,
					timerunningSeasonID = 1,
				}
				friendWrapper.type = FRIENDS_BUTTON_TYPE_BNET
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
					rafLinkType = Enum.RafLinkType.Friend,
				}
				friendWrapper.type = FRIENDS_BUTTON_TYPE_WOW
				friendWrapper.data = data
			end
			Friends.AddFieldAlias(friendWrapper.data, isBNet)
			return Parse.Format(friendWrapper, format)
		end

		---@param raw string
		---@return string
		local function ConvertToText(raw)
			return (raw:gsub("|", "||"))
		end

		---@param raw any
		---@return string
		local function ConvertToFormat(raw)
			if type(raw) ~= "string" then return "" end
			return (raw:gsub("||", "|"))
		end

		local varNamesBNet = {
			"bnet/isBNet",
			"accountName",
			"battleTag",
			"name/characterName",
			"level/characterLevel",
			"class/className",
			"area/areaName",
			"note",
			"customMessage",
			"richPresence",
			"race/raceName",
			"faction/factionName",
			"realmName",
			"realmDisplayName",
			"canSummon",
			"isInCurrentRegion",
			"isFavorite",
			"isBattleTagFriend",
			"appearOffline",
			"isOnline/connected",
			"isWowMobile",
			"isGameAFK/isAFK/afk",
			"isGameBusy/isDND/dnd",
			"timerunner",
			"timerunnerIcon",
		}

		local varNamesWoW = {
			"name",
			"level",
			"class/className",
			"area",
			"notes",
			"connected/isOnline",
			"mobile/isWowMobile",
			"afk/isAFK/isGameAFK",
			"dnd/isDND/isGameBusy",
		}

		local syntaxExamples = [[
[=accountName||name]
[if=bnet][=battleTag] - [=name][/if]
[if~=bnet][=name][/if]
[color=class][=characterName||name][/color]
[color=level][=level][/color]
]]

		---@class FriendsListColorsInterfaceOptionItem
		---@field public label string
		---@field public description string
		---@field public key? string
		---@field public text? boolean
		---@field public paragraph? boolean
		---@field public reminder? boolean
		---@field public example1? boolean
		---@field public example2? boolean
		---@field public widget? PanelWidget

		---@class FriendsListColorsInterfaceOption
		---@field public label string
		---@field public description string
		---@field public options FriendsListColorsInterfaceOptionItem[]

		---@type FriendsListColorsInterfaceOption[]
		local optionGroups = {
			{
				label = "Format",
				description = "Customize the appearance of your friends list.\n\nList of variables for BNet friends:  " ..
					"|cffFFFF00" .. table.concat(varNamesBNet, "|r  |cffFFFF00") .. "|r" ..
					"\n\nList of variables for World of Warcraft friends:  " ..
					"|cffFFFF00" .. table.concat(varNamesWoW, "|r  |cffFFFF00") .. "|r" ..
					"\n\nSyntax examples:\n" .. syntaxExamples,
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
					},
					{
						paragraph = true,
						reminder = true,
						label = "",
						description = ""
					},
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
						local format = ConvertToFormat(self:GetText())
						if format == "" then return self:SetText(Config.format) end
						Config.format = format
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
					end,
					focusGain = function(self)
						optionGroups[1].options[4].widget:SetText("\r\n|cffFFFF00Remember to press Enter to save your changes!|r")
						self.backup = Config.format
					end,
					focusLost = function(self, cancel)
						optionGroups[1].options[4].widget:SetText("")
						if not cancel then return end
						Config.format = self.backup
						handlers.option.text.update(optionGroups[1].options[1].widget)
					end,
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
		---@field public option FriendsListColorsInterfaceOptionItem
		---@field public refresh? fun(self: PanelWidget)
		---@field public SetText fun(self: PanelWidget, text: any)

		---@class PanelTitle : PanelWidget

		---@param panel Frame
		---@param name string
		---@param version? string
		local function CreateTitle(panel, name, version)

			local title = CreateFrame("Frame", "$parentTitle" .. unique, panel) ---@class PanelTitle : Frame
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

			local header = CreateFrame("Frame", "$parentHeader" .. unique, anchor:GetParent() or anchor) ---@class PanelHeader : Frame
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

			local header = CreateFrame("Frame", "$parentParagraph" .. unique, anchor:GetParent() or anchor) ---@class PanelParagraph : Frame
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

			header.label:SetWordWrap(true)
			header.label:SetNonSpaceWrap(true)
			header.label:SetMaxLines(20)

			header:SetScript("OnUpdate", function()
				if header:GetHeight() < MAX_HEIGHT and header.label:GetHeight() == header:GetHeight() then
					header:SetScript("OnUpdate", nil)
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
		---@field public Left Frame
		---@field public Middle Frame
		---@field public Right Frame
		---@field public Backdrop Frame|BackdropTemplate

		---@param anchor PanelWidget
		---@param kind? "number"|"text"
		---@param text? string
		---@param tooltip? string
		local function CreateInput(anchor, kind, text, tooltip)

			local editbox = CreateFrame("EditBox", "$parentEditBox" .. unique, anchor:GetParent() or anchor, "InputBoxTemplate") ---@class PanelEditBox : EditBox
			unique = unique + 1
			editbox:SetFontObject("GameFontHighlight")
			editbox:SetSize(160, 22)
			editbox:SetAutoFocus(false)
			editbox:SetHyperlinksEnabled(false)
			editbox:SetMultiLine(false)
			editbox:SetIndentedWordWrap(false)
			editbox:SetMaxLetters(255)
			editbox.tooltipText = tooltip

			if kind == "number" then
				editbox:SetMaxLetters(4)
				editbox:SetNumeric(true)
				editbox:SetNumber(text) ---@diagnostic disable-line: param-type-mismatch
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
				editbox:SetHeight(128)
				editbox:SetMultiLine(true)
				editbox:SetMaxLetters(1024)

				editbox:SetPoint("RIGHT", -8, 0)

				editbox.Left:Hide()
				editbox.Middle:Hide()
				editbox.Right:Hide()

				editbox.Backdrop = CreateFrame("Frame", nil, editbox, BackdropTemplateMixin and "BackdropTemplate")
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

			local panel = CreateFrame("Frame", addonName .. "Panel" .. unique, InterfaceOptionsFramePanelContainer) ---@class FriendsListColorsInterfaceOptionsPanel : Frame
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

				panel.scroll = CreateFrame("ScrollFrame", nil, panel) ---@class FriendsListColorsInterfaceOptionsPanelScroll : ScrollFrame
				panel.scroll:SetPoint("TOPLEFT", 10, -10)
				panel.scroll:SetPoint("BOTTOMRIGHT", -26, 10)

				panel.scroll.bar = CreateFrame("Slider", nil, panel.scroll, "UIPanelScrollBarTemplate") ---@class FriendsListColorsInterfaceOptionsPanelScrollBar : Slider
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

				last = CreateTitle(panel.content, addonName, C_AddOns.GetAddOnMetadata(addonName, "Version"))

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
								option.widget = last
								last.option = option
								last.refresh = handlers.option.text.update
								last:HookScript("OnEditFocusGained", function(self) handlers.option.text.focusGain(self) end)
								last:HookScript("OnEditFocusLost", function(self) handlers.option.text.focusLost(self) end)
								last:HookScript("OnEscapePressed", function(self) handlers.option.text.focusLost(self, true) end)
								last:SetScript("OnEnterPressed", function(self) handlers.option.text.save(self) self:ClearFocus() end)
								last:SetScale(1.5)
								table.insert(panel.widgets, last)

							elseif option.paragraph then
								last = CreateInput(last, "text", option.label, option.description)
								option.widget = last
								last.option = option
								last:SetScale(1.5)
								last.Backdrop:Hide()
								last:Disable()
								if option.example1 or option.example2 then
									last:SetScript("OnUpdate", handlers.option.text.example)
								end
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
		local category = Settings.RegisterCanvasLayoutCategory(ui, ui.name, ui.name)
		category.ID = ui.name
		Settings.RegisterAddOnCategory(category)

	end

	function Init()
		InitConfig()
		InitAPI()
		InitUI()
	end

end

local Frame do

	---@class AddOnFrame : Frame

	Frame = CreateFrame("Frame") ---@class AddOnFrame
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
		if IsLoggedIn() then
			Frame:ADDON_LOADED("ADDON_LOADED", addonName)
		else
			Frame:RegisterEvent("ADDON_LOADED")
		end
	end

end

Frame:Init()
