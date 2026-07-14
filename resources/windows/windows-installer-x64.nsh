; x64 architecture entry for the NSIS installer.

!include "x64.nsh"

!define CORA_COWORK_TARGET_ARCH "x64"
!define CORA_COWORK_RUNTIME_KEY "win32-x64"
!define CORA_COWORK_EXTRACT_METHOD "7z"

!addincludedir "${PROJECT_DIR}\resources\windows"
!include "installer-common.nsh"

!macro customHeader
  !insertmacro CORA_COWORK_INSTALLER_CUSTOM_HEADER
!macroend

!macro preInit
  !insertmacro CORA_COWORK_INSTALLER_PREINIT
!macroend

!macro customFiles_x64
  !insertmacro CORA_COWORK_LOG_EXTRACT_RESULT "7z"
!macroend

Function .onVerifyInstDir
  ${IfNot} ${RunningX64}
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_ARCH_MISMATCH}" \
      "target=x64 actual=x86" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_EN}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_EN}" \
      "target=x64 actual=x86" \
      "target=x64 actual=x86"
  ${EndIf}

  ${If} ${IsNativeARM64}
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_ARCH_MISMATCH}" \
      "target=x64 actual=arm64" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_EN}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_EN}" \
      "target=x64 actual=arm64" \
      "target=x64 actual=arm64"
  ${EndIf}
FunctionEnd
