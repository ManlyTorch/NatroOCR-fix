#Include JSON.ahk

/************************************************************************
 * @description [RapidOcrOnnx](https://github.com/RapidAI/RapidOcrOnnx)
 * A cross platform OCR Library based on PaddleOCR & OnnxRuntime
 * @author thqby, RapidAI
 * @date 2025/11/11
 * @version 1.0.3
 * @license Apache-2.0
 ***********************************************************************/
filterSpaces(lines) {
	filteredLines := Array()
	for idx, line in lines {
		line.Text := StrReplace(line.Text, ' ')
		filteredLines.Push(line)
	}
	return filteredLines
}
strInLine(str, line, *) {
	return InStr(StrLower(line), str)
}
strInLines(strs, line, result) {
	for _, str in strs {
		if pos := InStr(StrLower(line), str) {
			result["Found"] := str
			return pos
		}
	}
}

findTextInRect(str, x, y?, w?, h?, scale:=1, filterLines:=filterSpaces, customCheck:=strInLine) {
	ocrResult := Map()
    if !IsSet(y) or not (y is Integer) {
        ocrResult := x
        if x is Integer {
            ocrResult := RapidOcr.FromBitmap(x, scale)
        } else if x is String {
            ocrResult := RapidOcr.FromFile(x)
        }
        if IsSet(y)
            filterLines := y
        if IsSet(w)
            customCheck := w
	} else
		ocrResult := RapidOcr.FromRect(x, y, w, h, scale)

	if ocrResult is String
		return Map("Lines", [], "OCRResult", ocrResult)

	unspacedStr := str is String ? StrLower(StrReplace(str, " ")) : ''
    lines := filterLines(ocrResult.Lines)

	if str is Array and customCheck = strInLine {
		customCheck := strInLines
		unspacedStr := Array()
		for _, str in str {
			unspacedStr.Push(StrLower(StrReplace(str, ' ')))
		}
	}

	searchResult := Map("Lines", lines, 'OCRResult', ocrResult)
	for idx, line in lines {
		if customCheck(unspacedStr, line.Text, searchResult) {
			searchResult["Line"] := line
			searchResult["LineIndex"] := idx
			break
		}
	}
	
    return searchResult
}

is64Bit := A_PtrSize >= 8
assets := A_LineFile "\..\OCRAssets\"
class RapidOcr {
	static Engine := is64Bit ? RapidOcr(2) : ''
	ptr := 0
	/**
	 * @example
	 * param := RapidOcr.OcrParam()
	 * param.doAngle := false ;, param.maxSideLen := 300
	 * ocr := RapidOcr({ models: A_ScriptDir '\models' })
	 * MsgBox ocr.FromFile('1.jpg', param)
	*/
	__New(threads:=2) {
		static init := DllCall('LoadLibrary', 'str', assets (A_PtrSize >= 8 ? '' : '32Bit\') 'RapidOcrOnnx.dll', 'ptr')
		if (!init)
			Throw OSError()
		if !DllCall('GetProcAddress', 'ptr', init, 'astr', 'OcrGetLastError', 'ptr')
			this.DefineProp('throw', { call: _ => '' })
		det_model := assets 'ch_PP-OCRv3_det_infer.onnx'
		cls_model := assets 'ch_ppocr_mobile_v2.0_cls_infer.onnx'
		rec_model := assets 'ch_PP-OCRv3_rec_infer.onnx'
		keys_dict := assets 'ppocr_keys_v1.txt'
		if this.ptr := DllCall('RapidOcrOnnx\OcrInit', 'str', det_model, 'str', cls_model, 'str', rec_model, 'str', keys_dict, 'int', threads, 'cdecl ptr')
			this.throw()
		else throw MemoryError()
	}
	__Delete() =>  is64Bit ? this.ptr && DllCall('RapidOcrOnnx\OcrDestroy', 'ptr', this, 'cdecl') : ''
	throw() {
		if err := DllCall('RapidOcrOnnx\OcrGetLastError', 'ptr', this, 'cdecl astr')
			throw Error(err, -2)
	}

	static __cb(i, x:=0, y:=0, scale:=1) {
		cbs := [
			{ ptr: CallbackCreate(get_text), __Delete: this => CallbackFree(this.ptr) },
			{ ptr: CallbackCreate(get_result), __Delete: this => CallbackFree(this.ptr) },
		]
		return cbs[i]
		get_text(userdata, ptext, presult) => %ObjFromPtrAddRef(userdata)% := StrGet(ptext, 'utf-8')
		get_result(userdata, ptext, presult) {
			result := %ObjFromPtrAddRef(userdata)% := RapidOcr.OcrResult(presult, x, y, scale)
			result.text := StrGet(ptext, 'utf-8')
			return result
		}
	}

	; opencv4.8.0 Mat
	static FromMat(mat, scale:=1, param := 0, allresult := true, x:=0, y:=0) => DllCall('RapidOcrOnnx\OcrDetectMat', 'ptr', this.Engine, 'ptr', mat, 'ptr', param, 'ptr', RapidOcr.__cb(2 - !allresult, x, y, scale), 'ptr', ObjPtr(&res), 'cdecl') ? res : this.Engine.throw()

	; path of pic
	static FromFile(picpath, scale:=1, param := 0, allresult := true, x:=0, y:=0) => DllCall('RapidOcrOnnx\OcrDetectFile', 'ptr', this.Engine, 'astr', picpath, 'ptr', param, 'ptr', RapidOcr.__cb(2 - !allresult, x, y, scale), 'ptr', ObjPtr(&res), 'cdecl') ? res : this.Engine.throw()

	; Image binary data
	static FromBinary(data, size, scale:=1, param := 0, allresult := false, x:=0, y:=0) => DllCall('RapidOcrOnnx\OcrDetectBinary', 'ptr', this.Engine, 'ptr', data, 'uptr', size, 'ptr', param, 'ptr', RapidOcr.__cb(2 - !allresult, scale, x, y), 'ptr', ObjPtr(&res), 'cdecl') ? res : this.Engine.throw()

	; `struct BITMAP_DATA { void *bits; uint pitch; int width, height, bytespixel;};`
	static FromBitmap64Bit(pBitmap, scale := 1, param := 0, allresult := true, x:=0, y:=0) {
		if scale > 1 {
			Gdip_GetImageDimensions(pBitmap, &tw, &th)
			pBitmap := Gdip_ResizeBitmap(pBitmap, tw * scale, th * scale)
		}
		Gdip_GetImageDimensions(pBitmap, &w, &h)
		Gdip_LockBits(pBitmap, 0, 0, w, h, &stride, &scan0, &bitmapData, 1)
		NumPut("ptr",  scan0, "uint", Abs(stride), "uint", w, "uint", h, "uint", 4, "uint", 0, "uint", 0, data := Buffer(40, 0))
		res := ''
		try {
			retVal := DllCall('RapidOcrOnnx\OcrDetectBitmapData', 'ptr', this.Engine, 'ptr', data, 'ptr', param, 'ptr', RapidOcr.__cb(2 - !allresult, x, y, scale), 'ptr', ObjPtr(&res), 'cdecl')
		} catch as e {
			if e.Message = 'Unhandled exception.' {
				retVal := true
				res := {Lines:[]}
			} else {
				throw Error(e, -1)
			}
		}
		Gdip_UnlockBits(pBitmap, &bitmapData)
		if scale > 1 {
			Gdip_DisposeImage(pBitmap)
		}
		return retVal ? res : ''
	}

	static FromRect(x, y, w, h, scale := 1, param := 0, allresult := true) {
		pBitmap := Gdip_BitmapFromScreen(x '|' y '|' w '|' h)
		res := this.FromBitmap(pBitmap, scale, param, allresult, x, y)
		Gdip_DisposeImage(pBitmap)
		return res
	}

	class OcrParam extends Buffer {
		__New(param?) {
			super.__New(42, 0)
			p := NumPut('int', 50, 'int', 1024, 'float', 0.6, 'float', 0.3, 'float', 2.0, this)
			if !IsSet(param)
				return NumPut('int', 1, 'int', 1, p)
			for k, v in (param is Map ? param : param.OwnProps())
				if this.Base.HasOwnProp(k)
					this.%k% := v
		}
		; default: 50
		padding {
			get => NumGet(this, 0, 'int')
			set => NumPut('int', Value, this, 0)
		}
		; default: 0
		maxSideLen {
			get => NumGet(this, 4, 'int')
			set => NumPut('int', Value, this, 4)
		}
		; default: 0.5
		boxScoreThresh {
			get => NumGet(this, 8, 'float')
			set => NumPut('float', Value, this, 8)
		}
		; default: 0.3
		boxThresh {
			get => NumGet(this, 12, 'float')
			set => NumPut('float', Value, this, 12)
		}
		; default: 1.6
		unClipRatio {
			get => NumGet(this, 16, 'float')
			set => NumPut('float', Value, this, 16)
		}
		; default: false
		doAngle {
			get => NumGet(this, 20, 'int')
			set => NumPut('int', Value, this, 20)
		}
		; default: false
		mostAngle {
			get => NumGet(this, 24, 'int')
			set => NumPut('int', Value, this, 24)
		}
		; Output path of image with the boxes
		outputPath {
			get => StrGet(NumGet(this, 24 + A_PtrSize, 'ptr') || StrPtr(''), 'cp0')
			set => (StrPut(Value, this.__outputbuf := Buffer(StrPut(Value, 'cp0')), 'cp0'), NumPut('ptr', this.__outputbuf.Ptr, this, 24 + A_PtrSize))
		}
	}

	class OcrResult extends Array {
		__New(ptr, orgX, orgY, scale) {
			this.dbNetTime := NumGet(ptr, 'double')
			this.detectTime := NumGet(ptr, 8, 'double')
			this.Lines := Array()
			read_vector(this.Lines, &ptr += 16, read_textblock)

			for idx, line in this.Lines {
				line.idx := idx
				x := (line.rect[1].x // scale) + orgX, y := (line.rect[1].y // scale) + orgY
				w := (line.rect[2].x - x) // scale, h := (line.rect[3].y - line.rect[1].y) // scale
				setRectProperties(line)
				setRectProperties(line.rect)
				setRectProperties(obj) {
					obj.x := x, obj.y := y, obj.w := w, obj.h := h
					obj.Width := w, obj.Height := h
				}
			}

			align(ptr, begin, to_align) => begin + ((ptr - begin + --to_align) & ~to_align)
			read_textblock(&ptr, begin := ptr) => {
				rect: read_vector([], &ptr, read_point),
				boxScore: read_float(&ptr),
				angleIndex: read_int(&ptr),
				angleScore: read_float(&ptr),
				angleTime: read_double(&ptr := align(ptr, begin, 8)),
				text: read_string(&ptr),
				charScores: read_vector([], &ptr, read_float),
				crnnTime: read_double(&ptr := align(ptr, begin, 8)),
				blockTime: read_double(&ptr)
			}
			read_double(&ptr) => (v := NumGet(ptr, 'double'), ptr += 8, v)
			read_float(&ptr) => (v := NumGet(ptr, 'float'), ptr += 4, v)
			read_int(&ptr) => (v := NumGet(ptr, 'int'), ptr += 4, v)
			read_point(&ptr) => { x: read_int(&ptr), y: read_int(&ptr) }
			read_string(&ptr) {
				static size := 2 * A_PtrSize + 16
				sz := NumGet(ptr + 16, 'uptr'), p := sz < 16 ? ptr : NumGet(ptr, 'ptr'), ptr += size
				s := StrGet(p, sz, 'utf-8')
				return s
			}
			read_vector(arr, &ptr, read_element) {
				static size := 3 * A_PtrSize
				pend := NumGet(ptr, A_PtrSize, 'ptr'), p := NumGet(ptr, 'ptr'), ptr += size
				while p < pend
					arr.Push(read_element(&p))
				return arr
			}
		}
	}
}

if !is64Bit and A_Is64bitOS and FileExist(A_LineFile "\..\..\submacros\AutoHotkey64.exe") {
	; 32bit side of communicator

	; create shared mem
	Mem_Size := 30 * 1024 * 1024 ; 30 MB, should be more than enough
	hMap := DllCall("CreateFileMapping", "ptr", -1, "ptr", 0, "uint", 4, "uint", 0, "uint", Mem_Size, "str", "RapidOCR_SharedMem", "ptr")
	pMem := DllCall("MapViewOfFile", "ptr", hMap, "uint", 0xF001F, "uint", 0, "uint", 0, "uptr", 0, "ptr")
	hMapResult := DllCall("CreateFileMapping", "ptr", -1, "ptr", 0, "uint", 4, "uint", 0, "uint", Mem_Size, "str", "RapidOCR_Result", "ptr")
	pMemResult := DllCall("MapViewOfFile", "ptr", hMapResult, "uint", 0xF001F, "uint", 0, "uint", 0, "uptr", 0, "ptr")
	
	; run the 64 bit helper
	prevDHW := DetectHiddenWindows(1)
	if !WinExist("64BitCommunicator.ahk ahk_class AutoHotkey") {
		libFolder := A_LineFile "\..\"
		Run libFolder '..\submacros\AutoHotkey64.exe "' libFolder '64BitCommunicator.ahk"'
		WinWait "64BitCommunicator.ahk ahk_class AutoHotkey",, 10
	}
	DetectHiddenWindows(prevDHW)
	
	; I'm too lazy to implement more of its functions, besides its like the only one going to be used so.
	FromBitmap32Bit(this, pBitmap, scale := 1, param := 0, allresult := true, x:=0, y:=0) {
		if scale > 1 {
			Gdip_GetImageDimensions(pBitmap, &tw, &th)
			pBitmap := Gdip_ResizeBitmap(pBitmap, tw * scale, th * scale)
		}
		Gdip_GetImageDimensions(pBitmap, &w, &h)
		Gdip_LockBits(pBitmap, 0, 0, w, h, &stride, &scan0, &bitmapData, 1)
		
		; setup shared mem data
		data := Buffer(40, 0)
		NumPut("int64", 0, data, 0)
		NumPut("uint", Abs(stride), data, 8)
		NumPut("uint", w, data, 12)
		NumPut("uint", h, data, 16)
		NumPut("uint", 4, data, 20)
		NumPut("uint", 0, data, 24)
		NumPut("uint", 0, data, 28)
		NumPut("int", x, "int", y, "int", scale, "int", allresult ? 1 : 0, meta := Buffer(16, 0))
		
		; put bitmap data inside shared memory
		DllCall("RtlMoveMemory", "ptr", pMem, "ptr", data.Ptr, "uptr", 40)
		DllCall("RtlMoveMemory", "ptr", pMem + 40, "ptr", meta.Ptr, "uptr", 16)
		DllCall("RtlMoveMemory", "ptr", pMem + 56, "ptr", scan0, "uptr", Abs(stride) * h)
		
		; yell at the 64 bit helper to do the OCR detection
		prevDHW := DetectHiddenWindows(1)
		hwnd64 := WinExist("64BitCommunicator.ahk ahk_class AutoHotkey")
		SendMessage(0x9999, 0, 0, hwnd64)
		DetectHiddenWindows(prevDHW)
		Gdip_UnlockBits(pBitmap, &bitmapData)
		if scale > 1
			Gdip_DisposeImage(pBitmap)
		
		; yay we're done (God I hate tis)
		len := NumGet(pMemResult, "uint")
		res := StrGet(pMemResult + 4, len, "UTF-8")
		return res ? (allresult ? JSON.parse(res,, false) : res) : ''
	}
	RapidOcr.FromBitmap := FromBitmap32Bit
} else {
	RapidOcr.FromBitmap := RapidOcr.FromBitmap64Bit
	if !is64Bit
		RapidOcr.Engine := RapidOcr(2)
}