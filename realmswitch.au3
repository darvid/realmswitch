#cs
   Author:  dave
   License: WTFPL, see COPYING
   Version: 0.1

   This program is free software. It comes without any warranty, to
   the extent permitted by applicable law. You can redistribute it
   and/or modify it under the terms of the Do What The Fuck You Want
   To Public License, Version 2, as published by Sam Hocevar. See
   http://sam.zoy.org/wtfpl/COPYING for more details.
#ce
#include <GUIConstantsEx.au3>
#include <GUIListView.au3>
#include <ButtonConstants.au3>
#include <WindowsConstants.au3>

Opt("TrayIconHide", 1)

$debug = True
$configFile = @ScriptDir & "\settings.ini"
$regexEnabledRealmlist = "(?i)^set realmlist (\S+)(?:\s+#\s+([^#]+)|())?"
$regexDisabledRealmlist = "(?i)^#\s+set realmlist ([^:]+)(?:(?::([^#]+))|())"

Global $listview, $btnNew, $btnEdit, $btnDelete, $btnSave, $btnLaunch

Func Debug($msg)
   If $debug = True Then ConsoleWrite($msg & @CRLF)
EndFunc

Func Error($msg)
   MsgBox(0, "Error", $msg)
EndFunc

Func FatalError($msg)
   Error($msg)
   Exit
EndFunc

Func CreateDefaultConfig()
   If Not FileExists($configFile) Then
      Local $installPath = RegRead("HKLM\SOFTWARE\Blizzard Entertainment\World of Warcraft", "InstallPath")
      Local $mainSection = "wow_dir = " & $installPath
      IniWriteSection($configFile, "main", $mainSection)
   EndIf
EndFunc

Func GetLocale($wow_dir)
   Local $file = FileOpen($wow_dir & "\WTF\Config.wtf", 0)
   If $file = -1 Then
	  SetError(1)
	  Return
   EndIf

   Local $retVal
   While 1
      Local $line = FileReadLine($file)
      If @error = -1 Then ExitLoop
      Local $array = StringRegExp($line, 'SET (\S+) "(.*)"', 1)
      If @error = 0 And $array[0] == "locale" Then
		 $retVal = $array[1]
      EndIf
   WEnd
   FileClose($file)
   Return $retVal
EndFunc

Func ImportRealmlist($realmlist_file)
   Local $file = FileOpen($realmlist_file, 0)
   If $file = -1 Then
	  SetError(1)
	  Return
   EndIf

   Local $realms[10]
   Local $i = 0
   While 1
      Local $line = FileReadLine($file)
      If @error = -1 Then ExitLoop
      Local $match = StringRegExp($line, $regexEnabledRealmlist, 1)
      If @error = 0 Then
         ; Debug(StringFormat("[enabled] url: %s; name: %s", $match[0], $match[1]))
      Else
         Local $match = StringRegExp($line, $regexDisabledRealmlist, 1)
         If @error <> 0 Then ContinueLoop
         ; Debug(StringFormat("[disabled] url: %s; name: %s", $match[0], $match[1]))
      EndIf

      $realms[$i] = $match

      $i += 1
      If $i >= 10 Then
         ReDim $realms[$i + 1]
      EndIf
   WEnd

   FileClose($file)
   Return $realms
EndFunc

Func OnWM_Notify($hWnd, $msgId, $wParam, $lParam)
   Local $tagNMHDR, $event
   If $wParam = $listview Then
      $tagNMHDR = DllStructCreate("int;int;int", $lParam)
      If @error Then Return
      $event = DllStructGetData($tagNMHDR, 3)
      If $event = $NM_CLICK Then
         Local $state
         If BitAND(GUICtrlGetState($btnEdit), $GUI_DISABLE) Then
			$state = $GUI_ENABLE
         ElseIf GUICtrlRead($listview) = 0 Then
			$state = $GUI_DISABLE
         EndIf
		 GUICtrlSetState($btnEdit, $state)
		 GUICtrlSetState($btnDelete, $state)
		 GUICtrlSetState($btnLaunch, $state)
      EndIf
   EndIf
EndFunc

Func GetRealmlistPath($wowDir)
   Return StringFormat("%s\\Data\\%s\\realmlist.wtf", $wowDir, GetLocale($wowDir))
EndFunc

Func UpdateRealmlist($realmlistFile)
   Local $realms = ImportRealmlist($realmlistFile)
   If @error <> 0 Then
	  SetError(@error)
	  Return
   EndIf
   _GUICtrlListView_DeleteAllItems(GUICtrlGetHandle($listview))
   For $realm in $realms
      If IsArray($realm) Then
         GUICtrlCreateListViewItem($realm[1] & "|" & $realm[0], $listview)
      EndIf
   Next
   _GUICtrlListView_SetColumnWidth($listview, 0, $LVSCW_AUTOSIZE_USEHEADER)
   _GUICtrlListView_SetColumnWidth($listview, 1, $LVSCW_AUTOSIZE)
   Local $realmHeaderWidth = _GUICtrlListView_GetColumnWidth($listview, 1)
   Local $windowPos = WinGetPos($mainWindow)
   _GUICtrlListView_SetColumnWidth($listview, 1, $windowPos[2] - $realmHeaderWidth + 28)
   Return $realms
EndFunc

Func SaveRealmlist($realmlistFile, ByRef $realms)
   $activeCtl = GUICtrlRead($listview)
   If $activeCtl = 0 Then
	  MsgBox(48, "Error", "You must select a server to use.")
   Else
	  Local $file = FileOpen($realmlistFile, 2)
	  Local $realmInfo = StringSplit(GUICtrlRead($activeCtl), "|")
	  For $realm in $realms
		 If Not IsArray($realm) Then
			ContinueLoop
		 Else
			If $realm[0] <> $realmInfo[2] Then
			   FileWriteLine($file, "# set realmlist " & $realm[0] & ":" & $realm[1])
			Else
			   FileWriteLine($file, "set realmlist " & $realm[0] & " # " & $realm[1])
			EndIf
		 EndIf
	  Next
	  FileClose($file)
	  GUICtrlSetState($btnSave, $GUI_DISABLE)
   EndIf
EndFunc

Func Main()
   CreateDefaultConfig()
   Local $wowDir = IniRead($configFile, "main", "wow_dir", "")

   Global $mainWindow = GUICreate("Realmswitch", 402, 290, -1, -1, $WS_SIZEBOX)
   GUISetIcon(@ScriptDir & "/WoW_glass.ico")

   $listview = GUICtrlCreateListView("Name|Server", 0, 0, 400, 200, $LVS_SHOWSELALWAYS)
   GUICtrlSetResizing(-1, $GUI_DOCKBORDERS)

   $btnNew = GUICtrlCreateButton("New Server", 0, 200, 80, 40, $BS_MULTILINE)
   $btnEdit = GUICtrlCreateButton("Edit Server", 80, 200, 80, 40, $BS_MULTILINE)
   $btnDelete = GUICtrlCreateButton("Delete Server", 160, 200, 80, 40, $BS_MULTILINE)
   $btnSave = GUICtrlCreateButton("Save Realmlist", 240, 200, 80, 40, $BS_MULTILINE)
   $btnLaunch = GUICtrlCreateButton("Launch Game", 320, 200, 80, 40, $BS_MULTILINE)

   GUICtrlSetState($btnEdit, $GUI_DISABLE)
   GUICtrlSetState($btnDelete, $GUI_DISABLE)
   GUICtrlSetState($btnSave, $GUI_DISABLE)
   GUICtrlSetState($btnLaunch, $GUI_DISABLE)

   GUICtrlSetResizing($btnNew, $GUI_DOCKSTATEBAR)
   GUICtrlSetResizing($btnEdit, $GUI_DOCKSTATEBAR)
   GUICtrlSetResizing($btnDelete, $GUI_DOCKSTATEBAR)
   GUICtrlSetResizing($btnSave, $GUI_DOCKSTATEBAR)
   GUICtrlSetResizing($btnLaunch, $GUI_DOCKSTATEBAR)

   GUICtrlCreateLabel("Installation path:", 5, 247, 110)
   GUICtrlSetResizing(-1, $GUI_DOCKSTATEBAR)
   Local $inputInstallDir = GUICtrlCreateInput($wowDir, 115, 245, 200, 22)
   GUICtrlSetResizing(-1, $GUI_DOCKSTATEBAR)
   GUICtrlSetState(-1, $GUI_DISABLE)
   Local $btnSelectDir = GUICtrlCreateButton("Select Folder", 315, 245, 85, 22)
   GUICtrlSetResizing(-1, $GUI_DOCKSTATEBAR)

   Local $realms[1]
   $realms = UpdateRealmlist(GetRealmlistPath($wowDir))
   If @error Then
	  GUICtrlSetState($btnNew, $GUI_DISABLE)
	  GUICtrlSetColor($inputInstallDir, 0xff0000)
	  Msgbox(48, "Error", "Invalid World of Warcraft installation directory selected, or none was detected. Please select the proper directory.")
   EndIf

   Local $editWindow = GUICreate("Add/Modify Server", 260, 125, -1, -1, $DS_MODALFRAME, -1, $mainWindow)
   GUICtrlCreateLabel("Name:", 10, 10, 40, 22)
   GUICtrlCreateLabel("Server:", 10, 35, 40, 22)
   Local $inputName = GUICtrlCreateInput("", 50, 8, 200, 22)
   Local $inputServer = GUICtrlCreateInput("", 50, 32, 200, 22)

   Local $btnOk = GUICtrlCreateButton("OK", 70, 64, 90, 28)
   Local $btnCancel = GUICtrlCreateButton("Cancel", 160, 64, 90, 28)

   Dim $accels[1][2] = [["{ENTER}", $btnOk]]
   GUISetAccelerators($accels)

   Local $activeCtl, $newCtl
   GUISetState(@SW_SHOW, $mainWindow)
   GUIRegisterMsg($WM_NOTIFY, "OnWM_Notify")
   Do
      $msg = GUIGetMsg(1)
      Switch $msg[1]
         Case $mainWindow
            Switch $msg[0]
               Case $btnNew
                  $newCtl = GUICtrlCreateListViewItem("", $listview)
                  $activeCtl = $newCtl
                  _GUICtrlListView_SetItemSelected($listview, UBound($realms) - 1, True, True)
                  GUICtrlSetData($inputName, "")
                  GUICtrlSetData($inputServer, "")
                  GUISetState(@SW_SHOW, $editWindow)
                  GUISetState(@SW_DISABLE, $mainWindow)
                  GUISwitch($editWindow)
               Case $btnEdit
                  $activeCtl = GUICtrlRead($listview)
                  If $activeCtl <> 0 Then
                     Local $realmInfo = StringSplit(GUICtrlRead($activeCtl), "|")
                     GUICtrlSetData($inputName, $realmInfo[1])
                     GUICtrlSetData($inputServer, $realmInfo[2])
                     GUISetState(@SW_SHOW, $editWindow)
                     GUISetState(@SW_DISABLE, $mainWindow)
                     GUISwitch($editWindow)
                     ; Debug($realmInfo[1] & " " & $realmInfo[2])
                  EndIf
               Case $btnDelete
                  $activeCtl = GUICtrlRead($listview)
                  If $activeCtl <> 0 Then
                     GUICtrlDelete($activeCtl)
                  EndIf
			   Case $btnSave
				  SaveRealmlist(GetRealmlistPath($wowDir), $realms)
			   Case $btnLaunch
				  ;SaveRealmlist(GetRealmlistPath($wowDir), $realms)
				  ;Run($wowDir & "\WoW.exe")
				  Debug($wowDir & "\Wow.exe")
				  Run($wowDir & "\Wow.exe", $wowDir)
				  ;ShellExecute($wowDir & "\WoW.exe", "", $wowDir)
               Case $btnSelectDir
                  $wowDir = FileSelectFolder("Select Installation Directory", "", 2, $wowDir)
				  If @error = 0 Then
					 $realms = UpdateRealmlist(GetRealmlistPath($wowDir))
					 IniWrite($configFile, "main", "wow_dir", $wowDir)
					 GUICtrlSetData($inputInstallDir, $wowDir)
					 If BitAND(GUICtrlGetState($btnNew), $GUI_DISABLE) Then
						GUICtrlSetState($btnNew, $GUI_ENABLE)
					 EndIf
				  EndIf
            EndSwitch
         Case $editWindow
            Switch $msg[0]
               Case $GUI_EVENT_CLOSE, $btnCancel
                  If $newCtl <> 0 Then
                     GUICtrlDelete($newCtl)
                     $newCtl = 0
                  EndIf
                  GUISetState(@SW_HIDE, $editWindow)
                  GUISwitch($mainWindow)
               Case $btnOk
                  Local $realmId = _GUICtrlListView_GetSelectedIndices($listview)
                  Local $updatedRealm[2] = [GUICtrlRead($inputServer), GUICtrlRead($inputName)]
                  Local $currentRealm = StringSplit(GUICtrlRead($activeCtl), "|")
                  If ($updatedRealm[0] <> $currentRealm[0]) Or ($updatedRealm[1] <> $currentRealm[1]) Then
                     GUICtrlSetState($btnSave, $GUI_ENABLE)
                  EndIf
                  GUISetState(@SW_HIDE, $editWindow)
                  GUISwitch($mainWindow)
                  GUICtrlSetData($activeCtl, $updatedRealm[1] & "|" & $updatedRealm[0])
                  If $newCtl <> 0 Then
                     ReDim $realms[UBound($realms)]
                     GUICtrlSetState($btnSave, $GUI_ENABLE)
                  EndIf
                  $realms[$realmId] = $updatedRealm
                  _GUICtrlListView_Scroll($listview, 0, 16 * $realmId)
                  _GUICtrlListView_EnsureVisible($listview, $realmId - 1)
            EndSwitch
            GUISetState(@SW_ENABLE, $mainWindow)
      EndSwitch
   Until $msg[0] = $GUI_EVENT_CLOSE And $msg[1] = $mainWindow
   GUIDelete($mainWindow)
EndFunc

Main()