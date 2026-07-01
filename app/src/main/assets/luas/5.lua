local require=require;local import=import;local isValid=slua.isValid

local ID={TPF=9999910,FPF=9999911,TPF_SEC=9999912}
local TXT={[ID.TPF]="Camera",[ID.FPF]="FPP",[ID.TPF_SEC]="Display"}

_G._Suk=_G._Suk or {}
local S=_G._Suk
local D={TpFov=85,FpFov=85}
for k,v in pairs(D) do if S[k]==nil then S[k]=v end end

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
    end)
end
Load()
local function Set(k,v)S[k]=v;Save()end

-- Patch built-in config to unlock FOV range
pcall(function()
    local SettingCfg=require("client.logic.setting.setting_config")
    local GraphicSettingDB=require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
    if SettingCfg then
        if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max=140 end
        if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max=140 end
    end
    if GraphicSettingDB then
        if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max=140 end
    end
end)

-- iPad FOV multiplier
local function GetTargetFOV(raw)
    if raw>80 and raw<=90 then return 80+(raw-80)*6 end
    return raw
end

-- Direct FieldOfView force (ipad.lua style)
local function ApplyFOV()
    pcall(function()
        local gd=require("GameLua.GameCore.Data.GameplayData")
        local ch=gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
        if not isValid(ch)then return end
        local tpp=ch.ThirdPersonCameraComponent
        if not isValid(tpp)then return end
        local tp=GetTargetFOV(S.TpFov)
        if not ch.bIsWeaponAiming and tpp.FieldOfView~=tp then
            tpp.FieldOfView=tp
        end
    end)
end

-- Realtime tick
local _fovTick=false
local function StartFOVTick()
    if _fovTick then return end
    _fovTick=true
    local function tick()
        pcall(function()
            local gd=require("GameLua.GameCore.Data.GameplayData")
            local ch=gd and gd.GetPlayerCharacter and gd.GetPlayerCharacter()
            if not isValid(ch)then return end
            local tpp=ch.ThirdPersonCameraComponent
            if not isValid(tpp)then return end
            local tp=GetTargetFOV(S.TpFov)
            if not ch.bIsWeaponAiming and tpp.FieldOfView~=tp then
                tpp.FieldOfView=tp
            end
        end)
    end
    Game:SetTimer(0.5,true,tick)
end
Game:SetTimer(3,false,StartFOVTick)

-- Chain TXT into LocUtil
pcall(function()
    local LU=_G.LocUtil
    if not LU or type(LU.GetLocalizeResStr)~="function"then return end
    local orig=LU.GetLocalizeResStr
    LU.GetLocalizeResStr=function(id)return TXT[id]or orig(id)end
end)

-- Add FOV slider to existing SUKUNA tab stack
local _fovAdded=false
local function AddItems()
    if _fovAdded then return end
    pcall(function()
        local ui=_G.UIManager
        if not ui or not ui.UI_Config then return end
        local C=ui.UI_Config
        local Sl=C.Setting_Option_Slider
        local T=C.Setting_Title
        local Sp=C.Setting_Spacer
        if not Sl then return end
        local ok,SPD=pcall(require,"client.logic.NewSetting.SettingPageDefine")
        if not ok or type(SPD)~="table"or not SPD.Sukuna or not SPD.Sukuna.Stack then return end
        local stack=SPD.Sukuna.Stack
        for _,v in ipairs(stack)do
            if type(v)=="table"and v.Key=="TpFov"then _fovAdded=true;return end
        end
        local function sl_fov(key,tid,mn,mx)
            return{Key=key,Text=tid,UI=Sl,Max=mx,Min=mn,StepSize=1,IsPercent=false,
                    SetFunc=function(k,v)Set(k,v);pcall(ApplyFOV);return true end,
                    GetFunc=function()return S[key]end}
        end
        if Sp then stack[#stack+1]={UI=Sp}end
        if T then stack[#stack+1]={Key="S_CAM",Text=ID.TPF_SEC,UI=T}end
        stack[#stack+1]=sl_fov("TpFov",ID.TPF,70,120)
        _fovAdded=true
    end)
end
Game:SetTimer(2,true,AddItems)

pcall(function()
    local ok,U=pcall(require,"GameLua.Util.UIUtils")
    if ok and U and U.ShowNotice then U:ShowNotice("[IPADVIEW]LOADED")end
end)
