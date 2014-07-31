local _, ns = ...
local locale = GetLocale()
local L = setmetatable({}, {
	__index = function(self, key)
		return "[" .. locale .. "{" .. key .. "}]"
	end
})
ns.L = L

L.OPT_DESC = "Customize and preview your friend list labels."
L.OPT_FORMAT_TITLE = "Format"
L.OPT_PREVIEW_ONLINE_TITLE = "Online preview"
L.OPT_PREVIEW_OFFLINE_TITLE = "Offline preview"

if locale == "deDE" then
elseif locale == "esES" then
elseif locale == "esMX" then
elseif locale == "frFR" then
elseif locale == "itIT" then
elseif locale == "koKR" then
elseif locale == "ptBR" then
elseif locale == "ruRU" then
elseif locale == "zhCN" then
elseif locale == "zhTW" then
end
