filterText(lines) {
    filteredLines := Array()
    for idx, line in lines {
		line.Text := MultiStrReplace(line.Text, "-", '', ' ', '')
		filteredLines.Push(line)
    }
	return filteredLines
}

MultiStrReplace(str, params*) {
	if params is Map {
		for needle, replacement in params {
			str := StrReplace(str, needle, replacement)
		}
	} else {
		Loop params.Length // 2 {
			idx := (A_Index - 1) * 2 + 1
			needle := params[idx]
			replacement := params[idx + 1]
			str := StrReplace(str, needle, replacement)
		}
	}
	return str
}

itemArray := ["Cog", "Ticket", "SprinklerBuilder", "BeequipCase", "Gumdrops", "Coconut", "Stinger", "Snowflake", "MicroConverter", "Honeysuckle", "Whirligig", "FieldDice", "SmoothDice", "LoadedDice", "JellyBeans", "RedExtract", "BlueExtract", "Glitter", "Glue", "Oil", "Enzymes", "TropicalDrink", "PurplePotion", "SuperSmoothie", "MarshmallowBee", "Sprout", "MagicBean", "FestiveBean", "CloudVial", "BloomShaker", "NightBell", "BoxOFrogs", "AntPass", "BrokenDrive", "7ProngedCog", "RoboPass", "Translator", "SpiritPetal", "Present", "Treat", "StarTreat", "AtomicTreat", "SunflowerSeed", "Strawberry", "Pineapple", "Blueberry", "Bitterberry", "Neonberry", "MoonCharm", "GingerbreadBear", "AgedGingerbreadBear", "WhiteDrive", "RedDrive", "BlueDrive", "GlitchedDrive", "ComfortingVial", "InvigoratingVial", "MotivatingVial", "RefreshingVial", "SatisfyingVial", "NectarShowerVial", "PinkBalloon", "RedBalloon", "WhiteBalloon", "BlackBalloon", "SoftWax", "HardWax", "CausticWax", "SwirledWax", "Turpentine", "PaperPlanter", "TicketPlanter", "StickerPlanter", "FestivePlanter", "PlasticPlanter", "CandyPlanter", "RedClayPlanter", "BlueClayPlanter", "TackyPlanter", "PesticidePlanter", "HeatTreatedPlanter", "HydroponicPlanter", "PetalPlanter", "PlanterOfPlenty", "BasicEgg", "SilverEgg", "GoldEgg", "DiamondEgg", "MythicEgg", "StarEgg", "GiftedSilverEgg", "GiftedGoldEgg", "GiftedDiamondEgg", "GiftedMythicEgg", "RoyalJelly", "StarJelly", "BumbleBeeEgg", "GiftedExhaustedBeeEgg", "GiftedFrostyBeeEgg", "GiftedDiamondBeeEgg", "BumbleBeeJelly", "RageBeeJelly", "ShockedBeeJelly", "BearBeeJelly", "CobaltBeeJelly", "CrimsonBeeJelly", "FestiveBeeJelly", "GummyBeeJelly", "PhotonBeeJelly", "PuppyBeeJelly", "TabbyBeeJelly", "ViciousBeeJelly"]
(items := Map()).CaseSense := 0
for idx, item in itemArray {
	items[item] := [idx, item]
	items[idx] := [idx, item]
}

getRemainingItems(orgLine, line:=orgLine) {
	lineIdx := line.idx
	line.ItemsRemaining := 1
	nextLine := orgLine.items[line.foundIdx + 1]
	Loop nextLine.idx - lineIdx - 1 {
		iterLine := orgLine.searchLines[A_Index + lineIdx]
		if pos := InStr(iterLine.Text, 'x') {
			int := MultiStrReplace(SubStr(iterLine.Text, pos + 1), "o", "0", "i", "1", "l", "1", "a", "4", "/", "7")
			if IsInteger(int) {
				line.ItemsRemaining := Integer(int)
			}
			break
		}
	}
}

/**
 * Looks for the given item in the invetory
 * @param {String | Integer} item The item you're searching for
 * @param {String} direction direction you want it to search IF the item is unknown
 * @param {Integer} max max amount of attempts
 * @returns {Rect | Boolean} X,Y,W,H Map or false if it failed to find the item.
*/
nm_InventorySearch(item, direction:="down", maxIter:=70, intensity:=3, getRemaining:=false) {
	static firstItemIdx := 0, lastItemIdx := 0
	nm_OpenMenu("itemmenu")
	
	itemIdx := 0
	itemName := item
	if items.Has(item)
		itemIdx := items[item][1], itemName := items[item][2]
	
	; Activate roblox window and get it's current position and height
	if !(hwnd := GetRobloxHWND())
		return false ; No roblox, return nothing.
	
	ActivateRoblox()
	GetRobloxClientPos(hwnd)
	offsetY := GetYOffset(hwnd)

	xAdd := getRemaining ? 0 : 100
	xWidth := 250 + (getRemaining ? 100 : 0)
	
	; Scroll to the end of inventory IF item isn't known
	if !itemIdx {
		firstItemIdx := 0, lastItemIdx := 0
		preScrollDir := direction = "down" ? "Up" : "Down"
		Loop 10 {
			SendEvent "{Click " windowX+30 " " windowY+offsetY+200 " 0}"
			SendInput "{Wheel" preScrollDir " 100}"
			Sleep 50
		}
	}

	doubleCheck := false
	foundIdx := 0, itemLines := ''
	scrollDir := direction = "down" ? "Down" : "Up"
	Loop maxIter { ; Start searching
		ActivateRoblox()
		GetRobloxClientPos(hwnd)
		scrollIntensity := intensity

		; get items
		searchResult := RapidOcr.FromRect(windowX+xAdd, windowY+150, xWidth, windowHeight-150)
		if !searchResult { ; no reading?
			continue
		}
		lines := filterText(searchResult.Lines)

		prevFirstLine := itemLines and itemLines.Has(1) ? itemLines[1] : ''
		(itemLines := Map()).CaseSense := 0
		foundIdx := 0

		; ensure all lines are items.
		firstItemIdx ? prevSearch(lines) : bruteForce(lines)

		hasItems := itemLines.Has(1)
		firstItemIdx := hasItems ? itemLines[1].itemidx : 0
		if itemLines.Has(itemName) {
			if itemLines["last"].item = itemName {
				SendEvent "{Click " windowX+30 " " windowY+offsetY+200 " 0}"
				SendInput "{WheelDown " intensity "}"
				Sleep 550
				continue
			}
			itemLines[itemName].searchLines := searchResult.Lines
			itemLines[itemName].lines := lines
			if getRemaining {
				getRemainingItems(itemLines[itemName])
			}
			return itemLines[itemName]
		} else if itemIdx and firstItemIdx {
			if firstItemIdx < itemIdx and lastItemIdx > itemIdx {
				if !doubleCheck {
					doubleCheck := true
					continue
				}
				return false
			}
			scrollDir := firstItemIdx > itemIdx ? "Up" : "Down"
			scrollIntensity := Max(Abs(itemIdx - firstItemIdx) // 10, intensity)
		}

		SendEvent "{Click " windowX+30 " " windowY+offsetY+200 " 0}"
		SendInput "{Wheel" scrollDir " " scrollIntensity "}"
		Sleep 550 ; wait for scroll to finish

		if !itemIdx and hasItems and prevFirstLine.Text = itemLines[1].Text {
			if !doubleCheck {
				doubleCheck := true
				continue
			}
			break
		}

		doubleCheck := false
	}

	bruteForce(curLines) {
		for _, line in curLines {
			if items.Has(line.Text) {
				addLine(line, items[line.Text][2], items[line.Text][1])
				continue
			}
			Loop itemArray.Length - lastItemIdx {
				idx := lastItemIdx + A_Index
				item := itemArray[idx]
				if InStr(line.Text, StrLower(item)) {
					addLine(line, item, idx)
					break
				}
			}
		}
	}
	prevSearch(curLines) {
		searchIdx := firstItemIdx - 3
		for _, line in curLines {
			Loop itemArray.Length - firstItemIdx + 3 {
				idx := searchIdx + A_Index
				if itemArray.Length < idx {
					break
				}
				item := itemArray[idx]
				if InStr(line.Text, StrLower(item)) {
					addLine(line, item, idx)
					break
				}
			}
		}
	}
	addLine(line, item, idx) {
		foundIdx += 1
		line.items := itemLines
		line.item := item
		line.itemidx := idx
		line.foundIdx := foundIdx
		itemLines[item] := line
		itemLines[foundIdx] := line
		itemLines["last"] := line
		lastItemIdx := idx
	}
}