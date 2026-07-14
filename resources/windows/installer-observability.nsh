!ifndef CORA_COWORK_INSTALLER_OBSERVABILITY_NSH
!define CORA_COWORK_INSTALLER_OBSERVABILITY_NSH

!define CORA_COWORK_APP_EXECUTABLE_FILENAME "CoraCowork.exe"
!define CORA_COWORK_FALLBACK_LOG "cora-cowork-installer-${VERSION}-fallback-log.jsonl"

!pragma warning disable 6001
Var /GLOBAL CoraCoworkSessionId
Var /GLOBAL CoraCoworkIsUpdated
Var /GLOBAL CoraCoworkSessionLogResult
Var /GLOBAL CoraCoworkSessionLogPath

!macro CORA_COWORK_SESSION_HEADER
  !insertmacro CORA_COWORK_SLOG "event=header arch=${CORA_COWORK_TARGET_ARCH} updated=$CoraCoworkIsUpdated instDir=$INSTDIR version=${VERSION} log=$CoraCoworkSessionLogPath detail=customHeader"
!macroend

!macro CORA_COWORK_SLOG _MESSAGE
  Push $9
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$session = '$CoraCoworkSessionId'; \
    if (-not $$session) { $$session = 'uninitialized' }; \
    $$message = '${_MESSAGE}'; \
    $$event = 'log'; \
    if ($$message -match '(^|\s)event=([^\s]+)') { $$event = $$Matches[2] } else { $$first = @($$message -split '\s+', 2)[0]; if ($$first -and $$first -notmatch '=') { $$event = $$first } }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = $$session; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = $$event; message = $$message }; \
    $$json = $$payload | ConvertTo-Json -Compress -Depth 8; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value $$json \
  }"`
  Pop $9
  Pop $9
!macroend

!macro CORA_COWORK_LOG_EVENT _MESSAGE
  Push $9
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$session = '$CoraCoworkSessionId'; \
    if (-not $$session) { $$session = 'uninitialized' }; \
    $$message = '${_MESSAGE}'; \
    $$event = 'log'; \
    if ($$message -match '(^|\s)event=([^\s]+)') { $$event = $$Matches[2] } else { $$first = @($$message -split '\s+', 2)[0]; if ($$first -and $$first -notmatch '=') { $$event = $$first } }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = $$session; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = $$event; message = $$message }; \
    $$json = $$payload | ConvertTo-Json -Compress -Depth 8; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value $$json \
  }"`
  Pop $9
  Pop $9
!macroend

!macro CORA_COWORK_LOG_JSON_EVENT _EVENT _JSON_FIELDS
  Push $9
  nsExec::Exec `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "& { \
    $$ErrorActionPreference = 'SilentlyContinue'; \
    $$log = '$CoraCoworkSessionLogPath'; \
    if (-not $$log) { $$log = Join-Path $$env:TEMP '${CORA_COWORK_FALLBACK_LOG}' }; \
    $$session = '$CoraCoworkSessionId'; \
    if (-not $$session) { $$session = 'uninitialized' }; \
    $$payload = [ordered]@{ schemaVersion = 1; ts = (Get-Date -Format o); session = $$session; version = '${VERSION}'; arch = '${CORA_COWORK_TARGET_ARCH}'; updated = ('$CoraCoworkIsUpdated' -eq '1'); instDir = '$INSTDIR'; event = '${_EVENT}' }; \
    ${_JSON_FIELDS}; \
    $$json = $$payload | ConvertTo-Json -Compress -Depth 8; \
    Add-Content -LiteralPath $$log -Encoding UTF8 -Value $$json \
  }"`
  Pop $9
  Pop $9
!macroend

!macro CORA_COWORK_SESSION_BEGIN
  ${GetParameters} $R9
  ClearErrors
  ${GetOptions} $R9 "--installer-log=" $R8
  ${IfNot} ${Errors}
    StrCpy $CoraCoworkSessionLogPath $R8
  ${EndIf}
  ClearErrors
  ${GetOptions} $R9 "--installer-session=" $R8
  ${IfNot} ${Errors}
    StrCpy $CoraCoworkSessionId $R8
  ${EndIf}

  ${If} $CoraCoworkSessionLogPath == ""
    nsExec::ExecToStack `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$$id = '$CoraCoworkSessionId'; if (-not $$id) { $$id = [guid]::NewGuid().ToString('N').Substring(0,12) }; $$stamp = Get-Date -Format 'yyyyMMdd'; $$name = 'cora-cowork-installer-${VERSION}-' + $$stamp + '-log.jsonl'; $$log = Join-Path $$env:TEMP $$name; [Console]::Out.Write($$id + '|' + $$log)"`
    Pop $CoraCoworkSessionLogResult
    Pop $CoraCoworkSessionLogResult
    StrCpy $CoraCoworkSessionId $CoraCoworkSessionLogResult 12
    StrCpy $CoraCoworkSessionLogPath $CoraCoworkSessionLogResult 1024 13
  ${ElseIf} $CoraCoworkSessionId == ""
    nsExec::ExecToStack `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "[Console]::Out.Write([guid]::NewGuid().ToString('N').Substring(0,12))"`
    Pop $CoraCoworkSessionLogResult
    Pop $CoraCoworkSessionLogResult
    StrCpy $CoraCoworkSessionId $CoraCoworkSessionLogResult
  ${EndIf}

  ClearErrors
  ${GetOptions} $R9 "--updated" $R8
  StrCpy $CoraCoworkIsUpdated "0"
  ${IfNot} ${Errors}
    StrCpy $CoraCoworkIsUpdated "1"
  ${EndIf}

  !insertmacro CORA_COWORK_SLOG "event=session-begin detail=preInit"
!macroend

!macro CORA_COWORK_LOG_EXTRACT_RESULT _METHOD
  ${IfNot} ${FileExists} "$INSTDIR\CoraCowork.exe"
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_EXTRACT_FAILED}" \
      "event=extract result=fail method=${_METHOD} missing=CoraCowork.exe" \
      "${CORA_COWORK_MSG_EXTRACT_FAILED_ZH}" \
      "${CORA_COWORK_MSG_EXTRACT_FAILED_EN}" \
      "${CORA_COWORK_MSG_EXTRACT_FAILED_ACTION_ZH}" \
      "${CORA_COWORK_MSG_EXTRACT_FAILED_ACTION_EN}" \
      "extract result=fail method=${_METHOD} missing=CoraCowork.exe instDir=$INSTDIR" \
      "extract result=fail method=${_METHOD} missing=CoraCowork.exe instDir=$INSTDIR"
  ${Else}
    !insertmacro CORA_COWORK_SLOG "event=extract result=ok method=${_METHOD} detail=customFiles_${CORA_COWORK_TARGET_ARCH}"
  ${EndIf}
!macroend

!macro CORA_COWORK_SESSION_SUCCESS
  !insertmacro CORA_COWORK_SLOG "event=session-end result=success detail=customInstall"
!macroend

!endif
