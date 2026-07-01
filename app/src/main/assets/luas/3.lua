--[[
    ANTIBAN_ v2.0 - Comprehensive Anti-Detection Module for optiski.lua
    ===================================================================
    Built by analysing the anti-cheat surface area in ALLLUADEC 4.4/
    and cross-referencing with the reference bypass snippets in
    1.lua / small_ui.lua / small.lua from the kaluaa project.

    DETECTION LAYERS NEUTRALISED  (22 hooks)
    ----------------------------------------
     1.  AvatarExceptionReportSubsystem     (end-of-match BUGgly upload)
     2.  AvatarExceptionSubsystem           (30s tick scanner)
     3.  AvatarExceptionPlayerInst          (per-pawn check)
     4.  GameReportUtils                    (BUGgly gate)
     5.  GameReportSubsystem                (BUGgly backend)
     6.  PufferTlog                         (skin-asset download telemetry)
     7.  EquipmentExceptionReport           (equipment load exception)
     8.  AttachToOtherConfig                (weapon blacklist)
     9.  AvatarUtils                        (native validation)
    10.  ClientToolsReport                  (general telemetry)
    11.  ReportPlatformCrashKit             (custom crash submissions)
    12.  ReportClientPingSystem             (ping-based reporting)
    13.  FileCheckSubsystem                 (file integrity)
    14.  Client.CrashPostException          (native crash bridge)
    15.  BugglyReportRecord                 (frequency gate)
    16.  AvatarFuzzySubsystem               (variant / mismatch check)
    17.  Client.AddAttachFileString         (BUGgly attachment channel)
    18.  HiggsBosonComponent                (master-hack / Hisar / avatar check)
    19.  ClientGlueHiaSystem                (Hit Integrity Analysis)
    20.  SecurityCommonUtils                (replay strategy counters)
    21.  BehaviorScoreSubsystem             (survival-mode scoring)
    22.  NetUtil telemetry C2S packets      (on_crow_update_ntf*, hisar)

    INSTALL
    -------
    Drop into the CHETAN_MODS folder so the injector (LoadAllFeatures)
    picks it up. Rename to load BEFORE optiski.lua (e.g. 0_antiban.lua
    or aa_antiban.lua -- Lua's file order is lexicographic, numeric
    prefix files load first if they are 1..99, and "a" sorts after
    digits in Lua's default alphabetical sort).
]]

if _G._ANTIBAN_INSTALLED then return end

local function safe(fn) pcall(fn) end

-- ===================================================================
-- 1.  AVATAR EXCEPTION REPORT SUBSYSTEM  (end-of-match BUGgly upload)
-- ===================================================================
local function disableAvatarExceptionReport()
    local ok, mod = pcall(require,
        "GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionReport")
    if not ok or not mod then return end
    local impl = mod.__inner_impl
    if not impl then return end

    impl.OnPreBattleResult       = function() end
    impl.OnRecordAvatarException = function() end
    impl.OnAvatarAlarm           = function() end
    impl.OnInit                  = function() end
    impl.OnRelease               = function() end
    impl.ReportExceptionMsgBox   = function() end
    impl.GetAvatarHandlePath     = function() return "" end
    impl.bEnableAvatarExceptionReport = false
end

-- ===================================================================
-- 2.  AVATAR EXCEPTION SUBSYSTEM  (the 30s tick scanner)
-- ===================================================================
local function disableAvatarExceptionSubsystem()
    local ok, mod = pcall(require,
        "GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionSubsystem")
    if not ok or not mod then return end
    local impl = mod.__inner_impl
    if not impl then return end

    impl.OnInit                           = function() end
    impl.OnRelease                        = function() end
    impl.RegisterTickCheckCharacterAvatar = function() end
    impl.TickCheckCharacterAvatar         = function() end
    impl.OnAvatarAllMeshLoaded            = function() end
    impl.OnClickReportCheckAvatar         = function() end
    impl.OnGameModeStateChange            = function() end
    impl.BindPlayerCharacter              = function() end
    impl.UnbindPlayerCharacter            = function() end
    impl.ResetAvatarExceptionCheckCount   = function() end
    impl.ClearAllCheckCharacterTimer      = function() end
    impl.GetPlayerInstData                = function() return nil end
    impl.GetPlayerInstConfig              = function() return nil, nil end
    impl.tPlayerInstMap                   = {}
    impl.tTickPlayerMap                   = {}
    impl.TickCheckTimer                   = nil
end

-- ===================================================================
-- 3.  AVATAR EXCEPTION PLAYER INSTANCE  (per-pawn check)
-- ===================================================================
local function disableAvatarExceptionPlayerInst()
    local ok, mod = pcall(require,
        "GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst")
    if not ok or not mod then return end
    local impl = mod.__inner_impl
    if not impl then return end

    impl.CheckAvatarException        = function() end
    impl.CheckAvatarExceptionOnce    = function() end
    impl.CheckSlotMeshVisible        = function() return false end
    impl.CheckPawnVisible            = function() return false end
    impl.CheckPlayerStateIsValid     = function() return false end
    impl.ReportAvatarException       = function() end
    impl.IsActive                    = function() return false end
    impl.InitCheckCountTable         = function() end
    impl.ClearAllTimer               = function() end
    impl.GetCheckCount               = function() return 0 end
    impl.CheckCanBugglyPostException = function() return false end
    impl._GetAllCountString          = function() return "" end
    impl._GetSlotCountString         = function() return "" end
end

-- ===================================================================
-- 4.  GAME REPORT UTILS  (gates ALL BUGgly posts)
-- ===================================================================
local function disableGameReportUtils()
    local ok, mod = pcall(require,
        "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
    if not ok or not mod then return end

    mod.CheckCanBugglyPostException = function() return false end
    mod.BugglyPostExceptionFull     = function() return false end
    mod.ReplayReportData            = function() return false end
    mod.ReportException             = function() end
end

-- ===================================================================
-- 5.  GAME REPORT SUBSYSTEM  (the underlying backend hook)
-- ===================================================================
local function disableGameReportSubsystem()
    local ok, mod = pcall(require,
        "GameLua.Mod.BaseMod.Client.GameReport.GameReportSubsystem")
    if not ok or not mod then return end
    local impl = mod.__inner_impl
    if not impl then return end

    impl.CheckCanBugglyPostException = function() return false end
    impl.BugglyPostExceptionFull     = function() return false end
    impl.ReplayReportData            = function() return false end
    impl.GetBugglyReportRecord       = function() return nil end
    impl.ConvertToBugglyParam        = function() return nil end
end

-- ===================================================================
-- 6.  PUFFER TLOG  (skin-asset download telemetry)
-- ===================================================================
local function disablePufferTlog()
    local ok, mod = pcall(require,
        "client.slua.logic.download.report.puffer_tlog")
    local PufferTlog = ok and mod or package.loaded["client.slua.logic.download.report.puffer_tlog"]
    if not PufferTlog then return end

    PufferTlog.SendTLog         = function() end
    PufferTlog.ReportEvent      = function() end
    PufferTlog.ReportDownloadResult = function() end
    PufferTlog.ReportODPAKError = function() end

    if PufferTlog.__inner_impl then
        PufferTlog.__inner_impl.SendTLog = function() end
    end
end

-- ===================================================================
-- 7.  EQUIPMENT EXCEPTION REPORT
-- ===================================================================
local function disableEquipmentExceptionReport()
    local ok, mod = pcall(require,
        "client.slua.logic.report.EquipmentExceptionReport")
    local EER = ok and mod or package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
    if not EER then return end

    if type(EER) == "table" then
        EER.Report         = function() end
        EER.ReportException= function() end
        if EER.__inner_impl then
            EER.__inner_impl.Report          = function() end
            EER.__inner_impl.ReportException = function() end
        end
    end
end

-- ===================================================================
-- 8.  ATTACH-TO-OTHER CONFIG  (weapon blacklist check)
-- ===================================================================
local function disableWeaponBlacklist()
    local ok, mod = pcall(require,
        "GameLua.Mod.Library.GamePlay.Weapon.AttachToOtherConfig")
    if not ok or not mod then return end
    local impl = mod.__inner_impl or mod
    impl.CheckIsWeaponInBlackList = function() return false end
end

-- ===================================================================
-- 9.  AVATAR UTILS  (native module validation)
-- ===================================================================
local function disableAvatarUtils()
    local AvUtils = package.loaded["AvatarUtils"]
    if AvUtils and type(AvUtils) == "table" then
        AvUtils.CheckIsWeaponInBlackList = function() return false end
        AvUtils.IsValidAvatar            = function() return true end
    end
    local ok, AvUtils2 = pcall(import, "AvatarUtils")
    if ok and AvUtils2 and type(AvUtils2) == "table" then
        AvUtils2.CheckIsWeaponInBlackList = function() return false end
        AvUtils2.IsValidAvatar            = function() return true end
    end
end

-- ===================================================================
-- 10. CLIENT TOOLS REPORT  (general telemetry)
-- ===================================================================
local function disableClientToolsReport()
    local ok, mod = pcall(require,
        "client.slua.logic.report.ClientToolsReport")
    local CTR = ok and mod or package.loaded["client.slua.logic.report.ClientToolsReport"]
    if not CTR then return end
    if CTR.__inner_impl then
        local i = CTR.__inner_impl
        i.Report  = function() end
        i.Post    = function() end
        i.PostLog = function() end
    end
    if type(CTR) == "table" then
        CTR.Report  = function() end
        CTR.Post    = function() end
        CTR.PostLog = function() end
    end
end

-- ===================================================================
-- 11. REPORT PLATFORM CRASH KIT  (custom crash submissions)
-- ===================================================================
local function disableReportPlatformCrashKit()
    local ok, mod = pcall(require,
        "client.slua.logic.report.ReportPlatformCrashKit")
    local RPCK = ok and mod or package.loaded["client.slua.logic.report.ReportPlatformCrashKit"]
    if not RPCK then return end
    if type(RPCK) == "table" then
        RPCK.ForceSend = function() end
        RPCK.Send      = function() end
        RPCK.Report    = function() end
    end
    if RPCK.__inner_impl then
        local i = RPCK.__inner_impl
        i.ForceSend = function() end
        i.Send      = function() end
        i.Report    = function() end
    end
end

-- ===================================================================
-- 12. REPORT CLIENT PING SYSTEM
-- ===================================================================
local function disableReportPing()
    local ok, mod = pcall(require,
        "client.slua.logic.report.ReportClientPingSystem")
    local RPS = ok and mod or package.loaded["client.slua.logic.report.ReportClientPingSystem"]
    if not RPS then return end
    if type(RPS) == "table" then
        RPS.Report = function() end
        RPS.Send   = function() end
    end
end

-- ===================================================================
-- 13. FILE INTEGRITY SUBSYSTEM
-- ===================================================================
local function disableFileCheck()
    local ok, mgr = pcall(require,
        "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if not ok or not mgr then return end
    local subs = mgr.Get and mgr:Get("FileCheckSubsystem") or nil
    if not subs then return end
    local impl = subs.__inner_impl or subs
    impl.StartCheck         = function() end
    impl.ReportAbnormalFile = function() end
    impl.OnInit             = function() end
    impl.OnRelease          = function() end
    impl.Check              = function() return true end
    impl.OnTick             = function() end
    impl.IsValid            = function() return false end
end

-- ===================================================================
-- 14. CLIENT.CrashPostException  (the native bridge)
-- ===================================================================
local function disableNativeCrash()
    if not Client then return end
    safe(function() Client.CrashPostException    = function() end end)
    safe(function() Client.CrashPostExceptionEx  = function() end end)
    safe(function() Client.PostException         = function() end end)
    safe(function() Client.ReportLog             = function() end end)
end

-- ===================================================================
-- 15. BUGGLY REPORT RECORD  (frequency gate + per-game limit)
-- ===================================================================
local function disableBugglyRecord()
    local ok, cls = pcall(require,
        "GameLua.Mod.BaseMod.Client.BugglyReport.BugglyReportRecord")
    if not ok or not cls then return end
    local impl = cls.__inner_impl or cls
    impl.CheckCanBugglyPostException = function() return false end
    impl.BugglyPostExceptionFull     = function() return false end
    impl.OnPost                      = function() end
    impl.OnSkip                      = function() end
end

-- ===================================================================
-- 16. AVATAR FUZZY SUBSYSTEM  (variant / mismatch check)
-- ===================================================================
local function disableAvatarFuzzy()
    local ok, mod = pcall(require,
        "GameLua.Mod.Library.GamePlay.Avatar.AvatarFuzzySubsystem")
    if not ok or not mod then return end
    local impl = mod.__inner_impl or mod
    impl.OnInit     = function() end
    impl.OnRelease  = function() end
    impl.OnTick     = function() end
    impl.CheckFuzzy = function() return true end
    impl.Report     = function() end
end

-- ===================================================================
-- 17. NATIVE Client.AddAttachFileString  (BUGgly attachment channel)
-- ===================================================================
local function disableAttachString()
    if not Client then return end
    safe(function() Client.AddAttachFileString = function() end end)
    safe(function() Client.CrashPostException  = function() end end)
end

-- ===================================================================
-- 18.  HIGGS BOSON COMPONENT  (anti-cheat core)
--
--  Per-player-controller security component. It runs:
--    * avatar validation (TriggerAvatarCheck / StartAvatarCheck)
--    * weapon skin ID validation (GetCurWeaponSkinID / GetNetAvatarItemIDs)
--    * device fingerprint upload (SendHisarData)
--    * move input / fire-button flow telemetry
--      (SendAntiDataFlow / SendHitFireBtnFlow)
--    * the dev-only alert window (StaticShowSecurityAlertInDev)
--    * replay strategy recording (RecordStrategyTimestampInReplay)
-- ===================================================================
local function disableHiggsBoson()
    local ok, mod = pcall(require,
        "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if not ok or not mod then return end
    local impl = mod.__inner_impl or mod

    -- Skin / avatar validation hooks
    impl.ControlMHActive               = function() return false end
    impl.TriggerAvatarCheck            = function() end
    impl.StartAvatarCheck              = function() end
    impl.GetNetAvatarItemIDs           = function() return {} end
    impl.GetCurWeaponSkinID            = function() return 0 end
    impl.SendHisarData                 = function() end
    impl.OnLogin                       = function() end
    impl.ValidateSecurityData          = function() return true end
    impl.StaticShowSecurityAlertInDev  = function() end
    impl.ShowABCD                      = function() end
    impl._ClientShowSecurityAlertWindow= function() end
    impl._ReportChatRobot              = function() end
    impl._ProcessReportChatRobotQueue  = function() end
    impl.SkipAlertServer               = function() end

    -- Battle telemetry
    impl.SendAntiDataFlow              = function() end
    impl.SendHitFireBtnFlow            = function() end
    impl.OnBattleResult                = function() end
    impl.OnGameModeType                = function() end

    -- Lifecycle / replay recording
    impl.ReceiveBeginPlay                = function() end
    impl.RecordStrategyTimestampInReplay = function() end
    impl.SetClientAlertWindowEnabled     = function() end

    -- Class-level (called as CHiggsBosonComponent.SendHisarData())
    mod.ControlMHActive               = impl.ControlMHActive
    mod.TriggerAvatarCheck            = impl.TriggerAvatarCheck
    mod.StartAvatarCheck              = impl.StartAvatarCheck
    mod.GetNetAvatarItemIDs           = impl.GetNetAvatarItemIDs
    mod.GetCurWeaponSkinID            = impl.GetCurWeaponSkinID
    mod.SendHisarData                 = impl.SendHisarData
    mod.OnLogin                       = impl.OnLogin
    mod.ValidateSecurityData          = impl.ValidateSecurityData
    mod.StaticShowSecurityAlertInDev  = impl.StaticShowSecurityAlertInDev
    mod.SkipAlertServer               = impl.SkipAlertServer

    if _G.DisableHiggsBoson then _G.DisableHiggsBoson = function() end end
end

-- ===================================================================
-- 19.  CLIENT GLUE HIA SYSTEM  (Hit Integrity Analysis)
--
--  Anti-aimbot subsystem. LuaFunc1..LuaFunc9 run per-enemy to validate
--  hit positions against the bone positions the server expects. With
--  VIP skins changing bone scales/positions, this would otherwise flag
--  the player for impossible hits.
-- ===================================================================
local function disableClientGlueHiaSystem()
    local ok, mod = pcall(require,
        "GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem")
    if not ok or not mod then return end
    local impl = mod.__inner_impl or mod

    impl.CheckHitIntegrity = function() return true end
    impl.InitSession       = function() end
    impl.OnBattleEnd       = function() end

    -- Per-enemy check stubs
    for i = 1, 9 do
        impl["LuaFunc" .. i] = function() return true end
    end

    -- Global alias used in some scripts
    if _G.ClientGlueHiaSystem then
        _G.ClientGlueHiaSystem.CheckHitIntegrity = function() return true end
    end
    mod.CheckHitIntegrity = impl.CheckHitIntegrity
end

-- ===================================================================
-- 20.  SECURITY COMMON UTILS  (replay strategy counters)
--
--  ESPTraceCnt, IME focus, gravity anomaly, flying error counters are
--  recorded during a match and replayed to the server. Setting them
--  to 0 prevents the server from ever seeing elevated counts.
-- ===================================================================
local function disableSecurityCommonUtils()
    local ok, mod = pcall(require,
        "GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
    if not ok or not mod then return end

    if mod.EStrategyTypeInReplay then
        mod.EStrategyTypeInReplay.EspTotalSimTraceCnt       = 0
        mod.EStrategyTypeInReplay.EspTotalImeFocusCnt       = 0
        mod.EStrategyTypeInReplay.ClientGravityAnomalyCount = 0
        mod.EStrategyTypeInReplay.FlyingErrorCnt            = 0
    end

    -- The recording API itself -- never let it record anything
    mod.IsStrategyInReplayCount         = function() return false end
    mod.RecordStrategyTimestampInReplay = function() end
    mod.IncrementStrategyCount          = function() end
    mod.GetStrategyCount                = function() return 0 end
    mod.ResetStrategyCount              = function() end

    -- bones.lua imports this for IsHealthStatusAlive
    mod.IsHealthStatusAlive = mod.IsHealthStatusAlive or function(status) return status ~= 2 end
end

-- ===================================================================
-- 21.  BEHAVIOR SCORE SUBSYSTEM  (survival-mode scoring)
-- ===================================================================
local function disableBehaviorScoreSubsystem()
    local ok, mod = pcall(require,
        "GameLua.Mod.Escape.Gameplay.Subsystem.BehaviorScoreSubsystem")
    if not ok or not mod then return end
    local impl = mod.__inner_impl or mod

    impl.OnHandleBehaviorScore     = function() end
    impl.AIPerceptionScore         = function() end
    impl.ReportBehavior            = function() end
    impl.CalcFinalScore            = function() return 0 end
    impl.OnHandleRescued           = function() end
    impl.OnHealthChangedHandler    = function() end
    impl.UpdateBehaviorScore       = function() end
    impl.GetPlayerScoreByPlayerKey = function() return 0 end
    impl.GetCountByBehaviorId      = function() return 0 end
    impl.LoadTable                 = function() end
    impl.OnInit                    = function() end
    impl.OnRelease                 = function() end
end

-- ===================================================================
-- 22.  C2S TELEMETRY CHANNELS  (NetUtil.SendPkg hijack)
--
--  The Higgs Boson component sends recurring C2S packets that are not
--  gated by the BUGgly system at all:
--    on_crow_update_ntf   -- move-input bitmap per match
--    on_crow_update_ntf2  -- move-input angle distribution
--    on_crow_update_ntf3  -- fire-button flow
--    on_crow_update_ntf4/5 -- newer variants
--    hisar                -- device fingerprint on first login
--
--  Hijack NetUtil.SendPkg so these are silently dropped.
-- ===================================================================
local _droppedPkgs = {
    ["on_crow_update_ntf"]  = true,
    ["on_crow_update_ntf2"] = true,
    ["on_crow_update_ntf3"] = true,
    ["on_crow_update_ntf4"] = true,
    ["on_crow_update_ntf5"] = true,
    ["hisar"]               = true,
}

local function disableNetUtilTelemetry()
    local NetUtil = nil
    local ok = pcall(function() NetUtil = require("common.net.net_util") end)
    if not ok or type(NetUtil) ~= "table" then NetUtil = _G.NetUtil end
    if not NetUtil or type(NetUtil) ~= "table" then return end

    if not NetUtil._OrigSendPkg and type(NetUtil.SendPkg) == "function" then
        NetUtil._OrigSendPkg = NetUtil.SendPkg
        NetUtil.SendPkg = function(self, pkgName, ...)
            if type(pkgName) == "string" and _droppedPkgs[pkgName] then
                return nil
            end
            return NetUtil._OrigSendPkg(self, pkgName, ...)
        end
    end
end

-- ===================================================================
-- MASTER INSTALL ROUTINE
-- ===================================================================
local function installAll()
    safe(disableAvatarExceptionReport)
    safe(disableAvatarExceptionSubsystem)
    safe(disableAvatarExceptionPlayerInst)
    safe(disableGameReportUtils)
    safe(disableGameReportSubsystem)
    safe(disablePufferTlog)
    safe(disableEquipmentExceptionReport)
    safe(disableWeaponBlacklist)
    safe(disableAvatarUtils)
    safe(disableClientToolsReport)
    safe(disableReportPlatformCrashKit)
    safe(disableReportPing)
    safe(disableFileCheck)
    safe(disableNativeCrash)
    safe(disableBugglyRecord)
    safe(disableAvatarFuzzy)
    safe(disableAttachString)
    safe(disableHiggsBoson)
    safe(disableClientGlueHiaSystem)
    safe(disableSecurityCommonUtils)
    safe(disableBehaviorScoreSubsystem)
    safe(disableNetUtilTelemetry)
end

-- Run once now (modules that have already loaded will be patched)
installAll()

-- ===================================================================
-- WATCHDOG: re-apply hooks every 3s and on match start
-- ===================================================================
if not _G._ANTIBAN_WATCHDOG_STARTED then
    _G._ANTIBAN_WATCHDOG_STARTED = true
    local ok, timeTicker = pcall(require, "common.time_ticker")
    if ok and timeTicker and timeTicker.AddTimerOnce then
        local function watchdog()
            installAll()
            timeTicker.AddTimerOnce(3.0, watchdog)
        end
        timeTicker.AddTimerOnce(3.0, watchdog)
    end

    -- Re-patch on match start
    pcall(function()
        local CGameState = _G.CGameState
        if CGameState and CGameState.RegisterEvent then
            CGameState:RegisterEvent("OnMatchStart", function()
                installAll()
            end)
        end
    end)

    -- Re-patch right before the original would have reported
    pcall(function()
        local CGameState = _G.CGameState
        if CGameState and CGameState.RegisterEvent then
            CGameState:RegisterEvent("OnPreBattleResult", function()
                installAll()
            end)
        end
    end)
end

_G._ANTIBAN_INSTALLED   = true
_G.ANTIBAN_VERSION      = "2.0"
_G.ANTIBAN_HOOK_COUNT   = 22
_G.ANTIBAN_INSTALLED_AT = os.time and os.time() or 0
print(string.format("[ANTIBAN_] v%s installed (%d hooks active)",
    _G.ANTIBAN_VERSION, _G.ANTIBAN_HOOK_COUNT))
