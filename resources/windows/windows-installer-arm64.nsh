; ARM64 architecture entry for the NSIS installer.

!include "x64.nsh"

!define CORA_COWORK_TARGET_ARCH "arm64"
!define CORA_COWORK_RUNTIME_KEY "win32-arm64"
!define CORA_COWORK_EXTRACT_METHOD "zip"

!addincludedir "${PROJECT_DIR}\resources\windows"
!include "installer-common.nsh"

!macro customHeader
  !insertmacro CORA_COWORK_INSTALLER_CUSTOM_HEADER
!macroend

!macro preInit
  !insertmacro CORA_COWORK_INSTALLER_PREINIT
!macroend

!macro customFiles_arm64
  !insertmacro CORA_COWORK_LOG_EXTRACT_RESULT "zip"
!macroend

Function .onVerifyInstDir
  ${IfNot} ${IsNativeARM64}
    !insertmacro CORA_COWORK_FAIL_UX \
      "${CORA_COWORK_E_ARCH_MISMATCH}" \
      "target=arm64 actual=non-arm64" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_EN}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_ZH}" \
      "${CORA_COWORK_MSG_ARCH_MISMATCH_ACTION_EN}" \
      "target=arm64 actual=non-arm64" \
      "target=arm64 actual=non-arm64"
  ${EndIf}
FunctionEnd
