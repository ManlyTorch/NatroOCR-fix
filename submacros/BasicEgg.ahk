#NoTrayIcon
#SingleInstance Force

#Include "%A_ScriptDir%\..\lib"
#Include "Gdip_All.ahk"
#Include "Gdip_ImageSearch.ahk"
#Include "Roblox.ahk"
#Include "nm_OpenMenu.ahk"
#Include "nm_InventorySearch.ahk"

CoordMode "Mouse", "Screen"
OnExit(ExitFunc)
pToken := Gdip_Startup()

giftedstar := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAgAAAAIAgMAAAC5YVYYAAAACVBMVEX9rDT+rDT/rDOj6H2ZAAAAFElEQVR42mNYtYoBgVYyrFoBYQMAf4AKnlh184sAAAAASUVORK5CYII=")

if (MsgBox("WELCOME TO THE BASIC BEE REPLACEMENT PROGRAM!!!!!``nMade by anniespony#8135``n``nMake sure BEE SLOT TO CHANGE is always visible``nDO NOT MOVE THE SCREEN ORRESIZE WINDOW FROM NOW ON.``nMAKE SURE AUTO-JELLY IS DISABLED!!", "Basic Bee Replacement Program", 0x40001) = "Cancel")
	ExitApp

if (MsgBox("After dismissing this message,``nleft click ONLY once on BEE SLOT", "Basic Bee Replacement Program", 0x40001) = "Cancel")
	ExitApp

hwnd := GetRobloxHWND()
ActivateRoblox()
GetRobloxClientPos()
offsetY := GetYOffset(hwnd, &offsetfail)
if (offsetfail = 1) {
	MsgBox "Unable to detect in-game GUI offset!``nStopping Feeder!``n``nThere are a few reasons why this can happen, including:``n - Incorrect graphics settings``n - Your `'Experience Language`' is not set to English``n - Something is covering the top of your Roblox window``n``nJoin our Discord server for support and our Knowledge Base post on this topic (Unable to detect in-game GUI offset)!", "WARNING!!", 0x40030
	ExitApp
}
StatusBar := Gui("-Caption +E0x80000 +AlwaysOnTop +ToolWindow -DPIScale")
StatusBar.Show("NA")
hbm := CreateDIBSection(windowWidth, windowHeight), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
G := Gdip_GraphicsFromHDC(hdc), Gdip_SetSmoothingMode(G, 2), Gdip_SetInterpolationMode(G, 2)
Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0x60000000), -1, -1, windowWidth+1, windowHeight+1), Gdip_DeleteBrush(pBrush)
UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, windowHeight)

KeyWait "LButton", "D" ; Wait for the left mouse button to be pressed down.
MouseGetPos &beeX, &beeY
Gdip_GraphicsClear(G), Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0xd0000000), -1, -1, windowWidth+1, 38), Gdip_DeleteBrush(pBrush)
Gdip_TextToGraphics(G, "Hatching... Right Click or Shift to Stop!", "x0 y0 cffff5f1f Bold Center vCenter s24", "Tahoma", windowWidth, 38)
UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, 38)
SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc), Gdip_DeleteGraphics(G)
Hotkey "Shift", ExitFunc, "On"
Hotkey "RButton", ExitFunc, "On"
Hotkey "F11", ExitFunc, "On"
Sleep 250

common := Gdip_CreateBitmap(2,2), G := Gdip_GraphicsFromImage(common), Gdip_GraphicsClear(G,0xffae792f), Gdip_DeleteGraphics(G) ; Common
mythic := Gdip_CreateBitmap(2,2), G := Gdip_GraphicsFromImage(mythic), Gdip_GraphicsClear(G,0xffbda4ff), Gdip_DeleteGraphics(G) ; Mythic

curItem := "BasicEgg"
displayName := Map(
	"BasicEgg", "Basic Eggs!",
	"RoyalJelly", "Royal Jellies!"
)

Loop {
	itemRect := nm_InventorySearch(curItem,, 70)
	if not itemRect {
		MsgBox "You ran out of " displayName[curItem], "Basic Bee Replacement Program", 0x40010
		break
	}

	GetRobloxClientPos(hwnd)
	SendEvent "{Click " windowX + 30 " " itemRect.Y + itemRect.H " 0}"
	Send "{Click Down}"
	Sleep 100
	SendEvent "{Click " beeX " " beeY " 0}"
	Sleep 100
	Send "{Click Up}"
	found := false
	Loop 10 {
		Sleep 100
        searchResult := findTextInRect("yes", windowX+windowWidth//2-250, windowY+windowHeight//2-52, 500, 150)
		if searchResult.Has("Word") {
			rect := searchResult["Word"].BoundingRect
			Click rect.x, rect.y
			found := true
		} else if found {
			break
		}

		if (A_Index = 10) {
			curItem := "RoyalJelly"
			continue 2
		}
	}
	Sleep 750

	pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-155 "|" windowY+offsetY+((4*windowHeight)//10 - 135) "|310|205")
	
	if (Gdip_ImageSearch(pBMScreen, mythic, , 50, 165, 260, 205, 2, , , 5) = 5) { ; Mythic Hatched
		if (MsgBox("MYTHIC!!!!``nKeep this?", "Basic Bee Replacement Program", 0x40024) = "Yes") {
			Gdip_DisposeImage(pBMScreen)
			break
		}
	} else if (Gdip_ImageSearch(pBMScreen, giftedstar, , 0, 20, 130, 50, 5) = 1) {
		if (Gdip_ImageSearch(pBMScreen, common, , 50, 165, 260, 205, 2, , , 5) = 5) { ; Gifted basic bee
			MsgBox "SUCCESS!!!!", "Basic Bee Replacement Program", 0x40020
			Gdip_DisposeImage(pBMScreen)
			break
		} else if (MsgBox("GIFTED!!!!``nKeep this?", "Basic Bee Replacement Program", 0x40024) = "Yes") {  ; Non-Basic Gifted Hatched
			Gdip_DisposeImage(pBMScreen)
			break
		}
	}
	Gdip_DisposeImage(pBMScreen)
}
ExitApp

ExitFunc(*) {
	try Gdip_DisposeImage(mythic), Gdip_DisposeImage(common)
	try StatusBar.Destroy()
	try Gdip_Shutdown(pToken)
	ExitApp
}