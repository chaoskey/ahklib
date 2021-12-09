;@Ahk2Exe-SetProductName    Ctrl增强 
;@Ahk2Exe-SetProductVersion 2021.12.07
;@Ahk2Exe-SetDescription Ctrl增强 
;@Ahk2Exe-SetFileVersion    2021.12.07
;@Ahk2Exe-SetCopyright @2021-2025
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetOrigFilename CtrlRich
;@Ahk2Exe-SetLegalTrademarks chaoskey
;@Ahk2Exe-SetCompanyName chaoskey
;@Ahk2Exe-SetMainIcon images\ctrl.ico

#SingleInstance, force

FileEncoding , UTF-8-RAW

#Include lib\TokenGdip.ahk
#Include lib\util.ahk

; 托盘提示
Menu, Tray,Tip , Ctrl增强
if FileExist("images\ctrl.ico"){
    Menu, Tray, Icon, images\ctrl.ico
}

; 启动GDI+支持
startupGdip()
; 启动“Ctrl+命令”死循环
startCtrlCmdLoop()
return ; 自动运行段结束


/*
最终命令（Ctrl松开执行的命令）
    【系统复制】Ctrl + c    
    【系统粘贴】Ctrl + v
    【系统剪切】Ctrl + x

    【截图复制】Ctrl + cc    
        鼠标选择屏幕上任何矩形区域（先Ctrl+cc，后选择）
    【图片粘贴】Ctrl + vv
        鼠标选择粘贴屏幕任意位置，也可以将复制文本作为图片粘贴  （先Ctrl+cc，后选择）

Clipboard浏览管理（Ctrl未松开执行的命令）
    【下一个clip浏览】  Ctrl + vs(x)    如果以x结尾，则表示松开后也不执行（下同）
    【上一个clip浏览】  Ctrl + vf(x)
    【删除当前clip】       Ctrl + vd(x)
    【删除全部】           Ctrl + va(x)

贴图管理（Ctrl未松开执行的命令）
    【下一个贴图】  Ctrl + vvs(x)
    【上一个贴图】  Ctrl + vvf(x)
    【删除当前贴图】   Ctrl + vvd(x)
    【删除全部贴图】   Ctrl + vva(x)

组合命令（Ctrl松开后）
    Ctrl + c[a|s|d|f]*  = Ctrl + c      
    Ctrl + v[a|s|d|f]*  = Ctrl + v
    Ctrl + c[a|s|d|f]*c  = Ctrl + cc
    Ctrl + v[a|s|d|f]*v  = Ctrl + vv
*/
$^c::
$^v::
$^x::
$^s::
$^d::
$^a::
$^f::
CtrlHandler()
return

/*  
    Ctrl+命令 拦截
*/
CtrlHandler(){
    global ctrlCmd ; Ctrl+命令
    if (not ctlCmd){
        ctlCmd := ""
    }
    ctrlCmd := ctrlCmd SubStr(A_ThisHotkey, 3) 
}

/* 
    “Ctrl+命令”处理之死循环
*/
startCtrlCmdLoop(){
    ; Ctrl+命令
    global ctrlCmd := ""
    ; 桌面贴图及其索引 
    global screenPastes := []
    global activepaste := 0
    ; 当前clip文件名索引
    global activeclip := 0
    ; 标记的clip文件名（保持和文件.clip/clip.tag内容同步）
    ; 注意： 
    ; 1) tagcliparray则用"`n"分割并作为开头结尾
    ; 2) 但是， .clip/clip.tag的内容不包括开头和结尾的"`n"
    global tagcliparray := "`n" 

    ; 如果tagcliparray没数据，尝试从.clip/clip.tag读取
    if (tagcliparray = "`n") and FileExist(".clip\clip.tag") {  
        Loop, read, .clip\clip.tag 
        {
            line := Trim(A_LoopReadLine)
            if (line != "") {
                tagcliparray := tagcliparray line "`n"
            }
        }
    }

    ; 初始索引
    indexClip()

    working := False
    loop{
        if (not working){
            ; 等待CTRL按下
            KeyWait, Control, D
        }
        keyIsDown := GetKeyState("CTRL" , "P")
        if keyIsDown{
            ; 进入工作状态
            working := True

            ; Ctrl+命令 （Ctrl未松开）
            execCtrlDownCmd()
        }else if working {
            ; Ctrl+命令 （Ctrl松开）
            execCtrlDownUPCmd()

            ; 工作完成，状态复原
            ctrlCmd := ""
            working := False
            activepaste := 0
        }
    }
}

/*  
    Ctrl+命令 （Ctrl未松开）
*/
execCtrlDownCmd(){
    global ctrlCmd ; Ctrl+命令
    global activeclip ; 当前clip文件名索引
    global screenPastes ; 桌面贴图列表
    global activepaste ; 当前桌面贴图索引

    if (ctrlCmd = "vs"){
        ; 复原
        ctrlCmd := "v"
        ; 显示下一个索引位置的clip
        nextClip()
        showClip()
    }if (ctrlCmd = "vf"){
        ; 复原
        ctrlCmd := "v"
        ; 显示上一个索引位置的clip
        prevClip()
        showClip()
    }else if (ctrlCmd = "vd"){
        ; 复原
        ctrlCmd := "v"
        ; 删除当前索引位置的clip
        deleteClip()
    }else if (ctrlCmd = "va"){
        ; 复原
        ctrlCmd := "v"
        ; 删除当前索引位置的clip
        deleteClipAll()
    }else if (ctrlCmd = "vvs"){
        ctrlCmd := "vv"
        if (screenPastes.Length() > 1){
            activepaste := activepaste + 1
            if (activepaste > screenPastes.Length()){
                activepaste := 1
            }
            hWND := screenPastes[activepaste]
            fn := Func("RemoveToolTipFlash").Bind(hWND)
            SetTimer, % fn , -1
        }
    }else if (ctrlCmd = "vvf"){
        ctrlCmd := "vv"
        if (screenPastes.Length() > 1){
            activepaste := activepaste - 1
            if (activepaste < 1){
                activepaste := screenPastes.Length()
            }
            hWND := screenPastes[activepaste]
            fn := Func("RemoveToolTipFlash").Bind(hWND)
            SetTimer, % fn , -1
        }
    }else if (ctrlCmd = "vvd"){
        ctrlCmd := "vv"
        hWND := screenPastes[activepaste]
        deletScreenPaste(hWND)
    }else if (ctrlCmd = "vva"){
        ctrlCmd := "vv"
        clearScreenPastes()
    }

}

/*  
    Ctrl+命令 （Ctrl松开）
 
*/
execCtrlDownUPCmd(){
    global ctrlCmd ; Ctrl+命令
    global activeclip ; 当前clip文件名索引
    global activepaste ; 当前桌面贴图索引

    if (ctrlCmd = "ss"){
        ; 进入搜索粘贴模式
        ; 只搜索剪切板中的文本内容
        ; 凡是搜索过的内容，都不会被“全部删除命令a”删除
        searchTextClipForPaste()
    } else if (ctrlCmd = "cc"){
        ; Ctrl+cc 截图复制（会出现跟随鼠标的坐标提示，鼠标左键“按下-移动-松开”完成截图复制）
        screenShot()
        addClip()
    } else if (ctrlCmd = "vv"){
        ; Ctrl+vv 粘贴到屏幕(待贴图的内容会跟随鼠标移动，点击鼠标左键完成屏幕贴图)
        screenPaste() 
        moveClip() 
    }else if (StrLen(ctrlCmd) = 1) {
        if (ctrlCmd = "c") or (ctrlCmd = "x"){
            clip1:=ClipboardAll ; 备份
            clipboard := ""   ; 清空剪贴板.
        }
        ; 保证拦截的“Ctrl+单字符命令”的系统原生功能不变
        Send, ^%ctrlCmd%
        if (ctrlCmd = "c")  or (ctrlCmd = "x") {
            ClipWait, , 1  ; 等待剪贴板中出现数据.
            clip2 := ClipboardAll
            IF clip1 <> %clip2%
            {
                addClip()
            }
        }else if (ctrlCmd = "v"){
            moveClip()       
        }
    }
    ; 复位
    activeclip := 0
    activepaste := 0

    ; 其它的情况无动作
}

/*
    将当前clip读入Clipboard【同步操作】
*/
readClip(){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引

    if (cliparray.Length() = 0){
        activeclip := 0
    }else{
        activeclip := Min(Max(activeclip,1), cliparray.Length()) 
    }

    if (activeclip > 0) {
        currclip := cliparray[activeclip]
        IfExist,.clip\%currclip%.clip
            FileRead,Clipboard,*c .clip\%currclip%.clip
    }else{
        Clipboard := ""
    }
}

/*
    将当前clip变成最近clip
*/
moveClip(){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引
    global tagcliparray ; 标记的clip文件名（用"`n"分割并作为开头结尾）

    if (activeclip > 1) {
        ; 当前粘贴内容对应的clip文件名
        oldclip := cliparray[activeclip]
        newclip := cliparray[1] + 1
        ; 将当前clip文件变成最近文件 
        FileMove, .clip\%oldclip%.clip, .clip\%newclip%.clip , 1
        ; 同步修改 .clip\clip.tag
        if InStr(tagcliparray, "`n" oldclip "`n") {
            tagcliparray := StrReplace(tagcliparray, "`n" oldclip "`n" , "`n" newclip "`n")
            FileDelete, .clip\clip.tag
            FileAppend , %  SubStr(tagcliparray, 2) , .clip\clip.tag
        }
        ; 重新索引
        indexClip()
    }
}

/*
    显示当前clip 【无需同步】
*/
showClip(){
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap < 0) {
        toolTipClip(Clipboard)
    }else{
        toolTipImage(pBitmap)
    }
}

/*
    下一个clip【保证同步】
*/
nextClip(){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引

    if (cliparray.Length() > 1) {
        ; 下一个位置
        activeclip := activeclip + 1
        if (activeclip > cliparray.Length()){
            activeclip := 1
        }
        readClip()
    }
}

/*
    上一个clip【保证同步】
*/
prevClip(){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引

    if (cliparray.Length() > 1) {
        ; 上一个位置
        activeclip := activeclip - 1
        if (activeclip < 1){
            activeclip := cliparray.Length()
        }
        ; 将当前clip读入到Clipboard
        readClip()
    }
}     

/*
    删除所有clip【保证同步】
*/
deleteClipAll(){
    global cliparray ; clip文件名列表
    global activeclip :=0 ; 当前clip文件名索引
    global tagcliparray ; 标记的clip文件名（用"`n"分割并作为开头结尾）

    for i_, v_ in cliparray {
        if (InStr(tagcliparray, "`n" v_ "`n") == 0){
            Filedelete,.clip\%v_%.clip ; 清空clip文件
        }
    }
    cliparray := StrSplit(Trim(tagcliparray, " `t`n"), "`n")
    if (cliparray.Length() = 0){
        clipboard := "" ; 清空剪贴板
    }else{
        ; 重新索引
        indexClip(True)
    }
}

/*
    删除当前clip【保证同步】
*/
deleteClip(){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引
    global tagcliparray ; 标记的clip文件名（用"`n"分割并作为开头结尾）

    if (activeclip > 0) {
        ; 删除当前索引位置的clip
        currclip := cliparray[activeclip]
        Filedelete, .clip\%currclip%.clip
        if InStr(tagcliparray, "`n" currclip "`n") {
            tagcliparray := StrReplace(tagcliparray, "`n" currclip "`n" , "`n")
            FileDelete, .clip\clip.tag
            FileAppend , % SubStr(tagcliparray, 2) , .clip\clip.tag
        }
        ; 重新索引
        indexClip()
    }
}

/*
    新加clip【保证同步】
*/
addClip(){
    global cliparray ; Clipboar缓存文件索引cliparray

    ; 最近的clip文件名+1，即将添加的clip文件名
    lastclip := 1
    if (cliparray.Length() > 0){
        lastclip := cliparray[1] + 1 
    }
    ; 将当前Clipboard内容保存到文件
    IfExist,.clip\%lastclip%.clip
        FileDelete,.clip\%lastclip%.clip
    FileAppend,%ClipboardAll%,.clip\%lastclip%.clip
    ; 重新索引
    indexClip()
}

/*
    clip索引（逆序排列）【保证同步】
*/
indexClip(renumber := False){
    ; renumber 默认情况下不重新编号，只在tagcliparray非空且全部删除时启用

    global cliparray := [] ; clip文件名列表
    global activeclip := 0 ; 当前clip文件名索引
    global tagcliparray ; 标记的clip文件名（用"`n"分割并作为开头结尾）

    ; 收集clip文件名
    filelist := ""
    Loop, Files, .clip\*.clip
    {
        filename := SubStr(A_LoopFileName, 1, -5)
        filelist := filelist filename "`n"
    }
    if (filelist != ""){
        filelist := Trim(filelist, " `t`n")
        if renumber and (tagcliparray  != "`n") {
            ; 正序排列
            Sort,filelist,N
            ; filelist的列表形式，及其"`n"分割的字符串副本
            _filelist_ := StrSplit(filelist, "`n")
            filelist := "`n" filelist "`n"
            ; 批量文件改名，并保证和tagcliparray一致（重新从1开始编号）
            newIndex := 0
            for i_, v_ in _filelist_
            {
                newIndex := newIndex + 1
                if (newIndex != v_) { 
                    filelist := StrReplace(filelist, "`n" v_ "`n" , "`n" newIndex "`n")
                    FileMove, .clip\%v_%.clip, .clip\%newIndex%.clip , 1
                }
            }
            ; 逆序排列
            filelist := Trim(filelist, " `t`n")
            Sort,filelist,N R
            ; 写入.clip\clip.tag，并保持和tagcliparray一致
            tagcliparray := "`n" filelist "`n"
            FileDelete, .clip\clip.tag
            FileAppend , % SubStr(tagcliparray, 2), .clip\clip.tag
        }else {
            ; 逆序排列
            Sort,filelist,N R
        }
        ; 索引后的结果
        cliparray := StrSplit(filelist, "`n")
        activeclip := 1
        ; 保证和剪切板同步
        readClip()
    }
}

/*
    （文本）clip浏览提示
*/
toolTipClip(tooltip_){
    ToolTip, %tooltip_%
    SetTimer,RemoveToolTipClip,-900
}
RemoveToolTipClip:
ToolTip
return

/*
    （图片）clip浏览提示
*/
toolTipImage(pBitmap){
    global _hWND_
    ; 贴图
    CoordMode, Mouse, Screen
    MouseGetPos, X, Y
    scale := "h" A_ScreenHeight*0.2
    hWND := pasteImageToScreen(pBitmap, , X "," Y, , scale)
    Gdip_DisposeImage(pBitmap)
    fn := Func("RemoveToolTipImage").Bind(hWND)
    SetTimer, % fn , -900
}
RemoveToolTipImage(_hWND_){
    Gui, %_hWND_%:Destroy
}

/*
    桌面贴图闪动提示
*/
RemoveToolTipFlash(_hWND_){
    Loop 3
    {
        Gui, %_hWND_%:Hide
        Sleep 300
        Gui, %_hWND_%:Show
        Sleep 300
    }
}

/*
    截图复制
*/
screenShot(){
    ; 按住鼠标左键-移动鼠标-松开: 选择截图区域
    screen_ := SelectRegionFromScreen("LButton")
    ; 获取区域截图
    pBitmap := Gdip_BitmapFromScreen(screen_)
    ; 获取到Clipboard
    Gdip_SetBitmapToClipboard(pBitmap)
    ; 删除内存位图
    Gdip_DisposeImage(pBitmap)
    return 
}

/*
    粘贴到屏幕
*/
screenPaste(){
    global screenPastes ; 用于临时存储屏幕贴图的句柄列表

    ; 从Clipboard获取位图
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap < 0 ){
        return -1
    }
    ; 贴图
	CoordMode, Mouse, Screen
    MouseGetPos, X, Y
    hWND := pasteImageToScreen(pBitmap, , X "," Y)
    screenPastes.Push(hWND)
    ; 删除内存位图
    Gdip_DisposeImage(pBitmap)
    ; 定位
    down_ := False
    loop{
        keyIsDown := GetKeyState("LButton" , "P")
        if keyIsDown {
            down_ := True
        } else if down_{
            break
        }
        MouseGetPos, X, Y
        ; 移动贴图
        WinMove, ahk_id %hWND%, , %X%, %Y%  
    }
    return hWND
}

/*
    清空所有屏幕贴图
*/
clearScreenPastes(){
    global screenPastes ; 桌面贴图列表
    global activepaste :=0 ; 当前桌面贴图索引

    if (not (not screenPastes)){
        for idx_, value_ in screenPastes {
            Gui, %value_%:Destroy
        }
    }
    screenPastes := []
}

/*
    删除指定屏幕贴图
*/
deletScreenPaste(hWND){
    global screenPastes ; 桌面贴图列表
    global activepaste ; 当前桌面贴图索引
    if (not (not screenPastes)){
        for idx_, value_ in screenPastes {
            if (value_ == hWND){
                Gui, %value_%:Destroy
                screenPastes.RemoveAt(idx_)
                Break
            }
        }
    }
    if (screenPaste.Length()==0){
        activepaste := 0
    }else if (activepaste > screenPaste.Length()){
        activepaste := 1
    }
}

; 进入搜索粘贴模式
; 只搜索剪切板中的文本内容
; 凡是搜索过的内容，都不会被“全部删除命令a”删除
searchTextClipForPaste(){
    global cliparray
    global matchedSingleLineClip := [] ; 匹配到的所有单行文本
    global matchedSingleLineClipIndex := [] ; 匹配到的所有单行文本在cliparray中的索引
    ; 输入搜索关键词，然后tab确认
    ; 等候输入
    Input, search, V C , {tab}{space}{enter}{esc}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Up}{Down}{Home}{End}{PgUp}{PgDn}{CapsLock}{NumLock}{PrintScreen}{Pause}
    ; 非tab终止符触发，表示放弃
    if (ErrorLevel != "EndKey:tab"){
        return
    }
    ; 搜索
    for i_ , v_ in cliparray{
        if FileExist(".clip\" v_ ".clip"){
            FileRead,Clipboard,*c .clip\%v_%.clip
            clip := StrSplit(Trim(Clipboard, " `t`r`n"), "`r`n")
            ; 确保只处理单行文本
            if (clip.Length() != 1) {
                Continue
            }
            clip := Trim(clip[1])
            if (clip = "") {
                Continue
            }
            ; 单行匹配收集
            if InStr(clip, search){
                matchedSingleLineClip.Push(clip)
                matchedSingleLineClipIndex.Push(i_)
            }
        }       
    }
    ; 弹出建议窗口
    if (matchedSingleLineClip.Length() > 0)
    {
        n_ := StrLen(search)+1
        Send, {bs %n_%}
        Sleep 30 ; 延迟30毫秒，确保弹出提示窗口前退格完成（似乎没有同步发送的API，只能这样）
        ; 准备列表数据，并计算提示窗口的长宽
        maxWidth := 100
        maxHeight := Min(Max(Ceil(20*matchedSingleLineClip.Length()),40),200)
        suggList := ""
        for index, value in matchedSingleLineClip
        {
            maxWidth := Max(Ceil(10*StrLen(value)),maxWidth)
            suggList := suggList value "`n"
        }
        maxWidth := Min(maxWidth,500)
        maxWH := maxWidth "," maxHeight
        ; 弹出提示窗口
        ShowSuggestionsGui(suggList, "SearchPasteHandler", maxWH)
        return
    }
}

; 搜索后选择后的粘贴处理
SearchPasteHandler(index){
    global cliparray ; clip文件名列表
    global activeclip ; 当前clip文件名索引
    global matchedSingleLineClip ; 匹配到的所有单行文本
    global matchedSingleLineClipIndex ; 匹配到的所有单行文本在cliparray中的索引 
    global tagcliparray ; 标记的clip文件名（用"`n"分割并作为开头结尾）

    ; 选择粘贴
    Send, % matchedSingleLineClip[index]

    ; 凡是搜索选择过的内容，都认为是比较重要的，所以特别添加到.clip\clip.tag中标记之 
    activeclip := matchedSingleLineClipIndex[index]
    currclip := cliparray[activeclip]
    if (tagcliparray = "`n") or (0 = InStr(tagcliparray, "\n"currclip "\n")) {
        FileAppend , % currclip "`n", .clip\clip.tag
        tagcliparray := tagcliparray currclip "`n"
    }

    ; 将选择的clip移到最新
    moveClip()
}

; 选择保存文件
;FileSelectFile, saveFile, S, , 保存截图, PNG图片 (*.png)
;if saveFile {
;    SplitPath, saveFile , , , outExt
;    if (not outExt){
;        saveFile := saveFile ".png"
;    }
;    ; 保存到文件
;    Gdip_SaveBitmapToFile(pBitmap, saveFile)
;}

