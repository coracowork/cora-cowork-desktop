!ifndef CORA_COWORK_INSTALLER_REPAIR_HEAL_NSH
!define CORA_COWORK_INSTALLER_REPAIR_HEAL_NSH

Var /GLOBAL CoraCoworkRegistryInstallIsValid
Var /GLOBAL CoraCoworkInnerFailureSummary
Var /GLOBAL CoraCoworkInnerRootCode
Var /GLOBAL CoraCoworkInnerFailureReadResult

!macro CORA_COWORK_READ_LAST_INNER_FAILURE
  InitPluginsDir
  StrCpy $CoraCoworkInnerRootCode ""
  StrCpy $CoraCoworkInnerFailureSummary "No specific locking process was identified. Close CoraCowork, terminals, editors, and file managers opened in the install folder."
  nsExec::ExecToStack `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$logPath = '$CoraCoworkSessionLogPath'; \
    $$summary = 'No specific locking process was identified. Close CoraCowork, terminals, editors, and file managers opened in the install folder.'; \
    $$code = ''; \
    if ($$logPath -and (Test-Path -LiteralPath $$logPath)) { \
      $$events = @(Get-Content -LiteralPath $$logPath -ErrorAction SilentlyContinue | ForEach-Object { try { $$_ | ConvertFrom-Json } catch { $$null } } | Where-Object { $$_ }); \
      $$failure = @($$events | Where-Object { $$_.event -eq 'failure' -and $$_.updated -eq $$true } | Select-Object -Last 1)[0]; \
      if (-not $$failure) { $$failure = @($$events | Where-Object { $$_.event -eq 'failure' } | Select-Object -Last 1)[0] }; \
      if ($$failure) { \
        $$code = ([string]$$failure.code).Trim(); \
        $$phase = ([string]$$failure.phase).Trim(); \
        $$path = ([string]$$failure.failedPath).Trim(); \
        $$blocking = ''; \
        $$processes = @($$failure.blockingProcesses); \
        if ($$processes.Count -gt 0) { $$blocking = (@($$processes | ForEach-Object { if ($$_.pid) { [string]$$_.name + '(' + [string]$$_.pid + ')' } else { [string]$$_.name } }) -join ', ') }; \
        if (-not $$blocking) { $$blocking = ([string]$$failure.message).Trim() }; \
        if (-not $$blocking) { $$blocking = 'Windows did not identify a specific locking process. Close terminals, editors, and file managers opened in the install folder.' }; \
        $$parts = @('- Outer installer: previous uninstaller exited with code $R0', ('- Inner failure: ' + $$code + ' phase ' + $$phase)); \
        if ($$path) { $$parts += ('- File or folder: ' + $$path) }; \
        $$parts += ('- Blocking process: ' + $$blocking); \
        $$summary = $$parts -join [Environment]::NewLine; \
      } \
    }; \
    if (-not $$code) { $$code = '-----' }; \
    [Console]::Out.Write($$code + '|' + $$summary) \
  }"`
  Pop $CoraCoworkInnerFailureReadResult
  Pop $CoraCoworkInnerFailureReadResult
  StrCpy $CoraCoworkInnerRootCode $CoraCoworkInnerFailureReadResult 5
  ${If} $CoraCoworkInnerRootCode == "-----"
    StrCpy $CoraCoworkInnerRootCode ""
  ${EndIf}
  StrCpy $CoraCoworkInnerFailureSummary $CoraCoworkInnerFailureReadResult 4096 6
!macroend

!macro CORA_COWORK_LOG_UNINSTALLER_REPAIR _PHASE
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$path = '$INSTDIR\${UNINSTALL_FILENAME}'; \
    $$item = Get-Item -LiteralPath $$path -ErrorAction SilentlyContinue; \
    $$version = if ($$item) { $$item.VersionInfo.ProductVersion } else { '' }; \
    $$length = if ($$item) { $$item.Length } else { '' }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = '$CoraCoworkSessionId'; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = 'uninstaller-repair'; phase = '${_PHASE}'; path = $$path; exists = [bool]$$item; productVersion = $$version; length = $$length }; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value ($$payload | ConvertTo-Json -Compress -Depth 8) \
  }"`
  Pop $CoraCoworkRepairLogResult
!macroend

!macro CORA_COWORK_REPAIR_INSTALLED_UNINSTALLER
  Var /GLOBAL CoraCoworkInstalledUninstaller
  Var /GLOBAL CoraCoworkBundledUninstaller
  Var /GLOBAL CoraCoworkRepairLogResult

  !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "before"
  StrCpy $CoraCoworkInstalledUninstaller "$INSTDIR\${UNINSTALL_FILENAME}"

  InitPluginsDir
  StrCpy $CoraCoworkBundledUninstaller "$PLUGINSDIR\CoraCowork-fixed-uninstaller.exe"
  SetOverwrite on
  File "/oname=$PLUGINSDIR\CoraCowork-fixed-uninstaller.exe" "${UNINSTALLER_OUT_FILE}"

  ${If} ${FileExists} "$CoraCoworkInstalledUninstaller"
    ClearErrors
    CopyFiles /SILENT "$CoraCoworkBundledUninstaller" "$CoraCoworkInstalledUninstaller"
    ${If} ${Errors}
      !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "copy-failed-retry"
      !insertmacro CORA_COWORK_STOP_APP_PROCESSES
      Sleep 1000

      ClearErrors
      CopyFiles /SILENT "$CoraCoworkBundledUninstaller" "$CoraCoworkInstalledUninstaller"
      ${If} ${Errors}
        ${If} ${FileExists} "$CoraCoworkBundledUninstaller"
          !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "copy-failed-using-bundled"
          !insertmacro CORA_COWORK_LOG_EVENT "event=uninstaller-repair phase=copy-failed-using-bundled"
        ${Else}
          !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_UNINSTALLER_COPY_OR_REBUILD_FAILED} "uninstaller-repair copy-failed-retry-bundled-missing" "${CORA_COWORK_MSG_UNINSTALLER_COPY_LOCKED_EN}" "${CORA_COWORK_MSG_UNINSTALLER_COPY_LOCKED_ZH}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_EN}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_ZH}"
        ${EndIf}
      ${Else}
        !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "after-copy-retry"
      ${EndIf}
    ${Else}
      !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "after-copy"
    ${EndIf}
  ${Else}
    ClearErrors
    CopyFiles /SILENT "$CoraCoworkBundledUninstaller" "$CoraCoworkInstalledUninstaller"
    ${If} ${Errors}
      !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_UNINSTALLER_COPY_OR_REBUILD_FAILED} "uninstaller-repair rebuild-failed" "${CORA_COWORK_MSG_UNINSTALLER_REBUILD_FAILED_EN}" "${CORA_COWORK_MSG_UNINSTALLER_REBUILD_FAILED_ZH}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_EN}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_ZH}"
    ${EndIf}

    ${IfNot} ${FileExists} "$CoraCoworkInstalledUninstaller"
      !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_UNINSTALLER_COPY_OR_REBUILD_FAILED} "uninstaller-repair rebuild-missing-after-copy" "${CORA_COWORK_MSG_UNINSTALLER_REBUILD_MISSING_EN}" "${CORA_COWORK_MSG_UNINSTALLER_REBUILD_MISSING_ZH}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_EN}" "${CORA_COWORK_MSG_UNINSTALLER_REPAIR_ACTION_ZH}"
    ${EndIf}

    !insertmacro CORA_COWORK_LOG_UNINSTALLER_REPAIR "rebuilt"
    !insertmacro CORA_COWORK_LOG_EVENT "event=uninstaller-repair phase=rebuilt"
  ${EndIf}
!macroend

!macro CORA_COWORK_HEAL_INSTALL_REGISTRY
  Var /GLOBAL CoraCoworkRegInstallLocation
  Var /GLOBAL CoraCoworkRegUninstallString
  Var /GLOBAL CoraCoworkRegInstallExe

  StrCpy $CoraCoworkRegistryInstallIsValid "0"

  ReadRegStr $CoraCoworkRegInstallLocation SHCTX "${INSTALL_REGISTRY_KEY}" "InstallLocation"
  ReadRegStr $CoraCoworkRegUninstallString SHCTX "${UNINSTALL_REGISTRY_KEY}" "UninstallString"

  ${If} $CoraCoworkRegInstallLocation == ""
    !insertmacro CORA_COWORK_LOG_EVENT "event=registry-heal phase=missing-install-location uninstallString=$CoraCoworkRegUninstallString"
    !insertmacro CORA_COWORK_CLEAR_INSTALL_REGISTRY "missing-install-location"
  ${Else}
    StrCpy $CoraCoworkRegInstallExe "$CoraCoworkRegInstallLocation\${CORA_COWORK_APP_EXECUTABLE_FILENAME}"
    ${If} ${FileExists} "$CoraCoworkRegInstallExe"
      StrCpy $INSTDIR "$CoraCoworkRegInstallLocation"
      StrCpy $CoraCoworkRegistryInstallIsValid "1"
      !insertmacro CORA_COWORK_LOG_EVENT "event=registry-heal phase=valid-install-location instDir=$INSTDIR uninstallString=$CoraCoworkRegUninstallString"
    ${Else}
      !insertmacro CORA_COWORK_LOG_EVENT "event=registry-heal phase=stale-install-location installLocation=$CoraCoworkRegInstallLocation uninstallString=$CoraCoworkRegUninstallString"
      !insertmacro CORA_COWORK_CLEAR_INSTALL_REGISTRY "stale-install-location"
    ${EndIf}
  ${EndIf}
!macroend

!macro CORA_COWORK_LOG_UNINSTALL_RESULT _ROOT_KEY _HAD_ERRORS
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = '$CoraCoworkSessionId'; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = 'uninstall-result'; root = '${_ROOT_KEY}'; launchErrors = '${_HAD_ERRORS}'; exitCode = '$R0' }; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value ($$payload | ConvertTo-Json -Compress -Depth 8) \
  }"`
  Pop $CoraCoworkUninstallLogResult
!macroend

!macro CORA_COWORK_HANDLE_UNINSTALL_RESULT _ROOT_KEY _LABEL_PREFIX
  ${If} ${Errors}
    StrCpy $CoraCoworkUninstallHadErrors "1"
  ${Else}
    StrCpy $CoraCoworkUninstallHadErrors "0"
  ${EndIf}

  !insertmacro CORA_COWORK_LOG_UNINSTALL_RESULT "${_ROOT_KEY}" "$CoraCoworkUninstallHadErrors"

  ${If} $CoraCoworkUninstallHadErrors == "1"
    DetailPrint `Uninstall was not successful. Not able to launch uninstaller!`
    Return
  ${EndIf}

  ${If} $R0 != 0
      DetailPrint `Uninstall was not successful. Uninstaller error code: $R0.`
      !insertmacro CORA_COWORK_READ_LAST_INNER_FAILURE
      ${If} $CoraCoworkLockerList != ""
        StrCpy $CoraCoworkInnerFailureSummary "- Failure: previous uninstaller failed with exit code $R0$\r$\n- File or folder: $INSTDIR$\r$\n- Blocking process: $CoraCoworkLockerList"
      ${EndIf}
      !insertmacro CORA_COWORK_LOG_EVENT "event=old-uninstaller-failed action=report exitCode=$R0 lockers=$CoraCoworkLockerList uninstallerDetail=$CoraCoworkInnerFailureSummary"
      ${If} $CoraCoworkInnerRootCode != ""
        !insertmacro CORA_COWORK_FAIL_REPORTABLE_ROOTED_BILINGUAL_DIAGNOSTICS "$CoraCoworkInnerRootCode" ${CORA_COWORK_E_OLD_UNINSTALL_FAILED} "old-uninstaller exitCode=$R0 lockers=$CoraCoworkLockerList uninstallerDetail=$CoraCoworkInnerFailureSummary" "${CORA_COWORK_MSG_OLD_UNINSTALL_FAILED_EN}" "${CORA_COWORK_MSG_OLD_UNINSTALL_FAILED_ZH}" "${CORA_COWORK_MSG_OLD_UNINSTALL_ACTION_EN}" "${CORA_COWORK_MSG_OLD_UNINSTALL_ACTION_ZH}" "$CoraCoworkInnerFailureSummary" "$CoraCoworkInnerFailureSummary"
      ${Else}
        !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL_DIAGNOSTICS ${CORA_COWORK_E_OLD_UNINSTALL_FAILED} "old-uninstaller exitCode=$R0 lockers=$CoraCoworkLockerList uninstallerDetail=$CoraCoworkInnerFailureSummary" "${CORA_COWORK_MSG_OLD_UNINSTALL_FAILED_EN}" "${CORA_COWORK_MSG_OLD_UNINSTALL_FAILED_ZH}" "${CORA_COWORK_MSG_OLD_UNINSTALL_ACTION_EN}" "${CORA_COWORK_MSG_OLD_UNINSTALL_ACTION_ZH}" "$CoraCoworkInnerFailureSummary" "$CoraCoworkInnerFailureSummary"
      ${EndIf}
  ${EndIf}
!macroend

!macro customInit
  !insertmacro CORA_COWORK_HEAL_INSTALL_REGISTRY
  ${If} $CoraCoworkRegistryInstallIsValid == "1"
    !insertmacro CORA_COWORK_REPAIR_INSTALLED_UNINSTALLER
  ${EndIf}
!macroend

!macro customUnInstallCheck
  !insertmacro CORA_COWORK_HANDLE_UNINSTALL_RESULT "SHELL_CONTEXT" "shctx"
!macroend

!macro customUnInstallCheckCurrentUser
  !insertmacro CORA_COWORK_HANDLE_UNINSTALL_RESULT "HKEY_CURRENT_USER" "hkcu"
!macroend

!endif
