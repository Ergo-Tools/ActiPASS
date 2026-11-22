; engine-hooks.nsh  NSIS hooks of the Actipass installer (tauri.release.conf.json).
;
; After the app is installed, runs the bundled Actipass Engine installer (compiled MATLAB
; engine; it downloads the MATLAB Runtime when missing), unless the same engine version is
; already installed. The engine is a separate program in "Apps"; uninstalling Actipass
; leaves it (other Actipass versions may use it).
;
; SPDX-License-Identifier: GPL-3.0-or-later

!include "FileFunc.nsh"

; Default install folder %ProgramFiles%\Ergo-Tools\Actipass (next to the engine and the
; MATLAB-only ActiPASS) instead of Tauri's %ProgramFiles%\Actipass. Tauri's template
; (2.12) has no hook in .onInit, so this uses MUI's GUI-init callback, which runs after
; .onInit and before the directory page. Only Tauri's fresh default is changed: a /D=
; folder or the folder of an earlier install (it has uninstall.exe) is kept. Silent
; installs have no GUI init and keep Tauri's default. Defines of the template (PRODUCTNAME
; ...) do not exist yet at this point, hence the literal names.
!define MUI_CUSTOMFUNCTION_GUIINIT ActipassGuiInit
Function ActipassGuiInit
  ${If} $INSTDIR == "$PROGRAMFILES64\Actipass"
  ${AndIfNot} ${FileExists} "$INSTDIR\uninstall.exe"
    StrCpy $INSTDIR "$PROGRAMFILES64\Ergo-Tools\Actipass"
  ${EndIf}
FunctionEnd

!define ENGINE_EXE "$PROGRAMFILES64\Ergo-Tools\Actipass Engine\application\actipass_engine.exe"

!macro NSIS_HOOK_POSTINSTALL
  ; bundled engine version (version.txt has no newline)
  StrCpy $R0 ""
  ClearErrors
  FileOpen $R1 "$INSTDIR\engine\version.txt" r
  ${IfNot} ${Errors}
    FileRead $R1 $R0
    FileClose $R1
  ${EndIf}

  ; installed engine version ("2026.11.3.0"), empty if not installed
  StrCpy $R2 ""
  ${If} ${FileExists} "${ENGINE_EXE}"
    ${GetFileVersion} "${ENGINE_EXE}" $R2
  ${EndIf}

  ${If} "$R2" == "$R0.0"
    DetailPrint "Actipass Engine $R0 is already installed"
  ${ElseIf} ${Silent}
    DetailPrint "Silent install: Actipass Engine $R0 not installed (run $INSTDIR\engine\Actipass_Engine_Installer.exe)"
  ${Else}
    MessageBox MB_OK|MB_ICONINFORMATION "Actipass needs the Actipass Engine $R0. Its installer starts when you click OK; it also installs the MATLAB Runtime (downloaded if it is not on this computer yet).$\n$\nPlease be patient: after its splash screen it can take several minutes (on some computers much longer) before the engine installer window appears. Do not start it again meanwhile. This setup continues when the engine installer has finished."
    DetailPrint "Running the Actipass Engine installer (its window can take several minutes to appear)..."
    ExecWait '"$INSTDIR\engine\Actipass_Engine_Installer.exe"' $R3
    DetailPrint "Actipass Engine installer finished ($R3)"
    ${IfNot} ${FileExists} "${ENGINE_EXE}"
      MessageBox MB_OK|MB_ICONEXCLAMATION "The Actipass Engine was not installed. Actipass cannot process data without it.$\n$\nRun $INSTDIR\engine\Actipass_Engine_Installer.exe later to install it."
    ${EndIf}
  ${EndIf}
!macroend
