local ModMenu = {}

local MENU_BP = "/Game/UMG/UI_BP/Common/Common_Legal_01_UIBP.Common_Legal_01_UIBP"
local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
local Z_TRIGGER = 9300
local Z_MENU = 9600

ModMenu.menuWidget = nil
ModMenu.triggerWidget = nil
ModMenu.currentPage = 1
ModMenu.loadedButtons = {}

local function log(msg) print("[ModMenu] " .. tostring(msg)) end
local function valid(obj) return obj and (not slua.isValid or slua.isValid(obj)) end

local function later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    local tk = _G.Mytimer_ticker
    if not tk then pcall(function() tk = require("common.time_ticker"); _G.Mytimer_ticker = tk end) end
    if tk and tk.AddTimer then pcall(tk.AddTimer, sec, fn); return end
    local GameThread = import("GameThread")
    if GameThread and GameThread.Delay then pcall(GameThread.Delay, sec, fn); return end
end

local function getLocalChar()
    local ok, ch = pcall(function()
        if not slua_GameFrontendHUD then return nil end
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return nil end
        local func = pc.GetPlayerCharacterSafety or pc.GetPawn
        if func then return func(pc) end
        return nil
    end)
    return ok and ch or nil
end

local function getWeaponComp()
    local char = getLocalChar()
    if not slua.isValid(char) then return nil, nil, nil end
    local WeaponMgr = char.WeaponManagerComponent
    if not slua.isValid(WeaponMgr) then return char, nil, nil end
    local wep = WeaponMgr.CurrentWeaponReplicated
    if not slua.isValid(wep) then return char, WeaponMgr, nil end
    local shootComp = wep.ShootWeaponEntityComp
    return char, WeaponMgr, shootComp
end

local function getConfig()
    _G.LexusConfig = _G.LexusConfig or {
        AimbotLevel = 1,
        AutoAimBone = 1,
        FovValue = 110,
        FOVEnabled = false,
        DisableGrass = false,
        BlackSky = false,
    }
    return _G.LexusConfig
end

local AIMBOT_LEVELS = {"OFF", "LOW", "MEDIUM", "HARD", "EXTREME"}
local AIMBOT_CONFIGS = {
    { S=0, SR=0, RR=0, RRS=0, SRS=0, CSR=0, CR=0, PR=0, DR=0, GDF=0 },
    { S=5, SR=5, RR=1, RRS=1, SRS=5, CSR=3, CR=1, PR=1, DR=0, GDF=0 },
    { S=7, SR=7, RR=2, RRS=2, SRS=7, CSR=5, CR=2, PR=2, DR=0, GDF=0 },
    { S=10, SR=10, RR=10, RRS=10, SRS=10, CSR=7, CR=2, PR=2, DR=0, GDF=0 },
    { S=50, SR=20, RR=20, RRS=20, SRS=20, CSR=15, CR=5, PR=5, DR=0, GDF=0 },
}

local BONE_NAMES = {"Head", "neck_01", "pelvis"}


local function toggleWide()
    _G.WideViewEnabled = not (_G.WideViewEnabled ~= false)
    if _G.ApplyWideView then pcall(_G.ApplyWideView) end
end

local function toggleFog()
    _G.NoFogEnabled = not (_G.NoFogEnabled == true)
    if _G.ApplyNoFog then pcall(_G.ApplyNoFog) end
end

local function toggleGrass()
    local cfg = getConfig()
    cfg.DisableGrass = not cfg.DisableGrass
    pcall(function()
        local sg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = sg.GetGameInstance()
        if gi then
            if cfg.DisableGrass then
                gi:ExecuteCMD("grass.heightScale", "0")
            else
                gi:ExecuteCMD("grass.heightScale", "1")
            end
        end
    end)
    log("Grass: " .. tostring(cfg.DisableGrass))
end

local function toggleBlackSky()
    local cfg = getConfig()
    cfg.BlackSky = not cfg.BlackSky
    pcall(function()
        local sg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = sg.GetGameInstance()
        if gi then
            if cfg.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
            else
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0")
            end
        end
    end)
    log("BlackSky: " .. tostring(cfg.BlackSky))
end



local function toggleSpeed()
    _G.SpeedHackEnabled = not (_G.SpeedHackEnabled == true)
    _G.SpeedHackStealth = true
    if _G.ApplySpeedHack then pcall(_G.ApplySpeedHack) end
end

local function toggleJuleHud()
    _G.JuleHudEnabled = not (_G.JuleHudEnabled == true)
    if _G.JuleHudEnabled then
        pcall(function()
            local tk = _G.Mytimer_ticker
            if not tk then tk = require("common.time_ticker"); _G.Mytimer_ticker = tk end
            if tk and tk.AddTimerLoop then
                tk.AddTimerLoop(3, function()
                    if not _G.JuleHudEnabled then return false end
                    pcall(function()
                        local controller = slua_GameFrontendHUD:GetPlayerController()
                        local STExtra = import("STExtraBlueprintFunctionLibrary")
                        local ping = -1
                        if slua.isValid(controller) then ping = STExtra.GetPlayerPing(controller) end
                        log(string.format("JULE HUD | Ping: %dms", ping))
                    end)
                    return true
                end)
            end
        end)
        log("HUD enabled")
    else
        log("HUD disabled")
    end
end



local function EnsureFPS165()
    pcall(function()
        local sg = require("client.slua.logic.setting.logic_setting_graphics")
        if sg and not sg.__FPS165_P__ then
            sg.__FPS165_P__ = true
            local orig = sg.SetFPS
            sg.SetFPS = function(a, b)
                if orig then orig(a, b) end
                if b == 8 and _G.FPS165Enabled then
                    a:ExecuteCMD("t.MaxFPS", "165")
                    a:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end
        local GSC = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        if GSC and GSC.__inner_impl and not GSC.__inner_impl.__FPS165_P__ then
            local impl = GSC.__inner_impl
            impl.__FPS165_P__ = true
            impl.GetMaxFPSLevel = function()
                if not _G.FPS165Enabled then return 7, 7 end
                return 8, 8
            end
            impl.__OrigInit = impl.InitRealSupportFPS
            impl.InitRealSupportFPS = function(a)
                if not _G.FPS165Enabled then
                    if a.__OrigInit then return a:__OrigInit() end
                    return {}
                end
                local res = {}
                for i = 1, 8 do res[i] = {true, true} end
                pcall(function()
                    local DB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
                    if DB then DB:UpdateUIData(DB.RealSupportFPS, res, false) end
                end)
                return res
            end
        end
    end)
end

local function toggleFPS165()
    _G.FPS165Enabled = not (_G.FPS165Enabled == true)
    log("FPS165: " .. tostring(_G.FPS165Enabled))
    if _G.FPS165Enabled then
        pcall(EnsureFPS165)
        pcall(function()
            local GI = UnrealHelpers.GetGameInstance and UnrealHelpers.GetGameInstance()
            if GI then GI:ExecuteCMD("t.MaxFPS", "165"); GI:ExecuteCMD("r.FrameRateLimit", "165") end
        end)
    else
        pcall(function()
            local GI = UnrealHelpers.GetGameInstance and UnrealHelpers.GetGameInstance()
            if GI then GI:ExecuteCMD("t.MaxFPS", "60"); GI:ExecuteCMD("r.FrameRateLimit", "60") end
        end)
    end
end



local function ApplyFOV()
    local cfg = getConfig()
    local char = getLocalChar()
    if not slua.isValid(char) then return end
    local cam = char.ThirdPersonCameraComponent
    if not slua.isValid(cam) then return end
    if not (char.bIsWeaponAiming or false) then
        cam.FieldOfView = cfg.FovValue
        cam:SetFieldOfView(cfg.FovValue)
    end
    pcall(function()
        local db = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if db and db.TpViewValue then db.TpViewValue.max = cfg.FovValue end
    end)
end

local function cycleFOV()
    local cfg = getConfig()
    local fovs = {80, 90, 100, 110, 120, 130, 140}
    local cur = cfg.FovValue or 110
    for i, v in ipairs(fovs) do
        if v == cur then
            cfg.FovValue = fovs[(i % #fovs) + 1]
            break
        end
    end
    if cfg.FOVEnabled then ApplyFOV() end
    log("FOV value: " .. cfg.FovValue)
end

local function toggleFOV()
    local cfg = getConfig()
    cfg.FOVEnabled = not cfg.FOVEnabled
    log("FOV: " .. tostring(cfg.FOVEnabled) .. " val=" .. tostring(cfg.FovValue))
    if cfg.FOVEnabled then
        ApplyFOV()
        pcall(function()
            local tk = _G.Mytimer_ticker
            if not tk then tk = require("common.time_ticker"); _G.Mytimer_ticker = tk end
            if tk and tk.AddTimerLoop then
                tk.AddTimerLoop(1, function()
                    if not getConfig().FOVEnabled then return false end
                    pcall(ApplyFOV)
                    return true
                end)
            end
        end)
    else
        pcall(function()
            local char = getLocalChar()
            if slua.isValid(char) then
                local cam = char.ThirdPersonCameraComponent
                if slua.isValid(cam) then cam.FieldOfView = 80; cam:SetFieldOfView(80) end
            end
        end)
    end
end



local function ApplyAimbot()
    local cfg = getConfig()
    local level = cfg.AimbotLevel or 1
    local c = AIMBOT_CONFIGS[level]
    if not c then return end

    local _, _, shootComp = getWeaponComp()
    if not slua.isValid(shootComp) then return end

    local aa = shootComp.AutoAimingConfig
    if not aa then return end

    for _, range in ipairs({"OuterRange", "InnerRange"}) do
        local r = aa[range]
        if r then
            r.Speed = c.S; r.SpeedRate = c.SR; r.RangeRate = c.RR
            r.RangeRateSight = c.RRS; r.SpeedRateSight = c.SRS
            r.CenterSpeedRate = c.CSR; r.CrouchRate = c.CR
            r.ProneRate = c.PR; r.DyingRate = c.DR
        end
    end
    shootComp.GameDeviationFactor = c.GDF
end

local function ApplyAutoAimBone()
    local cfg = getConfig()
    local char = getLocalChar()
    if not slua.isValid(char) then return end
    local autoComp = char.AutoAimComp or char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent
    if not slua.isValid(autoComp) then return end
    local bone = BONE_NAMES[cfg.AutoAimBone or 1] or "Head"
    autoComp.Bones = {bone, bone, bone}
    log("AutoAim bone: " .. bone)
end

local function toggleAimbot()
    local cfg = getConfig()
    cfg.AimbotLevel = (cfg.AimbotLevel or 0) + 1
    if cfg.AimbotLevel > 4 then cfg.AimbotLevel = 0 end
    log("Aimbot: " .. AIMBOT_LEVELS[cfg.AimbotLevel + 1])
    if cfg.AimbotLevel > 0 then
        ApplyAimbot()
        pcall(function()
            local tk = _G.Mytimer_ticker
            if not tk then tk = require("common.time_ticker"); _G.Mytimer_ticker = tk end
            if tk and tk.AddTimerLoop then
                tk.AddTimerLoop(2, function()
                    if (getConfig().AimbotLevel or 0) == 0 then return false end
                    pcall(ApplyAimbot)
                    return true
                end)
            end
        end)
    end
end

local function toggleAutoAim()
    local cfg = getConfig()
    cfg.AutoAimBone = (cfg.AutoAimBone or 0) + 1
    if cfg.AutoAimBone > 3 then cfg.AutoAimBone = 1 end
    log("AutoAim: " .. BONE_NAMES[cfg.AutoAimBone])
    ApplyAutoAimBone()
end



local function toggleMetroBox()
    local on = not (_G.MetroEspBox == true)
    _G.MetroEspBox = on
    if _G.MetroEspToggle then pcall(_G.MetroEspToggle, _G.MetroEspBox, _G.MetroEspLoot or false) end
end

local function toggleMetroLoot()
    local on = not (_G.MetroEspLoot == true)
    _G.MetroEspLoot = on
    if _G.MetroEspToggle then pcall(_G.MetroEspToggle, _G.MetroEspBox or false, _G.MetroEspLoot) end
end

local function toggleMetroHideGear()
    _G.MetroHideGear = not (_G.MetroHideGear == true)
    pcall(function()
        if slua_GameFrontendHUD then
            local cfg2 = slua_GameFrontendHUD:GetUserSettings()
            if cfg2 then
                cfg2.LocalHideMetroHelmet = _G.MetroHideGear
                cfg2.LocalHideMetroArmor = _G.MetroHideGear
                cfg2.LocalHideMetroBackpack = _G.MetroHideGear
            end
        end
    end)
end

local function toggleMetroSafeBoxScan()
    pcall(function()
        local UGameplayStatics = import("GameplayStatics")
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local ch = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not ch or not valid(ch) then log("no player"); return end
        local SafeBoxClass = import("/Script/ShadowTrackerExtra.STExtraInteractiveActor")
        local world = ch:GetWorld()
        if not world then log("no world"); return end
        local outArr = slua.Array(UEnums.EPropertyClass.Object, SafeBoxClass)
        local all = UGameplayStatics.GetAllActorsOfClass(world, SafeBoxClass, outArr)
        local open, closed = 0, 0
        if all then
            for i = 0, all:Num() - 1 do
                local a = all:Get(i)
                if a and valid(a) then
                    local ok, opened = pcall(function() return a.bOpened end)
                    if ok then
                        if opened then open = open + 1 else closed = closed + 1 end
                    end
                end
            end
        end
        log(string.format("Chests: %d closed, %d opened", closed, open))
    end)
end

-- ==================== DUMP CACHE & DEBUG TEXT ====================
if not _G._DumpCache then
    _G._DumpCache = {}
    pcall(function()
        local DUMP_PATH="/storage/emulated/0/Android/data/com.pubg.imobile/files/dump_full.txt"
        local f=io.open(DUMP_PATH,"r")
        if f then
            for l in (f:read("*a")or""):gmatch("[^\r\n]+")do
                local id,nm=l:match("^(%d+)%s*|%s*[^|]+%s*|%s*(.+)$")
                if id and nm then _G._DumpCache[tonumber(id)] = nm end
            end
            f:close()
        end
    end)
end

local function ShowSkinName(sname)
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not pc then return end
        local HUD = pc:GetHUD()
        if not HUD then return end
        local gd = require("GameLua.GameCore.Data.GameplayData")
        local ch = gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not valid(ch) then return end
        HUD:AddDebugText(sname, ch, 2.0, {X=0,Y=0,Z=0}, {X=0,Y=0,Z=220}, {R=255,G=255,B=0,A=255}, true, false, true, nil, 2.0, true)
    end)
end

-- ==================== SKIN CYCLING ====================
local SKIN_SLOTS = {"Suit", "Hat", "Mask", "Glasses", "Pants", "Shoes", "Helmet", "Bag", "Parachute"}

local function getSkinList(key)
    local skins = _G.OutfitSkins and _G.OutfitSkins[key == "Parachute" and "Parachut" or key]
    if type(skins) == "table" and #skins > 0 then return skins end
    return nil
end

local function getCurrentSkinIndex(key)
    local skins = getSkinList(key)
    if not skins then return 0, 0 end
    local current = _G.OutfitMap and _G.OutfitMap[key] or 0
    for i, id in ipairs(skins) do
        if id == current then return i, #skins end
    end
    return 1, #skins
end

local function cycleSkin(key)
    local skins = getSkinList(key)
    if not skins then log(key .. ": no skins in INI"); return end
    local idx, total = getCurrentSkinIndex(key)
    idx = idx + 1
    if idx > total then idx = 1 end
    local newId = skins[idx]
    _G.OutfitMap = _G.OutfitMap or {}
    _G.OutfitMap[key] = newId
    if _G.skinIdCache then _G.skinIdCache[newId] = nil end
    local globalKey = key .. "Skin"
    if key == "Parachute" then globalKey = "ParachuteSkin" end
    _G[globalKey] = newId
    log(key .. " -> " .. tostring(newId) .. " (" .. idx .. "/" .. total .. ")")
    local sn = _G._DumpCache[newId]
    if sn then
        ShowSkinName(key .. ": " .. sn)
    else
        ShowSkinName(key .. " [" .. idx .. "/" .. total .. "]")
    end
end

local function skinLabel(key)
    local skins = getSkinList(key)
    if not skins then return key .. " [N/A]" end
    local idx, total = getCurrentSkinIndex(key)
    return key .. " [" .. idx .. "/" .. total .. "]"
end

local skinFeatures = {}
for _, key in ipairs(SKIN_SLOTS) do
    local k = key
    table.insert(skinFeatures, {
        label = function() return skinLabel(k) end,
        action = function() cycleSkin(k) end,
    })
end

-- ==================== GUN SKIN CYCLING ====================
-- Gun definitions: name, category, and all base IDs for that gun
local GUN_DEFS = {
    -- AR
    { name = "AKM",         cat = "AR", ids = {101001, 101901} },
    { name = "M16A4",       cat = "AR", ids = {101002} },
    { name = "SCAR",        cat = "AR", ids = {101003, 101903} },
    { name = "M416",        cat = "AR", ids = {101004} },
    { name = "Groza",       cat = "AR", ids = {101005} },
    { name = "AUG",         cat = "AR", ids = {101006} },
    { name = "QBZ",         cat = "AR", ids = {101007} },
    { name = "M762",        cat = "AR", ids = {101008, 101908} },
    { name = "MK47",        cat = "AR", ids = {101009} },
    { name = "G36C",        cat = "AR", ids = {101010} },
    { name = "HoneyBadger", cat = "AR", ids = {101012} },
    { name = "FAMAS",       cat = "AR", ids = {101100} },
    { name = "ASM",         cat = "AR", ids = {101101} },
    { name = "ACE32",       cat = "AR", ids = {101102} },

    -- SMG
    { name = "UZI",         cat = "SMG", ids = {102001, 102901} },
    { name = "UMP",         cat = "SMG", ids = {102002} },
    { name = "Vector",      cat = "SMG", ids = {102003, 102903} },
    { name = "Thompson",    cat = "SMG", ids = {102004} },
    { name = "Bizon",       cat = "SMG", ids = {102005} },
    { name = "MP5K",        cat = "SMG", ids = {102007} },
    { name = "JS9",         cat = "SMG", ids = {102008} },
    { name = "P90",         cat = "SMG", ids = {102105} },

    -- SR
    { name = "Kar98",       cat = "SR", ids = {103001, 103901} },
    { name = "M24",         cat = "SR", ids = {103002, 103902} },
    { name = "AWM",         cat = "SR", ids = {103003, 103903} },
    { name = "Mosin",       cat = "SR", ids = {103011} },
    { name = "AMR",         cat = "SR", ids = {103012} },
    { name = "DSR",         cat = "SR", ids = {103102} },

    -- DMR
    { name = "SKS",         cat = "DMR", ids = {103004} },
    { name = "VSS",         cat = "DMR", ids = {103005} },
    { name = "Mini14",      cat = "DMR", ids = {103006} },
    { name = "MK14",        cat = "DMR", ids = {103007} },
    { name = "SLR",         cat = "DMR", ids = {103009} },
    { name = "QBU",         cat = "DMR", ids = {103010} },
    { name = "MK12",        cat = "DMR", ids = {103100} },

    -- Shotgun
    { name = "S686",        cat = "Shotgun", ids = {104001} },
    { name = "S1897",       cat = "Shotgun", ids = {104002} },
    { name = "S12K",        cat = "Shotgun", ids = {104003} },
    { name = "DBS",         cat = "Shotgun", ids = {104004} },
    { name = "NS2000",      cat = "Shotgun", ids = {104102} },

    -- LMG
    { name = "M249",        cat = "LMG", ids = {105001} },
    { name = "DP28",        cat = "LMG", ids = {105002} },
    { name = "MG3",         cat = "LMG", ids = {105010} },

    -- Melee
    { name = "Machete",     cat = "Melee", ids = {108001} },
    { name = "Crowbar",     cat = "Melee", ids = {108002} },
    { name = "Sickle",      cat = "Melee", ids = {108003} },
    { name = "Pan",         cat = "Melee", ids = {108004} },
}

-- Build merged skin list per gun (all skins from all base IDs, deduplicated)
local function getGunSkins(def)
    local skins = {}
    local seen = {}
    for _, baseId in ipairs(def.ids) do
        local list = _G.skinIdMappings and _G.skinIdMappings[baseId]
        if list then
            for _, sid in ipairs(list) do
                if not seen[sid] then
                    seen[sid] = true
                    table.insert(skins, sid)
                end
            end
        end
    end
    return skins
end

-- Track current index per gun name
if not _G._GunSkinIdx then _G._GunSkinIdx = {} end

local function cycleGun(def)
    local skins = getGunSkins(def)
    if #skins < 2 then log(def.name .. ": only 1 skin"); return end
    local idx = (_G._GunSkinIdx[def.name] or 1) + 1
    if idx > #skins then idx = 1 end
    _G._GunSkinIdx[def.name] = idx
    local skinId = skins[idx]
    -- Find which base ID owns this skin and set its index
    for _, baseId in ipairs(def.ids) do
        local list = _G.skinIdMappings and _G.skinIdMappings[baseId]
        if list then
            for si, sid in ipairs(list) do
                if sid == skinId then
                    _G.WeaponSkinIndex = _G.WeaponSkinIndex or {}
                    _G.WeaponSkinIndex[baseId] = si
                    if _G._ResolvedWeaponSkins then _G._ResolvedWeaponSkins[baseId] = nil end
                    if _G.skinIdCache2 then _G.skinIdCache2[skinId] = nil end
                end
            end
        end
    end
    log(def.name .. " -> skin " .. idx .. "/" .. #skins .. " (ID:" .. skinId .. ")")
    local sn = _G._DumpCache[skinId]
    if sn then
        ShowSkinName(def.name .. ": " .. sn)
    else
        ShowSkinName(def.name .. " [" .. idx .. "/" .. #skins .. "]")
    end
end

local function gunLabel(def)
    local skins = getGunSkins(def)
    if #skins < 2 then return def.name .. " [1/1]" end
    local idx = _G._GunSkinIdx[def.name] or 1
    return def.name .. " [" .. idx .. "/" .. #skins .. "]"
end

-- Build features per category dynamically
_G.CurrentGunCat = _G.CurrentGunCat or "AR"
local GUN_CATS = {"AR", "SMG", "SR", "DMR", "Shotgun", "LMG", "Melee"}

local function cycleGunCategory()
    for i, c in ipairs(GUN_CATS) do
        if c == _G.CurrentGunCat then
            _G.CurrentGunCat = GUN_CATS[(i % #GUN_CATS) + 1]
            break
        end
    end
end

local pages = {
    { title = "MODS", features = {
        { label = "FPS 165", toggle = toggleFPS165, state = function() return _G.FPS165Enabled == true end },
        { label = "Wide View", toggle = toggleWide, state = function() return _G.WideViewEnabled ~= false end },
        { label = "No Fog", toggle = toggleFog, state = function() return _G.NoFogEnabled == true end },
        { label = "No Grass", toggle = toggleGrass, state = function() return getConfig().DisableGrass == true end },
        { label = "Black Sky", toggle = toggleBlackSky, state = function() return getConfig().BlackSky == true end },
        { label = function() return "FOV [" .. tostring(getConfig().FovValue) .. "]" end,
          toggle = function() cycleFOV(); toggleFOV() end,
          state = function() return getConfig().FOVEnabled == true end },
    }},
    { title = "SKINS", features = skinFeatures },
    { title = "GUNS", features = function()
        local feats = {}
        table.insert(feats, {
            label = function() return ">>> TYPE: " .. _G.CurrentGunCat .. " <<<" end,
            action = cycleGunCategory
        })
        for _, def in ipairs(GUN_DEFS) do
            if def.cat == _G.CurrentGunCat then
                local d = def
                table.insert(feats, {
                    label = function() return gunLabel(d) end,
                    action = function() cycleGun(d) end,
                })
            end
        end
        return feats
    end},
    { title = "METRO", features = {
        { label = "Box ESP", toggle = toggleMetroBox, state = function() return _G.MetroEspBox == true end },
        { label = "Loot ESP", toggle = toggleMetroLoot, state = function() return _G.MetroEspLoot == true end },
        { label = "SafeBox Scan", action = toggleMetroSafeBoxScan },
        { label = "Hide Gear", toggle = toggleMetroHideGear, state = function() return _G.MetroHideGear == true end },
    }},
}

local function getLabel(feat)
    if type(feat.label) == "function" then return feat.label() end
    if feat.state then
        local s = feat.state()
        if s == true then return feat.label .. "  [ON]" end
        if s == false then return feat.label .. "  [OFF]" end
    end
    return feat.label
end

function ModMenu:ClearButtons()
    for _, b in ipairs(self.loadedButtons) do
        pcall(function()
            if valid(b) then b:RemoveFromParent() end
        end)
    end
    self.loadedButtons = {}
end

function ModMenu:BuildButtons(w)
    self:ClearButtons()
    local page = pages[self.currentPage]
    if not page then return end

    local feats = type(page.features) == "function" and page.features() or page.features

    local startY = 150
    local btnH = 46
    local gapY = 8
    local gapX = 300
    
    local useTwoCols = #feats > 7

    for i, feat in ipairs(feats) do
        pcall(function()
            local btn = slua.loadUI(BTN_BP)
            if not btn or not valid(btn) then return end

            btn:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)

            if btn.RichText_Content then
                btn.RichText_Content:SetText(getLabel(feat))
            end

            if btn.Button_Temp and btn.Button_Temp.OnClicked then
                btn.Button_Temp.OnClicked:Add(function()
                    if feat.action then
                        feat.action()
                    elseif feat.toggle then
                        feat.toggle()
                    end
                    later(0.1, function() self:BuildButtons(w) end)
                end)
            end

            pcall(function() require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, Z_MENU + i) end)

            pcall(function()
                local slot = import("WidgetLayoutLibrary").SlotAsCanvasSlot(btn)
                if slot then
                    slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
                    slot:SetAlignment(FVector2D(0.5, 0))
                    
                    local posX = 0
                    local posY = startY + (i - 1) * (btnH + gapY)
                    local btnW = 400
                    
                    if useTwoCols then
                        local col = (i - 1) % 2
                        local row = math.floor((i - 1) / 2)
                        local offsetX = 60
                        posX = offsetX + (col == 0 and (-gapX / 2) or (gapX / 2))
                        posY = startY + row * (btnH + gapY)
                        btnW = gapX - 10
                    end

                    slot:SetPosition(FVector2D(posX, posY))
                    slot:SetSize(FVector2D(btnW, btnH))
                end
            end)

            table.insert(self.loadedButtons, btn)
        end)
    end
end

function ModMenu:UpdateTabs(w)
    local tabNames = {}
    for i, p in ipairs(pages) do tabNames[i] = p.title end
    for i = 1, #pages do
        pcall(function()
            local sw = w["WidgetSwitcher_HighLight_" .. i]
            if sw then
                if i == self.currentPage then sw:SetActiveWidgetIndex(1)
                else sw:SetActiveWidgetIndex(0) end
            end
        end)
        pcall(function()
            local txt = w["TextBlock_Tab_" .. i]
            if txt then txt:SetText(tabNames[i]) end
        end)
    end
end

function ModMenu:Close()
    self:ClearButtons()
    if self.menuWidget and valid(self.menuWidget) then
        pcall(function() self.menuWidget:RemoveFromParent() end)
    end
    self.menuWidget = nil
    log("Closed")
end

function ModMenu:Open()
    if self.menuWidget and valid(self.menuWidget) then return end

    local w = nil
    pcall(function() w = slua.loadUI(MENU_BP) end)
    if not w or not valid(w) then log("ERROR: loadUI MENU_BP failed"); return end

    pcall(function() require("game_frontend_hud").AddToContainer(UIContainers.Top, w, Z_MENU) end)

    pcall(function() if w.HBox_Button then w.HBox_Button:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.TextBlock_tips then w.TextBlock_tips:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.Button_OK then w.Button_OK:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.Button_Cancel then w.Button_Cancel:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.Button_1 then w.Button_1:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.Background_Btn then w.Background_Btn:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    pcall(function() if w.UTRichText_Content then w.UTRichText_Content:SetText("") end end)

    for i = #pages + 1, 8 do
        pcall(function() if w["CanvasPanel_Tab_" .. i] then w["CanvasPanel_Tab_" .. i]:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end end)
    end

    local tabNames = {}
    for i, p in ipairs(pages) do tabNames[i] = p.title end

    for i = 1, #pages do
        pcall(function()
            local tab = w["CanvasPanel_Tab_" .. i]
            if tab then tab:SetWidgetVisibility(UEnums.ESlateVisibility.Visible) end
            local txt = w["TextBlock_Tab_" .. i]
            if txt then txt:SetText(tabNames[i]) end
        end)
        pcall(function()
            local btn = w["Button_Tab_" .. i]
            if btn then
                if btn.OnClicked then btn.OnClicked:Clear() end
                if btn.OnClicked then
                    local idx = i
                    btn.OnClicked:Add(function()
                        self.currentPage = idx
                        self:BuildButtons(w)
                        self:UpdateTabs(w)
                    end)
                end
            end
        end)
    end

    pcall(function()
        local popup = w.Common_Popup_Large_UIBP
        if popup and valid(popup) and popup.close and valid(popup.close) then
            if popup.close.OnClicked then popup.close.OnClicked:Clear() end
            if popup.close.OnClicked then
                popup.close.OnClicked:Add(function() self:Close() end)
            end
        end
    end)

    self.currentPage = 1
    self:BuildButtons(w)
    self:UpdateTabs(w)
    self.menuWidget = w
    log("Opened")
end

function ModMenu:Toggle()
    if self.menuWidget and valid(self.menuWidget) then self:Close()
    else self:Open() end
end

function ModMenu:EnsureTrigger()
    if self.triggerWidget and valid(self.triggerWidget) then return end

    local tw = nil
    pcall(function() tw = slua.loadUI(BTN_BP) end)
    if tw and valid(tw) then
        pcall(function() require("game_frontend_hud").AddToContainer(UIContainers.Top, tw, Z_TRIGGER) end)

        pcall(function()
            if tw.RichText_Content then
                local f = tw.RichText_Content.Font
                f.Size = 14
                tw.RichText_Content:SetFont(f)
                tw.RichText_Content:SetText("MOD")
            end
        end)

        pcall(function()
            if tw.Button_Temp and tw.Button_Temp.OnClicked then
                tw.Button_Temp.OnClicked:Add(function() self:Toggle() end)
            end
        end)

        pcall(function()
            local slot = import("WidgetLayoutLibrary").SlotAsCanvasSlot(tw)
            if slot then
                slot:SetAnchors(FAnchors(1, 0, 1, 0))
                slot:SetAlignment(FVector2D(1, 0))
                slot:SetPosition(FVector2D(-16, 72))
                slot:SetSize(FVector2D(72, 44))
            end
            tw:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)

        self.triggerWidget = tw
    end
end



_G.ModMenuOpen = function() ModMenu:Open() end
_G.ModMenuClose = function() ModMenu:Close() end
_G.ModMenuToggle = function() ModMenu:Toggle() end
_G.EnsureFPS165 = EnsureFPS165
_G.getConfig = getConfig

later(3, function() ModMenu:EnsureTrigger() end)
later(10, function() ModMenu:EnsureTrigger() end)

local tk = _G.Mytimer_ticker
if not tk then pcall(function() tk = require("common.time_ticker"); _G.Mytimer_ticker = tk end) end
if tk and tk.AddTimerLoop then
    tk.AddTimerLoop(20, function() ModMenu:EnsureTrigger() end, -1, 20)
end
