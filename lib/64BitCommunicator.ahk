#Requires AutoHotkey v2.0
Persistent

#Include Gdip_All.ahk
#Include RapidOCR.ahk

pToken := Gdip_Startup()
hMap := DllCall("OpenFileMapping", "uint", 0x2, "int", 0, "str", "RapidOCR_SharedMem", "ptr")
pMem := DllCall("MapViewOfFile", "ptr", hMap, "uint", 0xF001F, "uint", 0, "uint", 0, "uptr", 0, "ptr")

hMapResult := DllCall("OpenFileMapping", "uint", 0x2, "int", 0, "str", "RapidOCR_Result", "ptr")
pMemResult := DllCall("MapViewOfFile", "ptr", hMapResult, "uint", 0xF001F, "uint", 0, "uint", 0, "uptr", 0, "ptr")

OnMessage(0x9999, RunBitmapOCR)
RunBitmapOCR(*) {
    data := Buffer(40, 0)
    DllCall("RtlMoveMemory", "ptr", data.Ptr, "ptr", pMem, "uptr", 40)
    x			:= NumGet(pMem + 40, 0,  "int")
    y			:= NumGet(pMem + 40, 4,  "int")
    scale		:= NumGet(pMem + 40, 8,  "int")
    allresult	:= NumGet(pMem + 40, 12, "int")
    NumPut("ptr", pMem + 56, data, 0)
    res := ''
    retVal := DllCall('RapidOcrOnnx\OcrDetectBitmapData', 'ptr', RapidOcr.Engine, 'ptr', data, 'ptr', 0, 'ptr', RapidOcr.__cb(2 - !allresult, x, y, scale), 'ptr', ObjPtr(&res), 'cdecl')
    jsonStr := retVal ? (allresult ? JSON.stringify(res) : res) : ''
    buf := Buffer(StrPut(jsonStr, "UTF-8"))
    StrPut(jsonStr, buf, "UTF-8")
    lenBuf := Buffer(4, 0)
    NumPut("uint", buf.Size, lenBuf)
    DllCall("RtlMoveMemory", "ptr", pMemResult, "ptr", lenBuf.Ptr, "uptr", 4)
    DllCall("RtlMoveMemory", "ptr", pMemResult + 4, "ptr", buf.Ptr, "uptr", buf.Size)
    return
}

OnExit(close)
close(*) {
    DllCall("UnmapViewOfFile", "ptr", pMem)
    DllCall("UnmapViewOfFile", "ptr", pMemResult)
    DllCall("CloseHandle", "ptr", hMap)
    DllCall("CloseHandle", "ptr", hMapResult)
    Gdip_Shutdown(pToken)
}