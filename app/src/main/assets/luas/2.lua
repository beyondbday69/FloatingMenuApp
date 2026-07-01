--[[
    OPTISKI - Performance-Optimized Skin System
    ==============================================
    Drop-in replacement for skin.lua, designed for low-end Android.
    Same global API (get_skin_id, get_vehicle_skin_id, equip_character_avatar,
    ApplyWeaponSkins, ApplyVehicleSkins, HandlePetLogic, ReadConfigFile, etc.)
    so it can be used standalone or alongside the original skin.lua.

    KEY OPTIMIZATIONS vs skin.lua
    -----------------------------
    1. Multi-rate tickers instead of one 0.1s loop
         - Fast apply  (0.4s) : weapon + outfit skin apply
         - Slow scan   (2.0s) : deadbox scan (was every 0.1s = 20x more)
         - Slow hooks  (5.0s) : kill-counter UI hook (mostly one-shot anyway)
    2. INI file is reparsed only when its mtime changes (was every 0.1s)
    3. AlreadyChangedSet converted to a hash set (O(1) lookup, was O(n))
    4. equip_character_avatar only calls OnRep_BodySlotStateChanged() when
       something actually changed (was called every tick on every slot)
    5. ApplyVehicleSkins no longer calls EnableHighTireLight / UpdateParticle /
       ChangeParticles / ReActivateExhaustParticle every tick. They only run
       when the (vehicle, skin) pair changes.
    6. import("BackpackUtils") cached on first use (was re-imported every tick)
    7. DeadBox_TemperRequest throttled to 2.0s and short-circuits if no kills
       are possible (player dead / not in match)
    8. Kill-counter UI hook check throttled to 5.0s; once installed it
       becomes a no-op
    9. Glider slot pre-add work is now a one-shot per slotSyncData lifetime
   10. Dead-box linear scan of _G.DeadBoxSkins capped at last 32 entries
]]

-- ===================================================================
-- SECTION 1: PER-MATCH GUARD
-- ===================================================================
do
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if pc then
        if _G._AKSKIN_LOADED and _G._AKSKIN_PC == pc then return end
        _G._AKSKIN_PC = pc
        _G._AKSKIN_LOADED = true
        _G.AKSkinLoopStarted = false
    else
        _G._AKSKIN_LOADED = false
    end
end

-- ===================================================================
-- SECTION 2: CONFIG FILE PATH
-- ===================================================================
_G.ConfigFilePath = '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini'

-- ===================================================================
-- SECTION 3: BASE SKIN ID DEFINITIONS
-- ===================================================================
_G.BaseSkinIDs = {
    Weapons = {
        101001, 101002, 101003, 101004, 101005, 101006, 101007, 101008,
        101009, 101010, 101012, 101101, 101100, 101102, 102001, 102002,
        102003, 102004, 102005, 102007, 102105, 103001, 103002, 103003,
        103004, 103005, 103006, 103007, 103009, 103010, 103100, 103012,
        103102, 103013, 104003, 104004, 104001, 104002, 105001, 105002,
        105010, 108004, 108001, 108002, 108003,
    },
    Outfits = {
        Suit     = 403003,
        Bag      = 501001,
        Helmet   = 502001,
        Parachut = 703001,
        Pet      = 50000,
        Shirt    = 403001,
        Hat      = 401003,
        Mask     = 402001,
        Glasses  = 402002,
        Pants    = 404001,
        Shoes    = 405001,
        Armor    = 0,
    }
}

_G.OutfitSkins = {
    Suit     = { _G.BaseSkinIDs.Outfits.Suit },
    Bag      = { _G.BaseSkinIDs.Outfits.Bag },
    Helmet   = { _G.BaseSkinIDs.Outfits.Helmet },
    Parachut = { _G.BaseSkinIDs.Outfits.Parachut },
    Pet      = { _G.BaseSkinIDs.Outfits.Pet },
    Shirt    = { _G.BaseSkinIDs.Outfits.Shirt },
    Hat      = { _G.BaseSkinIDs.Outfits.Hat },
    Mask     = { _G.BaseSkinIDs.Outfits.Mask },
    Glasses  = { _G.BaseSkinIDs.Outfits.Glasses },
    Pants    = { _G.BaseSkinIDs.Outfits.Pants },
    Shoes    = { _G.BaseSkinIDs.Outfits.Shoes },
    Armor    = { _G.BaseSkinIDs.Outfits.Armor },
}

-- ===================================================================
-- SECTION 4: WEAPON SKIN MAPPING TABLE
-- ===================================================================
_G.skinIdMappings = {}
for _, id in ipairs(_G.BaseSkinIDs.Weapons) do
    _G.skinIdMappings[id] = { id }
end

-- ===================================================================
-- SECTION 5: VEHICLE DEFINITIONS
-- ===================================================================
_G.VehicleMapDict = {
    UAZ = 1908001, Dacia = 1903001, Buggy = 1907001,
    Motor = 1901001, CoupeRB = 1961001,
}
_G.VehicleSkinsList = {}
_G.VehicleSkinIndex = {}

-- ===================================================================
-- SECTION 6: EQUIPMENT SLOT TYPES
-- ===================================================================
_G.CustSlotType = {
    ClothesEquipemtSlot   = 5,
    BackpackEquipemtSlot  = 8,
    HelmetEquipemtSlot    = 9,
    ParachuteEquipemtSlot = 11,
    GlideEquipemtSlot     = 15,
    HatEquipemtSlot       = 0,
    MaskEquipemtSlot      = 1,
    GlassesEquipemtSlot   = 2,
    ShirtEquipemtSlot     = 3,
    PantsEquipemtSlot     = 4,
    ShoesEquipemtSlot     = 6,
    ArmorEquipemtSlot     = 14,
}

-- ===================================================================
-- SECTION 7: RUNTIME STATE
-- ===================================================================
_G.WeaponSkinIndex       = _G.WeaponSkinIndex or {}
_G.SuitSkin              = 0
_G.BagSkin               = 0
_G.HelmetSkin            = 0
_G.ParachuteSkin         = 0
_G.GliderSkin            = 0
_G.PetSkin               = 0
_G.ShirtSkin             = 0
_G.HatSkin               = 0
_G.MaskSkin              = 0
_G.GlassesSkin           = 0
_G.PantsSkin             = 0
_G.ShoesSkin             = 0
_G.ArmorSkin             = 0
_G.LastBackApplyValue    = 0
_G.LastHelmetApplyValue  = 0
_G.skinIdCache           = {}
_G.skinIdCache2          = {}

-- _G.OutfitMap -- single mirror of all outfit skin IDs, used by the
-- logic.lua-style apply in equip_character_avatar.
_G.OutfitMap             = _G.OutfitMap or {
    Suit = 0, Bag = 0, Helmet = 0, Parachute = 0, Pet = 0,
    Shirt = 0, Hat = 0, Mask = 0, Glasses = 0, Pants = 0, Shoes = 0, Armor = 0,
}
-- Last-applied extra-outfit cache (Hat / Mask / Glasses / Pants / Shoes / Armor / Parachute)
_G.LastEquippedOutfits   = _G.LastEquippedOutfits or {}

-- Cached resolved lookup (weaponID -> resolved skinID), rebuilt only on INI change
_G._ResolvedWeaponSkins  = {}
_G._ResolvedVehicleSkins = {}
_G._SkinDataVersion      = 0

-- Local change-detection cache (for INI selected indices)
local changeDetectionCache = {}

-- Cached import handles
local _BackpackUtils = nil
local _BackpackUtilsTried = false
local function getBackpackUtils()
    if _BackpackUtils then return _BackpackUtils end
    if _BackpackUtilsTried then return nil end
    _BackpackUtilsTried = true
    local ok, mod = pcall(import, "BackpackUtils")
    if ok and mod then _BackpackUtils = mod end
    return _BackpackUtils
end

-- ===================================================================
-- SECTION 8: ASSET DOWNLOAD HELPER
-- ===================================================================
local function downloadSkinAsset(id)
    local pufferManager = require('client.slua.logic.download.puffer.puffer_manager')
    local pufferConst   = require('client.slua.logic.download.puffer_const')
    if pufferManager and pufferConst then
        local currentState = pufferManager.GetState(pufferConst.ENUM_DownloadType.ODPAK, {id})
        if currentState ~= pufferConst.ENUM_DownloadState.Done then
            pufferManager.Download(pufferConst.ENUM_DownloadType.ODPAK, {id})
        end
    end
end
_G.download_item = downloadSkinAsset

-- ===================================================================
-- SECTION 9: SKIN ID RESOLVERS
-- Use the resolved cache so a hot path is one table lookup.
-- ===================================================================
_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local resolved = _G._ResolvedWeaponSkins[weaponID]
    if resolved == nil then
        local selectedIndex = _G.WeaponSkinIndex[weaponID] or 1
        local skinList = _G.skinIdMappings[weaponID]
        if not skinList or not skinList[selectedIndex] then
            resolved = weaponID
        else
            resolved = skinList[selectedIndex]
        end
        _G._ResolvedWeaponSkins[weaponID] = resolved
    end
    if resolved and resolved ~= weaponID then
        if not _G.skinIdCache2[resolved] then
            pcall(_G.download_item, resolved)
            _G.skinIdCache2[resolved] = true
        end
    end
    return resolved
end

_G.get_vehicle_skin_id = function(vehicleID)
    if not vehicleID or vehicleID == 0 then return vehicleID end
    local resolved = _G._ResolvedVehicleSkins[vehicleID]
    if resolved == nil then
        local vehicleStr = tostring(vehicleID)
        local basePrefix = string.sub(vehicleStr, 1, 4)
        local baseTypeID = tonumber(basePrefix .. "001")

        local skinList = _G.VehicleSkinsList[baseTypeID]
        if skinList then
            local idx = _G.VehicleSkinIndex[baseTypeID] or 1
            if idx < 1 then idx = 1 end
            if idx > #skinList then idx = #skinList end
            local skinID = skinList[idx]
            if skinID and skinID > 0 then
                resolved = skinID
            else
                resolved = vehicleID
            end
        else
            resolved = vehicleID
        end
        _G._ResolvedVehicleSkins[vehicleID] = resolved
    end
    if resolved and resolved ~= vehicleID then
        if not _G.skinIdCache2[resolved] then
            if _G.download_item then pcall(_G.download_item, resolved) end
            _G.skinIdCache2[resolved] = true
        end
    end
    return resolved
end

-- Force the resolver caches to be rebuilt (called on INI change).
local function rebuildResolverCaches()
    _G._ResolvedWeaponSkins  = {}
    _G._ResolvedVehicleSkins = {}
end

-- ===================================================================
-- SECTION 10: INI FILE PARSERS  (content-aware, only reparse on change)
-- ===================================================================
local _iniContent    = nil
local _iniEverLoaded = false

_G.LoadSkinDataFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local inSkinSection = false
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then
            inSkinSection = true
        elseif line:match('%[SELECTED%]') then
            inSkinSection = false
        end
        if inSkinSection and not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, valueStr = line:match('([^=]+)=(.+)')
            if key and valueStr then
                key = key:match("^%s*(.-)%s*$")
                local values = {}
                for val in valueStr:gmatch('([^,]+)') do
                    local num = tonumber(val:match("^%s*(.-)%s*$"))
                    if num then table.insert(values, num) end
                end
                if #values > 0 then
                    if _G.OutfitSkins[key] ~= nil then
                        _G.OutfitSkins[key] = values
                    elseif _G.VehicleMapDict[key] ~= nil then
                        local vehicleBaseID = _G.VehicleMapDict[key]
                        _G.VehicleSkinsList[vehicleBaseID] = values
                    elseif tonumber(key) then
                        _G.skinIdMappings[tonumber(key)] = values
                    end
                end
            end
        end
    end
    file:close()
    _G.SuitSkinsMap     = _G.OutfitSkins.Suit
    _G.BagSkinsMap      = _G.OutfitSkins.Bag
    _G.HelmetSkinsMap   = _G.OutfitSkins.Helmet
    _G.ParachutSkinsMap = _G.OutfitSkins.Parachut
    _G.PetSkinsMap      = _G.OutfitSkins.Pet
    _G.ShirtSkinsMap    = _G.OutfitSkins.Shirt
    _G.HatSkinsMap      = _G.OutfitSkins.Hat
    _G.MaskSkinsMap     = _G.OutfitSkins.Mask
    _G.GlassesSkinsMap  = _G.OutfitSkins.Glasses
    _G.PantsSkinsMap    = _G.OutfitSkins.Pants
    _G.ShoesSkinsMap    = _G.OutfitSkins.Shoes
    _G.ArmorSkinsMap    = _G.OutfitSkins.Armor
end
pcall(_G.LoadSkinDataFromINI)

_G.ReadConfigFile = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local config = {}
    
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then break end
        if not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, val = line:match('([%w_]+)%s*=%s*([%w]+)')
            if key and val and not line:match(',') then
                if val:lower() == "off" then
                    config[key] = -1
                else
                    config[key] = tonumber(val)
                end
            end
        end
    end
    file:close()

    local function applyOutfitSelection(key, skinMap, globalVarName)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G[globalVarName] = skinMap and skinMap[config[key] + 1] or 0
            changeDetectionCache[key] = config[key]
        end
    end
    applyOutfitSelection('Suit',     _G.SuitSkinsMap,     'SuitSkin')
    applyOutfitSelection('Bag',      _G.BagSkinsMap,      'BagSkin')
    applyOutfitSelection('Helmet',   _G.HelmetSkinsMap,   'HelmetSkin')
    applyOutfitSelection('Parachute', _G.ParachutSkinsMap, 'ParachuteSkin')
    applyOutfitSelection('Pet',      _G.PetSkinsMap,      'PetSkin')
    applyOutfitSelection('Shirt',    _G.ShirtSkinsMap,    'ShirtSkin')
    applyOutfitSelection('Hat',      _G.HatSkinsMap,      'HatSkin')
    applyOutfitSelection('Mask',     _G.MaskSkinsMap,     'MaskSkin')
    applyOutfitSelection('Glasses',  _G.GlassesSkinsMap,  'GlassesSkin')
    applyOutfitSelection('Pants',    _G.PantsSkinsMap,    'PantsSkin')
    applyOutfitSelection('Shoes',    _G.ShoesSkinsMap,    'ShoesSkin')
    applyOutfitSelection('Armor',    _G.ArmorSkinsMap,    'ArmorSkin')

    -- Mirror every *_Skin into _G.OutfitMap so the logic.lua-style
    -- apply in equip_character_avatar reads a single source of truth.
    _G.OutfitMap.Suit     = _G.SuitSkin
    _G.OutfitMap.Bag      = _G.BagSkin
    _G.OutfitMap.Helmet   = _G.HelmetSkin
    _G.OutfitMap.Parachute = _G.ParachuteSkin
    _G.OutfitMap.Pet      = _G.PetSkin
    _G.OutfitMap.Shirt    = _G.ShirtSkin
    _G.OutfitMap.Hat      = _G.HatSkin
    _G.OutfitMap.Mask     = _G.MaskSkin
    _G.OutfitMap.Glasses  = _G.GlassesSkin
    _G.OutfitMap.Pants    = _G.PantsSkin
    _G.OutfitMap.Shoes    = _G.ShoesSkin
    _G.OutfitMap.Armor    = _G.ArmorSkin

    local function applyWeaponSelection(key, weaponID)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.WeaponSkinIndex[weaponID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    
    local exhaustiveWeapons = {
        AKM = 101001, M16A4 = 101002, SCAR = 101003, M416 = 101004,
        GROZA = 101005, AUG = 101006, QBZ = 101007, M762 = 101008,
        MK47 = 101009, G36C = 101010, HoneyBadger = 101012, ASM = 101101, FAMAS = 101100, ACE32 = 101102,
        UZI = 102001, UMP = 102002, Vector = 102003, Thompson = 102004, Bizon = 102005, MP5K = 102007, P90 = 102105,
        Kar98 = 103001, M24 = 103002, AWM = 103003, SKS = 103004, VSS = 103005,
        Mini14 = 103006, MK14 = 103007, SLR = 103009, QBU = 103010, MK12 = 103100, AMR = 103012, DSR = 103102, Mosin = 103013,
        S12K = 104003, DBS = 104004, S1897 = 104001, S686 = 104002,
        M249 = 105001, DP28 = 105002, MG3 = 105010,
        Pan = 108004, Machete = 108001, Crowbar = 108002, Sickle = 108003,
    }
    for wName, wID in pairs(exhaustiveWeapons) do
        applyWeaponSelection(wName, wID)
    end
    -- Fallbacks for old names
    applyWeaponSelection('Kar98k', 103001)
    applyWeaponSelection('Shotgun', 104004)

    local function applyVehicleSelection(key)
        local vehicleBaseID = _G.VehicleMapDict[key]
        if vehicleBaseID and config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.VehicleSkinIndex[vehicleBaseID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    applyVehicleSelection('UAZ')
    applyVehicleSelection('Dacia')
    applyVehicleSelection('Buggy')
    applyVehicleSelection('Motor')
    applyVehicleSelection('CoupeRB')
end

-- Content-aware: only re-parse when the file content actually changed
_G.RefreshConfigIfChanged = function(force)
    local f = io.open(_G.ConfigFilePath, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    if not content then
        if not _iniEverLoaded then return end
        content = ''
    end
    if force or content ~= _iniContent or not _iniEverLoaded then
        _iniContent = content
        _iniEverLoaded = true
        rebuildResolverCaches()
        pcall(_G.LoadSkinDataFromINI)
        pcall(_G.ReadConfigFile)
    end
end

-- ===================================================================
-- SECTION 11: ATTACHMENT SKIN SYSTEM
-- ===================================================================
_G.BaseAttachToIndex = {
    [201010] = 1, [201005] = 1, [201004] = 1,
    [201009] = 2, [201003] = 2, [201002] = 2,
    [201011] = 3, [201007] = 3, [201006] = 3,
    [204012] = 4, [204005] = 4, [204008] = 4,
    [204011] = 5, [204004] = 5, [204007] = 5,
    [204013] = 6, [204006] = 6, [204009] = 6,
    [203001] = 7,  [203002] = 8,  [203003] = 9,
    [203014] = 10, [203004] = 11, [203015] = 12, [203005] = 13,
    [202002] = 14, [202001] = 15, [202004] = 16,
    [202005] = 17, [202007] = 18, [202006] = 19,
    [205002] = 20, [205003] = 20, [205001] = 20,
    [203018] = 21, [204014] = 22,
}

_G.VIP_Attachments  = {}
_G.VipAttachToIndex = {}

_G.LoadAttachmentsFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    _G.VIP_Attachments  = {}
    _G.VipAttachToIndex = {}
    local inAttachSection = false
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line == '[ATTACHMENTS]' then
            inAttachSection = true
        elseif line:match('^%[') then
            inAttachSection = false
        end
        if inAttachSection and not line:match('^%[') and line ~= '' and not line:match('^#') then
            local skinIDStr, valuesStr = line:match('^(%d+)=(.+)$')
            if skinIDStr and valuesStr then
                local skinID = tonumber(skinIDStr)
                local attachments = {}
                local slotIndex = 1
                for val in valuesStr:gmatch('([^,]+)') do
                    local attachID = tonumber(val) or 0
                    table.insert(attachments, attachID)
                    if attachID > 0 then
                        _G.VipAttachToIndex[attachID] = slotIndex
                    end
                    slotIndex = slotIndex + 1
                end
                _G.VIP_Attachments[skinID] = attachments
            end
        end
    end
    file:close()
end
pcall(_G.LoadAttachmentsFromINI)

-- Track whether attachments file changed
local _attachContent   = nil
local _attachEverLoaded = false
_G.RefreshAttachmentsIfChanged = function(force)
    local f = io.open(_G.ConfigFilePath, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    if not content then
        if not _attachEverLoaded then return end
        content = ''
    end
    if force or content ~= _attachContent or not _attachEverLoaded then
        _attachContent = content
        _attachEverLoaded = true
        pcall(_G.LoadAttachmentsFromINI)
    end
end

-- ===================================================================
-- SECTION 12: ORGSKIN-STYLE ATTACHMENT RESOLUTION
-- Reads attachments.txt + ItemUpgradeSystem + AvatarUtils fallback.
-- ===================================================================
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}
_G.ItemUpgradeSystem = _G.ItemUpgradeSystem or nil

local _AttachFilePath = string.match(_G.ConfigFilePath, '^(.*/)') .. 'attachments.txt'

local _AttachSystemInit = false
local function initAttachSystem()
    if _AttachSystemInit then return end
    _AttachSystemInit = true
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
        if IUS then
            IUS:DefineAndResetData(); IUS:OnInitialize()
            _G.ItemUpgradeSystem = IUS
        end
    end)
end

_G.get_group_id = function(itemId)
    if not _G.ItemUpgradeSystem or not itemId then return nil end
    local cfg = _G.ItemUpgradeSystem:GetUpgradeCfg(itemId)
    return cfg and cfg.GroupID or nil
end

_G.InitParts = function(groupId, itemId)
    if not itemId then return _G.g_parts end
    if _G.g_parts[itemId] and next(_G.g_parts[itemId]) then return _G.g_parts end
    _G.g_parts[itemId] = {}
    if not _G.ItemUpgradeSystem then return _G.g_parts end
    if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
        groupId = _G.ItemUpgradeSystem:GetNormalGroupID(groupId or _G.get_group_id(itemId))
    else
        groupId = groupId or _G.get_group_id(itemId)
    end
    if not groupId then return _G.g_parts end
    local cfg = CDataTable.GetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
    if cfg then
        for _, info in pairs(cfg) do
            local partId = info.PartId
            if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                if switched and switched ~= partId then partId = switched end
            end
            local item = CDataTable.GetTableData("Item", partId)
            if item and item.ItemName then _G.g_parts[itemId][item.ItemName] = partId end
        end
    end
    return _G.g_parts
end

_G.muzzles = { id_flash_hider = {201010,201005,201004}, id_compensator = {201009,201003,201002}, id_suppressor = {201011,201006,201007} }
_G.foregrips = { id_Angledforegrip=202001, id_thumb_grip=202006, id_vertical_grip=202002, id_light_grip=202004, id_half_grip=202005, id_ergonomic_grip=205051, id_laser_sight=202007 }
_G.magazines = { id_expanded_mag={204011,204007,204004}, id_quick_mag={204012,204008,204005}, id_expanded_quick_mag={204013,204009,204006} }
_G.scopes = { id_reddot=203001, id_holo=203002, id_2x=203003, id_3x=203014, id_4x=203004, id_6x=203015, id_8x=203005 }
_G.stock = { id_microStock=205001, id_tactical=205002, id_bulletloop=204014, id_CheekPad=205003 }

_G.GetRawAttachMap = function(skinid)
    if not skinid or skinid <= 0 then return {} end
    if _G.skinAttachCache[skinid] then return _G.skinAttachCache[skinid] end
    local UAvatarUtils = import("AvatarUtils")
    if not UAvatarUtils then return {} end
    local list = UAvatarUtils.GetWeaponAvatarDefaultAttachmentSkin(skinid, {}, false) or {}
    _G.skinAttachCache[skinid] = list
    return list
end

_G.GetSlotFromSkinID = function(skinid, slot)
    if not skinid or not slot then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local tmap = {
        [1] = {291004,291102,291001,291006,291005,291002,293003,293004,293009,293007,293005,293006,295001,295002,291007,291003,292002,292003,291011,291008},
        [2] = {205005,205102,205007,205009,205006},
        [3] = {203008,203009,203006,203022,203010}
    }
    local targetIDs = tmap[slot]
    if not targetIDs then return 0 end
    for _, targetID in ipairs(targetIDs) do
        for attachID, attachSkinID in pairs(list) do
            if attachID == targetID then return attachSkinID end
        end
    end
    return 0
end

_G.AutoDetectAttach = function(skinid, base_id)
    if not skinid or not base_id then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local v = list[base_id]
    return (v and v > 0) and v or 0
end

local ATTACH_NAME_MAP = {
    ["Red Dot Sight"]="RedDot",["Holographic Sight"]="Holo",["2x Scope"]="Scope2x",
    ["3x Scope"]="Scope3x",["4x Scope"]="Scope4x",["6x Scope"]="Scope6x",["8x Scope"]="Scope8x",
    ["Canted Sight"]="CantedSight",["Flash Hider"]="FlashHider",["Compensator"]="Compensator",
    ["Suppressor"]="Suppressor",["Extended Mag"]="ExtMag",["Quickdraw Mag"]="QuickMag",
    ["Extended Quickdraw Mag"]="ExtQuickMag",["Angled Foregrip"]="AngledGrip",
    ["Vertical Foregrip"]="VerticalGrip",["Thumb Grip"]="ThumbGrip",["Half Grip"]="HalfGrip",
    ["Light Grip"]="LightGrip",["Laser Sight"]="LaserSight",["Tactical Stock"]="TactStock",
    ["Stock"]="MicroStock",["Cheek Pad"]="CheekPad",
}
local _attachFileCache
local function parseAttachmentsFile()
    local result = {}
    pcall(function()
        local f = io.open(_AttachFilePath, "r")
        if not f then return end
        local content = f:read("*all"); f:close()
        local curSkin
        for line in content:gmatch("[^\r\n]+") do
            local firstNum = line:match("^(%d+)%s*|")
            if firstNum then
                local num = tonumber(firstNum)
                if num and num > 1100000000 then curSkin = num; result[curSkin] = result[curSkin] or {}
                elseif num and curSkin then
                    local an = line:match("^%d+%s*|%s*%x+%s*|%s*(.-)%s*$")
                    if not an then an = line:match("^%d+%s*|%s*(.-)%s*$") end
                    if an and an ~= "" then
                        local key = ATTACH_NAME_MAP[an]
                        if key then result[curSkin][key] = num end
                    end
                end
            elseif line:find("^#%-%-%-%-") and line:find("skin") then curSkin = nil end
        end
    end)
    return result
end
_G.GetAttachForSkin = function(skinId, key)
    if not skinId or skinId == 0 or not key then return nil end
    if not _attachFileCache then _attachFileCache = parseAttachmentsFile() end
    local t = _attachFileCache[skinId]
    if not t then return nil end
    local v = t[key]
    return (v and v > 0) and v or nil
end

_G.get_muzzleid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.muzzles[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_flash_hider") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "FlashHider") or (p and p["Flash Hider"]) or (auto>0 and auto) or current_id
    elseif is_in("id_compensator") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Compensator") or (p and p["Compensator"]) or (auto>0 and auto) or current_id
    elseif is_in("id_suppressor") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Suppressor") or (p and p["Suppressor"]) or (auto>0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_forgripid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.foregrips.id_Angledforegrip then current_id = lookup("AngledGrip","Angled Foregrip")
    elseif current_id == _G.foregrips.id_thumb_grip then current_id = lookup("ThumbGrip","Thumb Grip")
    elseif current_id == _G.foregrips.id_vertical_grip then current_id = lookup("VerticalGrip","Vertical Foregrip")
    elseif current_id == _G.foregrips.id_light_grip then current_id = lookup("LightGrip","Light Grip")
    elseif current_id == _G.foregrips.id_half_grip then current_id = lookup("HalfGrip","Half Grip")
    elseif current_id == _G.foregrips.id_ergonomic_grip then current_id = (p and p["Ergonomic Grip"]) or (auto>0 and auto) or current_id
    elseif current_id == _G.foregrips.id_laser_sight then current_id = lookup("LaserSight","Laser Sight") end
    return current_id, (initial_id ~= current_id)
end
_G.get_magazinesid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t) for _, id in ipairs(_G.magazines[t]) do if current_id == id then return true end end; return false end
    if is_in("id_expanded_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtMag") or (p and p["Extended Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "QuickMag") or (p and p["Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_expanded_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtQuickMag") or (p and p["Extended Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    else local fb = _G.GetSlotFromSkinID(avatarid,1); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end
_G.get_scopeid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.scopes.id_reddot then current_id = lookup("RedDot","Red Dot Sight")
    elseif current_id == _G.scopes.id_holo then current_id = lookup("Holo","Holographic Sight")
    elseif current_id == _G.scopes.id_2x then current_id = lookup("Scope2x","2x Scope")
    elseif current_id == _G.scopes.id_3x then current_id = lookup("Scope3x","3x Scope")
    elseif current_id == _G.scopes.id_4x then current_id = lookup("Scope4x","4x Scope")
    elseif current_id == _G.scopes.id_6x then current_id = lookup("Scope6x","6x Scope")
    elseif current_id == _G.scopes.id_8x then current_id = lookup("Scope8x","8x Scope")
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_stockid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id end
    if current_id == _G.stock.id_microStock then current_id = lookup("MicroStock","Stock")
    elseif current_id == _G.stock.id_tactical then current_id = lookup("TactStock","Tactical Stock")
    elseif current_id == _G.stock.id_bulletloop then current_id = (p and p["Bullet Loop"]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id
    elseif current_id == _G.stock.id_CheekPad then current_id = lookup("CheekPad","Cheek Pad")
    else local fb = _G.GetSlotFromSkinID(avatarid,2); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end

_G.apply_attachment = function(CurWeapon, avatarid)
    if not slua.isValid(CurWeapon) or not avatarid then return end
    local array = CurWeapon.synData
    if not slua.isValid(array) then return end
    local changed = false
    for AttachIdx = 0, 3 do
        local Data = array:Get(AttachIdx)
        local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
        if itemid and itemid > 0 and itemid < 10000000 then
            local isrefresh = false
            if AttachIdx == 0 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_muzzleid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 1 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_forgripid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 2 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_magazinesid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 3 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_stockid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    do
        local AttachIdx = 4
        local Data = array:Get(AttachIdx)
        if Data then
            local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
            local isrefresh = false
            if itemid and itemid > 0 and itemid < 10000000 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    if changed then
        local savedScopeID
        local scopeData = array:Get(4)
        if scopeData then
            local sid = slua.IndexReference(scopeData, "defineID").TypeSpecificID
            if sid and sid > 0 and sid < 10000000 then
                savedScopeID = sid
            end
        end

        _G.download_item(avatarid)
        if CurWeapon.DelayHandleAvatarMeshChanged then
            pcall(function() CurWeapon:DelayHandleAvatarMeshChanged() end)
        end
        if CurWeapon.OnRep_synData then
            pcall(function() CurWeapon:OnRep_synData() end)
        end
        if CurWeapon.UpdateWeaponAttachment then
            pcall(function() CurWeapon:UpdateWeaponAttachment() end)
        end

        if savedScopeID then
            local newData = array:Get(4)
            if newData then
                local newID = slua.IndexReference(newData, "defineID").TypeSpecificID
                if newID ~= savedScopeID then
                    newData.defineID.TypeSpecificID = savedScopeID
                    array:Set(4, newData)
                end
            end
        end
    end
end

-- ===================================================================
-- SECTION 13: CHARACTER AVATAR (OUTFIT) SKIN APPLICATION
-- Now O(changed slots) not O(all slots * all skins).
-- ===================================================================
_G.equip_character_avatar = function(playerChar)
    if not playerChar or not slua.isValid(playerChar) or not playerChar.AvatarComponent2 then return end

    local ac = playerChar.AvatarComponent2
    if not ac or not slua.isValid(ac) or not ac.NetAvatarData then return end

    local slotSyncData = ac.NetAvatarData.SlotSyncData
    if not slotSyncData or not slua.isValid(slotSyncData) then return end

    local BackpackUtils = getBackpackUtils()

    -- One-shot glider slot pre-add (per slotSyncData lifetime)
    local syncDataId = tostring(slotSyncData)
    if not _G._GliderSlotEnsuredFor then _G._GliderSlotEnsuredFor = {} end
    if not _G._GliderSlotEnsuredFor[syncDataId] then
        local hasGliderSlot = false
        local preNum = slotSyncData:Num()
        for i = 0, preNum - 1 do
            local slotData = slotSyncData:Get(i)
            if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then
                hasGliderSlot = true
                break
            end
        end
        if not hasGliderSlot then
            slotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 })
        end
        _G._GliderSlotEnsuredFor[syncDataId] = true
    end

    -- One-shot extra slot injection (per slotSyncData lifetime, like Glider).
    -- Cached to prevent duplicate Add() calls that corrupt the array.
    if not _G._ExtraSlotsEnsuredFor then _G._ExtraSlotsEnsuredFor = {} end
    if not _G._ExtraSlotsEnsuredFor[syncDataId] then
        local extraSlots = {
            _G.CustSlotType.HatEquipemtSlot,
            _G.CustSlotType.MaskEquipemtSlot,
            _G.CustSlotType.GlassesEquipemtSlot,
            _G.CustSlotType.ShirtEquipemtSlot,
            _G.CustSlotType.PantsEquipemtSlot,
            _G.CustSlotType.ShoesEquipemtSlot,
            _G.CustSlotType.ArmorEquipemtSlot,
        }
        local preNum = slotSyncData:Num()
        local existingSlots = {}
        for i = 0, preNum - 1 do
            local slotData = slotSyncData:Get(i)
            if slotData then existingSlots[slotData.SlotID] = true end
        end
        for _, slotType in ipairs(extraSlots) do
            if not existingSlots[slotType] then
                slotSyncData:Add({ SlotID = slotType, ItemId = 0 })
            end
        end
        _G._ExtraSlotsEnsuredFor[syncDataId] = true

        -- New slotSyncData = new match/character. Clear download cache
        -- so assets get re-requested on the new character instance.
        for _, key in ipairs({"Shirt","Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute"}) do
            local id = _G.OutfitMap[key]
            if id and id > 0 then
                _G.skinIdCache[id] = nil
            end
        end
    end

    -- ALL equipment slots via SlotSyncData — same approach as Suit.
    local ref = false
    local num = slotSyncData:Num()
    for i = 0, num - 1 do
        local eq = slotSyncData:Get(i)
        if eq then
            local target = 0
            local slotID = eq.SlotID
            if slotID == _G.CustSlotType.ClothesEquipemtSlot
                and _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0
            then
                target = _G.OutfitMap.Suit
            elseif slotID == _G.CustSlotType.BackpackEquipemtSlot
                and _G.OutfitMap.Bag and _G.OutfitMap.Bag ~= 0
                and _G.OutfitMap.Bag ~= 501001
                and BackpackUtils
            then
                local level = (BackpackUtils.GetEquipmentBagLevel
                    and BackpackUtils.GetEquipmentBagLevel(eq.AdditionalItemID)) or 1
                target = _G.OutfitMap.Bag + (level - 1) * 1000
            elseif slotID == _G.CustSlotType.HelmetEquipemtSlot
                and _G.OutfitMap.Helmet and _G.OutfitMap.Helmet ~= 0
                and _G.OutfitMap.Helmet ~= 502001
                and BackpackUtils
            then
                local level = (BackpackUtils.GetEquipmentHelmetLevel
                    and BackpackUtils.GetEquipmentHelmetLevel(eq.AdditionalItemID)) or 1
                target = _G.OutfitMap.Helmet + (level - 1) * 1000
            elseif slotID == _G.CustSlotType.HatEquipemtSlot
                and _G.OutfitMap.Hat and _G.OutfitMap.Hat ~= 0
            then
                target = _G.OutfitMap.Hat
            elseif slotID == _G.CustSlotType.MaskEquipemtSlot
                and _G.OutfitMap.Mask and _G.OutfitMap.Mask ~= 0
            then
                target = _G.OutfitMap.Mask
            elseif slotID == _G.CustSlotType.GlassesEquipemtSlot
                and _G.OutfitMap.Glasses and _G.OutfitMap.Glasses ~= 0
            then
                target = _G.OutfitMap.Glasses
            elseif slotID == _G.CustSlotType.ShirtEquipemtSlot
                and _G.OutfitMap.Shirt and _G.OutfitMap.Shirt ~= 0
            then
                target = _G.OutfitMap.Shirt
            elseif slotID == _G.CustSlotType.PantsEquipemtSlot
                and _G.OutfitMap.Pants and _G.OutfitMap.Pants ~= 0
            then
                target = _G.OutfitMap.Pants
            elseif slotID == _G.CustSlotType.ShoesEquipemtSlot
                and _G.OutfitMap.Shoes and _G.OutfitMap.Shoes ~= 0
            then
                target = _G.OutfitMap.Shoes
            elseif slotID == _G.CustSlotType.ArmorEquipemtSlot
                and _G.OutfitMap.Armor and _G.OutfitMap.Armor ~= 0
            then
                target = _G.OutfitMap.Armor
            end
            if target and target ~= 0 and eq.ItemId ~= target then
                if not _G.skinIdCache[target] then
                    pcall(_G.download_item, target)
                    _G.skinIdCache[target] = true
                end
                eq.ItemId = target
                slotSyncData:Set(i, eq)
                ref = true
            end
        end
    end
    if ref and ac.OnRep_BodySlotStateChanged then
        ac:OnRep_BodySlotStateChanged()
    end

    -- PutOnCustomEquipmentByID for instant visual load.
    -- Called every tick but lightweight when asset is already loaded.
    local extra_keys = {"Shirt","Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute"}
    for _, key in ipairs(extra_keys) do
        local id = _G.OutfitMap[key]
        if id and id > 0 then
            if not _G.skinIdCache[id] then
                pcall(_G.download_item, id)
                _G.skinIdCache[id] = true
            end
            pcall(function()
                if ac.PutOnCustomEquipmentByID then
                    ac:PutOnCustomEquipmentByID(id, {})
                end
            end)
        end
    end
end

-- ===================================================================
-- SECTION 14: WEAPON SKIN APPLICATION
-- Skip DelayHandleAvatarMeshChanged/OnRep_synData when nothing changed.
-- ===================================================================
_G.ApplyWeaponSkins = function(playerChar)
    pcall(function()
        initAttachSystem()
        local weaponManager = playerChar:GetWeaponManager()
        if not slua.isValid(weaponManager) then return end

        for slot = 1, 3 do
            local weapon = weaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(weapon) and slua.isValid(weapon.synData) then
                local weaponID = weapon:GetWeaponID()
                local targetSkinID = _G.get_skin_id(weaponID) or weaponID
                local wasModified = false

                local avatarData = weapon.synData:Get(7)
                if avatarData and avatarData.defineID and avatarData.defineID.TypeSpecificID ~= targetSkinID then
                    avatarData.defineID.TypeSpecificID = targetSkinID
                    weapon.synData:Set(7, avatarData)
                    if weapon.SetWeaponAvatarID then
                        pcall(function() weapon:SetWeaponAvatarID(targetSkinID) end)
                    end
                    if not _G.skinIdCache[targetSkinID] then
                        _G.download_item(targetSkinID)
                        _G.skinIdCache[targetSkinID] = true
                    end
                    wasModified = true
                end

                pcall(_G.apply_attachment, weapon, targetSkinID)
                if targetSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[targetSkinID] then
                    local attachSet = _G.VIP_Attachments[targetSkinID]
                    for attachIdx = 0, 5 do
                        local attachData = weapon.synData:Get(attachIdx)
                        if attachData then
                            local defineRef = slua.IndexReference(attachData, "defineID")
                            if defineRef then
                                local currentAttachID = defineRef.TypeSpecificID
                                if currentAttachID and currentAttachID > 0 then
                                    local slotIndex = _G.BaseAttachToIndex[currentAttachID]
                                                or _G.VipAttachToIndex[currentAttachID]
                                    local newAttachID = slotIndex and attachSet[slotIndex] or 0
                                    if newAttachID and newAttachID > 0 and newAttachID ~= currentAttachID then
                                        attachData.defineID.TypeSpecificID = newAttachID
                                        weapon.synData:Set(attachIdx, attachData)
                                        if not _G.skinIdCache2[newAttachID] then
                                            if _G.download_item then pcall(_G.download_item, newAttachID) end
                                            _G.skinIdCache2[newAttachID] = true
                                        end
                                        wasModified = true
                                    end
                                end
                            end
                        end
                    end
                end

                if wasModified then
                    if weapon.DelayHandleAvatarMeshChanged then
                        pcall(function() weapon:DelayHandleAvatarMeshChanged() end)
                    end
                    if weapon.OnRep_synData then
                        pcall(function() weapon:OnRep_synData() end)
                    end
                end
            end
        end
    end)
end

-- ===================================================================
-- SECTION 15: VEHICLE SKIN APPLICATION
-- Only re-trigger expensive particle / light / plate updates when
-- the (vehicle, target skin) pair actually changes.
-- ===================================================================
_G.ApplyVehicleSkins = function(playerChar)
    pcall(function()
        local vehicle = playerChar:GetCurrentVehicle()
        if not slua.isValid(vehicle) then
            _G.LastVehicleEntity = nil
            _G._LastVehicleSkinKey = nil
            return
        end
        if not Game:IsDriver(playerChar.Object) then return end

        local avatarComp = vehicle.VehicleAvatarComponent_BP or vehicle:GetAvatarComponent()
        if not slua.isValid(avatarComp) then return end

        local baseTypeID = 0
        if vehicle.AvatarDefaultCfg then
            baseTypeID = vehicle.AvatarDefaultCfg.TypeSpecificID
        end
        if baseTypeID == 0
            and avatarComp.VehicleNetAvatarData
            and avatarComp.VehicleNetAvatarData.ItemDefineID
        then
            baseTypeID = avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
        end
        if baseTypeID == 0 then return end

        local targetSkinID = _G.get_vehicle_skin_id(baseTypeID)
        local currentAvatarID = avatarComp:GetCurItemAvatarID()
        if not targetSkinID or targetSkinID == 0 or currentAvatarID == targetSkinID then
            _G.LastVehicleEntity = vehicle
            _G.CurrentEquipVehicleID = targetSkinID
            return
        end

        if not _G.skinIdCache[targetSkinID] then
            if _G.download_item then pcall(_G.download_item, targetSkinID) end
            _G.skinIdCache[targetSkinID] = true
        end

        if avatarComp.VehicleNetAvatarData and avatarComp.VehicleNetAvatarData.ItemDefineID then
            avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID = targetSkinID
            avatarComp.VehicleNetAvatarData.SkinOwnerUID = playerChar.PlayerUID
        end

        local comboKey = tostring(vehicle) .. ":" .. tostring(targetSkinID)
        local firstTimeForCombo = (_G._LastVehicleSkinKey ~= comboKey)
            or (_G.LastVehicleEntity ~= vehicle)
            or (_G.CurrentEquipVehicleID ~= targetSkinID)

        if firstTimeForCombo then
            _G.LastVehicleEntity       = vehicle
            _G.CurrentEquipVehicleID   = targetSkinID
            _G._LastVehicleSkinKey     = comboKey

            pcall(function()
                avatarComp.lastEquipedAvatarId = currentAvatarID
                if avatarComp.ShowVehicleSwitchEffect then
                    avatarComp:ShowVehicleSwitchEffect()
                end
                avatarComp.ClientUsedAvatarID = targetSkinID
                vehicle.ClientUsedAvatarID = targetSkinID
                if avatarComp.ChangeItemAvatar then
                    avatarComp:ChangeItemAvatar(targetSkinID, false)
                end
            end)
        else
            if avatarComp.ChangeItemAvatar then
                avatarComp:ChangeItemAvatar(targetSkinID, false)
            end
        end

        -- Only run these heavy ops on combo change (was every tick)
        if firstTimeForCombo then
            if avatarComp.EnableHighTireLight then
                avatarComp:EnableHighTireLight(true, targetSkinID)
            end
            if vehicle.UpdateParticle then
                pcall(function() vehicle:UpdateParticle(targetSkinID) end)
            end
            if vehicle.ChangeParticles then
                pcall(function() vehicle:ChangeParticles(targetSkinID) end)
            end
            if vehicle.ReActivateExhaustParticle then
                pcall(function() vehicle:ReActivateExhaustParticle() end)
            end

            local LicensePlateComp = import("VehicleLicenseNumberComponent")
            local plateComp = vehicle:GetComponentByClass(LicensePlateComp)
            if slua.isValid(plateComp) then
                if plateComp.LicensePlate then
                    plateComp.LicensePlate.ItemID = targetSkinID
                    plateComp.LicensePlate.ChassisLightId = targetSkinID + 1000
                end
                if plateComp.PreChangeEffect then plateComp:PreChangeEffect() end
                if plateComp.PreChangeChassisLight then plateComp:PreChangeChassisLight() end
            end
        end

        if vehicle.SetVehicleMusicPlayState then
            vehicle:SetVehicleMusicPlayState(true)
        end
    end)
end

-- ===================================================================
-- SECTION 16: PET SKIN APPLICATION
-- ===================================================================
_G.HandlePetLogic = function()
    pcall(function()
        if not _G.PetSkin or _G.PetSkin == 0 or _G.PetSkin == 50000
            or _G.PetSkin == _G.LastAppliedPet
        then
            return
        end
        if not _G.skinIdCache[_G.PetSkin] then
            _G.download_item(_G.PetSkin)
            _G.skinIdCache[_G.PetSkin] = true
        end
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local petModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if petModule then
                if petModule.SetCurPetID then petModule:SetCurPetID(_G.PetSkin) end
                if petModule.EquipPet then petModule:EquipPet(_G.PetSkin) end
            end
        end
        _G.LastAppliedPet = _G.PetSkin
    end)
end

-- ===================================================================
-- SECTION 17: KILL COUNTER / KILL MESSAGE SYSTEM
-- Real-time kill tracking with proper UI push on every event.
-- ===================================================================
_G.AKFakeKillCounts = _G.AKFakeKillCounts or setmetatable({}, { __index = function() return 4292 end })

local _KCHooked = false
local _KCModuleManager = nil
local _KCUIManager = nil

local function getKCModuleManager()
    if not _KCModuleManager then
        local ok, mod = pcall(require, "client.module_framework.ModuleManager")
        if ok and mod then _KCModuleManager = mod end
    end
    return _KCModuleManager
end

local function getKCUIManager()
    if not _KCUIManager then
        local ok, mod = pcall(require, "client.slua_ui_framework.manager")
        if ok and mod then _KCUIManager = mod end
    end
    return _KCUIManager
end

local function pushKillCounterUpdate(weaponID, skinID, killCount)
    pcall(function()
        local UIManager = getKCUIManager()
        if not UIManager then return end
        local killCounterUI = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if not killCounterUI or not killCounterUI.UpdateWeaponID then return end
        local avatarSkinID = skinID or weaponID
        killCounterUI:UpdateWeaponID(weaponID, avatarSkinID)
        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic and kcLogic.GetEquipedKillCounterId then
                local equippedKCId = kcLogic:GetEquipedKillCounterId(0, avatarSkinID)
                if killCounterUI.SetKillCounterItemShowWithNum then
                    killCounterUI:SetKillCounterItemShowWithNum(equippedKCId, killCount, avatarSkinID)
                end
            end
        end
    end)
end

local function safeRequire(name)
    local loaded = package.loaded[name]
    if loaded then return loaded end
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end

local function installKillCounterHooks()
    if _KCHooked then return end
    local anyHooked = false
    pcall(function()
        local KillCounterUI = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUI and KillCounterUI.__inner_impl then
            local impl = KillCounterUI.__inner_impl
            impl.CheckSupportKCUI = function() return true end
            impl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                if slua.isValid(weapon) then
                    local weaponID = weapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID) or weaponID
                    self:UpdateMainKillCounterUI(true, weaponID, skinID)
                    pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    self:UpdateMainKillCounterUI(false)
                end
            end
            local origUpdate = impl.UpdateMainKillCounterUI
            impl.UpdateMainKillCounterUI = function(self, bShow, weaponID, AvatarID)
                if bShow then
                    AvatarID = _G.get_skin_id(weaponID) or AvatarID
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                    pushKillCounterUpdate(weaponID, AvatarID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                end
            end
            anyHooked = true
        end

        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic then
                kcLogic.CheckSupportKC = function() return true end
                kcLogic.CheckSupportKillCounterAvatar = function() return true end
                kcLogic.CheckHasWeaponKillCounter = function() return true end
                kcLogic.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                kcLogic.GetEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetMyEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetOneWeaponKillCountInBattle = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                kcLogic.GetWeaponKillCountByUid = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                anyHooked = true
            end
        end

        local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
        if KillInfo and KillInfo.__inner_impl then
            local origFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local playerChar = safeRequire("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if not slua.isValid(playerChar) then return end
                    if DamageRecordData.Causer ~= playerChar:GetPlayerNameSafety() then return end
                    local currentWeapon = playerChar:GetCurrentWeapon()
                    if not slua.isValid(currentWeapon) then return end
                    local weaponID = currentWeapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID)
                    if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                    if _G.SuitSkin ~= 0 then DamageRecordData.CauserClothAvatarID = _G.SuitSkin end
                    DamageRecordData.IsUseColor = true
                    DamageRecordData.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)
                    if DamageRecordData.ResultHealthStatus == 2 then
                        _G.AKFakeKillCounts[weaponID] = (_G.AKFakeKillCounts[weaponID] or 0) + 1
                        pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID])
                    end
                end)
                if origFileItem then return origFileItem(self, DamageRecordData) end
            end
            anyHooked = true
        end

        local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SlotMode2 and SlotMode2.__inner_impl then
            local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
            SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                end
                if origCheck then return origCheck(self) end
            end
            local origShow = SlotMode2.__inner_impl.ShowKCIcon
            if origShow then
                SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                    local cnt = _G.AKFakeKillCounts[weaponID] or 0
                    if origShow then origShow(self, weaponID, skinID) end
                    if cnt > 0 then
                        pcall(function()
                            if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                self.KillCounterImg:SetKillCount(cnt)
                            end
                        end)
                    end
                end
            end
            anyHooked = true
        end
    end)
    if anyHooked then _KCHooked = true end
end

-- Immediately push kill counter for current weapon on call
_G.ForceEnableKillCounterUI = function()
    installKillCounterHooks()
    _G.RefreshKillCounterUI()
end

-- Per-tick refresh: keeps KC UI visible and count accurate
_G.RefreshKillCounterUI = function()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not pc then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not slua.isValid(lp) then return end
        local cw = lp:GetCurrentWeapon()
        if not slua.isValid(cw) then return end
        local wID = cw:GetWeaponID()
        if not wID or wID == 0 then return end
        local sid = _G.get_skin_id(wID)
        if not sid then
            local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
            if KCUI and KCUI.__inner_impl then
                KCUI.__inner_impl:UpdateMainKillCounterUI(false)
            end
            return
        end
        local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
        if KCUI and KCUI.__inner_impl then
            KCUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
        end
        pushKillCounterUpdate(wID, sid, _G.AKFakeKillCounts[wID] or 0)
    end)
end

-- ===================================================================
-- SECTION 18: DEAD BOX SKIN APPLICATION
-- Set-based membership (O(1)) + capped location cache + 2.0s throttle.
-- ===================================================================
_G.DeadBoxSkins      = _G.DeadBoxSkins or {}
_G.AlreadyChangedSet = _G.AlreadyChangedSet or {}
-- Force AlreadyChangedSet to act as a hash set
do
    if getmetatable(_G.AlreadyChangedSet) == nil then
        -- we keep the original array semantics for older code, but
        -- tableContainsSet below uses the SAME table as a hash by
        -- writing truthy markers (a sentinel) for set lookups.
    end
end

-- Hash-set membership helpers using _G.AlreadyChangedSet as both array
-- and hash (entries can be either deadbox refs or {__setKey=ref}).
local _DBSetKeys = _G._DBSetKeys or {}
_G._DBSetKeys = _DBSetKeys

local function dbContains(ref)
    if _DBSetKeys[ref] then return true end
    -- legacy path: check if the array contains the ref directly
    for i = 1, #_G.AlreadyChangedSet do
        if _G.AlreadyChangedSet[i] == ref then
            _DBSetKeys[ref] = true
            return true
        end
    end
    return false
end

local function dbAdd(ref)
    if _DBSetKeys[ref] then return end
    _G.AlreadyChangedSet[#_G.AlreadyChangedSet + 1] = ref
    _DBSetKeys[ref] = true
end

local function dbReset()
    -- clear both array and hash, keep tables allocated
    for k in pairs(_DBSetKeys) do _DBSetKeys[k] = nil end
    for i = #_G.AlreadyChangedSet, 1, -1 do _G.AlreadyChangedSet[i] = nil end
end
_G.DeadBox_ResetChangedSet = dbReset

local function isNearLocation(loc1, loc2, tolerance)
    local dx = loc1.X - loc2.X
    local dy = loc1.Y - loc2.Y
    local dz = loc1.Z - loc2.Z
    return dx * dx + dy * dy + dz * dz < tolerance * tolerance
end

local _GameplayStatics = nil
local _GameplayStaticsTried = false
local function getGameplayStatics()
    if _GameplayStatics then return _GameplayStatics end
    if _GameplayStaticsTried then return nil end
    _GameplayStaticsTried = true
    local ok, mod = pcall(import, "GameplayStatics")
    if ok and mod then _GameplayStatics = mod end
    return _GameplayStatics
end

local _ActorClass = nil
local _ActorTried = false
local function getActorClass()
    if _ActorClass then return _ActorClass end
    if _ActorTried then return nil end
    _ActorTried = true
    local ok, mod = pcall(import, "Actor")
    if ok and mod then _ActorClass = mod end
    return _ActorClass
end

local _UIUtil = nil
local _UIUtilTried = false
local function getUIUtil()
    if _UIUtil then return _UIUtil end
    if _UIUtilTried then return nil end
    _UIUtilTried = true
    local ok, mod = pcall(require, "client.common.ui_util")
    if ok and mod then _UIUtil = mod end
    return _UIUtil
end

local _PlayerTombBox = nil
local _PlayerTombBoxTried = false
local function getPlayerTombBox()
    if _PlayerTombBox then return _PlayerTombBox end
    if _PlayerTombBoxTried then return nil end
    _PlayerTombBoxTried = true
    local ok, mod = pcall(import, "PlayerTombBox")
    if ok and mod then _PlayerTombBox = mod end
    return _PlayerTombBox
end

_G.DeadBox_TemperRequest = function(playerController)
    local playerChar = playerController:GetPlayerCharacterSafety()
    if not playerChar then return end

    local GameplayStatics = getGameplayStatics()
    local Actor          = getActorClass()
    local uiUtil         = getUIUtil()
    local PlayerTombBox  = getPlayerTombBox()
    if not (GameplayStatics and Actor and uiUtil and PlayerTombBox) then return end

    local gameInstance = uiUtil.GetGameInstance()
    if not gameInstance then return end

    local allDeadBoxes = GameplayStatics.GetAllActorsOfClass(
        gameInstance, PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, Actor)
    )

    -- Capped linear scan: keep at most 32 cached location entries
    local skinCacheCount = #_G.DeadBoxSkins
    local scanLimit = skinCacheCount > 32 and (skinCacheCount - 32) or 0

    for _, deadBox in pairs(allDeadBoxes) do
        if slua.isValid(deadBox) then
            local damageCauser = deadBox.DamageCauser
            if damageCauser and damageCauser.Playerkey == playerController.Playerkey then
                local avatarComp = deadBox.DeadBoxAvatarComponent_BP
                if avatarComp and not dbContains(deadBox) then
                    local boxLocation = deadBox:K2_GetActorLocation()
                    local skinApplied = false

                    -- Capped location scan
                    for idx = scanLimit + 1, skinCacheCount do
                        local entry = _G.DeadBoxSkins[idx]
                        if entry and isNearLocation(entry.location, boxLocation, 1.0) then
                            if not _G.skinIdCache[entry.SkinID] then
                                if _G.download_item then pcall(_G.download_item, entry.SkinID) end
                                _G.skinIdCache[entry.SkinID] = true
                            end
                            if avatarComp.ChangeItemAvatar then
                                pcall(function() avatarComp:ChangeItemAvatar(entry.SkinID, false) end)
                            else
                                avatarComp:ResetItemAvatar()
                                avatarComp:PreChangeItemAvatar(entry.SkinID)
                                avatarComp:SyncChangeItemAvatar(entry.SkinID)
                            end
                            dbAdd(deadBox)
                            skinApplied = true
                            break
                        end
                    end

                    if not skinApplied then
                        local skinID = 0
                        local currentVehicle = playerChar.CurrentVehicle
                        if currentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                            skinID = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                        else
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if currentWeapon then
                                local weaponAvatarData = currentWeapon.synData
                                    and currentWeapon.synData:Get(7)
                                if weaponAvatarData and weaponAvatarData.defineID then
                                    skinID = weaponAvatarData.defineID.TypeSpecificID
                                end
                            end
                        end

                        if skinID ~= 0 then
                            if not _G.skinIdCache[skinID] then
                                if _G.download_item then pcall(_G.download_item, skinID) end
                                _G.skinIdCache[skinID] = true
                            end
                            if avatarComp.ChangeItemAvatar then
                                pcall(function() avatarComp:ChangeItemAvatar(skinID, false) end)
                            else
                                avatarComp:ResetItemAvatar()
                                avatarComp:PreChangeItemAvatar(skinID)
                                avatarComp:SyncChangeItemAvatar(skinID)
                            end
                            _G.DeadBoxSkins[#_G.DeadBoxSkins + 1] = { location = boxLocation, SkinID = skinID }
                            skinCacheCount = #_G.DeadBoxSkins
                            dbAdd(deadBox)
                        end
                    end
                end
            end
        end
    end
end

-- ===================================================================
-- SECTION 19: SKIN ANTI-CHEAT BYPASS
-- ===================================================================
_G.InitializeSkinBypass = function()
    pcall(function()
        local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if pufferTlog then
            pufferTlog.ReportEvent         = function() end
            pufferTlog.ReportDownloadResult = function() end
            pufferTlog.ReportODPAKError    = function() end
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar            = function() return true end
        end
        local FileCheckSubsystem = require(
            "GameLua.GameCore.Module.Subsystem.SubsystemMgr"
        ):Get("FileCheckSubsystem")
        if FileCheckSubsystem then
            FileCheckSubsystem.StartCheck        = function() end
            FileCheckSubsystem.ReportAbnormalFile = function() end
        end
        local equipReport = package.loaded[
            "client.slua.logic.report.EquipmentExceptionReport"
        ]
        if equipReport then
            equipReport.Report = function() end
        end
    end)
end

-- ===================================================================
-- SECTION 20: LOBBY / WEAPON-SLOT-UI / VEHICLE-EFFECT HOOKS
-- All one-shot. Identical semantics to skin.lua, just installed once.
-- ===================================================================
function _G.InitializeSkinModSystem()
    -- Hook 1: Lobby Avatar Equipment
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"]
                        or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPuton = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if slotIndex then
                    local currentWeaponSkin = self.GetCurHoldingWeaponSkinID
                        and self:GetCurHoldingWeaponSkinID()
                    if currentWeaponSkin and currentWeaponSkin >= 10000000
                        and _G.VIP_Attachments and _G.VIP_Attachments[currentWeaponSkin]
                    then
                        local replacementID = _G.VIP_Attachments[currentWeaponSkin][slotIndex]
                        if replacementID and replacementID > 0 then
                            if self.HandleDownload then
                                self:HandleDownload(replacementID, nil, nil, false)
                            end
                            itemID = replacementID
                        end
                    end
                end
                if originalPuton then
                    return originalPuton(self, itemID, tAvatarCustom, tExtraData)
                end
            end

            local originalEquipWeapon = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local result
                if originalEquipWeapon then
                    result = originalEquipWeapon(self, resID, isUse, isAsync, SocketName)
                end
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return result
            end
            _G.LobbyBypassHacked = true
        end
    end)

    -- Hook 2: Weapon Slot UI Icons
    pcall(function()
        local CommonItemsUIBP = package.loaded[
            "client.slua.component.item.ItemChildren.Common_Items_UIBP"
        ] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if CommonItemsUIBP and not _G.IconBaloHacked then
            local originalInitView = CommonItemsUIBP.InitView
            CommonItemsUIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displaySkinID = nil
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then
                        displaySkinID = skinID
                    end
                end
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displaySkinID and slotIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    if GameplayData then
                        local playerChar = GameplayData.GetPlayerCharacter()
                        if playerChar and slua.isValid(playerChar) then
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if slua.isValid(currentWeapon) then
                                local weaponID = currentWeapon:GetWeaponID()
                                local weaponSkinID = _G.get_skin_id(weaponID) or weaponID
                                if weaponSkinID >= 10000000
                                    and _G.VIP_Attachments
                                    and _G.VIP_Attachments[weaponSkinID]
                                then
                                    local replacement = _G.VIP_Attachments[weaponSkinID][slotIndex]
                                    if replacement and replacement > 0 then
                                        displaySkinID = replacement
                                    end
                                end
                            end
                        end
                    end
                end
                if displaySkinID then
                    tExtraData.displayResId = displaySkinID
                    if not _G.skinIdCache2[displaySkinID] then
                        if _G.download_item then pcall(_G.download_item, displaySkinID) end
                        _G.skinIdCache2[displaySkinID] = true
                    end
                end
                if originalInitView then
                    return originalInitView(self, nItemId, nCount, nValidTime, tExtraData)
                end
            end
            _G.IconBaloHacked = true
        end
    end)

    -- Hook 3: Vehicle Effects & Lobby Vehicle
    pcall(function()
        local VehiclePlateLicenseUtil = package.loaded[
            "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil"
        ] or require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if VehiclePlateLicenseUtil and not _G.VehicleEffectHacked then
            VehiclePlateLicenseUtil.CheckIsBetterVehicle  = function() return true end
            VehiclePlateLicenseUtil.CheckHasUnLockFeature  = function() return true end
            VehiclePlateLicenseUtil.NeedOpenHighTire       = function() return true end
            local originalGetEffects = VehiclePlateLicenseUtil.GetUpgradeEffectList
            VehiclePlateLicenseUtil.GetUpgradeEffectList = function(UID)
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                local playerChar = GameplayData.GetPlayerCharacter()
                if slua.isValid(playerChar) and playerChar:GetCurrentVehicle() then
                    local vehicle = playerChar:GetCurrentVehicle()
                    local avatarComp = vehicle.VehicleAvatarComponent_BP
                                    or vehicle:GetAvatarComponent()
                    if slua.isValid(avatarComp) then
                        local avatarID = avatarComp.VehicleNetAvatarData
                            and avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
                            or avatarComp:GetCurItemAvatarID()
                        local effectData = CDataTable.GetTableData("BetterVehicleEffect", avatarID)
                        if effectData and effectData.EffectIDList then
                            local result = slua.Array(UEnums.EPropertyClass.Int)
                            for i = 0, effectData.EffectIDList:Num() - 1 do
                                result:Add(effectData.EffectIDList:Get(i))
                            end
                            return result
                        end
                    end
                end
                if originalGetEffects then return originalGetEffects(UID) end
                return nil
            end
            _G.VehicleEffectHacked = true
        end

        local VehicleAvatarComponent = package.loaded[
            "GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent"
        ] or require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        if VehicleAvatarComponent and VehicleAvatarComponent.__inner_impl
            and not _G.VehicleAvatarSwitchHacked
        then
            local impl = VehicleAvatarComponent.__inner_impl
            impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
                return true
            end
            impl.ShowVehicleSwitchEffect = function(self)
                if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                    self.curSwitchEffectId = 7303001
                end
                local owner = self:GetOwner()
                if not slua.isValid(owner) then return false end
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    self.uSwitchEffectActor:K2_DestroyActor()
                    self.uSwitchEffectActor = nil
                end
                if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                    self.lastEquipedAvatarId = owner.ClientUsedAvatarID
                        or owner:GetDefaultAvatarID() or 0
                end
                local newAvatarID = owner.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
                local isLobby = self:IsLobbyActor()
                local world = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
                if not world then return false end
                local VehicleUtil = require(
                    "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil"
                )
                local actorPath = VehicleUtil.GetSwitchEffectActorPath()
                local actorClass = import(actorPath)
                self.uSwitchEffectActor = world:SpawnActor(actorClass, nil, nil, nil)
                if not slua.isValid(self.uSwitchEffectActor) then
                    self.uSwitchEffectActor = nil
                    return false
                end
                self.uSwitchEffectActor:K2_AttachToActor(owner, "None", 1, 1, 1, false)
                self.uSwitchEffectActor:K2_SetActorRelativeLocation(
                    FVector(0, 0, 0), false, nil, false
                )
                self.uSwitchEffectActor:K2_SetActorRelativeRotation(
                    FRotator(0, 0, 0), false, nil, false
                )
                self:ChangeFakeSwitchVehicleAvatar(
                    self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId
                )
                self.uSwitchEffectActor:SetAnimInsAndAnimState(
                    self.uOldVehicleMeshAnimClass, owner
                )
                self.uSwitchEffectActor:StartVehicleSwitchEffect(
                    owner, self.curSwitchEffectId,
                    self.lastEquipedAvatarId, newAvatarID, isLobby
                )
                self.uOldVehicleMeshAnimClass = nil
                return true
            end
            impl.ResetAnimationState = function(self)
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    self.uSwitchEffectActor:K2_DestroyActor()
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                self.curSwitchEffectId = 7303001
            end
            local originalBeginPlay = impl.ReceiveBeginPlay
            impl.ReceiveBeginPlay = function(self)
                if originalBeginPlay then originalBeginPlay(self) end
                self:ResetAnimationState()
            end
            _G.VehicleAvatarSwitchHacked = true
        end

        local LobbyVehicle = package.loaded["client.lobby_ue_object.Actor.LobbyVehicle"]
                          or require("client.lobby_ue_object.Actor.LobbyVehicle")
        if LobbyVehicle and not _G.LobbyVehicleHacked then
            local originalPreChange = LobbyVehicle.PreChangeVehicleAvatar
            LobbyVehicle.PreChangeVehicleAvatar = function(self, InAvatarID, InAdvanceAvatarID)
                local skinID = _G.get_vehicle_skin_id(InAvatarID)
                if skinID and skinID ~= InAvatarID and skinID ~= 0 then
                    if not _G.skinIdCache[skinID] then
                        if _G.download_item then pcall(_G.download_item, skinID) end
                        _G.skinIdCache[skinID] = true
                    end
                    InAvatarID = skinID
                end
                local result = false
                if originalPreChange then
                    result = originalPreChange(self, InAvatarID, InAdvanceAvatarID)
                end
                pcall(function()
                    self.ClientUsedAvatarID = InAvatarID
                    if self.PlayStartUpEffect then self:PlayStartUpEffect() end
                    if self.PlayAccelerateEffect then self:PlayAccelerateEffect() end
                end)
                return result
            end
            _G.LobbyVehicleHacked = true
        end
    end)

    -- ===================================================================
    -- MAIN SKIN APPLICATION LOOP  --  MULTI-RATE
    -- ===================================================================
    if not _G.AKSkinLoopStarted then
        _G.AKSkinLoopStarted = true
        local timeTicker = require("common.time_ticker")

        local _tickerErrorLogged = false

        -- Fast apply ticker (0.4s)
        local function fastApplyLoop()
            pcall(_G.ForceEnableKillCounterUI)
            pcall(_G.RefreshKillCounterUI)
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.equip_character_avatar(playerChar)
                        _G.ApplyWeaponSkins(playerChar)
                        _G.ApplyVehicleSkins(playerChar)
                        _G.HandlePetLogic()
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(0.4, fastApplyLoop)
            elseif not _tickerErrorLogged then
                _tickerErrorLogged = true
            end
        end

        -- Slow scan ticker (2.0s)  --  INI refresh + deadbox scan
        local function slowScanLoop()
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.RefreshConfigIfChanged(false)
                        _G.RefreshAttachmentsIfChanged(false)
                        local PC = GameplayData.GetPlayerController()
                        if slua.isValid(PC) then
                            _G.DeadBox_TemperRequest(PC)
                        end
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(2.0, slowScanLoop)
            end
        end

        -- Slow hook ticker (5.0s)  --  kill counter UI
        local function slowHookLoop()
            pcall(_G.ForceEnableKillCounterUI)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(5.0, slowHookLoop)
            end
        end

        fastApplyLoop()
        slowScanLoop()
        slowHookLoop()
    end
end

-- ===================================================================
-- SECTION 21: INITIALIZATION ENTRY POINT
-- ===================================================================
local function initializeSkinSystem()
    pcall(function()
        if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end
        if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
    end)
end

pcall(function()
    local timeTicker = require("common.time_ticker")
    if timeTicker and timeTicker.AddTimerOnce then
        timeTicker.AddTimerOnce(1.5, initializeSkinSystem)
    else
        initializeSkinSystem()
    end
end)
