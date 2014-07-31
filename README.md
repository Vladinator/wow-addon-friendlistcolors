FriendListColors
==========================
Allows customization of how your friends appear. You can decide what text appears and what colors are used. There are literally endless possibilities!

Getting started
--------------------------
Once in-game simply open your menu, navigate to the "AddOns" tab on top and find the addon in the list.

Examples
--------------------------
The variables you can use are split into two types: curly brackets and regular brackets. {} and [] respectively.

The curly brackets are used for coloring while the regular brackets are used for variables.

>{color=class}?{/color} - color the content by class

>{color=level}?{/color} - color the content by level difficulty

>[toonName] - show character name

>[toonName|realName] - show character name, if not available show real name

>[isBattleTag?bnetName] - if isBattleTag is true then show BNet name

>[!isBattleTag?realName] - if isBattleTag is false then show real name

>[isBattleTag?"Some text"] - you can insert text by adding quotes

>[!isBattleTag?"Some text"] - same as above

For instance the default formatting pattern:
>{color=level}[isOnline?"L"][isOnline?level]{/color} {color=class}[aliasName|realName]{/color}

This will be converted to the following text if the person is online:
>L100 Bob

If Bob is offline then the text will become:
>Bob

Where the "L100" will be in the level difficulty color compared to your own level, and "Bob" will be colored to what ever Bob is playing. Note that here Bob would be an alias we assigned, otherwise if Bob has no assigned alias we will fallback to the other variable, his realName. The realName is automatically assigned to his BNet, battle tag or character name - depending on what is available to us. In the event Bob is offline then the "L" won't be shown and neither will the level.

List of variables
--------------------------
* {color=?}?{/color}
	* class - class color
	* level - level difficulty color (red, orange, yellow, green, gray)
* [?]
	* bnetID - random assigned BNet ID
	* bnetName - BNet name
	* battleTag - BattleTag name
	* isBattleTag - check if added as a BattleTag friend (not RealID)
	* toonName - character name
	* toonID - character ID
	* client - game client (WoW, BNet, SC2, D3)
	* isOnline - check if currently online
	* lastOnline - last online timestamp
	* isAFK - check if away
	* isDND - check if do not disturb
	* broadcast - broadcasted message
	* note - note assigned by player
	* isRealID - check if added as a RealID friend (not BattleTag)
	* broadcastTime - broadcasted message timestamp
	* canSoR - can Scroll of Ressurection (DEPRECATED?)
	* hasFocus - check if user is logged on a character
	* realmName - realm name
	* realmID - realm ID
	* faction - faction
	* race - race
	* class - class
	* guild - guild
	* zone - zone
	* level - level
	* game - game client string (DEPRECATED?)
	* status - friend status string (AFK or DND)
	* numToons - number of characters online
	* aliasName - alias name assigned by player
	* realName - real name (regardless of alias, works for any type of friend)
