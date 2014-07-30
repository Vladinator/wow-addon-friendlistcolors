local _, ns = ...
local L, locale = {}, GetLocale()
ns.L = L

getmetatable(L).__index = function(self, key)
	return "[TRANSLATE-" .. locale .. "{" .. key .. "}]";
end

L.OPT_DESC = "Changes are saved automatically. Pressing Okay or Cancel will have no effect. Pressing Defaults will reset the addon back to its default configuration."
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
