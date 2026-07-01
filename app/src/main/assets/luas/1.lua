local require=require;local import=import;local isValid=slua.isValid

local ID={TAB=9999991,COLOR=9999992,DST=9999993,HP=9999994,ON=9999995,OFF=9999996,RED=9999981,GREEN=9999982,BLUE=9999983,YELLOW=9999984,WHITE=9999985,
ESP_ON=9999971,WHITE_BODY=9999972,WB_OFFSET=9999973,WB_POWER=9999974,WB_SHADOW=9999975,MAGIC_BULLET=9999976,ESP_WEAPON=9999977,
WPN_SIZE=9999960,WPN_AR=9999961,WPN_SMG=9999962,WPN_SR=9999963,WPN_SG=9999964,WPN_LMG=9999965,WPN_PISTOL=9999966,WPN_MELEE=9999967,
ESP_BOM=9999950,ESP_BOM_ITEM=9999951,ESP_BOM_ACTIVE=9999952}
local TXT={[ID.TAB]="MENU",[ID.COLOR]="ESP COLOR",[ID.DST]="DISTANCE",[ID.HP]="HP",[ID.ON]="ON",[ID.OFF]="OFF",
[ID.RED]="Red",[ID.GREEN]="Green",[ID.BLUE]="Blue",[ID.YELLOW]="Yellow",[ID.WHITE]="White",
[ID.ESP_ON]="ESP MASTER SWITCH",[ID.WHITE_BODY]="WHITE BODY", [ID.WB_OFFSET]="WB Offset", [ID.WB_POWER]="WB Power", [ID.WB_SHADOW]="WB Shadow", [ID.MAGIC_BULLET]="Magic Bullet (%)",
[ID.ESP_WEAPON]="WEAPON ESP",[ID.WPN_SIZE]="Loot Text Size %",[ID.WPN_AR]="AR (Assault Rifles)",[ID.WPN_SMG]="SMG",
[ID.WPN_SR]="Sniper / DMR",[ID.WPN_SG]="Shotgun",[ID.WPN_LMG]="LMG",[ID.WPN_PISTOL]="Pistol",[ID.WPN_MELEE]="Melee / Special",
[ID.ESP_BOM]="GRENADE ESP",[ID.ESP_BOM_ITEM]="Ground Grenades",[ID.ESP_BOM_ACTIVE]="Thrown Grenades"}

_G._Suk=_G._Suk or {}
local S=_G._Suk
local D={Distance=true,HP=true,Color=1,ESP_ON=true,WhiteBody=false,WbOffset=2,WbPower=5,WbShadow=100,MagicBullet=5,ESPWeapon=true,
WpnSize=100,WpnAR=true,WpnSMG=true,WpnSR=true,WpnSG=true,WpnLMG=true,WpnPistol=true,WpnMelee=true,
EspBom=true,EspBomItem=true,EspBomActive=true}
for k,v in pairs(D) do if S[k]==nil then S[k]=v end end
local function SyncGlobals()
    _G._UI_Distance=S.Distance;_G._UI_HP=S.HP;_G._UI_Color=S.Color
    _G._UI_ESP_ON=S.ESP_ON;_G._UI_WhiteBody=S.WhiteBody
    _G._UI_WbOffset=S.WbOffset;_G._UI_WbPower=S.WbPower;_G._UI_WbShadow=S.WbShadow
    _G._UI_MagicBullet=S.MagicBullet
    _G._UI_ESPWeapon=S.ESPWeapon
    _G._UI_WpnSize=S.WpnSize;_G._UI_WpnAR=S.WpnAR;_G._UI_WpnSMG=S.WpnSMG
    _G._UI_WpnSR=S.WpnSR;_G._UI_WpnSG=S.WpnSG;_G._UI_WpnLMG=S.WpnLMG
    _G._UI_WpnPistol=S.WpnPistol;_G._UI_WpnMelee=S.WpnMelee
    _G._UI_EspBom=S.EspBom;_G._UI_EspBomItem=S.EspBomItem;_G._UI_EspBomActive=S.EspBomActive
end
SyncGlobals()

local SP="/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS/sukuna_settings.cfg"
local function Save()
    pcall(function()
        local f=io.open(SP,"w");if not f then return end
        for k,v in pairs(S) do f:write(k.."="..tostring(v).."\n") end;f:close()
    end)
end
local function Load()
    pcall(function()
        local f=io.open(SP,"r");if not f then return end
        for l in (f:read("*a")or""):gmatch("[^\n]+")do
            local k,v=l:match("([^=]+)=(.+)")
            if k and v then
                if v=="true"then S[k]=true elseif v=="false"then S[k]=false
                else S[k]=tonumber(v)or v end
            end
        end;f:close()
    end);SyncGlobals()
end
Load()

local function ApplyWhiteBody()
    if not Client then return end
    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = logic_setting_graphics.GetGameInstance()
        if gi then
            if _G._UI_WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", tostring(_G._UI_WbOffset))
                gi:ExecuteCMD("r.CharacterDiffusePower", tostring(_G._UI_WbPower))
                gi:ExecuteCMD("r.CharacterMinShadowFactor", tostring(_G._UI_WbShadow))
            else
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "0")
            end
        end
    end)
end

local function Set(k,v)
    S[k]=v;SyncGlobals();Save()
    if k:match("Wb") or k == "WhiteBody" then ApplyWhiteBody() end
end

local function PatchLocUtil()
    local LU=_G.LocUtil
    if not LU or type(LU.GetLocalizeResStr)~="function"or LU._S0 then return end
    local orig=LU.GetLocalizeResStr
    LU.GetLocalizeResStr=function(id)return TXT[id]or orig(id)end
    LU._S0=true
end
pcall(PatchLocUtil)

local function BuildItems(C)
    local Sw=C.Setting_Option_Switcher
    local Sl=C.Setting_Option_Slider
    local T=C.Setting_Title
    local Sp=C.Setting_Spacer
    local function tg(key,tid)
        return{Key=key,Text=tid,UI=Sw,SwitcherText={ID.ON,ID.OFF},SwitcherValue={true,false},
                SetFunc=function(k,v)Set(k,v);return true end,GetFunc=function()return S[key]end}
    end
    local function color_tg(key,tid)
        return{Key=key,Text=tid,UI=Sw,SwitcherText={ID.RED,ID.GREEN,ID.BLUE,ID.YELLOW,ID.WHITE},SwitcherValue={1,2,3,4,5},
                SetFunc=function(k,v)Set(k,v);return true end,GetFunc=function()return S[key] or 1 end}
    end
    local function sl_tg(key,tid,mn,mx)
        return{Key=key,Text=tid,UI=Sl,Max=mx,Min=mn,StepSize=1,IsPercent=false,
                SetFunc=function(k,v)Set(k,v);return true end,GetFunc=function()return S[key]end}
    end
    
    local stack = {}
    if T then table.insert(stack, {Key="ESP_T",Text=ID.ESP_ON,UI=T}) end
    table.insert(stack, tg("ESP_ON", ID.ESP_ON))
    table.insert(stack, color_tg("Color",ID.COLOR))
    table.insert(stack, tg("Distance",ID.DST))
    table.insert(stack, tg("HP",ID.HP))
    
    if Sp then table.insert(stack, {UI=Sp}) end
    if T then table.insert(stack, {Key="WB_T",Text=ID.WHITE_BODY,UI=T}) end
    table.insert(stack, tg("WhiteBody", ID.WHITE_BODY))
    table.insert(stack, sl_tg("WbOffset", ID.WB_OFFSET, 0, 20))
    table.insert(stack, sl_tg("WbPower", ID.WB_POWER, 0, 50))
    table.insert(stack, sl_tg("WbShadow", ID.WB_SHADOW, 0, 200))
    
    if Sp then table.insert(stack, {UI=Sp}) end
    if T then table.insert(stack, {Key="MB_T",Text=ID.MAGIC_BULLET,UI=T}) end
    table.insert(stack, sl_tg("MagicBullet", ID.MAGIC_BULLET, 0, 100))
    
    if Sp then table.insert(stack, {UI=Sp}) end
    if T then table.insert(stack, {Key="WPN_T",Text=ID.ESP_WEAPON,UI=T}) end
    table.insert(stack, tg("ESPWeapon", ID.ESP_WEAPON))
    table.insert(stack, sl_tg("WpnSize", ID.WPN_SIZE, 50, 200))
    table.insert(stack, tg("WpnAR", ID.WPN_AR))
    table.insert(stack, tg("WpnSMG", ID.WPN_SMG))
    table.insert(stack, tg("WpnSR", ID.WPN_SR))
    table.insert(stack, tg("WpnSG", ID.WPN_SG))
    table.insert(stack, tg("WpnLMG", ID.WPN_LMG))
    table.insert(stack, tg("WpnPistol", ID.WPN_PISTOL))
    table.insert(stack, tg("WpnMelee", ID.WPN_MELEE))
    
    if Sp then table.insert(stack, {UI=Sp}) end
    if T then table.insert(stack, {Key="BOM_T",Text=ID.ESP_BOM,UI=T}) end
    table.insert(stack, tg("EspBom", ID.ESP_BOM))
    table.insert(stack, tg("EspBomItem", ID.ESP_BOM_ITEM))
    table.insert(stack, tg("EspBomActive", ID.ESP_BOM_ACTIVE))
    
    return stack
end

local CATALOGS={
    "client.logic.NewSetting.SettingCatalog",
    "GameLua.Mod.BaseMod.Client.Config.SettingCatalog",
    "GameLua.Mod.BaseMod.Client.OBUI.SettingCatalog_OB",
}

local function EnsurePage(SPD)
    if SPD.Sukuna and SPD.Sukuna.Stack then return true end
    local ui=_G.UIManager
    if not ui or not ui.UI_Config then return false end
    local items=BuildItems(ui.UI_Config)
    if #items==0 then return false end
    SPD.Sukuna={Key="Sukuna",loc=ID.TAB,UIKey="Setting_StackContainer",Stack=items}
    return true
end

local function Inject()
    pcall(function()
        local ok1,SPD=pcall(require,"client.logic.NewSetting.SettingPageDefine")
        if not ok1 or type(SPD)~="table"then return false end
        if not EnsurePage(SPD)then return false end
        for _,path in ipairs(CATALOGS)do
            local ok2,cat=pcall(require,path)
            if ok2 and type(cat)=="table"and cat[1]then
                local found=false
                for _,p in ipairs(cat)do
                    if type(p)=="table"and p.Key=="Sukuna"then found=true;break end
                end
                if not found then table.insert(cat,1,SPD.Sukuna)end
            end
        end
        
        -- Intercept GetCurrentConfig for dynamically loaded catalogs (In-Game support)
        local GPT = _G.GamePlayTools
        if GPT and type(GPT.GetCurrentConfig) == "function" and not GPT._SukunaMenuHooked then
            local orig = GPT.GetCurrentConfig
            GPT.GetCurrentConfig = function(...)
                local res = orig(...)
                local args = {...}
                if args[1] == "SettingCatalog" and type(res) == "table" then
                    local found = false
                    for _, p in ipairs(res) do
                        if type(p) == "table" and p.Key == "Sukuna" then found = true; break end
                    end
                    if not found and SPD and SPD.Sukuna then
                        table.insert(res, 1, SPD.Sukuna)
                    end
                end
                return res
            end
            GPT._SukunaMenuHooked = true
        end
    end)
end
if _G._SukunaTimer then pcall(function() Game:ClearTimer(_G._SukunaTimer) end) end
_G._SukunaTimer = Game:SetTimer(2, true, Inject)
local function OpenSukunaSettings()
    pcall(function()
        local ui=_G.UIManager
        if not ui or not ui.UI_Config or not ui.UI_Config.setting_main then return end
        local ok1,SPD=pcall(require,"client.logic.NewSetting.SettingPageDefine")
        if ok1 then EnsurePage(SPD)end
        local ok2,cat=pcall(require,"client.logic.NewSetting.SettingCatalog")
        if ok2 and type(cat)=="table"then
            local found=false
            for _,p in ipairs(cat)do
                if type(p)=="table"and p.Key=="Sukuna"then found=true;break end
            end
            if not found and SPD and SPD.Sukuna then table.insert(cat,1,SPD.Sukuna)end
            ui.ShowUI(ui.UI_Config.setting_main,cat,"Sukuna")
        end
    end)
end

-- Chat: hook ChatComponent.AddToArray to detect !menu messages
local _chatBound=false
local function BindChat()
    if _chatBound then return end
    local pc=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not isValid(pc)then Game:SetTimer(3,false,BindChat);return end
    local cc=type(pc.GetChatComponent)=="function"and pc:GetChatComponent()
    if not isValid(cc)then Game:SetTimer(3,false,BindChat);return end
    _chatBound=true
    local orig=cc.AddToArray
    if type(orig)=="function"then
        cc.AddToArray=function(self,...)
            orig(self,...)
            pcall(function()
                local n=self.UITextArray and self.UITextArray:Num()or 0
                if n>0 then
                    local text=self.UITextArray:Get(n-1)
                    if text and type(text)=="string"and text:lower():match("!menu")then
                        OpenSukunaSettings()
                    end
                end
            end)
        end
    end
end
Game:SetTimer(3,false,BindChat)

-- GROK TEAM — Weapon ESP
-- category: "AR"=Assault Rifle, "SMG"=SMG, "SR"=Sniper/DMR, "SG"=Shotgun, "LMG"=LMG, "P"=Pistol, "M"=Melee/Special
local WeaponData = {
    [101001]={n="AKM",c="AR"}, [101003]={n="SCAR-L",c="AR"}, [101004]={n="M416",c="AR"},
    [101006]={n="AUG",c="AR"}, [101007]={n="QBZ",c="AR"}, [101008]={n="M762",c="AR"}, [101102]={n="ACE32",c="AR"},
    [102001]={n="M16A4",c="SMG"}, [102002]={n="UMP45",c="SMG"}, [102003]={n="Vector",c="SMG"},
    [102004]={n="UZI",c="SMG"}, [102005]={n="Bizon",c="SMG"}, [102006]={n="Tommy Gun",c="SMG"},
    [103001]={n="Kar98k",c="SR"}, [103002]={n="M24",c="SR"}, [103003]={n="AWM",c="SR"}, [103004]={n="Win94",c="SR"},
    [103005]={n="SKS",c="SR"}, [103006]={n="Mini14",c="SR"}, [103007]={n="Mk14",c="SR"},
    [103008]={n="SLR",c="SR"}, [103009]={n="QBU",c="SR"}, [103010]={n="VSS",c="SR"}, [103012]={n="AMR",c="SR"},
    [104001]={n="S686",c="SG"}, [104002]={n="S1897",c="SG"}, [104003]={n="S12K",c="SG"}, [104004]={n="DBS",c="SG"},
    [105001]={n="M249",c="LMG"}, [105002]={n="DP-28",c="LMG"}, [105010]={n="MG3",c="LMG"},
    [106001]={n="P18C",c="P"}, [106002]={n="P92",c="P"}, [106003]={n="R1895",c="P"},
    [106004]={n="R45",c="P"}, [106005]={n="Deagle",c="P"}, [106006]={n="Skorpion",c="P"},
    [107001]={n="M79",c="M"}, [108001]={n="Pan",c="M"}, [108002]={n="Katana",c="M"}, [108003]={n="Machete",c="M"},
}
local WpnCatToggle = { AR="WpnAR", SMG="WpnSMG", SR="WpnSR", SG="WpnSG", LMG="WpnLMG", P="WpnPistol", M="WpnMelee" }
local WpnCatColor = {
    AR  = {R=255, G=165, B=0,   A=255}, -- Orange
    SMG = {R=0,   G=220, B=255, A=255}, -- Cyan
    SR  = {R=255, G=50,  B=255, A=255}, -- Magenta
    SG  = {R=0,   G=255, B=80,  A=255}, -- Green
    LMG = {R=255, G=255, B=0,   A=255}, -- Yellow
    P   = {R=200, G=200, B=200, A=255}, -- White/Gray
    M   = {R=255, G=100, B=150, A=255}, -- Pink
}

local function ESPWeaponTick()
    if not _G._UI_ESPWeapon then return end
    local txtScale = 0.12 * ((_G._UI_WpnSize or 100) / 100.0)
    pcall(function()
        local uCon = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not isValid(uCon) then return end
        local curPawn = uCon:GetCurPawn()
        if not isValid(curPawn) then return end
        local myPos; pcall(function() myPos = curPawn:K2_GetActorLocation() end)
        if not myPos then return end
        local HUD = uCon:GetHUD()
        if not isValid(HUD) then return end

        -- Cache pickup scan every 1.5s for FPS
        local curTime = os.clock()
        if not _G._WpnLastScan or (curTime - _G._WpnLastScan) > 1.5 then
            _G._WpnLastScan = curTime
            local world = slua_GameFrontendHUD:GetWorld()
            if not isValid(world) then _G._CachedLootPickups = nil; return end

            local foundPickups = nil
            local classNames = { "PickUpWrapperActor", "PickupWrapperActor" }
            for _, name in ipairs(classNames) do
                pcall(function()
                    local cls = import(name)
                    if cls then
                        local GPS = import("/Script/Engine.GameplayStatics")
                        if GPS then
                            local temp = GPS.GetAllActorsOfClass(world, cls, nil)
                            if temp and temp:Num() > 0 then foundPickups = temp end
                        end
                    end
                end)
                if foundPickups then break end
            end

            -- Build filtered list of weapon pickups only
            local weaponList = {}
            if foundPickups then
                local num = foundPickups:Num()
                for i = 0, num - 1 do
                    local pickup = foundPickups:Get(i)
                    if isValid(pickup) then
                        local itemID = nil
                        pcall(function()
                            if pickup.DefineID then itemID = pickup.DefineID.TypeSpecificID end
                        end)
                        local wd = itemID and WeaponData[itemID]
                        if wd then
                            local catKey = WpnCatToggle[wd.c]
                            if not (catKey and S[catKey] == false) then
                                table.insert(weaponList, {actor=pickup, data=wd})
                            end
                        end
                    end
                end
            end
            _G._CachedLootPickups = weaponList
        end

        -- Draw cached weapons
        local cached = _G._CachedLootPickups
        if not cached then return end
        for _, wp in ipairs(cached) do
            if isValid(wp.actor) then
                local bPos; pcall(function() bPos = wp.actor:K2_GetActorLocation() end)
                if bPos then
                    local dx = bPos.X - myPos.X
                    local dy = bPos.Y - myPos.Y
                    local dz = bPos.Z - myPos.Z
                    local distM = math.floor(math.sqrt(dx*dx + dy*dy + dz*dz) / 100)
                    if distM <= 300 then
                        pcall(function()
                            local clr = WpnCatColor[wp.data.c] or {R=255,G=0,B=0,A=255}
                            local actualScale = 1.5 * ((_G._UI_WpnSize or 100) / 100.0)
                            HUD:AddDebugText(
                                "[" .. wp.data.n .. " " .. distM .. "m]",
                                wp.actor, 0.16,
                                {X=0, Y=0, Z=80}, {X=0, Y=0, Z=80},
                                clr,
                                true, false, true, nil, actualScale, true
                            )
                        end)
                    end
                end
            end
        end
    end)
end

-- GRENADE / BOMB ESP (adapted from Lexus VVIP)
local function ESPBombTick()
    if not _G._UI_EspBom then return end
    if not _G._UI_EspBomItem and not _G._UI_EspBomActive then return end
    pcall(function()
        local uCon = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not isValid(uCon) then return end
        local curPawn = uCon:GetCurPawn()
        if not isValid(curPawn) then return end
        local myPos; pcall(function() myPos = curPawn:K2_GetActorLocation() end)
        if not myPos then return end
        local HUD = uCon:GetHUD()
        if not isValid(HUD) then return end

        -- Cache actor class and statics
        if not _G._BomActorClass then _G._BomActorClass = import("Actor") end
        if not _G._BomGPS then _G._BomGPS = import("GameplayStatics") end
        if not _G._BomActorClass or not _G._BomGPS then return end

        local ui_util = require("client.common.ui_util")
        local gi = ui_util and ui_util.GetGameInstance()
        if not gi then return end

        local curTime = os.clock()

        -- Scan every 2s for performance (Actor base class is HEAVY)
        if not _G._BomLastScan or (curTime - _G._BomLastScan) > 2.0 then
            _G._BomLastScan = curTime
            if not _G._BomArray then _G._BomArray = slua.Array(UEnums.EPropertyClass.Object, _G._BomActorClass) end
            local allActors = _G._BomGPS.GetAllActorsOfClass(gi, _G._BomActorClass, _G._BomArray)

            local activeBombs = {}
            local itemBombs = {}

            if allActors then
                local actorCount = 0
                for _, actor in pairs(allActors) do
                    actorCount = actorCount + 1
                    if actorCount > 1500 then break end
                    if isValid(actor) and not actor.bHidden and not actor.bTearOff then
                        local isPK = false
                        pcall(function() if type(actor.IsPendingKill)=="function" then isPK = actor:IsPendingKill() end end)
                        if not isPK then
                            local nm = string.lower(tostring(actor))
                            local bType = 0
                            if string.find(nm,"m79") or string.find(nm,"launcher") then bType=5
                            elseif string.find(nm,"smoke") then bType=2
                            elseif string.find(nm,"burn") or string.find(nm,"molotov") then bType=3
                            elseif string.find(nm,"flash") or string.find(nm,"stun") then bType=4
                            elseif string.find(nm,"grenade") then bType=1 end

                            if bType > 0 then
                                if string.find(nm,"projectile") or string.find(nm,"thrown") then
                                    table.insert(activeBombs, {act=actor, type=bType})
                                else
                                    local shouldAdd = true
                                    if bType==3 and not (string.find(nm,"pickup") or string.find(nm,"wrapper") or string.find(nm,"weapon")) then
                                        shouldAdd = false
                                    elseif bType==5 then
                                        local ap = nil
                                        pcall(function() if type(actor.GetAttachParentActor)=="function" then ap=actor:GetAttachParentActor() end end)
                                        if isValid(ap) then
                                            local holding=false
                                            pcall(function()
                                                local cw = type(ap.GetCurrentWeapon)=="function" and ap:GetCurrentWeapon() or ap.CurrentWeapon
                                                if cw==actor then holding=true end
                                            end)
                                            if not holding then shouldAdd=false end
                                        end
                                    end
                                    if shouldAdd then table.insert(itemBombs, {act=actor, type=bType}) end
                                end
                            end
                        end
                    end
                end
            end
            _G._CachedActiveBombs = activeBombs
            _G._CachedItemBombs = itemBombs
        end

        local gameTime = 0
        pcall(function() gameTime = _G._BomGPS.GetTimeSeconds(gi) end)

        local function DrawBombs(bombList, isItem, maxDist)
            if not bombList then return end
            for _, item in ipairs(bombList) do
                local bomb = item.act
                local bType = item.type
                if isValid(bomb) and not bomb.bHidden then
                    local bPos; pcall(function() bPos = bomb:K2_GetActorLocation() end)
                    if bPos then
                        local dx = bPos.X - myPos.X
                        local dy = bPos.Y - myPos.Y
                        local dz = bPos.Z - myPos.Z
                        local distM = math.floor(math.sqrt(dx*dx + dy*dy + dz*dz) / 100)
                        if distM > 0 and distM <= maxDist then
                            local displayName = ""
                            local bombColor = {R=255,G=255,B=255,A=255}
                            local zOff = isItem and 15 or 25

                            if bType==1 then displayName="FRAG"; bombColor = isItem and {R=255,G=100,B=100,A=255} or {R=255,G=0,B=0,A=255}
                            elseif bType==2 then displayName="SMOKE"; bombColor = isItem and {R=200,G=200,B=200,A=255} or {R=255,G=255,B=255,A=255}
                            elseif bType==3 then displayName="MOLOTOV"; bombColor = isItem and {R=255,G=160,B=50,A=255} or {R=255,G=100,B=0,A=255}
                            elseif bType==4 then displayName="FLASH"; bombColor = isItem and {R=150,G=255,B=255,A=255} or {R=0,G=255,B=255,A=255}
                            elseif bType==5 then displayName="LAUNCHER"; bombColor = isItem and {R=150,G=255,B=150,A=255} or {R=100,G=255,B=100,A=255}
                            end

                            local text = string.format("%s [%dm]", displayName, distM)
                            local shouldTimer = not isItem

                            if isItem then pcall(function()
                                if bomb.bIsPinPulled or bomb.bPinPulled or (type(bomb.IsPinPulled)=="function" and bomb:IsPinPulled()) then shouldTimer=true end
                            end) end

                            if shouldTimer and gameTime > 0 then
                                local timeLeft = -1
                                pcall(function()
                                    if bomb.ExplosionTime then timeLeft = bomb.ExplosionTime - gameTime
                                    elseif bomb.ExplodeTime then timeLeft = bomb.ExplodeTime - gameTime end
                                end)
                                if timeLeft==-1 or timeLeft>100 then
                                    _G._BomTimers = _G._BomTimers or {}
                                    local bid = tostring(bomb)
                                    if not _G._BomTimers[bid] then _G._BomTimers[bid] = gameTime end
                                    local elapsed = gameTime - _G._BomTimers[bid]
                                    local maxT = (bType==1 and 7) or (bType==2 and 45) or (bType==3 and 12) or (bType==4 and 5) or 45
                                    timeLeft = maxT - elapsed
                                end
                                if timeLeft < 0 then timeLeft = 0 end
                                if timeLeft > 0.1 then text = string.format("%s (%.1fs)", text, timeLeft) end
                            end

                            local dynScale = math.max(0.6, 1.1 - (distM / maxDist))
                            pcall(function()
                                HUD:AddDebugText(text, bomb, 0.16, {X=0,Y=0,Z=zOff}, {X=0,Y=0,Z=zOff}, bombColor, true, false, true, nil, dynScale, true)
                            end)
                        end
                    end
                end
            end
        end

        -- Cleanup old timers every 1s
        if not _G._BomLastClean or (curTime - _G._BomLastClean) > 1.0 then
            _G._BomLastClean = curTime
            pcall(function()
                if _G._BomTimers and gameTime > 0 then
                    for k,v in pairs(_G._BomTimers) do if (gameTime - v) > 60 then _G._BomTimers[k]=nil end end
                end
            end)
        end

        if _G._UI_EspBomItem then DrawBombs(_G._CachedItemBombs, true, 50) end
        if _G._UI_EspBomActive then DrawBombs(_G._CachedActiveBombs, false, 150) end
    end)
end

-- ESP
local SecurityCommonUtils=pcall(require,"GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")and require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
local ASTExtraPC=import("/Script/ShadowTrackerExtra.STExtraPlayerController")
local cachedPawns={};local lastRefresh=0

local function IsAlive(p)
    if not isValid(p)then return false end
    if p.HealthStatus then return SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive(p.HealthStatus)end
    if p.IsAlive then return p:IsAlive()end
    return p.GetHealth and(p:GetHealth()or 0)>0
end

local function TextScale(distM)return 0.16-math.min(distM/400,1)*0.08 end

local function ESPTick()
    if not _G._UI_ESP_ON then return end
    if _G._ESPTimerH and _G._ESPTimerC and not isValid(_G._ESPTimerC)then _G._ESPTimerH=nil;_G._ESPTimerC=nil end
    local uCon=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not(isValid(uCon)and Game:IsClassOf(uCon,ASTExtraPC))then return end
    local curPawn=uCon:GetCurPawn()
    if not isValid(curPawn)then return end
    
    local gd=require("GameLua.GameCore.Data.GameplayData")
    local localChar=gd and type(gd.GetPlayerCharacter)=="function" and gd.GetPlayerCharacter()
    if not isValid(localChar) then localChar=uCon:GetPlayerCharacterSafety() end
    
    -- Strip White Body from Local Player
    if _G._UI_WhiteBody and isValid(localChar) then
        pcall(function()
            local m = localChar.Mesh
            if isValid(m) then
                m:SetScalarParameterValueOnMaterials("DiffusePower", 1.0)
                m:SetScalarParameterValueOnMaterials("DiffuseOffset", 0.0)
                m:SetScalarParameterValueOnMaterials("MinShadowFactor", 0.0)
            end
        end)
    end
    
    local cMap = {
        [1] = {R=255,G=0,B=0,A=255}, -- Red
        [2] = {R=0,G=255,B=0,A=255}, -- Green
        [3] = {R=0,G=100,B=255,A=255}, -- Blue
        [4] = {R=255,G=255,B=0,A=255}, -- Yellow
        [5] = {R=255,G=255,B=255,A=255}, -- White
    }
    local espC = cMap[_G._UI_Color or 1] or cMap[1]

    local myTeamId=0
    pcall(function()
        if isValid(localChar)and localChar.TeamID then myTeamId=localChar.TeamID
        elseif isValid(curPawn)and curPawn.TeamID then myTeamId=curPawn.TeamID end
    end)
    local myPos;pcall(function()myPos=curPawn:K2_GetActorLocation()end)
    if not myPos then return end
    local HUD=uCon:GetHUD()
    local now=os.time()
    if now-lastRefresh>=1 then lastRefresh=now;pcall(function()cachedPawns=Game:GetAllPlayerPawns()or{}end)end
    for _,tPawn in pairs(cachedPawns)do
        if isValid(tPawn)and tPawn~=curPawn and tPawn~=localChar and tPawn.TeamID~=myTeamId then
            if IsAlive(tPawn)then
                local ePos;pcall(function()ePos=tPawn:K2_GetActorLocation()end)
                if ePos then
                    local dx,dy,dz=ePos.X-myPos.X,ePos.Y-myPos.Y,ePos.Z-myPos.Z
                    local dist=math.sqrt(dx*dx+dy*dy+dz*dz)
                    local isBot=false;pcall(function()isBot=Game:IsAI(tPawn)end)
                    if dist<600000 and HUD then
                        local distM=dist/100
                        local hp,maxHp=tPawn.Health,tPawn.HealthMax
                        local isKnock,hpPct=false,0
                        if not hp or not maxHp or maxHp<=0 or hp<=0 then isKnock=true
                        else hpPct=hp/maxHp end
                        local hpC={R=0,G=255,B=0,A=255}
                        if isKnock then hpC={R=255,G=0,B=0,A=255}
                        elseif hpPct<0.3 then hpC={R=255,G=0,B=0,A=255}
                        elseif hpPct<0.7 then hpC={R=255,G=255,B=0,A=255}end
                        local mesh=tPawn.Mesh;local headZ
                        if isValid(mesh)then pcall(function()headZ=mesh:K2_GetBoneLocation("head")end)end
                        local topZ=headZ and(headZ.Z-ePos.Z)or 90
                        local hpOff=topZ+70+math.min(distM,60)*3+math.max(0,distM-60)*0.5
                        local scale=TextScale(distM)
                        local hz=headZ and(headZ.Z-ePos.Z+15)or 105
                        pcall(function()HUD:AddDebugText("\226\151\128",tPawn,scale,{X=0,Y=0,Z=hz},{X=0,Y=0,Z=hz},espC,true,false,true,nil,1.0,true)end)
                        if S.HP~=false then
                            local hpS=isKnock and"\226\150\188"or string.format("[%d/100]",math.max(0,math.min(100,math.floor(hpPct*100+0.5))))
                            pcall(function()HUD:AddDebugText(hpS,tPawn,scale,{X=0,Y=0,Z=hpOff},{X=0,Y=0,Z=hpOff},hpC,true,false,true,nil,1.0,true)end)
                        end
                        if S.Distance~=false then
                            local ls=math.max(30,50*(scale/0.16))
                            local dt=string.format("[%.0fm]",distM)
                            pcall(function()HUD:AddDebugText(dt,tPawn,scale,{X=0,Y=0,Z=hpOff+ls*1.5},{X=0,Y=0,Z=hpOff+ls*1.5},espC,true,false,true,nil,1.0,true)end)
                        end
                    end
                end
            end
        end
    end
end

pcall(function()
    local function StartESP(actor)
        if not isValid(actor)then return end
        cachedPawns={};lastRefresh=0
        _G._ESPTimerC=actor
        _G._ESPTimerH=actor:AddGameTimer(0.15,true,function()
            pcall(ESPTick)
            pcall(ESPWeaponTick)
            pcall(ESPBombTick)
            pcall(function()
                if _G._UI_MagicBullet and _G._UI_MagicBullet > 0 then
                    local pc=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    local cp=pc and pc:GetPlayerCharacterSafety()
                    if isValid(cp) then
                        local w = cp:GetCurrentWeapon()
                        if isValid(w) and w.ShootWeaponEntityComp then
                            w.ShootWeaponEntityComp.GameDeviationFactor = _G._UI_MagicBullet / 100.0
                        end
                    end
                end
            end)
        end)
    end
    local function WD()
        pcall(function()
            local pc=slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            local cp=pc and pc:GetCurPawn()
            if isValid(cp)and _G._ESPTimerC~=cp then
                if _G._ESPTimerH and isValid(_G._ESPTimerC)then pcall(function()_G._ESPTimerC:RemoveGameTimer(_G._ESPTimerH)end)end
                _G._ESPTimerH=nil;StartESP(cp)
            elseif not _G._ESPTimerH then StartESP(cp)end
        end)
    end
    Game:SetTimer(1,true,WD);WD()
end)

pcall(function()
    if not _G._S0_N then _G._S0_N=true
        local ok,U=pcall(require,"GameLua.Util.UIUtils")
        if ok and U and U.ShowNotice then U:ShowNotice("[FINAL_UI]LOADED")end
    end
end)
