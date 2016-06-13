-- TODO
-- Capture cooldowns from combat log and player, then set them

local lower = string.lower
local match = string.match
local remove = table.remove
local GetSpellInfo = GetSpellInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitName = UnitName
local IsInInstance = IsInInstance  
local SendAddonMessage = SendAddonMessage
local GetNumPartyMembers = GetNumPartyMembers
local CooldownFrame_SetTimer = CooldownFrame_SetTimer

-- V: CDs
local CD_ID_EVERY_MAN_FOR_HIMSELF = 59752
local CD_ID_TRINKET = 42292
local CD_ID_WOTF = 7744
local CD_PVP_COOLDOWN = 120

local SPELLIDUPPER = 60000
local CommPrefix  = "PABx39dkes8xj" -- Receive ability and cooldown
local CommPrefix2 = "PAB935ndd8xid" -- Send GUID for syncing
local CommPrefix3 = "PABkd8cjnwuid" -- Receive GUID for syncing

local db
local pGUID
local pName

local PAB = CreateFrame("Frame","PAB",UIParent)
local PABIcons = CreateFrame("Frame",nil,UIParent)
local PABAnchor = CreateFrame("Frame",nil,UIParent)

local iconlist = {}
local anchors = {}
local syncGUIDS = {}
local activeGUIDS = {}

local function print(...)
	for i=1,select('#',...) do
		ChatFrame1:AddMessage("|cff33ff99PAB|r: " .. select(i,...))
	end
end

local InArena = function() return (select(2,IsInInstance()) == "arena") end

local _iconPaths = {}
local iconPaths = {
	[20594] = 1, -- Stoneform
	[2139] = 1, -- Counterspell
	[45438] = 1, -- Ice Block
	[31687] = 1, --Summon Water Elemental
	[29166] = 1, -- Innervate
	[1499] = 1, -- Freezing Trap
	[853] = 1, -- Hammer of Justice
	[1044] = 1, -- Hand of Freedom
	[8122] = 1, -- Psychic Scream
	[14185] = 1, -- Preparation
	[1856] = 1, -- Vanish
	[2983] = 1, -- Sprint
	[2094] = 1, -- Blind
	[31224] = 1, -- Shadow Cloak
	[1766] = 1, -- Kick
	[57994] = 1, -- Wind Shock
	[19647] = 1, -- Spell Lock
	[6789] = 1, -- Death Coil
	[6552] = 1, -- Pummel
	[100] = 1, -- Charge
	[47528] = 1, -- Mind Freeze
	[55342] = 1, --Mirror Image
	[66] = 1, --Invisibility
	[44572] = 1, --Deep Freeze
	[82676] = 1, --Ring of Frost
	[12472] = 1, --Icy Veins
	[76577] = 1, --Smoke Bomb
	[51713] = 1, --Shadow Dance
	[34433] = 1, --Shadowfiend			
	[10060] = 1, --Power Infusion
	[64901] = 1, --Hymn of Hope
	[64843] = 1, --Divine Hymn
	[73325] = 1, --Leap of Faith
	--[98888] = 1, --Power Word: Barrier?
	[33206] = 1, --Pain Supression
	[781] = 1, --Disengage
	[19503] = 1, --Scatter Shot
	[19263] = 1, --Deterrence
	[8177] = 1, --Grounding Totem
	[51514] = 1, --Hex
	[48020] = 1, --Demonic Circle: Teleport
	[5484] = 1, --Howl of Terror
	[77801] = 1, --Demon Soul
	[49576] = 1, --Death Grip
	[47476] = 1, --Strangulate
	[676] = 1, --Disarm	
	[80965] = 1, --"Skull Bash",
	[22812] = 1, --"Barkskin",
	[61336] = 1, --"Survival Instincts",
	[5211] = 1, --"Bash",
	[17116] = 1, --"Nature's Swiftness",
}
for k in pairs(iconPaths) do _iconPaths[GetSpellInfo(k)] = select(3,GetSpellInfo(k)) end
iconPaths = _iconPaths

local defaultAbilities = {
	["DRUID"] = {
		[80965] = 10, --"Skull Bash",
		[22812] = 60, --"Barkskin",
		[61336] = 180, --"Survival Instincts",
		[5211] = 50, --"Bash",
		[17116] = 180, --"Nature's Swiftness",
		[29166] = 180, -- Innervate
	},
	["HUNTER"] = {
		[19503] = 30, --Scatter Shot
		[1499] = 30, -- Freezing Trap			
		[781] = 16, --Disengage
		[19263] = 110, --Deterrence 
	},
	["MAGE"] = 	{
		[66] = 180, --Invisibility
		[55342] = 180, --Mirror Image
		[2139] = 24, -- Counterspell
		[44572] = 30,	--"Deep Freeze",
		[82676] = 120, -- Ring of Frost
		[11426] = 24,	--"Ice Barrier", 
		[45438] = 300, -- Ice Block
		[11958] = 384,	--"Cold Snap",
	},
	["PALADIN"] = {
		[853] = 60, -- Hammer of Justice			
		[6940] = 120, --Hand of Sacrifice
		[1022] = 300, --Blessing of Protection
		[642] = 300, --Divine Shield
	},
	["PRIEST"] = {
		[8122] = 30, -- Psychic Scream
		[34433] = 240, --Shadowfiend			
		[64901] = 360, --Hymn of Hope
		[64843] = 480, --Divine Hymn
		[73325] = 90, --Leap of Faith
		[33206] = 180, -- Painsup
	},
	["ROGUE"] = {		
		[1766] = 10, -- Kick
		[2983] = 60, -- Sprint
		[76577] = 180, --Smoke Bomb
		[51713] = 60, --Shadow Dance
		[1856] = 120, -- Vanish
		[31224] = 90, -- Shadow Cloak
		--[5277] = 180, -- Evasion, -- disabled for now, because it has 
		[2094] = 120, -- Blind
		[14185] = 300, -- Preparation
	},
	["SHAMAN"] = {
		[57994] = 15, --"Wind Shear",
		[8177] = 25, --Grounding Totem
		[16190] = 180,				--"Mana Tide Totem",
		[8143] = 60,				--"Tremor Totem", patch 4.0.6
		[79206] = 120,			--"Spiritwalker's Grace",
		[16166] = 180,			--"Elemental Mastery",
		[16188] = 120,				--"Nature's Swiftness",
		[98008] = 180,			--"Spirit Link Totem",
		[51514] = 35, --Hex
	},
	["WARLOCK"] = {
		[19647] = 24, -- Spell Lock		
		[48020] = 26, --Demonic Circle: Teleport
		[5484] = 32, --Howl of Terror
		[77801] = 120, --Demon Soul
		[6789] = 90, -- Death Coil
		[77801] = 120, 				-- Dark soul
	},
	["WARRIOR"] = {
		[6552] = 10, -- Pummel
		[676] = 60, --Disarm
		[100] = 12, -- Charge		
	},
	["DEATHKNIGHT"] = {
		[47528] = 10,				--"Mind Freeze",
		[47476] = 120,				--"Strangulate",
		[49576] = 25,				--"Death Grip",	
		[48707] = 45,				--"Anti-Magic Shell",
		[51052] = 120,				--"Anti-Magic Zone",
		[49039] = 120,				--"Lichborne",
		--[51271] = 60,				--"Pillar of Frost",
		--[49222] = 60,				--"Bone Shield",
	},
	["PVP"] = {
		[CD_ID_EVERY_MAN_FOR_HIMSELF] = CD_PVP_COOLDOWN,
		[CD_ID_TRINKET] = CD_PVP_COOLDOWN,
		[CD_ID_TRINKET] = CD_PVP_COOLDOWN,
	},
}

local function convertspellids(t)
	local temp = {}
	for class,table in pairs(t) do
		temp[class] = {}
		for k,v in pairs(table) do
			temp[class][GetSpellInfo(k)] = v
		end
	end
	return temp
end

defaultAbilities = convertspellids(defaultAbilities)

local groupedCooldowns = {
	["SHAMAN"] = {
		[8042] = 1, -- Earth Shock
		[8050] = 1, -- Flame Shock
		[8056] = 1, -- Frost Shock
		[57994] = 1, -- Wind Shock
	},
	["HUNTER"] = {
		[13813] = 1, -- Explosive Trap
		[82939] = 1, --Explosive Trap (Launcher)
		[1499] = 1, -- Freezing Trap
		[60192] = 1, --Freezing Trap (Launcher)
		[13809] = 1, --Ice Trap
		[82941] = 1, --Ice Trap (Launcher)
		[13795] = 1, -- Immolation Trap
		[82945] = 1, --Immolation Trap (Launcher)
		[34600] = 1, -- Snake Trap
		[82948] = 1, --Snake Trap (Launcher)
	},
}

groupedCooldowns = convertspellids(groupedCooldowns)

local cooldownResetters = {
	[11958] = { -- Cold Snap
		[120] = 1, -- Cone of Cold
		[122] = 1,  -- Frost Nova
		[11426] = 1, -- Ice Barrier
		[45438] = 1,  -- Ice Block
		[31687] = 1, -- Summon Water Elemental
		[71757] = 1, -- Deep Freeze
		[82676] = 1, -- Ring of Frost
		[12472] = 1, -- Icy Veins
	},
	[14185] = { -- Preparation
		[76577] = 1,  -- Smoke Bomb
		[2983] = 1,  -- Sprint
		[1856] = 1, -- Vanish
		[36554] = 1, -- Shadowstep
		[51722] = 1, --Disarm
		[1766] = 1, --Kick		
	},
	[23989] = "ALL", -- Readiness
}

local temp = {}
for k,v in pairs(cooldownResetters) do
	temp[GetSpellInfo(k)] = {}
	if type(v) == "table" then
		for id in pairs(v) do
			temp[GetSpellInfo(k)][GetSpellInfo(id)] = 1
		end
	else
		temp[GetSpellInfo(k)] = v
	end
end

cooldownResetters = temp
temp = nil
convertspellids = nil

function PAB:SavePositions()
	for k,anchor in ipairs(anchors) do
		local scale = anchor:GetEffectiveScale()
		local worldscale = UIParent:GetEffectiveScale()
		local x = anchor:GetLeft() * scale
		local y = (anchor:GetTop() * scale) - (UIParent:GetTop() * worldscale)
	
		if not db.positions[k] then
			db.positions[k] = {}
		end
	
		db.positions[k].x = x
		db.positions[k].y = y
	end
end

function PAB:LoadPositions()
	db.positions = db.positions or {}
	for k,anchor in ipairs(anchors) do
		if db.positions[k] then
			local x = db.positions[k].x
			local y = db.positions[k].y
			local scale = anchors[k]:GetEffectiveScale()
			anchors[k]:SetPoint("TOPLEFT", UIParent,"TOPLEFT", x/scale, y/scale)
		else
			anchors[k]:SetPoint("CENTER", UIParent, "CENTER")
		end
	end
end

local backdrop = {bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="", tile=false,}
function PAB:CreateAnchors()
	for i=1,4 do
		local anchor = CreateFrame("Frame","PABAnchor"..i ,PABAnchor)
		anchor:SetBackdrop(backdrop)
		anchor:SetHeight(15)
		anchor:SetWidth(15)
		anchor:SetBackdropColor(1,0,0,1)
		anchor:EnableMouse(true)
		anchor:SetMovable(true)
		anchor:Show()
		anchor.icons = {}
		anchor.HideIcons = function() for k,icon in ipairs(anchor.icons) do icon:Hide(); icon.shouldShow = nil end end
		anchor:SetScript("OnMouseDown",function(self,button) if button == "LeftButton" then self:StartMoving() end end)
		anchor:SetScript("OnMouseUp",function(self,button) if button == "LeftButton" then self:StopMovingOrSizing(); PAB:SavePositions() end end)
		anchors[i] = anchor
		
		local index = anchor:CreateFontString(nil,"ARTWORK","GameFontNormal")
		index:SetPoint("CENTER")
		index:SetText(i)
	end
end

local function CreateIcon(anchor)
	local icon = CreateFrame("Frame",anchor:GetName().."Icon".. (#anchor.icons+1),PABIcons)
	icon:SetHeight(30)
	icon:SetWidth(30)
		
	local cd = CreateFrame("Cooldown",icon:GetName().."Cooldown",icon,"CooldownFrameTemplate")
	icon.cd = cd
	
	icon.Start = function(sentCD)
		icon.cooldown = tonumber(sentCD);
		CooldownFrame_SetTimer(cd,GetTime(),icon.cooldown,1); 
		icon:Show(); 
		icon.active = true; 
		icon.starttime = GetTime()+0.4 
		activeGUIDS[icon.GUID][icon.ability] = activeGUIDS[icon.GUID][icon.ability] or {}
		activeGUIDS[icon.GUID][icon.ability].starttime = icon.starttime
		activeGUIDS[icon.GUID][icon.ability].cooldown =  icon.cooldown
	end
	
	icon.Stop = function() 
		CooldownFrame_SetTimer(cd,0,0,0); 
		icon.starttime = 0
	end
	
	icon.SetTimer = function(starttime,cooldown)
		CooldownFrame_SetTimer(cd,starttime,cooldown,1)
		icon.active = true
		icon.starttime = starttime
		icon.cooldown = cooldown
	end
	
	local texture = icon:CreateTexture(nil,"ARTWORK")
	texture:SetAllPoints(true)
	texture:SetTexCoord(0.07,0.9,0.07,0.90)
	icon.texture = texture

	return icon
end

function PAB:AppendIcon(icons,anchor)
	local newicon = CreateIcon(anchor)
	iconlist[#iconlist+1] = newicon
	if #icons == 0 then
		newicon:SetPoint("TOPLEFT",anchor,"BOTTOMRIGHT")
	else
		newicon:SetPoint("LEFT",icons[#icons],"RIGHT")
	end
	icons[#icons+1] = newicon
	return newicon
end

function PAB:RequestSync()
	wipe(syncGUIDS)
	SendAddonMessage(CommPrefix2, pGUID, "PARTY")
end

function PAB:ShowUsedAnchors()
	for i=1,GetNumPartyMembers() do anchors[i]:Show() end
end

function PAB:HideUnusedAnchors()
	for k=GetNumPartyMembers()+1,#anchors do
		anchors[k]:Hide()
		anchors[k].HideIcons()
	end
end

function PAB:HideUnusedIcons(numIcons,icons)
	for j=numIcons,#icons do
		icons[j]:Hide()
		icons[j].shouldShow = nil
	end
end

function PAB:UpdateAnchorIconFromSpellId(anchor, numIcons, ability, cooldown)
	local abilityName,_ = GetSpellInfo(ability)
	self:UpdateAnchorIcon(anchor, numIcons, abilityName, cooldown)
end

function PAB:UpdateAnchorIcon(anchor, numIcons, ability, cooldown)
	local icons = anchor.icons
	local icon = icons[numIcons] or self:AppendIcon(icons,anchor)
	icon.texture:SetTexture(self:FindAbilityIcon(ability))
	icon.GUID = anchor.GUID
	icon.ability = ability
	icon.cooldown = cooldown
	icon.shouldShow = true
	activeGUIDS[icon.GUID] = activeGUIDS[icon.GUID] or {}
	if activeGUIDS[icon.GUID][icon.ability] then
		icon.SetTimer(activeGUIDS[icon.GUID][ability].starttime, activeGUIDS[icon.GUID][ability].cooldown)
	else
		icon.Stop()
	end
end

function PAB:UpdateAnchors()
	for i=1,GetNumPartyMembers() do
		local _,class = UnitClass("party"..i)
		if not class then return end
		local anchor = anchors[i]
		anchor.GUID = UnitGUID("party"..i)
		anchor.class = select(1,UnitClass("party"..i))
		local abilities = db.abilities[class]
		local numIcons = 1

		 -- V: add race-specific code for trinket display
		anchor.race = select(2, UnitRace("party"..i))
		if anchor.race == "Human" then
			self:UpdateAnchorIconFromSpellId(anchor, numIcons, CD_ID_EVERY_MAN_FOR_HIMSELF, CD_PVP_COOLDOWN) -- EMFH
		else
			self:UpdateAnchorIconFromSpellId(anchor, numIcons, CD_ID_TRINKET, CD_PVP_COOLDOWN) -- PVP trinket
		end
		numIcons = numIcons + 1
		-- extra: WOTF for undead (aka scourge)
		if anchor.race == "Scourge" then
			self:UpdateAnchorIconFromSpellId(anchor, numIcons, CD_ID_WOTF, CD_PVP_COOLDOWN) -- WOTF
			numIcons = numIcons + 1
		end

		for ability,cooldown in pairs(abilities) do
			self:UpdateAnchorIcon(anchor, numIcons, ability, cooldown)
			numIcons = numIcons + 1
		end
		self:HideUnusedIcons(numIcons, anchor.icons)
	end
	self:ShowUsedAnchors()
	self:HideUnusedAnchors()

	self:ApplyAnchorSettings()
end

function PAB:ApplyAnchorSettings()
	PABIcons:SetScale(db.scale or 1)
	
	if db.arena then
		if InArena() then
			PABIcons:Show()
		else
			PABIcons:Hide()
		end
	else
		PABIcons:Show()
	end

	for k,v in ipairs(anchors) do
		for k,v in ipairs(v.icons) do
			if db.hidden and not v.active then
				v:Hide()
			elseif v.shouldShow then
				v:Show()
			end
		end
	end	
	
	if db.lock then PABAnchor:Hide() else PABAnchor:Show() end
end

function PAB:PARTY_MEMBERS_CHANGED()
	if not pGUID then pGUID = UnitGUID("player") end
	if not pName then pName = UnitName("player") end
	self:RequestSync()
	self:UpdateAnchors()
end

function PAB:PLAYER_ENTERING_WORLD()
	if InArena() then self:StopAllIcons() end -- Cooldowns reset when joining arena
	if not pGUID then pGUID = UnitGUID("player") end
	if not pName then pName = UnitName("player") end
	self:RequestSync()
	self:UpdateAnchors()
end

function PAB:CheckAbility(anchor,ability,cooldown,pIndex)
	-- V: support for pvp trinket stuff (need to set their cooldown)
	for v,_ in pairs(defaultAbilities["PVP"]) do
		-- V: calling it over and over again might be a bad idea.
		if v == ability then
			cooldown = CD_PVP_COOLDOWN
		end
	end
	if not cooldown then return end
	for k,icon in ipairs(anchor.icons) do

		-- Direct cooldown
		--and icon.shouldShow
		if icon.ability == ability then icon.Start(cooldown) end
		-- Grouped Cooldowns
		if groupedCooldowns[anchor.class] and groupedCooldowns[anchor.class][ability] then
			for k in pairs(groupedCooldowns[anchor.class]) do
				if k == icon.ability and icon.shouldShow then icon.Start(cooldown); break end
			end
		end
		-- Cooldown resetters
		if cooldownResetters[ability] then
			if type(cooldownResetters[ability]) == "table" then
				for k in pairs(cooldownResetters[ability]) do
					if k == icon.ability then icon.Stop(); break end
				end
			else
				icon.Stop()
			end
		end
	end
end

function PAB:CHAT_MSG_ADDON(prefix, message, dist, sender)
	if dist == "PARTY" and sender ~= pName then
		if prefix == CommPrefix then
			local GUID,ability,cooldown = match(message,"(.+)|(.+)|(.+)")
			if syncGUIDS[GUID] then self:CheckAbility(syncGUIDS[GUID],ability,cooldown) end
		elseif prefix == CommPrefix2 then
			SendAddonMessage(CommPrefix3, pGUID, "PARTY")
		elseif prefix == CommPrefix3 then
			for i=1,GetNumPartyMembers() do if UnitGUID("party"..i) == message then syncGUIDS[message] = anchors[i] end end
		end
	end
end

function PAB:SendCooldownMessage(ability,cooldown)
	SendAddonMessage(CommPrefix, pGUID.."|"..ability.."|"..cooldown, "PARTY")
end

function PAB:SendCooldown(ability,rep)
	local start, duration, enabled = GetSpellCooldown(ability)
	if not start then return end
	if enabled == 0 or not rep then self:Schedule(0.1,self.SendCooldown,ability,true) return 
	elseif start > 0 and duration > 0 then
		self:SendCooldownMessage(ability,start + duration - GetTime())
	end
end

function PAB:UNIT_SPELLCAST_SUCCEEDED(unit,ability)
	if syncGUIDS[UnitGUID(unit)] then return end
	if unit == "player" then self:SendCooldown(ability) return end
	local pIndex = match(unit,"party[pet]*([1-4])")
	if pIndex and ability then
		local _,class = UnitClass("party"..pIndex)
		self:CheckAbility(anchors[tonumber(pIndex)],ability,db.abilities[class][ability],pIndex) 
	end
end

local timers, timerfuncs, timerargs = {}, {}, {}
function PAB:Schedule(duration,func,...)
	timers[#timers+1] = duration
	timerfuncs[#timerfuncs+1] = func
	timerargs[#timerargs+1] = {...}
end

local time = 0
local function PAB_OnUpdate(self,elapsed)
	time = time + elapsed
	if time > 0.05 then
		--  Update Icons
		for k,icon in ipairs(iconlist) do
			if icon.active then
				icon.timeleft = icon.starttime + icon.cooldown - GetTime()
				if icon.timeleft <= 0 then
					if db.hidden then icon:Hide() end
					activeGUIDS[icon.GUID][icon.ability] = nil
					icon.active = nil
				end
			end
		end
		
		-- Update Timers
		if #timers > 0 then
			for i=#timers,1,-1 do 
				timers[i] = timers[i] - 0.05
				if timers[i] <= 0 then
					remove(timers,i)
					remove(timerfuncs,i)(PAB,unpack(remove(timerargs,i)))
				end
			end
		end
		
		time = 0
	end
end

function PAB:StopAllIcons()
	for k,v in ipairs(iconlist) do v.Stop() end
	wipe(activeGUIDS)
end

local function PAB_OnLoad(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:SetScript("OnEvent",function(self,event,...) if self[event] then self[event](self,...) end end)
	
	PABDB = PABDB or { abilities = defaultAbilities, scale = 1  }
	db = PABDB

	self:CreateAnchors()
	self:UpdateAnchors()
	self:LoadPositions()
	self:CreateOptions()
	
	self:SetScript("OnUpdate",PAB_OnUpdate)
	
	print("Party Ability Bars by Kollektiv; ported to cata by ? and modified by V. Type /pab to open options")
end

function PAB:FindAbilityIcon(ability)
	if iconPaths[ability] then return iconPaths[ability] end
	for id=SPELLIDUPPER,1,-1 do
		local _ability,_,_icon = GetSpellInfo(id)
		if _ability and _ability == ability then
			iconPaths[ability] = _icon
			return _icon
		end
	end
end

function PAB:FormatAbility(s)
	s = s:gsub("(%a)(%a*)('*)(%a*)", function (a,b,c,d) return a:upper()..b:lower()..c..d:lower() end)
	s = s:gsub("(The)", string.lower)
	s = s:gsub("(Of)", string.lower)
	return s
end

-------------------------------------------------------------
-- Options
-------------------------------------------------------------

local SO = LibStub("LibSimpleOptions-1.0")

function PAB:CreateOptions()
	local panel = SO.AddOptionsPanel("PAB", function() end)
	self.panel = panel
	SO.AddSlashCommand("PAB","/pab")
	local title, subText = panel:MakeTitleTextAndSubText("Party Ability Bars","General settings")
	local scale = panel:MakeSlider(
	     'name', 'Scale',
	     'description', 'Adjust the scale of icons',
	     'minText', '0.1',
	     'maxText', '5',
	     'minValue', 0.1,
	     'maxValue', 5,
	     'step', 0.05,
	     'default', 1,
	     'current', db.scale,
	     'setFunc', function(value) db.scale = value; PAB:ApplyAnchorSettings() end,
	     'currentTextFunc', function(value) return string.format("%.2f",value) end)
	scale:SetPoint("TOPLEFT",subText,"TOPLEFT",16,-32)
	
	local lock = panel:MakeToggle(
	     'name', 'Lock',
	     'description', 'Show/hide anchors',
	     'default', false,
	     'getFunc', function() return db.lock end,
	     'setFunc', function(value) db.lock = value; PAB:ApplyAnchorSettings() end)
	     
	lock:SetPoint("TOP",panel,"TOP",10,-36)
	
	local arena = panel:MakeToggle(
	     'name', 'Arena',
	     'description', 'Show in arena only',
	     'default', false,
	     'getFunc', function() return db.arena end,
	     'setFunc', function(value) db.arena = value; PAB:ApplyAnchorSettings() end)
	arena:SetPoint("TOP",lock,"BOTTOM",0,-5)
	
	local hidden = panel:MakeToggle(
	     'name', 'Hidden',
	     'description', 'Show icon only when on cooldown',
	     'default', false,
	     'getFunc', function() return db.hidden end,
	     'setFunc', function(value) db.hidden = value; PAB:ApplyAnchorSettings() end)
	hidden:SetPoint("LEFT",lock,"RIGHT",50,0)
	
	local title2, subText2 = panel:MakeTitleTextAndSubText("Ability editor","Change what party member abilities are tracked")
	title2:ClearAllPoints()
	title2:SetPoint("LEFT",panel,"LEFT",16,80)
	subText2:ClearAllPoints()
	subText2:SetPoint("TOPLEFT",title2,"BOTTOMLEFT",0,-8)
	
	self:CreateAbilityEditor()
end

local function count(t) local i = 0 for k,v in pairs(t) do i = i + 1 end return i end

function PAB:UpdateScrollBar()
	local btns = self.btns
	local scrollframe = self.scrollframe
	local classSelectedTable = db.abilities[db.classSelected]
	local classSelectedTableLength = count(db.abilities[db.classSelected])
	FauxScrollFrame_Update(scrollframe,classSelectedTableLength,10,16,nil,nil,nil,nil,nil,nil,true);
	local line = 1
	for ability,cooldown in pairs(classSelectedTable) do
		lineplusoffset = line + FauxScrollFrame_GetOffset(scrollframe)
		btns[line]:SetText(ability)
		if btns[line]:GetText() ~= scrollframe.currentButton then
			btns[line]:SetNormalTexture("")
		else 
			btns[line]:SetNormalTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			btns[line]:GetNormalTexture():SetBlendMode("ADD") 
			scrollframe.addeditbox:SetText(ability)
			scrollframe.cdeditbox:SetText(cooldown)
		end
		btns[line]:Show()
		line = line + 1
	end
	for i=line,10 do btns[i]:Hide() end
end

function PAB:OnVerticalScroll(offset,itemHeight)
	local scrollbar = _G[self.scrollframe:GetName().. "ScrollBar"]
	scrollbar:SetValue(offset);
	self.scrollframe.offset = floor((offset / itemHeight) + 0.5);
	self:UpdateScrollBar()
end

local function CreateListButton(parent,index)
	local button = CreateFrame("Button",parent:GetName()..index,parent)
	button:SetWidth(130)
	button:SetHeight(16)
	local font = CreateFont("PABListFont")
	font:SetFont(GameFontNormal:GetFont(),12)
	font:SetJustifyH("LEFT")
	button:SetNormalFontObject(font)
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
	button:SetScript("OnClick",function(self) parent.currentButton = self:GetText(); PAB:UpdateScrollBar() end)
	return button
end

local function CreateEditBox(name,parent,width,height)
	local editbox = CreateFrame("EditBox",parent:GetName()..name,parent,"InputBoxTemplate")
	editbox:SetHeight(height)
	editbox:SetWidth(width)
	editbox:SetAutoFocus(false)
	
	local label = editbox:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
	label:SetText(name)
	label:SetPoint("BOTTOMLEFT", editbox, "TOPLEFT",-3,0)
	return editbox
end

function PAB:CreateAbilityEditor()
	local panel = self.panel
	local btns = {}
	self.btns = btns
	local scrollframe = CreateFrame("ScrollFrame", "PABScrollFrame",panel,"FauxScrollFrameTemplate")
	local button1 = CreateListButton(scrollframe,"1")
	button1:SetPoint("TOPLEFT",scrollframe,"TOPLEFT",11,0)
	btns[#btns+1] = button1
	for i=2,10 do
		local button = CreateListButton(scrollframe,tostring(i))
		button:SetPoint("TOPLEFT",btns[#btns],"BOTTOMLEFT")
		btns[#btns+1] = button
	end
	
	scrollframe:SetWidth(150); 
	scrollframe:SetHeight(160)
	scrollframe:SetPoint('LEFT',16,-45)
	scrollframe:SetBackdrop(backdrop)
	scrollframe:SetBackdropColor(.6,.6,.6,0.25)
	scrollframe:SetScript("OnVerticalScroll", function(self,offset) PAB:OnVerticalScroll(offset,16) end)
	scrollframe:SetScript("OnShow",function(self) if not db.classSelected then db.classSelected = "WARRIOR" end; PAB:UpdateScrollBar();  end)
	
	self.scrollframe = scrollframe
	
	local dropdown = panel:MakeDropDown(
       'name', 'Class',
	     'description', 'Pick a class to edit the ability list',
	     'values', {
	     		"WARRIOR", "Warrior",
					"DEATHKNIGHT", "Deathknight",
					"PALADIN", "Paladin",
					"PRIEST", "Priest",
					"SHAMAN", "Shaman",
					"DRUID", "Druid",
					"ROGUE", "Rogue",
					"MAGE", "Mage",
					"WARLOCK", "Warlock",
					"HUNTER", "Hunter",
	      },
	     'default', 'WARRIOR',
	     'getFunc', function() return db.classSelected end ,
	     'setFunc', function(value) db.classSelected = value; PAB:UpdateScrollBar(); end)
		
	dropdown:SetPoint("TOPLEFT",scrollframe,"TOPRIGHT",20,-8)
	local addeditbox = CreateEditBox("Ability name",scrollframe,120,25)
	scrollframe.addeditbox = addeditbox
	
	addeditbox:SetPoint("TOPLEFT",dropdown,"BOTTOMLEFT",20,-15)
	local cdeditbox = CreateEditBox("CD (s)",scrollframe,50,25)
	cdeditbox:SetPoint("LEFT",addeditbox,"RIGHT",15,0)
	scrollframe.cdeditbox = cdeditbox
	
	local addbutton = panel:MakeButton(
	     'name', 'Add/Edit',
	     'description', "Add a new ability with a specified cooldown. Don't worry about capitalization, the ability will be properly formatted",
	     'func', function() 
	     		local ability = PAB:FormatAbility(addeditbox:GetText())
	     		local iconfound = PAB:FindAbilityIcon(ability)
	     		local cdtext = cdeditbox:GetText():match("^[0-9]+$")
	     		if iconfound and cdtext then
	     			print("Added/updated "..ability)
	     			db.abilities[db.classSelected][ability] = tonumber(cdtext)
	     			scrollframe.currentButton = ability
	     			PAB:UpdateScrollBar()
	     			PAB:UpdateAnchors()
	     		else
	     			print("Invalid spell name and/or cooldown")
	     		end
	      end
	)
	addbutton:SetPoint("TOPLEFT",addeditbox,"BOTTOMLEFT",-5,0)
	
	local removebutton = panel:MakeButton(
	     'name', 'Remove',
	     'description', 'Remove the selected ability',
	     'func', function()
	     		 print("Removed " .. addeditbox:GetText())
	     		 db.abilities[db.classSelected][addeditbox:GetText()] = nil; 
	     		 addeditbox:SetText(""); 
	     		 cdeditbox:SetText(""); 
	     		 scrollframe.currentButton = nil; 
	     		 PAB:UpdateScrollBar(); 
	     		 PAB:UpdateAnchors() 
	     end
	)
	removebutton:SetPoint("TOPLEFT",addbutton,"BOTTOMLEFT",0,-5)
	
	local description =  panel:CreateFontString(nil,"ARTWORK","GameFontNormal")
	description:SetText("Don't worry about the CD number if your party member has the mod. It will ignore the stored CD and instead sync with your teammate.")
	description:SetNonSpaceWrap(true)
	description:SetJustifyH("LEFT")
	description:SetWidth(100)
	description:SetHeight(50)
	description:SetPoint("TOPLEFT",scrollframe,"BOTTOMLEFT",0,-10)
	description:SetPoint("RIGHT", -32, 0)
end

PAB:RegisterEvent("VARIABLES_LOADED")
PAB:SetScript("OnEvent",PAB_OnLoad)