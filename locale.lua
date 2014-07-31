local _, ns = ...
local locale = GetLocale()
local L = setmetatable({}, {
	__index = function(self, key)
		return "[" .. locale .. "{" .. key .. "}]"
	end
})
ns.L = L

L.OPT_DESC = "Remember that changes are saved instantaneously."
L.OPT_FEATURES_TITLE = "Features"
L.OPT_FEATURES_DESC = "Choose what features are enabled."
L.OPT_FEATURE1_TITLE = "Feature 1 Title"
L.OPT_FEATURE1_DESC = "Feature 1 Desc"
L.OPT_FEATURE2_TITLE = "Feature 2 Title"
L.OPT_FEATURE2_DESC = "Feature 2 Desc"

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
