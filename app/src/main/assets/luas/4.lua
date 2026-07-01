-- Per-match guard: allow re-init when the player controller changes (new match)
do
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if _G._AKMODVIP_LOADED and _G._AKMODVIP_PC == pc then return end
    _G._AKMODVIP_LOADED = true
    _G._AKMODVIP_PC = pc
end

-- Popup: only pop in first match of the user
if not _G._SumitBypassPopupShown then
  _G._SumitBypassPopupShown = true
  pcall(function()
    local Msg = package.loaded['client.slua.logic.common.logic_common_msg_box']
    if not Msg then pcall(function() Msg = require('client.slua.logic.common.logic_common_msg_box') end) end
    if Msg and Msg.Show then
      Msg.Show(4, 'SUMIT MODS', 'sumit bypass activated')
    end
  end)
end

function _G.InitializeSkinBypass()
    pcall(function()
        
        local lIIl11llI11ll = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if lIIl11llI11ll then
            lIIl11llI11ll.ReportEvent = function() end
            lIIl11llI11ll.ReportDownloadResult = function() end
            lIIl11llI11ll.ReportODPAKError = function() end
        end

        
        local l1l1I1Il111Il = package.loaded["AvatarUtils"]
        if l1l1I1Il111Il then
            l1l1I1Il111Il.CheckIsWeaponInBlackList = function() return false end
            l1l1I1Il111Il.IsValidAvatar = function() return true end
        end

        
        local lIlIIlIlIIIll = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if lIlIIlIlIIIll then
            lIlIIlIlIIIll.StartCheck = function() end
            lIlIIlIlIIIll.ReportAbnormalFile = function() end
        end
        
        
        local lI11Il1lll11I = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if lI11Il1lll11I then
            lI11Il1lll11I.Report = function() end
        end
    end)
    print('[SkinBypass] Resource & Skin Scanners Bypassed!')
end




function _G.InitializeLogBlocker()
    print('[LogBlocker] Initializing Ultimate Log/Crash/Screenshot Blocker V11...')
    pcall(function()
        local lllI1lllllllI = import("ScreenshotMaker")
        if lllI1lllllllI then
            lllI1lllllllI.MakePicture = function() return "" end
            lllI1lllllllI.ReMakePicture = function() return "" end
            lllI1lllllllI.HasCaptured = function() return true end
        end

        local lIIllIlII1llI = package.loaded["TLog"] or _G.TLog
        if lIIllIlII1llI then
            lIIllIlII1llI.Info = function() end; lIIllIlII1llI.Warning = function() end
            lIIllIlII1llI.Error = function() end; lIIllIlII1llI.Debug = function() end; lIIllIlII1llI.Report = function() end
        end

        local lII1II1IIIll1 = package.loaded["CrashSight"] or _G.CrashSight
        if lII1II1IIIll1 then
            lII1II1IIIll1.ReportException = function() end
            lII1II1IIIll1.SetCustomData = function() end; lII1II1IIIll1.Log = function() end
        end
        
        local lIll1II1Ill1I = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if lIll1II1Ill1I then
            lIll1II1Ill1I.BugglyPostExceptionFull = function() return false end
            lIll1II1Ill1I.CheckCanBugglyPostException = function() return false end
            lIll1II1Ill1I.ReplayReportData = function() end
            lIll1II1Ill1I.ReportGameException = function() end
        end

        local lIIlIIII1l1I1 = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if lIIlIIII1l1I1 then
            lIIlIIII1l1I1.SendReport = function() end; lIIlIIII1l1I1.SendException = function() end
        end

        local lIIl11ll111II = package.loaded["client.slua.config.tlog.tlog_report_utils"]
        if lIIl11ll111II then
            lIIl11ll111II.ReportTLogEvent = function() end
        end

        local lllllII1l1IIl = package.loaded["client.slua.logic.ugc.UGCNewTLogReport"] or package.loaded["client.slua.data.BasicData.BasicDataTLogReport"]
        if lllllII1l1IIl then
            lllllII1l1IIl.SendExposeReq = function() end
            lllllII1l1IIl.SendInteractionReq = function() end
            lllllII1l1IIl.TLogReport = function() end
        end
        
        local lIIlIlII11I1I = package.loaded["client.slua.logic.ugc.logic_ugc_tlog"]
        if lIIlIlII11I1I then
            lIIlIlII11I1I.SendModTLog = function() end
            lIIlIlII11I1I.ReportStay = function() end
        end

        local lllI1lII11I11 = package.loaded["GameLua.Mod.BaseMod.Client.ClientTLog.ClientTLogUtil"]
        if lllI1lII11I11 then
            lllI1lII11I11.ReportGeneralCountByBRPhase = function() end
            lllI1lII11I11.ReportCommonTLogDataByBRPhase = function() end
        end

        local lII11lIllllII = require("GameLua.GameCore.Data.GameplayData")
        if lII11lIllllII then
            local l11IlIlll1lIl = lII11lIllllII.GetPlayerControllerSafety and lII11lIllllII.GetPlayerControllerSafety() or lII11lIllllII.GetPlayerController()
            if slua.isValid(l11IlIlll1lIl) and l11IlIlll1lIl.ReportCrashKitFeature then
                l11IlIlll1lIl.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException = function() end
            end
        end
    end)
    print('[LogBlocker] Log/Crash/Buggly & Silent Screenshots Bypassed!')
end

function _G.InitializeScannerBlocker()
    print('[ScannerBlocker] Initializing Scanner Blocker V11...')
    pcall(function()
        local lI11l111lllll = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        
        if lI11l111lllll then
            local lI1IlIllIIl11 = lI11l111lllll:Get("AFKReportorSubsystem")
            if lI1IlIllIIl11 then 
                lI1IlIllIIl11.PlayerHaveAction = function() end; lI1IlIllIIl11.ReportAFK = function() end
            end

            local l1II11l1lIl1l = lI11l111lllll:Get("ClientDataStatistcsSubsystem")
            if l1II11l1lIl1l then
                l1II11l1lIl1l.StartToCheck = function() end
                l1II11l1lIl1l.DelayCount = 0
                if l1II11l1lIl1l.ReportPingDelayTimer then
                    l1II11l1lIl1l:RemoveGameTimer(l1II11l1lIl1l.ReportPingDelayTimer)
                    l1II11l1lIl1l.ReportPingDelayTimer = nil
                end
            end

            local lIlIll111l11l = lI11l111lllll:Get("AvatarExceptionSubsystem")
            if lIlIll111l11l then
                lIlIll111l11l.ReportException = function() end
                lIlIll111l11l.BindPlayerCharacter = function() end
                lIlIll111l11l.CheckAvatarValid = function() return true end
            end
            
            local llIlIII111I1l = lI11l111lllll:Get("ShootVerifySubSystemClient")
            if llIlIII111I1l then
                llIlIII111I1l.ReportVerifyFail = function() end
                llIlIII111I1l.OnVerifyFailed = function() end
            end
        end

        local llIll11l1lI1I = import("CreativeModeBlueprintLibrary")
        if llIll11l1lI1I then
            llIll11l1lI1I.MD5HashByteArray = function() return "BYPASSED_MD5_HASH" end
            llIll11l1lI1I.GetContentDiffData = function() return true, "BYPASSED" end
        end

        local lIlII11l1I1Il = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if lIlII11l1I1Il then
            lIlII11l1I1Il.CheckAvatarException = function() end
            lIlII11l1I1Il.CheckAvatarExceptionOnce = function() end
            lIlII11l1I1Il.ReportAvatarException = function() end
            lIlII11l1I1Il.CheckSlotMeshVisible = function() return false end
            lIlII11l1I1Il.CheckPawnVisible = function() return false end
            lIlII11l1I1Il.CheckCanBugglyPostException = function() return false end
        end

        local llI1I1I1Ill11 = package.loaded["blacklist.slua.logic.lobby_gm.AvatarCheckerModule"]
        if llI1I1I1Ill11 then
            llI1I1I1Ill11.CheckAvatar = function() return true end
            llI1I1I1Ill11.ReportException = function() end
        end

        local llIII1I1I11Il = package.loaded["client.slua.logic.memory_warning.logic_memory_warning"]
        if llIII1I1I11Il then
            llIII1I1I11Il.OnMemoryWarning = function() end
            llIII1I1I11Il.ReportMemoryWarning = function() end
        end

        local lI1lIIlIII1lI = package.loaded["client.slua.logic.store.logic_store_game_interface"]
        if lI1lIIlIII1lI then
            lI1lIIlIII1lI.IsStoreGameSupported = function() return true end 
            lI1lIIlIII1lI.NotifyGetPGSLoginInfo = function() end 
        end

        local lI1lIll111III = package.loaded["GameLua.Mod.BaseMod.Client.Voice.VoiceChatSubsystem"]
        if lI1lIll111III then
            lI1lIll111III.OnPlayerSubmitComplaint = function() end
        end

        
        local l1II1lllI1II1 = package.loaded["TssSdk"] or _G.TssSdk
        if l1II1lllI1II1 then
            local lII11l1I1lIlI = l1II1lllI1II1.OnRecvData
            l1II1lllI1II1.OnRecvData = function(data)
                
                if type(data) == "string" and (string.find(data, "report") or string.find(data, "exception")) then
                    return
                end
                if lII11l1I1lIlI then lII11l1I1lIlI(data) end
            end
            
            l1II1lllI1II1.SendReportInfo = function() end
            l1II1lllI1II1.ScanMemory = function() return true end
            l1II1lllI1II1.IsEmulator = function() return false end
            l1II1lllI1II1.GetTssSdkReportInfo = function() return "" end
        end
    end)
    print('[ScannerBlocker] Magic Bullet/MD5 Checks/TSS/OS Scans Bypassed!')
end

function _G.InitializeReplayTelemetryBlocker()
    print('[ReplayBlocker] Initializing Replay Telemetry Blocker V11...')
    pcall(function()
        local lI11l111lllll = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        
        local llI1ll1IIIlIl = lI11l111lllll and lI11l111lllll:Get("RescueBtnReplayTraceSubsystem")
        if llI1ll1IIIlIl then
            llI1ll1IIIlIl.ReportTrace = function() end
            llI1ll1IIIlIl.ReportTickMonitorHeartbeat = function() end
        end

        local lIllIll1lI11l = lI11l111lllll and lI11l111lllll:Get("GameReportSubsystem")
        if lIllIll1lI11l then
            lIllIll1lI11l.ReplayReportData = function() return false end
            lIllIll1lI11l.CheckCanBugglyPostException = function() return false end
            lIllIll1lI11l.BugglyPostExceptionFull = function() return false end
            lIllIll1lI11l.GetClientReplayDataReporter = function() return nil end
            
            if lIllIll1lI11l.Reporter then
                lIllIll1lI11l.Reporter.ReportIntArrayData = function() end
                lIllIll1lI11l.Reporter.ReportUInt8ArrayData = function() end
                lIllIll1lI11l.Reporter.ReportFloatArrayData = function() end
            end
        end

        local l1I1IIl1I1I1I = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if l1I1IIl1I1I1I then
            l1I1IIl1I1I1I.ReportReplay = function() end
            l1I1IIl1I1I1I.SendReportReq = function() end
        end

        local ll1Il1l1IIlI1 = package.loaded["client.slua.logic.home.logic_home_report"]
        if ll1Il1l1IIlI1 then
            ll1Il1l1IIlI1.ShowInGameReportUI = function() end
            ll1Il1l1IIlI1.SendReport = function() end
        end
    end)
    print('[ReplayBlocker] Replay Evidence Collection Stopped!')
end

function _G.DisableHiggsBoson()
    local lI11lIlIlI1II = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not lI11lIlIlI1II or not slua.isValid(lI11lIlIlI1II) then return end
    if lI11lIlIlI1II.HiggsBoson then
        lI11lIlIlI1II.HiggsBoson.bMHActive = false
        lI11lIlIlI1II.HiggsBoson.bCallPreReplication = false
    end
    if lI11lIlIlI1II.HiggsBosonComponent then
        lI11lIlIlI1II.HiggsBosonComponent.bMHActive = false
        lI11lIlIlI1II.HiggsBosonComponent:ControlMHActive(0)
    end
end

function _G.InitializeAntiCheatHooks()
    print('[AntiCheat] Initializing bypass system...')
    pcall(function()
        local lllIl11IIll1I = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if lllIl11IIll1I and lllIl11IIll1I.StaticShowSecurityAlertInDev then
            lllIl11IIll1I.StaticShowSecurityAlertInDev = function() end
        end
    end)

    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = function(lllIl11IIll1I) end
        _G.AvatarCheckCallback.OnReportItemID = function(lllIl11IIll1I) end
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(lI11lIlIlI1II)
            if slua.isValid(lI11lIlIlI1II) and lI11lIlIlI1II.HiggsBosonComponent then
                lI11lIlIlI1II.HiggsBosonComponent:ControlMHActive(0)
                lI11lIlIlI1II.HiggsBosonComponent.bMHActive = false
            end
        end
    end

    pcall(function()
        local lllIlllIIII11 = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if lllIlllIIII11 and lllIlllIIII11.BlackList then
            for k in pairs(lllIlllIIII11.BlackList) do lllIlllIIII11.BlackList[k] = nil end
        end
    end)

    _G.BlackList = {}

    pcall(function()
        _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
        _G.GlobalPlayerCheatTimes = _G.GlobalPlayerCheatTimes or {}
        local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
        mt.__newindex = function(t, k, v) end
        setmetatable(_G.GlobalPlayerCoronaData, mt)
    end)

    pcall(function()
        if _G.GameSafeCallbacks and _G.GameSafeCallbacks.RecordStrategyTimestampInReplay then
            _G.GameSafeCallbacks.RecordStrategyTimestampInReplay = function(...) end
            _G.GameSafeCallbacks.DoAttackFlowStrategy = function() end
            _G.GameSafeCallbacks.GetScriptReportContent = function() return "" end
        end
    end)

    pcall(function()
        local lllI1lIIl11ll = import("STExtraBlueprintFunctionLibrary")
        if lllI1lIIl11ll then
            lllI1lIIl11ll.IsDevelopment = function() return false end
        end
    end)
    print('[AntiCheat] Bypass system activated!')
end

function _G.InitializeAntiReport()
    print('[AntiReport] Initializing System...')
    pcall(function()
        local l1lI111l11lII = { "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem" }
        local lIlIIIlIl11l1 = nil
        for _, path in ipairs(l1lI111l11lII) do
            if package.loaded[path] then lIlIIIlIl11l1 = package.loaded[path] break end
            local llIIl1I111I11, ll1Il1II1lIll = pcall(require, path)
            if llIIl1I111I11 and ll1Il1II1lIll then lIlIIIlIl11l1 = ll1Il1II1lIll break end
        end
        if lIlIIIlIl11l1 then
            lIlIIIlIl11l1.OnInit = function(self) return end
            lIlIIIlIl11l1._OnPlayerKilledOtherPlayer = function() return end
            lIlIIIlIl11l1._RecordFatalDamager = function() return end
            lIlIIIlIl11l1._OnDeathReplayDataWhenFatalDamaged = function() return end
            lIlIIIlIl11l1._RecordMurdererFromDeathReplayData = function() return end
            lIlIIIlIl11l1._RecordTeammatePlayerInfo = function() return end
            lIlIIIlIl11l1._OnBattleResult = function() return end
            lIlIIIlIl11l1._OnShowQuickReportMutualExclusiveUI = function() return end
            lIlIIIlIl11l1.GetFatalDamagerMap = function() return {} end
            lIlIIIlIl11l1.GetCachedTeammateName2InfoMap = function() return {} end
            lIlIIIlIl11l1.GetTeammateName2InfoMapDuringBattle = function() return {} end
            lIlIIIlIl11l1.GetCurrentNotInTeamHistoricalTeammateMap = function() return {} end
            lIlIIIlIl11l1.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
        end
    end)

    pcall(function()
        local l1lI111l11lII = { "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem", "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem" }
        local llll11IlIll1l = nil
        for _, path in ipairs(l1lI111l11lII) do
            if package.loaded[path] then llll11IlIll1l = package.loaded[path] break end
            local llIIl1I111I11, ll1Il1II1lIll = pcall(require, path)
            if llIIl1I111I11 and ll1Il1II1lIll then llll11IlIll1l = ll1Il1II1lIll break end
        end
        if llll11IlIll1l then
            llll11IlIll1l.OnInit = function(self) return end
            llll11IlIll1l._OnNearDeathOrRescued = function() return end
            llll11IlIll1l._OnCharacterDied = function() return end
            llll11IlIll1l._OnTeammateDamage = function() return end
            llll11IlIll1l._OnPlayerSettlementStart = function() return end
            llll11IlIll1l._AddKnockDownerToBattleResult = function() return end
            llll11IlIll1l._AddKillerToBattleResult = function() return end
            llll11IlIll1l._AddTeammateMurderToBattleResult = function() return end
            llll11IlIll1l._AddFatalDamagerMapToBattleResult = function() return end
            llll11IlIll1l._AddMLKillerUIDToBattleResult = function() return end
            llll11IlIll1l._SaveHistoricalTeammateInfo = function() return end
            llll11IlIll1l._RecordFatalDamager = function() return end
            llll11IlIll1l._RecordTeammateMurderer = function() return end
        end
    end)

    pcall(function()
        local l1IIlIlIIllIl = require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
        if l1IIlIlIIllIl then
            l1IIlIlIIllIl.RecordFatalDamager = function() return end
            l1IIlIlIIllIl.IsUsingHistoricalTeammateInfo = function() return false end
            l1IIlIlIIllIl.IsCharacterDeliverAI = function() return false end
        end
    end)

    pcall(function()
        local l1lIlIl1llII1 = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
        if l1lIlIl1llII1 then
            l1lIlIl1llII1.ExtractPlayerBasicInfo = function() return {} end
            l1lIlIl1llII1.LogIf = function() return false end
        end
    end)

    pcall(function()
        local ll1IlIlllI11l = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
        if ll1IlIlllI11l then
            ll1IlIlllI11l.OnShowMutualExclusiveUI = function() return end
            ll1IlIlllI11l.OnHideMutualExclusiveUI = function() return end
        end
    end)
    print('[AntiReport] System Fully Active!')
end

function _G.InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks or _G.GameplayCallbacks.IsBypassed then return end
        
        local GC = _G.GameplayCallbacks
        print('[GameplayBypass] Hooking GameplayCallbacks...')
        
        local lI1IIllI1I1ll = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            if InPlayerState and string.lower(tostring(InPlayerState)) == "cheatdetected" then return end
            if lI1IIllI1I1ll then return lI1IIllI1I1ll(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
        end

        local function l1III1Ill1ll1() return end
        local function l11ll1I1l1ll1() return {} end
        local function l111lIl1IIlll() return nil end
        
        GC.ReportAttackFlow = l1III1Ill1ll1
        GC.ReportSecAttackFlow = l1III1Ill1ll1
        GC.ReportHurtFlow = l1III1Ill1ll1
        GC.ReportFireArms = l1III1Ill1ll1
        GC.ReportVerifyInfoFlow = l1III1Ill1ll1
        GC.ReportMrpcsFlow = l1III1Ill1ll1
        GC.ReportPlayerBehavior = l1III1Ill1ll1
        GC.ReportTeammatHurt = l1III1Ill1ll1
        GC.ReportMisKillByTeammate = l1III1Ill1ll1
        GC.ReportForbitPick = l1III1Ill1ll1
        GC.ReportPlayerMoveRoute = l1III1Ill1ll1
        GC.ReportPlayerPosition = l1III1Ill1ll1
        GC.ReportVehicleMoveFlow = l1III1Ill1ll1
        GC.ReportSecTgameMovingFlow = l1III1Ill1ll1
        GC.ReportParachuteData = l1III1Ill1ll1
        GC.SendTssSdkAntiDataToLobby = l1III1Ill1ll1
        GC.SendDSErrorLogToLobby = l1III1Ill1ll1
        GC.SendDSErrorLogToLobbyOnece = l1III1Ill1ll1
        GC.SendDSHawkEyePatrolLogToLobby = l1III1Ill1ll1
        GC.ReportEquipmentFlow = l1III1Ill1ll1
        GC.ReportAimFlow = l1III1Ill1ll1
        GC.GetWeaponReport = l11ll1I1l1ll1
        GC.GetOneWeaponReport = l11ll1I1l1ll1
        GC.ReportHeavyWeaponBoxSpawnFlow = l1III1Ill1ll1
        GC.ReportHeavyWeaponBoxActivationFlow = l1III1Ill1ll1
        GC.ReportHeavyWeaponBoxOpenPlayerFlow = l1III1Ill1ll1
        GC.ReportHeavyWeaponBoxItemFlow = l1III1Ill1ll1
        GC.ReportPlayersPing = l1III1Ill1ll1
        GC.ReportPlayerIP = l1III1Ill1ll1
        GC.ReportPlayerFramePingRecord = l1III1Ill1ll1
        GC.OnDSConnectionSaturated = l1III1Ill1ll1
        GC.ReportDSNetSaturation = l1III1Ill1ll1
        GC.ReportNetContinuousSaturate = l1III1Ill1ll1
        GC.ReportDSNetRate = l1III1Ill1ll1
        GC.SendClientStats = l1III1Ill1ll1
        GC.SendServerAvgTickDelta = l1III1Ill1ll1
        GC.ReportCircleFlow = l1III1Ill1ll1
        GC.ReportDSCircleFlow = l1III1Ill1ll1
        GC.ReportJumpFlow = l1III1Ill1ll1
        GC.ReportAIStrategyInfo = l1III1Ill1ll1
        GC.SendAIDeliveryInfo = l1III1Ill1ll1
        GC.ReportDailyTaskInfo = l1III1Ill1ll1
        GC.ReportMatchRoomData = l1III1Ill1ll1
        GC.SendPlayerSpectatingLog = l1III1Ill1ll1
        GC.ReportIDCardProduceFlow = l1III1Ill1ll1
        GC.ReportIDCardPickUpFlow = l1III1Ill1ll1
        GC.ReportIDCardDestroyFlow = l1III1Ill1ll1
        GC.ReportRevivalFlow = l1III1Ill1ll1
        GC.ReportGameSetting = l1III1Ill1ll1
        GC.ReportGameSettingNew = l1III1Ill1ll1
        GC.ReportAntsVoiceTeamCreate = l1III1Ill1ll1
        GC.ReportAntsVoiceTeamQuit = l1III1Ill1ll1
        GC.ReportCommonInfo = l1III1Ill1ll1
        GC.ReportLightweightStat = l1III1Ill1ll1
        GC.SendSecTLog = l1III1Ill1ll1
        GC.SendDataMiningTLog = l1III1Ill1ll1
        GC.SendActivityTLog = l1III1Ill1ll1
        GC.GetGeneralTLogData = l111lIl1IIlll
        
        GC.IsBypassed = true
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil.IsBypassed then
            local llIlI1I1l1l11 = NetUtil.SendPacket
            local l111III1IIIll = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportHurtFlow"]=1,
                ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportTeammateKillConfirmFlow"]=1,
                ["ReportForbiddenPickupFlow"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["ReportSecVehicleMoveFlow"]=1, ["ReportSecTgameMovingFlow"]=1, ["report_parachute_data"]=1,
                ["report_character_all_drag"]=1, ["report_parachute_all_drag"]=1, ["report_vehicle_move_drag"]=1,
                ["on_tss_sdk_anti_data"]=1, ["report_unrealnet_exception"]=1, ["ReportPlayerEquipmentInfo"]=1,
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["log_shooting_miss"]=1, ["report_heavy_weapon_box_activation_flow"]=1,
                ["report_heavy_weapon_box_item_flow"]=1, ["ReportCircleFlow"]=1, ["report_ds_player_circle_flow"]=1,
                ["ReportJumpFlow"]=1, ["ReportGameStartFlow"]=1, ["ReportGameEndFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_player_frame_ping_record"]=1, ["report_net_saturate"]=1,
                ["report_ds_netsaturate"]=1, ["report_ds_net_continuous_saturate"]=1, ["report_ds_netrate"]=1,
                ["report_unrealnet_clientstats"]=1, ["report_serverstat_avgtickdelta"]=1, ["report_all_players_address"]=1,
                ["report_ai_strategyinfo"]=1, ["ReportAIActionFlow"]=1, ["ReportGenerateMonsterFlow"]=1,
                ["report_ds_match_room_data"]=1, ["SendSpectatingLog"]=1, ["ReportIDCardProduceFlow"]=1,
                ["ReportIDCardPickUpFlow"]=1, ["ReportIDCardDestroyFlow"]=1, ["ReportRevivalFlow"]=1,
                ["ReportGameSetting"]=1, ["ReportGameSettingNew"]=1, ["ReportAntsVoiceTeamCreate"]=1,
                ["ReportAntsVoiceTeamQuit"]=1, ["report_common_info"]=1, ["report_common_battle_info"]=1,
                ["report_client_scan_result"]=1, ["tss_sdk_report"]=1, ["report_memory_exception"]=1,
                ["report_avatar_exception"]=1, ["report_ui_state"]=1, ["report_hit_reg_fail"]=1,
                ["report_character_state"]=1, ["report_vehicle_exception"]=1, ["report_camera_exception"]=1,
                ["ReportPlayerControllerStateChanged"]=1, ["ReportAvatarFlow"]=1,
                
                
                ["send_ugc_report_uni_mod_expose_req"]=1, 
                ["send_ugc_report_uni_mod_interactive_req"]=1,
            }
            
            NetUtil.SendPacket = function(packetName, ...)
                if l111III1IIIll[packetName] then return end
                return llIlI1I1l1l11(packetName, ...)
            end
            NetUtil.IsBypassed = true
        end
    end)
end

function _G.InitializeConnectionGuard()
    pcall(function()
        if _G.ConnectionGuardInitialized or not _G.GameplayCallbacks then return end
        print('[ConnectionGuard] Initializing Shield...')
        
        local GC = _G.GameplayCallbacks
        local lI1IIllI1I1ll = GC.OnDSPlayerStateChanged

        GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            local l1llI1II1II11 = InPlayerState and string.lower(tostring(InPlayerState)) or ""
            local l1I11ll1lllll = {
                ["cheatdetected"] = true, ["connectionlost"] = true,
                ["connectiontimeout"] = true, ["connectionexception"] = true,
                ["netdrivererror"] = true
            }
            if l1I11ll1lllll[l1llI1II1II11] then return end
            if lI1IIllI1I1ll then
                pcall(lI1IIllI1I1ll, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            end
        end

        GC.OnPlayerNetConnectionClosed = function(GameID, UID, Reason, ErrorMessage) end
        GC.OnPlayerActorChannelError = function(GameID, UID, Reason, ErrorMessage) end
        GC.OnPlayerRPCValidateFailed = function(GameID, UID, Reason, ErrorMessage) end
        GC.OnPlayerSpectateException = function(GameID, UID, Reason, ErrorMessage) end
        GC.OnShutdownAfterError = function(GameID) end

        _G.ConnectionGuardInitialized = true
        print('[ConnectionGuard] Active & Protecting!')
    end)
end


local function InitAllBypasses()
    pcall(function()
        if _G.InitializeAntiReport then _G.InitializeAntiReport() end
        if _G.InitializeAntiCheatHooks then _G.InitializeAntiCheatHooks() end
        if _G.InitializeGameplayBypass then _G.InitializeGameplayBypass() end
        if _G.InitializeConnectionGuard then _G.InitializeConnectionGuard() end
        if _G.DisableHiggsBoson then _G.DisableHiggsBoson() end
        if _G.InitializeLogBlocker then _G.InitializeLogBlocker() end
        if _G.InitializeScannerBlocker then _G.InitializeScannerBlocker() end
        if _G.InitializeReplayTelemetryBlocker then _G.InitializeReplayTelemetryBlocker() end
        if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end
    end)
    _G._AKMODVIP_INIT_DONE = true
end

pcall(function()
    _G._AKMODVIP_INIT_DONE = false
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        pc:AddGameTimer(1.0, true, function()
            if not _G._AKMODVIP_INIT_DONE then
                InitAllBypasses()
            end
        end)
    else
        require('common.time_ticker').AddTimerOnce(1.5, InitAllBypasses)
    end
end)
