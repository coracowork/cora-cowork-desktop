!ifndef CORA_COWORK_INSTALLER_REMOVE_REGISTRY_NSH
!define CORA_COWORK_INSTALLER_REMOVE_REGISTRY_NSH

!macro CORA_COWORK_CLEAR_INSTALL_REGISTRY _REASON
  DeleteRegKey SHCTX "${UNINSTALL_REGISTRY_KEY}"
  DeleteRegKey SHCTX "${INSTALL_REGISTRY_KEY}"
  !insertmacro CORA_COWORK_LOG_EVENT "event=registry-clear reason=${_REASON} uninstallKey=${UNINSTALL_REGISTRY_KEY} installKey=${INSTALL_REGISTRY_KEY}"
!macroend

!macro CORA_COWORK_LOG_ATOMIC_REMOVE_FAILURE
  Push $9
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$failed = '$CoraCoworkAtomicFailedPath'; \
    $$instDir = '$INSTDIR'; \
    $$oldInstallDir = '$CoraCoworkAtomicStagingDir'; \
    $$relative = $$failed; \
    if ($$failed.StartsWith($$instDir, [System.StringComparison]::CurrentCultureIgnoreCase)) { $$relative = $$failed.Substring($$instDir.Length).TrimStart('\') }; \
    $$tempCandidate = if ($$relative -and $$relative -ne $$failed) { Join-Path $$oldInstallDir $$relative } else { '' }; \
    $$kind = if ($$tempCandidate.Length -ge 260) { 'likely-long-path' } else { 'unknown' }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = '$CoraCoworkSessionId'; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = 'remove-atomic-failed'; kind = $$kind; pathLength = $$failed.Length; tempCandidateLength = $$tempCandidate.Length; atomicFailedPath = $$failed; tempCandidate = $$tempCandidate }; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value ($$payload | ConvertTo-Json -Compress -Depth 8) \
  }"`
  Pop $9
  Pop $9
!macroend

!macro CORA_COWORK_LOG_REMOVE_FAILURE_JSON _PHASE _FATAL _FAILED_PATH _EXTRA_FIELDS
  !insertmacro CORA_COWORK_LOG_JSON_EVENT "failure" "$$lockerText = '$CoraCoworkLockerList'; $$processes = @(); if ($$lockerText -and $$lockerText -notlike 'Windows did not identify*' -and $$lockerText -ne 'unknown process') { $$processes = @($$lockerText -split ',\s*' | Where-Object { $$_ } | ForEach-Object { if ($$_ -match '^(.*)\(([0-9]+)\)$$') { [ordered]@{ name = $$Matches[1]; pid = [int]$$Matches[2] } } else { [ordered]@{ name = $$_; pid = $$null } } }) }; $$payload.code = '${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED}'; $$payload.phase = '${_PHASE}'; $$payload.failedPath = '${_FAILED_PATH}'; $$payload.blockingProcesses = @($$processes); if ($$lockerText -like 'CoraCowork installer(*)') { $$payload.fallbackReason = 'installer-self-lock'; $$payload.message = 'The installer process is using the install directory as its current output directory.' } elseif ($$processes.Count -eq 0) { $$payload.fallbackReason = 'restart-manager-no-process'; $$payload.message = 'Windows did not identify a specific locking process. Close terminals, editors, and file managers opened in the install folder.' } else { $$payload.fallbackReason = ''; $$payload.message = '' }; $$payload.fatal = ('${_FATAL}' -eq '1'); ${_EXTRA_FIELDS}"
!macroend

!macro CORA_COWORK_REMOVE_INSTALL_DIR
  StrCpy $CoraCoworkRemoveResidueCount "0"
  ${If} $CoraCoworkRemoveResidueRoot == ""
    StrCpy $CoraCoworkRemoveResidueRoot "$INSTDIR"
  ${EndIf}
  StrCpy $CoraCoworkRemoveFirstFailedPath ""
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'Continue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$path = [System.IO.Path]::GetFullPath('$CoraCoworkRemoveResidueRoot'); \
    $$firstFailedFile = '$PLUGINSDIR\cora-cowork-remove-first-failed.txt'; \
    Set-Content -LiteralPath $$firstFailedFile -Encoding UTF8 -NoNewline -Value ''; \
    function Write-InstallerLog($$message) { $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = '$CoraCoworkSessionId'; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = 'remove-log'; message = $$message }; if ($$message -match '(^|\s)event=([^\s]+)') { $$payload.event = $$Matches[2] }; Add-Content -LiteralPath $$log -Encoding UTF8 -Value ($$payload | ConvertTo-Json -Compress -Depth 8) } \
    function Convert-LongPath($$itemPath) { if ($$itemPath.StartsWith('\\')) { return '\\?\UNC\' + $$itemPath.TrimStart('\') } return '\\?\' + $$itemPath } \
    function Remove-WithRetries($$item, $$isDir) { \
      $$delays = @(200,500,1000); \
      for ($$i = 0; $$i -lt $$delays.Count; $$i++) { \
        try { \
          if ($$isDir) { [System.IO.Directory]::Delete((Convert-LongPath $$item), $$false) } else { [System.IO.File]::Delete((Convert-LongPath $$item)) } \
          return $$true \
        } catch { \
          if ($$i -lt $$delays.Count - 1) { Start-Sleep -Milliseconds $$delays[$$i] } else { Write-InstallerLog ('event=remove-resilient-leftover path=' + $$item + ' attempts=3 error=' + $$_.Exception.GetType().FullName + ': ' + $$_.Exception.Message); return $$false } \
        } \
      } \
      return $$false \
    } \
    try { \
      if (-not (Test-Path -LiteralPath $$path)) { Write-InstallerLog ('remove-longpath result=0 instDir=' + $$path); exit 0 } \
      $$failed = New-Object System.Collections.Generic.List[string]; \
      foreach ($$file in @(Get-ChildItem -LiteralPath $$path -Force -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)) { if (-not (Remove-WithRetries $$file.FullName $$false)) { $$failed.Add($$file.FullName) } } \
      foreach ($$dir in @(Get-ChildItem -LiteralPath $$path -Force -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)) { if (-not (Remove-WithRetries $$dir.FullName $$true)) { $$failed.Add($$dir.FullName) } } \
      if (-not (Remove-WithRetries $$path $$true)) { $$failed.Add($$path) } \
      Write-InstallerLog ('event=remove-resilient-summary failedCount=' + $$failed.Count + ' root=' + $$path); \
      if ($$failed.Count -gt 0) { Set-Content -LiteralPath $$firstFailedFile -Encoding UTF8 -NoNewline -Value $$failed[0]; exit $$failed.Count } \
      Write-InstallerLog ('remove-longpath result=0 instDir=' + $$path); \
      exit 0 \
    } catch { \
      Write-InstallerLog ('remove-longpath result=1 instDir=' + $$path + ' error=' + $$_.Exception.GetType().FullName + ': ' + $$_.Exception.Message); \
      exit 1 \
    } \
  }"`
  Pop $CoraCoworkRemoveDirResult

  ClearErrors
  SetDetailsPrint none
  FileOpen $CoraCoworkRemoveFirstFailedFile "$PLUGINSDIR\cora-cowork-remove-first-failed.txt" r
  ${IfNot} ${Errors}
    FileRead $CoraCoworkRemoveFirstFailedFile $CoraCoworkRemoveFirstFailedPath
    FileClose $CoraCoworkRemoveFirstFailedFile
  ${EndIf}
  SetDetailsPrint lastused

  ${If} $CoraCoworkRemoveDirResult == "error"
    !insertmacro CORA_COWORK_LOG_EVENT "event=remove-longpath fallback=RMDir reason=no-powershell root=$INSTDIR"
    RMDir /r "$CoraCoworkRemoveResidueRoot"
    ${If} ${FileExists} "$CoraCoworkRemoveResidueRoot\*.*"
      StrCpy $CoraCoworkRemoveDirResult "1"
    ${Else}
      StrCpy $CoraCoworkRemoveDirResult "0"
    ${EndIf}
  ${EndIf}

  ${If} $CoraCoworkRemoveDirResult != 0
    StrCpy $CoraCoworkRemoveResidueCount $CoraCoworkRemoveDirResult
  ${EndIf}
!macroend

!macro customRemoveFiles
  !insertmacro CORA_COWORK_LOG_EVENT "remove-start instDir=$INSTDIR"
  Var /GLOBAL CoraCoworkRemoveDirResult
  Var /GLOBAL CoraCoworkAtomicFailedPath
  Var /GLOBAL CoraCoworkAtomicRemoveSucceeded
  Var /GLOBAL CoraCoworkAtomicStagingDir
  Var /GLOBAL CoraCoworkRemoveResidueCount
  Var /GLOBAL CoraCoworkRemoveResidueRoot
  Var /GLOBAL CoraCoworkRemoveFirstFailedPath
  Var /GLOBAL CoraCoworkRemoveFirstFailedFile
  StrCpy $CoraCoworkAtomicFailedPath ""
  StrCpy $CoraCoworkAtomicRemoveSucceeded "0"
  StrCpy $CoraCoworkAtomicStagingDir ""
  StrCpy $CoraCoworkRemoveResidueCount "0"
  StrCpy $CoraCoworkRemoveResidueRoot "$INSTDIR"
  StrCpy $CoraCoworkRemoveFirstFailedPath ""

  SetOutPath $TEMP
  StrCpy $CoraCoworkCurrentOutDir "$TEMP"

  ${if} ${isUpdated}
    StrCpy $CoraCoworkAtomicStagingDir "$INSTDIR.__old"
    ${If} ${FileExists} "$CoraCoworkAtomicStagingDir\*.*"
      StrCpy $CoraCoworkRemoveResidueRoot "$CoraCoworkAtomicStagingDir"
      !insertmacro CORA_COWORK_LOG_EVENT "remove-stale-staging start root=$CoraCoworkRemoveResidueRoot"
      !insertmacro CORA_COWORK_REMOVE_INSTALL_DIR
      StrCpy $CoraCoworkRemoveResidueRoot "$INSTDIR"
    ${EndIf}

    cora-cowork_retry_atomic_rename:
      ClearErrors
      Rename "$INSTDIR" "$CoraCoworkAtomicStagingDir"
    ${if} ${Errors}
      DetailPrint "Atomic update cleanup failed before replacing previous installation: $INSTDIR"
      StrCpy $CoraCoworkAtomicFailedPath "$INSTDIR"
      !insertmacro CORA_COWORK_LOG_ATOMIC_REMOVE_FAILURE
      !insertmacro CORA_COWORK_CAPTURE_FAILED_PATH_LOCKERS "$CoraCoworkAtomicFailedPath"
      ${IfNot} ${Silent}
        !insertmacro CORA_COWORK_PROMPT_FAILED_PATH_LOCKERS "$CoraCoworkAtomicFailedPath" "atomic-failed" cora-cowork_retry_atomic_rename cora-cowork_cancel_atomic_rename cora-cowork_continue_atomic_failed
        cora-cowork_cancel_atomic_rename:
      ${EndIf}
      cora-cowork_continue_atomic_failed:
      !insertmacro CORA_COWORK_LOG_REMOVE_FAILURE_JSON "atomic-failed" "1" "$CoraCoworkAtomicFailedPath" "$$payload.atomicFailedPath = '$CoraCoworkAtomicFailedPath'"
      !insertmacro CORA_COWORK_LOG_EVENT "code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=atomic-failed fatal=1 degraded=none firstFailed=$CoraCoworkAtomicFailedPath atomicFailedPath=$CoraCoworkAtomicFailedPath"
      !insertmacro CORA_COWORK_CLEAR_INSTALL_REGISTRY "remove-failed-before-quit"
      !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} "event=session-end result=fail code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=atomic-failed fatal=1 firstFailed=$CoraCoworkAtomicFailedPath lockers=$CoraCoworkLockerList" "${CORA_COWORK_MSG_REPLACE_LOCKED_EN}" "${CORA_COWORK_MSG_REPLACE_LOCKED_ZH}" "${CORA_COWORK_MSG_CLOSE_SHOWN_FILE_ACTION_EN}" "${CORA_COWORK_MSG_CLOSE_SHOWN_FILE_ACTION_ZH}"
    ${else}
      !insertmacro CORA_COWORK_LOG_EVENT "remove-atomic result=0 staging=$CoraCoworkAtomicStagingDir"
      StrCpy $CoraCoworkAtomicRemoveSucceeded "1"
      StrCpy $CoraCoworkRemoveResidueRoot "$CoraCoworkAtomicStagingDir"
    ${endif}
  ${endif}

  cora-cowork_retry_remove_install_dir:
    !insertmacro CORA_COWORK_REMOVE_INSTALL_DIR
  ${if} $CoraCoworkRemoveDirResult != 0
    !insertmacro CORA_COWORK_CAPTURE_FAILED_PATH_LOCKERS "$CoraCoworkRemoveFirstFailedPath"
    ${if} $CoraCoworkAtomicRemoveSucceeded == "1"
      ${IfNot} ${Silent}
        !insertmacro CORA_COWORK_PROMPT_FAILED_PATH_LOCKERS "$CoraCoworkRemoveFirstFailedPath" "residual-delete-failed" cora-cowork_retry_remove_install_dir cora-cowork_cancel_remove_after_rm cora-cowork_continue_after_rm
        cora-cowork_cancel_remove_after_rm:
          !insertmacro CORA_COWORK_LOG_REMOVE_FAILURE_JSON "residual-delete-failed" "1" "$CoraCoworkRemoveFirstFailedPath" "$$payload.residueRoot = '$CoraCoworkRemoveResidueRoot'; $$payload.failedCount = '$CoraCoworkRemoveResidueCount'; $$payload.removeDirResult = '$CoraCoworkRemoveDirResult'; $$payload.atomicSucceeded = ('$CoraCoworkAtomicRemoveSucceeded' -eq '1')"
          !insertmacro CORA_COWORK_LOG_EVENT "code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=residual-delete-failed userAction=cancel fatal=1 residueRoot=$CoraCoworkRemoveResidueRoot failedCount=$CoraCoworkRemoveResidueCount firstFailed=$CoraCoworkRemoveFirstFailedPath removeDirResult=$CoraCoworkRemoveDirResult removeResidueCount=$CoraCoworkRemoveResidueCount atomicFailedPath=$CoraCoworkAtomicFailedPath atomicSucceeded=$CoraCoworkAtomicRemoveSucceeded"
          !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} "event=session-end result=fail code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=residual-delete-failed userAction=cancel fatal=1 firstFailed=$CoraCoworkRemoveFirstFailedPath lockers=$CoraCoworkLockerList" "${CORA_COWORK_MSG_PREVIOUS_FILE_OPEN_EN}" "${CORA_COWORK_MSG_PREVIOUS_FILE_OPEN_ZH}" "${CORA_COWORK_MSG_CLOSE_SHOWN_FILE_ACTION_EN}" "${CORA_COWORK_MSG_CLOSE_SHOWN_FILE_ACTION_ZH}"
      ${EndIf}
      cora-cowork_continue_after_rm:
      DetailPrint `CoraCowork previous installation had locked residual files; continuing after atomic cleanup succeeded: $INSTDIR`
      !insertmacro CORA_COWORK_LOG_EVENT "code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=residual-delete-failed degraded=continue fatal=0 residueRoot=$CoraCoworkRemoveResidueRoot failedCount=$CoraCoworkRemoveResidueCount firstFailed=$CoraCoworkRemoveFirstFailedPath removeDirResult=$CoraCoworkRemoveDirResult removeResidueCount=$CoraCoworkRemoveResidueCount atomicFailedPath=$CoraCoworkAtomicFailedPath atomicSucceeded=$CoraCoworkAtomicRemoveSucceeded"
    ${else}
      DetailPrint `Can't safely remove previous installation without atomic cleanup proof: $INSTDIR`
      ${IfNot} ${Silent}
        !insertmacro CORA_COWORK_PROMPT_FAILED_PATH_LOCKERS "$CoraCoworkRemoveFirstFailedPath" "residual-delete-failed-no-atomic-proof" cora-cowork_retry_remove_install_dir cora-cowork_cancel_remove_no_atomic cora-cowork_continue_remove_no_atomic
        cora-cowork_cancel_remove_no_atomic:
      ${EndIf}
      cora-cowork_continue_remove_no_atomic:
      !insertmacro CORA_COWORK_LOG_REMOVE_FAILURE_JSON "residual-delete-failed-no-atomic-proof" "1" "$CoraCoworkRemoveFirstFailedPath" "$$payload.residueRoot = '$CoraCoworkRemoveResidueRoot'; $$payload.failedCount = '$CoraCoworkRemoveResidueCount'; $$payload.removeDirResult = '$CoraCoworkRemoveDirResult'; $$payload.atomicSucceeded = ('$CoraCoworkAtomicRemoveSucceeded' -eq '1')"
      !insertmacro CORA_COWORK_LOG_EVENT "code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=residual-delete-failed-no-atomic-proof degraded=none fatal=1 residueRoot=$CoraCoworkRemoveResidueRoot failedCount=$CoraCoworkRemoveResidueCount firstFailed=$CoraCoworkRemoveFirstFailedPath removeDirResult=$CoraCoworkRemoveDirResult removeResidueCount=$CoraCoworkRemoveResidueCount atomicFailedPath=$CoraCoworkAtomicFailedPath atomicSucceeded=$CoraCoworkAtomicRemoveSucceeded"
      !insertmacro CORA_COWORK_CLEAR_INSTALL_REGISTRY "remove-failed-before-quit"
      !insertmacro CORA_COWORK_FAIL_REPORTABLE_BILINGUAL ${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} "event=session-end result=fail code=${CORA_COWORK_E_INSTALL_DIR_REMOVE_OR_LOCKED} phase=residual-delete-failed-no-atomic-proof fatal=1 firstFailed=$CoraCoworkRemoveFirstFailedPath removeDirResult=$CoraCoworkRemoveDirResult lockers=$CoraCoworkLockerList" "${CORA_COWORK_MSG_REMOVE_PREVIOUS_DIR_EN}" "${CORA_COWORK_MSG_REMOVE_PREVIOUS_DIR_ZH}" "${CORA_COWORK_MSG_CLOSE_INSTALL_DIR_ACTION_EN}" "${CORA_COWORK_MSG_CLOSE_INSTALL_DIR_ACTION_ZH}"
    ${endif}
  ${else}
    !insertmacro CORA_COWORK_LOG_EVENT "remove-final errors=0 instDir=$INSTDIR removeDirResult=$CoraCoworkRemoveDirResult removeResidueCount=$CoraCoworkRemoveResidueCount removeResidueRoot=$CoraCoworkRemoveResidueRoot atomicFailedPath=$CoraCoworkAtomicFailedPath atomicSucceeded=$CoraCoworkAtomicRemoveSucceeded"
  ${endif}
!macroend

!macro customUnInit
  !insertmacro CORA_COWORK_LOG_EVENT "uninit instDir=$INSTDIR"
!macroend

!macro customUnInstall
  !insertmacro CORA_COWORK_LOG_EVENT "uninstall-section start instDir=$INSTDIR"
!macroend

!endif
