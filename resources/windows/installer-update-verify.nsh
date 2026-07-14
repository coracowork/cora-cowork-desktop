!ifndef CORA_COWORK_INSTALLER_UPDATE_VERIFY_NSH
!define CORA_COWORK_INSTALLER_UPDATE_VERIFY_NSH

Var /GLOBAL CoraCoworkUninstallHadErrors
Var /GLOBAL CoraCoworkUninstallLogResult
Var /GLOBAL CoraCoworkVerifyResourceResult
Var /GLOBAL CoraCoworkUpdatedAppExitWaitResult
Var /GLOBAL CoraCoworkActiveMarkerExecResult
Var /GLOBAL CoraCoworkActiveMarkerResult

!define CORA_COWORK_ACTIVE_INSTALLER_MARKER "cora-cowork-installer-active.marker"

!macro CORA_COWORK_BRING_UPDATED_INSTALLER_TO_FRONT
  ${If} ${isUpdated}
    BringToFront
    !insertmacro CORA_COWORK_SLOG "event=updated-installer-foreground action=bring-to-front"
  ${EndIf}
!macroend

!macro CORA_COWORK_WAIT_FOR_UPDATED_APP_EXIT
  ${If} ${isUpdated}
    !insertmacro CORA_COWORK_SLOG "event=updated-app-exit-wait phase=start"
    StrCpy $CoraCoworkUpdatedAppExitWaitResult "0"

    nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
      $$ErrorActionPreference = 'SilentlyContinue'; \
      $$deadline = (Get-Date).AddSeconds(10); \
      $$target = [System.IO.Path]::GetFullPath((Join-Path '$INSTDIR' '${CORA_COWORK_APP_EXECUTABLE_FILENAME}')); \
      do { \
        $$hits = @(Get-CimInstance -ClassName Win32_Process | Where-Object { \
          $$path = $$_.ExecutablePath; \
          if (-not $$path) { $$path = $$_.Path } \
          $$_.Name -ieq '${CORA_COWORK_APP_EXECUTABLE_FILENAME}' -and $$path -and \
          [string]::Equals([System.IO.Path]::GetFullPath($$path), $$target, [System.StringComparison]::CurrentCultureIgnoreCase) \
        }); \
        if ($$hits.Count -eq 0) { exit 0 }; \
        Start-Sleep -Milliseconds 500; \
      } while ((Get-Date) -lt $$deadline); \
      exit 1 \
    }"`
    Pop $CoraCoworkUpdatedAppExitWaitResult

    ${If} $CoraCoworkUpdatedAppExitWaitResult != 0
      !insertmacro CORA_COWORK_SLOG "event=updated-app-exit-wait phase=timeout action=stop"
      !insertmacro CORA_COWORK_STOP_APP_PROCESSES
    ${EndIf}

    !insertmacro CORA_COWORK_SLOG "event=updated-app-exit-wait phase=done result=$CoraCoworkUpdatedAppExitWaitResult"
  ${EndIf}
!macroend

!macro CORA_COWORK_RECORD_ACTIVE_INSTALLER_MARKER
  nsExec::ExecToStack `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$marker = Join-Path $$env:TEMP '${CORA_COWORK_ACTIVE_INSTALLER_MARKER}'; \
    if (-not (Test-Path -LiteralPath $$marker)) { Write-Output 'missing'; exit 0 }; \
    $$item = Get-Item -LiteralPath $$marker; \
    if ($$item.LastWriteTime -lt (Get-Date).AddHours(-2)) { Write-Output 'stale'; exit 0 }; \
    Write-Output 'active' \
  }"`
  Pop $CoraCoworkActiveMarkerExecResult
  Pop $CoraCoworkActiveMarkerResult
  ${If} $CoraCoworkActiveMarkerResult == "active"
    !insertmacro CORA_COWORK_SLOG "event=installer-active-marker state=active"
  ${ElseIf} $CoraCoworkActiveMarkerResult == "stale"
    !insertmacro CORA_COWORK_SLOG "event=installer-active-marker state=stale"
  ${Else}
    !insertmacro CORA_COWORK_SLOG "event=installer-active-marker state=missing"
  ${EndIf}
!macroend

!macro CORA_COWORK_WRITE_ACTIVE_INSTALLER_MARKER
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$marker = Join-Path $$env:TEMP '${CORA_COWORK_ACTIVE_INSTALLER_MARKER}'; \
    Set-Content -LiteralPath $$marker -Encoding UTF8 -Value ('pid=' + $$PID + ';session=$CoraCoworkSessionId;started=' + (Get-Date -Format o)) \
  }"`
  Pop $CoraCoworkActiveMarkerResult
!macroend

!macro CORA_COWORK_CLEAR_ACTIVE_INSTALLER_MARKER
  !ifndef BUILD_UNINSTALLER
    nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
      $$ErrorActionPreference = 'SilentlyContinue'; \
      Remove-Item -LiteralPath (Join-Path $$env:TEMP '${CORA_COWORK_ACTIVE_INSTALLER_MARKER}') -Force \
    }"`
    Pop $CoraCoworkActiveMarkerResult
  !endif
!macroend

!macro CORA_COWORK_OVERRIDE_SINGLE_INSTANCE
!macroend

!macro CORA_COWORK_OVERRIDE_APP_CANNOT_BE_CLOSED_MESSAGE
  !pragma warning disable 6030
  LangString appCannotBeClosed 1033 "${CORA_COWORK_MSG_APP_CANNOT_BE_CLOSED_ZH}$\r$\n$\r$\n${CORA_COWORK_MSG_BLOCK_SEPARATOR}$\r$\n$\r$\n${CORA_COWORK_MSG_APP_CANNOT_BE_CLOSED_EN}"
  LangString appCannotBeClosed 2052 "${CORA_COWORK_MSG_APP_CANNOT_BE_CLOSED_ZH}$\r$\n$\r$\n${CORA_COWORK_MSG_BLOCK_SEPARATOR}$\r$\n$\r$\n${CORA_COWORK_MSG_APP_CANNOT_BE_CLOSED_EN}"
  !pragma warning default 6030
!macroend

!macro CORA_COWORK_INSTALLER_CUSTOM_HEADER
  !insertmacro CORA_COWORK_OVERRIDE_SINGLE_INSTANCE
  !insertmacro CORA_COWORK_OVERRIDE_APP_CANNOT_BE_CLOSED_MESSAGE
!macroend

!macro CORA_COWORK_RELEASE_INSTALL_DIR_OUTDIR
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  StrCpy $CoraCoworkCurrentOutDir "$PLUGINSDIR"
!macroend

!macro CORA_COWORK_INSTALLER_PREINIT
  !ifdef BUILD_UNINSTALLER
    StrCpy $CoraCoworkSessionId ""
    StrCpy $CoraCoworkIsUpdated "0"
    StrCpy $CoraCoworkSessionLogResult ""
    StrCpy $CoraCoworkSessionLogPath "$TEMP\${CORA_COWORK_FALLBACK_LOG}"
    StrCpy $CoraCoworkUninstallHadErrors "0"
    StrCpy $CoraCoworkUninstallLogResult ""
    StrCpy $CoraCoworkVerifyResourceResult ""
    StrCpy $CoraCoworkUpdatedAppExitWaitResult ""
    StrCpy $CoraCoworkActiveMarkerExecResult ""
    StrCpy $CoraCoworkActiveMarkerResult ""
    StrCpy $CoraCoworkStopResult ""
    StrCpy $CoraCoworkLockerListZh ""
    StrCpy $CoraCoworkLockerListEn ""
  !else
    !insertmacro CORA_COWORK_RELEASE_INSTALL_DIR_OUTDIR
    !insertmacro CORA_COWORK_SESSION_BEGIN
    !insertmacro CORA_COWORK_SLOG "event=installer-outdir-release outDir=$CoraCoworkCurrentOutDir instDir=$INSTDIR"
    !insertmacro CORA_COWORK_BRING_UPDATED_INSTALLER_TO_FRONT
    !insertmacro CORA_COWORK_RECORD_ACTIVE_INSTALLER_MARKER
    !insertmacro CORA_COWORK_WRITE_ACTIVE_INSTALLER_MARKER
  !endif
!macroend

!macro CORA_COWORK_VERIFY_REQUIRED_FILE _PATH _LABEL
  ${IfNot} ${FileExists} "${_PATH}"
    !insertmacro CORA_COWORK_LOG_EVENT "verify-required-file missing label=${_LABEL} path=${_PATH}"
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_CORE_APP_FILES_INCOMPLETE}" \
      "verify-required-file missing label=${_LABEL} path=${_PATH}" \
      "${CORA_COWORK_MSG_VERIFY_REQUIRED_FILE_ZH} ${_LABEL}" \
      "${CORA_COWORK_MSG_VERIFY_REQUIRED_FILE_EN} ${_LABEL}" \
      "${CORA_COWORK_MSG_VERIFY_REQUIRED_FILE_ACTION_ZH}" \
      "${CORA_COWORK_MSG_VERIFY_REQUIRED_FILE_ACTION_EN}" \
      "verify-required-file missing label=${_LABEL} path=${_PATH}" \
      "verify-required-file missing label=${_LABEL} path=${_PATH}"
  ${Else}
    !insertmacro CORA_COWORK_LOG_EVENT "verify-required-file ok label=${_LABEL} path=${_PATH}"
  ${EndIf}
!macroend

!macro CORA_COWORK_VERIFY_CORE_APP_FILES
  !insertmacro CORA_COWORK_LOG_EVENT "verify-install start instDir=$INSTDIR"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\CoraCowork.exe" "CoraCowork.exe"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\ffmpeg.dll" "ffmpeg.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\libEGL.dll" "libEGL.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\libGLESv2.dll" "libGLESv2.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\d3dcompiler_47.dll" "d3dcompiler_47.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\dxcompiler.dll" "dxcompiler.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\dxil.dll" "dxil.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\vk_swiftshader.dll" "vk_swiftshader.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\vulkan-1.dll" "vulkan-1.dll"
  !insertmacro CORA_COWORK_VERIFY_REQUIRED_FILE "$INSTDIR\resources\app.asar" "resources\app.asar"
!macroend

!macro CORA_COWORK_VERIFY_BUNDLED_CoraCore_RESOURCES _RUNTIME_KEY
  InitPluginsDir
  File "/oname=$PLUGINSDIR\verify-bundled-cora-cowork-install.ps1" "${PROJECT_DIR}\resources\windows\support\verify-bundled-cora-cowork-install.ps1"
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\verify-bundled-cora-cowork-install.ps1" -InstallDir "$INSTDIR" -RuntimeKey "${_RUNTIME_KEY}" -LogPath "$CoraCoworkSessionLogPath"`
  Pop $CoraCoworkVerifyResourceResult

  ${If} $CoraCoworkVerifyResourceResult != 0
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_BUNDLED_CoraCore_INCOMPLETE}" \
      "event=session-end result=fail code=${CORA_COWORK_E_BUNDLED_CoraCore_INCOMPLETE} detail=bundled-cora-cowork-incomplete runtime=${_RUNTIME_KEY} result=$CoraCoworkVerifyResourceResult" \
      "${CORA_COWORK_MSG_BUNDLED_CoraCore_INCOMPLETE_ZH}" \
      "${CORA_COWORK_MSG_BUNDLED_CoraCore_INCOMPLETE_EN}" \
      "${CORA_COWORK_MSG_BUNDLED_CoraCore_INCOMPLETE_ACTION_ZH}" \
      "${CORA_COWORK_MSG_BUNDLED_CoraCore_INCOMPLETE_ACTION_EN}" \
      "bundled-cora-cowork-incomplete runtime=${_RUNTIME_KEY} result=$CoraCoworkVerifyResourceResult instDir=$INSTDIR" \
      "bundled-cora-cowork-incomplete runtime=${_RUNTIME_KEY} result=$CoraCoworkVerifyResourceResult instDir=$INSTDIR"
  ${EndIf}
!macroend

!macro customInstall
  !insertmacro CORA_COWORK_VERIFY_CORE_APP_FILES
  !insertmacro CORA_COWORK_VERIFY_BUNDLED_CoraCore_RESOURCES "${CORA_COWORK_RUNTIME_KEY}"
  !insertmacro CORA_COWORK_LOG_EVENT "verify-install ok instDir=$INSTDIR"
  !insertmacro CORA_COWORK_CLEAR_ACTIVE_INSTALLER_MARKER
  !insertmacro CORA_COWORK_SESSION_SUCCESS
!macroend

!endif
