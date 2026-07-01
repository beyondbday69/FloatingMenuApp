-- apply_skins.lua — outfits + weapon skins + custom attachments + vehicles
-- For use with CHETAN_MODS loader (runs every 0.5s tick)
if not (_G._CHETAN_SKINS_ENABLED ~= false) then return end

local function DetectBasePath()
    local pkgs = {"com.tencent.ig","com.pubg.imobile","com.pubg.krmobile","com.vng.pubgmobile","com.rekoo.pubg"}
    for _, pkg in ipairs(pkgs) do
        local p = "/storage/emulated/0/Android/data/" .. pkg .. "/files/config.ini"
        local f = io.open(p, "r")
        if f then f:close(); return "/storage/emulated/0/Android/data/" .. pkg .. "/files/" end
    end
    return "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
end

local BASE_PATH = DetectBasePath()
local CONFIG_PATH = BASE_PATH .. "config.ini"
local ATTACH_PATH = BASE_PATH .. "attachments.txt"

-- ============================ GLOBALS ============================
_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.SkinLoadedCache = _G.SkinLoadedCache or {}
_G.LastEquippedOutfits = _G.LastEquippedOutfits or {}
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}
_G.ItemUpgradeSystem = _G.ItemUpgradeSystem or nil
_G.KillData = _G.KillData or { kills = {} }
_G.DeadBoxSkins = _G.DeadBoxSkins or {}
_G.AlreadyChangedSet = _G.AlreadyChangedSet or {}
_G.CurrentEquipVehicleID = _G.CurrentEquipVehicleID or 0

local SAVE_KILL_PATH = BASE_PATH .. "kill_counts.txt"

_G.getKills = _G.getKills or function(weaponID)
    return _G.KillData.kills[weaponID] or 0
end

_G.GunHasCustomSkin = function(weaponID)
    if not weaponID or weaponID == 0 then return false end
    local sid = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    return sid ~= nil and sid > 0
end

_G.AddKill = _G.AddKill or function(weaponID)
    if not weaponID then return end
    _G.KillData.kills[weaponID] = (_G.KillData.kills[weaponID] or 0) + 1
    pcall(function()
        local file = io.open(SAVE_KILL_PATH, "w")
        if file then
            for id, count in pairs(_G.KillData.kills) do
                file:write(string.format("%d:%d\n", id, count))
            end
            file:close()
        end
    end)
end

-- ============================ DOWNLOAD ============================
_G.download_item = _G.download_item or function(i)
    if not i then return end
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PC = require("client.slua.logic.download.puffer_const")
        if PM.GetState(PC.ENUM_DownloadType.ODPAK, {i}) ~= PC.ENUM_DownloadState.Done then
            PM.Download(PC.ENUM_DownloadType.ODPAK, {i})
        end
    end)
end

-- ============================ CONSTANTS ============================
local WEAPON_NAME_TO_ID = {
    AKM = 101001, M16A4 = 101002, SCAR = 101003, ["SCAR-L"] = 101003, M416 = 101004,
    GROZA = 101005, Groza = 101005, AUG = 101006, QBZ = 101007, M762 = 101008,
    MK47 = 101009, G36C = 101010, HoneyBadger = 101012, ASM = 101101, FAMAS = 101100, ACE32 = 101102,
    UZI = 102001, UMP = 102002, UMP45 = 102002, Vector = 102003, Thompson = 102004,
    Bizon = 102005, ["PP-19"] = 102005, PP19 = 102005, ["PP-19 Bizon"] = 102005, ["PP19 Bizon"] = 102005, MP5K = 102007, P90 = 102105,
    Kar98 = 103001, Kar98k = 103001, M24 = 103002, AWM = 103003, SKS = 103004, VSS = 103005,
    Mini14 = 103006, MK14 = 103007, SLR = 103009, QBU = 103010, MK12 = 103100, AMR = 103012, DSR = 103102, Mosin = 103013,
    S12K = 104003, DBS = 104004, S1897 = 104001, S686 = 104002, M1014 = 104005, SPAS12 = 104006,
    M249 = 105001, DP28 = 105002, ["DP-28"] = 105002, DP_28 = 105002, ["DP 28"] = 105002, MG3 = 105010,
    Pan = 108004, Machete = 108001, Crowbar = 108002, Sickle = 108003,
}

-- ====================== CONFIG READER ======================
local function ReadConfig()
    pcall(function()
        local f = io.open(CONFIG_PATH, 'r')
        if not f then return end
        for line in f:read('*all'):gmatch('[^\r\n]+') do
            local k, v = line:match('^([^#=]+)=(.+)$')
            if k and v then
                k = k:gsub('^%s+', ''):gsub('%s+$', '')
                local val = tonumber(v)
                if val then
                    if     k == 'Suit'      then _G.OutfitMap.Suit      = val
                    elseif k == 'Hat'       then _G.OutfitMap.Hat       = val
                    elseif k == 'Mask'      then _G.OutfitMap.Mask      = val
                    elseif k == 'Glasses'   then _G.OutfitMap.Glasses   = val
                    elseif k == 'Pants'     then _G.OutfitMap.Pants     = val
                    elseif k == 'Shoes'     then _G.OutfitMap.Shoes     = val
                    elseif k == 'Bag' or k == 'Backpack' then _G.OutfitMap.Bag = val
                    elseif k == 'Helmet'    then _G.OutfitMap.Helmet    = val
                    elseif k == 'Armor'     then _G.OutfitMap.Armor     = val
                    elseif k == 'Parachute' then _G.OutfitMap.Parachute = val
                    elseif k == 'Pet'       then _G.OutfitMap.Pet       = val
                    elseif WEAPON_NAME_TO_ID[k] then _G.WeaponSkinMap[WEAPON_NAME_TO_ID[k]] = val
                    elseif k == 'Motorcycle_1901001'         then _G.VehicleSkinMap[1901001] = val
                    elseif k == 'Vehicle_1901002'            then _G.VehicleSkinMap[1901002] = val
                    elseif k == 'Sidecar_Motorcycle_1902001' then _G.VehicleSkinMap[1902001] = val
                    elseif k == 'Dacia_1903001'              then _G.VehicleSkinMap[1903001] = val
                    elseif k == 'Dacia_1903002'              then _G.VehicleSkinMap[1903002] = val
                    elseif k == 'Dacia_1903003'              then _G.VehicleSkinMap[1903003] = val
                    elseif k == 'dacia_1903004'              then _G.VehicleSkinMap[1903004] = val
                    elseif k == 'Mini_Bus_1904001'           then _G.VehicleSkinMap[1904001] = val
                    elseif k == 'MiniBus_1904002'            then _G.VehicleSkinMap[1904002] = val
                    elseif k == 'MiniBus_1904003'            then _G.VehicleSkinMap[1904003] = val
                    elseif k == 'Pickup_(Open_Top)_1905001'  then _G.VehicleSkinMap[1905001] = val
                    elseif k == 'Pickup_(Closed_Top)_1906001'then _G.VehicleSkinMap[1906001] = val
                    elseif k == 'PickUp_1906005'             then _G.VehicleSkinMap[1906005] = val
                    elseif k == 'Buggy_1907001'              then _G.VehicleSkinMap[1907001] = val
                    elseif k == 'buggy_1907002'              then _G.VehicleSkinMap[1907002] = val
                    elseif k == 'buggy_1907003'              then _G.VehicleSkinMap[1907003] = val
                    elseif k == 'UAZ_1908001'                then _G.VehicleSkinMap[1908001] = val
                    elseif k == 'UAZ_(Closed_Top)_1909001'   then _G.VehicleSkinMap[1909001] = val
                    elseif k == 'UAZ_(Open_Top)_1910001'     then _G.VehicleSkinMap[1910001] = val
                    elseif k == 'PG-117_1911001'             then _G.VehicleSkinMap[1911001] = val
                    elseif k == 'Jet_Ski_1912001'            then _G.VehicleSkinMap[1912001] = val
                    elseif k == 'Mirado_(Closed_Top)_1914001'then _G.VehicleSkinMap[1914001] = val
                    elseif k == 'Mirado_(Open_Top)_1915001'  then _G.VehicleSkinMap[1915001] = val
                    elseif k == 'Mirado_(Open_Top)_1915004'  then _G.VehicleSkinMap[1915004] = val
                    elseif k == 'Rony_1916001'               then _G.VehicleSkinMap[1916001] = val
                    elseif k == 'Rony_1916002'               then _G.VehicleSkinMap[1916002] = val
                    elseif k == 'Rony_1916003'               then _G.VehicleSkinMap[1916003] = val
                    elseif k == 'Scooter_1917001'            then _G.VehicleSkinMap[1917001] = val
                    elseif k == 'Scooter_1917002'            then _G.VehicleSkinMap[1917002] = val
                    elseif k == 'Snowmobile_1918001'         then _G.VehicleSkinMap[1918001] = val
                    elseif k == 'Tukshai_1919001'            then _G.VehicleSkinMap[1919001] = val
                    elseif k == 'Monster_Truck_1953001'      then _G.VehicleSkinMap[1953001] = val
                    elseif k == 'Monster_Truck_1953002'      then _G.VehicleSkinMap[1953002] = val
                    elseif k == 'Motor_Glider_1960001'       then _G.VehicleSkinMap[1960001] = val
                    elseif k == 'Coupe_RB_1961001'           then _G.VehicleSkinMap[1961001] = val
                    elseif k == 'Tank_1963001'               then _G.VehicleSkinMap[1963001] = val
                    elseif k == 'Mountain_Bike_1965001'      then _G.VehicleSkinMap[1965001] = val
                    elseif k == 'UTV_1966001'                then _G.VehicleSkinMap[1966001] = val
                    elseif k == '2-Seat_Bike_1967001'        then _G.VehicleSkinMap[1967001] = val
                    elseif k == 'Horse_1987001'              then _G.VehicleSkinMap[1987001] = val
                    elseif k == 'Hovercraft_1988001'         then _G.VehicleSkinMap[1988001] = val
                    end
                end
            end
        end
        f:close()
    end)
end

-- ====================== SKIN LOOKUP ======================
_G.get_skin_id = _G.get_skin_id or function(weaponID)
    if not weaponID or weaponID == 0 then return nil end
    local mapped = _G.WeaponSkinMap[weaponID]
    return (mapped and mapped > 0) and mapped or nil
end

-- ====================== ONCE-ONLY HOOKS ======================
if not _G._ApplySkinsHooksInstalled then
    local rawGetTableData = CDataTable.GetTableData
    local rawGetTableByFilter = CDataTable.GetTableByFilter

    -- CDataTable hook
    local _old = CDataTable.GetTableData
    CDataTable.GetTableData = function(tableName, id)
        local numId = tonumber(id)
        if numId then
            local upgradeID = _G.get_skin_id(numId)
            if upgradeID and upgradeID ~= numId then
                if tableName == "WeaponAvatarBattleEffect"
                or tableName == "GoldClothBattleEffect"
                or tableName == "WeaponSkinVoiceCfg"
                or tableName == "AvatarWeaponHitFXData" then
                    return _old(tableName, upgradeID)
                end
            end
        end
        return _old(tableName, id)
    end

    local function InjectWeaponLogicHooks(pawn)
        if not slua.isValid(pawn) then return end
        pcall(function()
            local wm = pawn:GetWeaponManager()
            if not slua.isValid(wm) then return end
            if wm.__WeaponLogicHookInjected then return end
            wm.__WeaponLogicHookInjected = true
            local old_GetEquipID = wm.GetEquipWeaponAvatarID
            if old_GetEquipID then
                wm.GetEquipWeaponAvatarID = function(self, weaponID)
                    local forced = _G.get_skin_id(weaponID)
                    if forced then return forced end
                    return old_GetEquipID(self, weaponID)
                end
            end
            local old_GetWeaponAvatarID = wm.GetWeaponAvatarID
            if old_GetWeaponAvatarID then
                wm.GetWeaponAvatarID = function(self, weapon)
                    if slua.isValid(weapon) then
                        local forced = _G.get_skin_id(weapon:GetWeaponID())
                        if forced then return forced end
                    end
                    return old_GetWeaponAvatarID(self, weapon)
                end
            end
        end)
    end

    local function ForceSyncWeaponSkins(pawn)
        local wm = pawn:GetWeaponManager()
        if not slua.isValid(wm) then return end
        for i = 1, 3 do
            local wpn = wm:GetInventoryWeaponByPropSlot(i)
            if slua.isValid(wpn) then
                local targetID = _G.get_skin_id(wpn:GetWeaponID())
                if targetID and targetID > 0 then
                    pcall(function()
                        if wpn.synData then
                            local data = wpn.synData:Get(7)
                            if data and data.defineID and data.defineID.TypeSpecificID ~= targetID then
                                data.defineID.TypeSpecificID = targetID
                                wpn.synData:Set(7, data)
                                if wpn.OnWeaponSkinUpdate then wpn:OnWeaponSkinUpdate() end
                            end
                        end
                        if wpn.SetWeaponAvatarID then
                            wpn:SetWeaponAvatarID(targetID)
                        end
                    end)
                end
            end
        end
    end

    _G.ApplyWeaponSkins = function(pawn)
        if not slua.isValid(pawn) then return end
        InjectWeaponLogicHooks(pawn)
        ForceSyncWeaponSkins(pawn)
    end

    -- Attachment system init
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
        if IUS then
            IUS:DefineAndResetData(); IUS:OnInitialize()
            _G.ItemUpgradeSystem = IUS
        end
    end)

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
        local cfg = rawGetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
        if cfg then
            for _, info in pairs(cfg) do
                local partId = info.PartId
                if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                    local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                    if switched and switched ~= partId then partId = switched end
                end
                local item = rawGetTableData("Item", partId)
                if item and item.ItemName then _G.g_parts[itemId][item.ItemName] = partId end
            end
        end
        return _G.g_parts
    end

    -- Attachment base IDs
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

    -- attachments.txt parser
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
    local function _parseAttachmentsFile()
        local result = {}
        pcall(function()
            local f = io.open(ATTACH_PATH, "r")
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
        if not _attachFileCache then _attachFileCache = _parseAttachmentsFile() end
        local t = _attachFileCache[skinId]
        if not t then return nil end
        local v = t[key]
        return (v and v > 0) and v or nil
    end
    _G.GetAttachFileCache = function()
        if not _attachFileCache then _G.attachFileCache = _parseAttachmentsFile() end
        return _attachFileCache
    end

    -- Attachment resolvers
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
        local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or _G.GetSlotFromSkinID(avatarid,3) or (auto>0 and auto) or current_id end
        if current_id == _G.scopes.id_reddot then current_id = lookup("RedDot","Red Dot Sight")
        elseif current_id == _G.scopes.id_holo then current_id = lookup("Holo","Holographic Sight")
        elseif current_id == _G.scopes.id_2x then current_id = lookup("Scope2x","2x Scope")
        elseif current_id == _G.scopes.id_3x then current_id = lookup("Scope3x","3x Scope")
        elseif current_id == _G.scopes.id_4x then current_id = lookup("Scope4x","4x Scope")
        elseif current_id == _G.scopes.id_6x then current_id = lookup("Scope6x","6x Scope")
        elseif current_id == _G.scopes.id_8x then current_id = lookup("Scope8x","8x Scope")
        else local fb = _G.GetSlotFromSkinID(avatarid,3); if fb and fb>0 then current_id = fb end end
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

    -- apply_attachment
    _G.apply_attachment = function(CurWeapon, avatarid)
        if not slua.isValid(CurWeapon) or not avatarid then return end
        local array = CurWeapon.synData
        if not slua.isValid(array) then return end

        local changed = false
        for AttachIdx = 0, 4 do
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
                elseif AttachIdx == 4 then
                    Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(itemid, avatarid)
                    array:Set(AttachIdx, Data)
                end
                if isrefresh then
                    changed = true
                end
            end
        end

        if changed then
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
        end
    end

    -- Load kill counts from file
    pcall(function()
        local file = io.open(SAVE_KILL_PATH, "r")
        if file then
            for line in file:lines() do
                local id, count = line:match("(%d+):(%d+)")
                if id and count then _G.KillData.kills[tonumber(id)] = tonumber(count) end
            end
            file:close()
        end
    end)

    _G.RefreshKillCounterUI = function()
        pcall(function()
            local pc = slua_GameFrontendHUD:GetPlayerController()
            if not pc then return end
            local lp = pc:GetPlayerCharacterSafety()
            if not slua.isValid(lp) then return end
            local cw = lp:GetCurrentWeapon()
            if not slua.isValid(cw) then return end
            local wID = cw:GetWeaponID()
            if not wID or wID == 0 then return end
            local sid = _G.get_skin_id(wID)
            if not sid then
                local KillCounterUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                if KillCounterUI and KillCounterUI.__inner_impl then
                    KillCounterUI.__inner_impl:UpdateMainKillCounterUI(false)
                end
                return
            end
            local KillCounterUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
            if KillCounterUI and KillCounterUI.__inner_impl then
                KillCounterUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
            end
            local UIM = require("client.slua_ui_framework.manager")
            local MKC = UIM.GetUI(UIM.UI_Config_InGame.MainKillCounter)
            if MKC and MKC.KillCounterItem then
                MKC:SetKillCounterItemShowWithNum(sid, _G.getKills(wID), sid)
            end
        end)
    end

    _G.ForceEnableKillCounterUI = function()
        if _G.KCUISystemHacked2 and _G.KCLogicHacked2 and _G.KillInfoCounterHacked
           and _G.DeadBoxHacked and _G.WeaponInfoBackpackHacked then
            return
        end
        pcall(function()
            local KillCounterUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                               or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
            if KillCounterUI and KillCounterUI.__inner_impl then
                local ui = KillCounterUI.__inner_impl

                ui.CheckSupportKCUI = function() return true end

                ui.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
                    local pc = slua_GameFrontendHUD:GetPlayerController()
                    local cw = (slua.isValid(Weapon) and Weapon)
                            or (pc and pc:GetPlayerCharacterSafety()
                                    and pc:GetPlayerCharacterSafety():GetCurrentWeapon())
                    if not slua.isValid(cw) then
                        self:UpdateMainKillCounterUI(false)
                        return
                    end
                    local wID = cw:GetWeaponID()
                    if not wID or wID == 0 then
                        self:UpdateMainKillCounterUI(false)
                        return
                    end
                    local sid = _G.get_skin_id(wID)
                    if not sid then
                        self:UpdateMainKillCounterUI(false)
                        return
                    end
                    self:UpdateMainKillCounterUI(true, wID, sid)
                end

                local old_Update = ui.UpdateMainKillCounterUI
                ui.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                    if not bShow then
                        return old_Update(self, false, WeaponID, AvatarID)
                    end
                    local finalAvatar = AvatarID or (WeaponID and _G.get_skin_id(WeaponID)) or WeaponID
                    return old_Update(self, true, WeaponID, finalAvatar)
                end

                _G.KCUISystemHacked2 = true
            end

            local MM = require("client.module_framework.ModuleManager")
            if MM then
                local LogicKC = MM.GetModule(MM.CommonModuleConfig.LogicKillCounter)
                if LogicKC and not _G.KCLogicHacked2 then
                    LogicKC.CheckSupportKC                = function() return true end
                    LogicKC.CheckSupportKillCounterAvatar = function() return true end
                    LogicKC.CheckHasWeaponKillCounter     = function() return true end
                    LogicKC.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                    LogicKC.GetEquipedKillCounterId        = function(self, uid, wid)
                        return _G.GunHasCustomSkin(wid) and 2100004 or nil
                    end
                    LogicKC.GetMyEquipedKillCounterId      = function(self, wid)
                        return _G.GunHasCustomSkin(wid) and 2100004 or nil
                    end
                    LogicKC.GetOneWeaponKillCountInBattle = function(self, uid, wid)
                        return _G.getKills(wid)
                    end
                    LogicKC.GetWeaponKillCountByUid = function(self, uid, wid)
                        return _G.getKills(wid)
                    end
                    _G.KCLogicHacked2 = true
                end
            end

            local KillInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
            local KillInfo = package.loaded[KillInfoPath] or require(KillInfoPath)
            if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
                local old_FileItem = KillInfo.__inner_impl.FileItem
                KillInfo.__inner_impl.FileItem = function(self, DRD)
                    pcall(function()
                        local GD = require("GameLua.GameCore.Data.GameplayData")
                        local lp = GD.GetPlayerCharacter()
                        if slua.isValid(lp) and DRD.Causer == lp:GetPlayerNameSafety() then
                            local cw = lp:GetCurrentWeapon()
                            if slua.isValid(cw) then
                                local wid = cw:GetWeaponID()
                                local sid = _G.get_skin_id(wid)

                                if sid then DRD.CauserWeaponAvatarID = sid end
                                if _G.OutfitMap.Suit then DRD.CauserClothAvatarID = _G.OutfitMap.Suit end
                                DRD.IsUseColor = true
                                DRD.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)

                                local expand_data = DRD.ExpandDataContent
                                if expand_data and sid then
                                    expand_data.KillCounterItemId = sid
                                    expand_data.KillCounterNum = _G.getKills(wid)
                                end

                                if DRD.ResultHealthStatus == 2 and sid then
                                    _G.AddKill(wid)
                                    pcall(function()
                                        local UIM = require("client.slua_ui_framework.manager")
                                        local MKC = UIM.GetUI(UIM.UI_Config_InGame.MainKillCounter)
                                        if MKC and MKC.KillCounterItem then
                                            MKC:SetKillCounterItemShowWithNum(sid, _G.getKills(wid), sid)
                                        end
                                    end)
                                    pcall(function()
                                        local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                                        if KCUI and KCUI.__inner_impl then
                                            KCUI.__inner_impl:CheckNeedMainKillCounterUI(cw, nil)
                                        end
                                    end)
                                end
                            end
                        end
                    end)
                    if old_FileItem then old_FileItem(self, DRD) end
                end
                _G.KillInfoCounterHacked = true
            end
            local ok, CDBF = pcall(require, "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature")
            if ok and CDBF and CDBF.__inner_impl and not _G.DeadBoxHacked then
                local o_CIB = CDBF.__inner_impl.ChangeInfoBgByWeaponAvatarIDLua
                if o_CIB then
                    CDBF.__inner_impl.ChangeInfoBgByWeaponAvatarIDLua = function(self, WeaponAvatarID)
                        local isOurKill = false
                        pcall(function()
                            local pc = slua_GameFrontendHUD:GetPlayerController()
                            if pc and self.Actor and self.Actor.DamageCauser
                            and self.Actor.DamageCauser.PlayerKey == pc.PlayerKey then isOurKill = true end
                        end)
                        if isOurKill then
                            local sid = _G.get_skin_id(WeaponAvatarID)
                            if sid then return o_CIB(self, sid) end
                        end
                        return o_CIB(self, WeaponAvatarID)
                    end
                    _G.DeadBoxHacked = true
                end
            end
            local ok2, WIIB = pcall(require, "GameLua.Mod.BaseMod.Client.Backpack.WeaponInfoItemBase")
            if ok2 and WIIB and WIIB.__inner_impl and not _G.WeaponInfoBackpackHacked then
                local o_UWA = WIIB.__inner_impl.UpdateWeaponAppearanceInfo
                if o_UWA then
                    WIIB.__inner_impl.UpdateWeaponAppearanceInfo = function(self, TypeSpecificID, BattleData, DragOrigin)
                        local rawGetTableData = CDataTable.GetTableData
                        local ItemData = rawGetTableData("Item", TypeSpecificID)
                        if not ItemData then return o_UWA(self, TypeSpecificID, BattleData, DragOrigin) end
                        local skin_id = _G.get_skin_id(TypeSpecificID)
                        if not skin_id or not _G.SkinLoadedCache[skin_id] then
                            return o_UWA(self, TypeSpecificID, BattleData, DragOrigin)
                        end
                        o_UWA(self, skin_id, BattleData, DragOrigin)
                        pcall(function()
                            self.TypeSpecificIDTemp = TypeSpecificID; self.ItemID = TypeSpecificID
                            if self.UIRoot then
                                self.UIRoot.ItemID = TypeSpecificID
                                if self.UIRoot.TextBlock_WeaponName and ItemData.ItemName then
                                    self.UIRoot.TextBlock_WeaponName:SetText(ItemData.ItemName)
                                end
                            end
                            if self.BindWeaponChangeEvent  then self:BindWeaponChangeEvent()  end
                            if self.UpdateBullet           then self:UpdateBullet()           end
                            if self.UpdateWeaponDurability then self:UpdateWeaponDurability() end
                            if self.UpdateWeaponAttachment then self:UpdateWeaponAttachment() end
                        end)
                    end
                    _G.WeaponInfoBackpackHacked = true
                end
            end
        end)
    end

    _G.InstallKillBroadcastSkinHook = function()
        if _G.BattleKillBroadcastSkinHacked then return end
        pcall(function()
            local BKBSS = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
            if not (BKBSS and BKBSS.__inner_impl) then return end
            local o_Copy = BKBSS.__inner_impl.CopyKillOrPutDownMessageDataUserDataToLuaTable
            BKBSS.__inner_impl.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                local msgData = o_Copy(self, messageData)
                pcall(function()
                    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    local character = pc and pc:GetPlayerCharacterSafety()
                    if character and slua.isValid(character) and msgData.bIamCauser and _G.LuaStateWrapper then
                        msgData.bShowBottomBothSidesKillInfo = true
                        local weapon = character:GetCurrentWeapon()
                        if weapon and slua.isValid(weapon) then
                            local weapon_id = weapon:GetItemDefineID() and weapon:GetItemDefineID().TypeSpecificID or 0
                            if weapon_id ~= 0 then
                                local expand_data = slua.LuaArchiverDecode(_G.LuaStateWrapper, msgData.ExpandDataContent) or {}
                                local isClassic = false
                                local uGameState = slua_GameFrontendHUD:GetGameState()
                                if uGameState and slua.isValid(uGameState) then
                                    local EGameModeType = import("EGameModeType")
                                    if uGameState.GameModeType == EGameModeType.ETypicalGameMode then isClassic = true end
                                end
                                local syn_data = weapon.synData
                                if syn_data and slua.isValid(syn_data) then
                                    local define_id = slua.IndexReference(syn_data:Get(7), "defineID")
                                    if define_id and slua.isValid(define_id) then
                                        expand_data.CauserWeaponAvatarID = define_id.TypeSpecificID
                                    end
                                end
                                if _G.AddKill then pcall(_G.AddKill, weapon_id) end
                                expand_data.KillCounterItemId = weapon_id
                                expand_data.KillCounterNum = _G.getKills and _G.getKills(weapon_id) or 0
                                msgData.bShowKillNum = true
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(_G.LuaStateWrapper, expand_data)
                            end
                        end
                    end
                end)
                return msgData
            end
            _G.BattleKillBroadcastSkinHacked = true
        end)
    end

    _G._ApplySkinsHooksInstalled = true
end

-- ======================== VEHICLE SWITCH EFFECT ========================
if not _G.VehicleSwitchEffectHacked then
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        if not (VAC and VAC.__inner_impl) then return end
        local impl = VAC.__inner_impl
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId) return true end
        impl.ShowVehicleSwitchEffect = function(self)
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then self.curSwitchEffectId = 7303001 end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect(); self.uSwitchEffectActor:K2_DestroyActor(); self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or vehicleActor:GetDefaultAvatarID() or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then self.uSwitchEffectActor = nil; return false end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end
        impl.ResetAnimationState = function(self)
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect(); self.uSwitchEffectActor:K2_DestroyActor(); self.uSwitchEffectActor = nil
            end
            self.lastEquipedAvatarId = 0; self.curSwitchEffectId = 7303001
        end
        local O_ReceiveBeginPlay = impl.ReceiveBeginPlay
        impl.ReceiveBeginPlay = function(self)
            if O_ReceiveBeginPlay then O_ReceiveBeginPlay(self) end
            self:ResetAnimationState()
        end
        _G.VehicleSwitchEffectHacked = true
    end)
end

-- ======================== DEADBOX SKIN ========================
if not table.contains then
    function table.contains(t, el)
        for _, v in ipairs(t) do if v == el then return true end end
        return false
    end
end

local function toBattleBoxID(carSkinID) return tostring(carSkinID) .. "1" end

local function locationsClose(loc1, loc2, tolerance)
    local dx = loc1.X - loc2.X; local dy = loc1.Y - loc2.Y; local dz = loc1.Z - loc2.Z
    return dx*dx + dy*dy + dz*dz < tolerance*tolerance
end

local function ApplyDeadBoxSkin()

    local pc = slua_GameFrontendHUD:GetPlayerController()
    if not pc then return end
    local uCharacter = pc:GetPlayerCharacterSafety()
    if not slua.isValid(uCharacter) then return end
    local UGameplayStatics = import("GameplayStatics")
    if not UGameplayStatics then return end
    local uActor = import("Actor")
    if not uActor then return end
    local UIUtil = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
    if not UIUtil then return end
    local uGameInstance = UIUtil.GetGameInstance()
    if not uGameInstance then return end
    local APlayerTombBox = import("PlayerTombBox")
    if not APlayerTombBox then return end
    local uActorArray = UGameplayStatics.GetAllActorsOfClass(
        uGameInstance, APlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, uActor))
    if not uActorArray then return end
    for _, actor in pairs(uActorArray) do
        if slua.isValid(actor) then
            local DamageCauser = actor.DamageCauser
            if DamageCauser and DamageCauser.PlayerKey == pc.PlayerKey then
                local Deadboxavatar = actor.DeadBoxAvatarComponent_BP
                if Deadboxavatar and not table.contains(_G.AlreadyChangedSet, actor) then
                    local actorLocation = actor:K2_GetActorLocation()
                    local found = false
                    for _, entry in pairs(_G.DeadBoxSkins) do
                        if locationsClose(entry.location, actorLocation, 1.0) then
                            Deadboxavatar:ResetItemAvatar()
                            Deadboxavatar:PreChangeItemAvatar(entry.SkinID)
                            Deadboxavatar:SyncChangeItemAvatar(entry.SkinID)
                            table.insert(_G.AlreadyChangedSet, actor); found = true; break
                        end
                    end
                    if not found then
                        local ApplySkinID = 0
                        local CV = uCharacter.CurrentVehicle
                        if CV then
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID ~= 0 then ApplySkinID = toBattleBoxID(carSkinID) end
                        else
                            local cw = uCharacter:GetCurrentWeapon()
                            if cw and cw.synData then
                                ApplySkinID = slua.IndexReference(cw.synData:Get(7), "defineID").TypeSpecificID
                            end
                        end
                        Deadboxavatar:ResetItemAvatar()
                        Deadboxavatar:PreChangeItemAvatar(ApplySkinID)
                        Deadboxavatar:SyncChangeItemAvatar(ApplySkinID)
                        table.insert(_G.DeadBoxSkins, { location = actorLocation, SkinID = ApplySkinID })
                        table.insert(_G.AlreadyChangedSet, actor)
                    end
                end
            end
        end
    end
end
_G.ApplyDeadBoxSkin = ApplyDeadBoxSkin

-- ============================ MAIN: EVERY TICK ============================
ReadConfig()

_G.InstallKillBroadcastSkinHook()
_G.ForceEnableKillCounterUI()

local function SkinTick()
    if not (_G._CHETAN_SKINS_ENABLED ~= false) then return end
    ReadConfig()
    pcall(function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end
        local p = pc:GetPlayerCharacterSafety()
        if not slua.isValid(p) then return end

        if _G.ForceEnableKillCounterUI then pcall(_G.ForceEnableKillCounterUI) end
        if _G.RefreshKillCounterUI then pcall(_G.RefreshKillCounterUI) end

        -- === OUTFITS ===
        pcall(function()
            local BackpackUtils = import("BackpackUtils")
            local ac = p:getAvatarComponent2()
            if not slua.isValid(ac) or not ac.NetAvatarData then return end
            local applyData = ac.NetAvatarData.SlotSyncData
            if slua.isValid(applyData) then
                local ref = false
                for i = 0, applyData:Num() - 1 do
                    local eq = applyData:Get(i)
                    if eq and eq.ItemId ~= 0 then
                        local target = 0
                        if eq.SlotID == 5 and _G.OutfitMap.Suit then target = _G.OutfitMap.Suit
                        elseif eq.SlotID == 8 and _G.OutfitMap.Bag and _G.OutfitMap.Bag ~= 501001 then
                            local level = BackpackUtils and BackpackUtils.GetEquipmentBagLevel(eq.AdditionalItemID) or 1
                            target = _G.OutfitMap.Bag + (level - 1) * 1000
                        elseif eq.SlotID == 9 and _G.OutfitMap.Helmet and _G.OutfitMap.Helmet ~= 502001 then
                            local level = BackpackUtils and BackpackUtils.GetEquipmentHelmetLevel(eq.AdditionalItemID) or 1
                            target = _G.OutfitMap.Helmet + (level - 1) * 1000
                        end
                        if target and target ~= 0 and eq.ItemId ~= target then
                            if not _G.SkinLoadedCache[target] then pcall(_G.download_item, target); _G.SkinLoadedCache[target] = true end
                            eq.ItemId = target; applyData:Set(i, eq); ref = true
                        end
                    end
                end
                if ref and ac.OnRep_BodySlotStateChanged then ac:OnRep_BodySlotStateChanged() end
            end
            local extra_keys = {"Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute"}
            for _, key in ipairs(extra_keys) do
                local id = _G.OutfitMap[key]
                if id and id > 0 and _G.LastEquippedOutfits[key] ~= id then
                    if not _G.SkinLoadedCache[id] then pcall(_G.download_item, id); _G.SkinLoadedCache[id] = true end
                    ac:PutOnCustomEquipmentByID(id, {}); _G.LastEquippedOutfits[key] = id
                end
            end
        end)

        -- === WEAPONS ===
        pcall(function()
            if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(p) end

            local wm = nil
            if p.GetWeaponManager then wm = p:GetWeaponManager() end
            if not slua.isValid(wm) then wm = p.WeaponManagerComponent end
            if not slua.isValid(wm) then wm = p.WeaponManager end
            if slua.isValid(wm) then
                for i = 1, 3 do
                    local wpn = wm:GetInventoryWeaponByPropSlot(i)
                    if slua.isValid(wpn) and slua.isValid(wpn.synData) then
                        local wID = wpn:GetWeaponID()
                        local target = _G.get_skin_id(wID)
                        if target and target ~= wID and target ~= 0 then
                            local d = wpn.synData:Get(7)
                            if d and d.defineID then
                                if wpn._SkinApplied ~= target then
                                    wpn._SkinApplied = target
                                    if not _G.SkinLoadedCache[target] then pcall(_G.download_item, target); _G.SkinLoadedCache[target] = true end
                                    d.defineID.TypeSpecificID = target
                                    wpn.synData:Set(7, d)

                                    if _G.apply_attachment then pcall(_G.apply_attachment, wpn, target) end
                                    if wpn.OnRep_synData then pcall(function() wpn:OnRep_synData() end) end
                                    if wpn.SetWeaponAvatarID then pcall(function() wpn:SetWeaponAvatarID(target) end) end
                                    if wpn.DelayHandleAvatarMeshChanged then pcall(function() wpn:DelayHandleAvatarMeshChanged() end) end
                                end
                            end
                        elseif target and target ~= 0 then
                            if _G.apply_attachment then pcall(_G.apply_attachment, wpn, target) end
                        end
                    end
                end
            end

            local cw = p:GetCurrentWeapon()
            if slua.isValid(cw) then
                local wID = cw:GetWeaponID()
                local target = _G.get_skin_id and _G.get_skin_id(wID)
                if target and target ~= wID and target ~= 0 then
                    local wAvatar = cw.WeaponAvatarComponent_BP or cw.WeaponAvatarComponent or cw.WeaponAvatar
                    if slua.isValid(wAvatar) then
                        if wAvatar.WeaponSkinId ~= target then
                            wAvatar.WeaponSkinId = target
                            if wAvatar.ChangeItemAvatar then pcall(function() wAvatar:ChangeItemAvatar(target, true) end) end
                            if wAvatar.PreChangeItemAvatar then pcall(function() wAvatar:PreChangeItemAvatar(target) end) end
                            if wAvatar.SyncChangeItemAvatar then pcall(function() wAvatar:SyncChangeItemAvatar(target) end) end
                            if wAvatar.RefreshAvatar then pcall(function() wAvatar:RefreshAvatar() end) end
                            if wAvatar.UpdateSkin then pcall(function() wAvatar:UpdateSkin() end) end
                        end
                    end
                    if _G.apply_attachment then pcall(_G.apply_attachment, cw, target) end
                end
            end
        end)

        -- === VEHICLE ===
        pcall(function()
            local CV = p.CurrentVehicle
            if slua.isValid(CV) then
                local VA = CV.VehicleAvatar
                if slua.isValid(VA) then
                    local defId = tostring(VA:GetDefaultAvatarID() or "")
                    local currentId = tostring(CV:GetAvatarId() or "")
                    local vehTarget = 0
                    for baseId, targetSkin in pairs(_G.VehicleSkinMap) do
                        local bStr = tostring(baseId)
                        if defId:find(bStr) or currentId:find(bStr) then vehTarget = targetSkin; break end
                    end
                    if vehTarget == 0 then
                        for baseId, targetSkin in pairs(_G.VehicleSkinMap) do
                            local bShort = tostring(baseId):sub(1, 4)
                            if defId:find(bShort) or currentId:find(bShort) then vehTarget = targetSkin; break end
                        end
                    end
                    if vehTarget and vehTarget > 0 then
                        _G.CurrentEquipVehicleID = vehTarget
                        if currentId ~= tostring(vehTarget) then
                            if not _G.SkinLoadedCache[vehTarget] then pcall(_G.download_item, vehTarget); _G.SkinLoadedCache[vehTarget] = true end
                            VA.curSwitchEffectId = 7303001; VA:ChangeItemAvatar(vehTarget, true)
                        end
                    end
                end
            end
        end)

        -- === PET ===
        if _G.OutfitMap.Pet and _G.OutfitMap.Pet ~= 0 then
            pcall(function()
                if pc.PetComponent and pc.PetComponent.PetId ~= _G.OutfitMap.Pet then
                    pc.PetComponent.PetId = _G.OutfitMap.Pet; pc.PetComponent:OnRep_PetId()
                end
            end)
        end

        -- === DEADBOX ===
        if _G.ApplyDeadBoxSkin then pcall(_G.ApplyDeadBoxSkin) end

    end)
end

local function AttachSkin()
    pcall(function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end
        if pc == _G._SkinPC then return end
        _G._SkinPC = pc
        if pc.AddGameTimer then
            -- Changed from 0.5s to 1.0s to reduce crash risk during active gameplay
            pc:AddGameTimer(1.0, true, SkinTick)

            pc:AddGameTimer(2.0, true, function()
                if not slua.isValid(_G._SkinPC) then
                    _G._SkinPC = nil
                    AttachSkin()
                end
            end)
        end
    end)
end

AttachSkin()