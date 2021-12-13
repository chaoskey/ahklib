#Include lib\Gdip_All.ahk

;-----------------------------------------------
;            通用的一些函数
;-----------------------------------------------

/*
    GDI+令牌:  global token_gdip 
*/

startupGdip(){
    global token_gdip
    if (not token_gdip){
        ; 启动GDI+
        If !token_gdip := Gdip_Startup()
        {
            MsgBox "启动GDI+启动失败，请确保您的系统中存在GDI+"
            ExitApp
        }
        OnExit("ExitFunc")
    }
    return token_gdip
}

ExitFunc(ExitReason, ExitCode)
{
    global token_gdip
    if token_gdip {
        Gdip_Shutdown(pToken)
    }
}



/*    选择屏幕上的矩形区域   
指定键 button_ 从“按下”到“松开”拉出的矩形区域（相对整个屏幕）

参数:
    button_ 按键

返回值:
    形如: “x|y|w|h”,  选定的矩形区域 左上角( x, y ) 和 长宽(w × h)

需要GDI+的支持
#Include lib\TokenGdip.ahk
startupGdip()
*/
SelectRegionFromScreen(button_){
	; 全屏模糊
	pBitmap := Gdip_BitmapFromScreen()
	hWND := pasteImageToScreen(pBitmap)
	Gdip_DisposeImage(pBitmap)

	; 区域长宽提示
	Gui, textTip:-Caption +LastFound +AlwaysOnTop +Owner +Disabled -SysMenu
	Gui, textTip:Font, s10 cFFFFFF , Verdana
	Gui, textTip:Color, 000000
	Gui, textTip:Add, Text, BackgroundTrans HwndtextTipHwnd

	; 不可的选择区域窗口
	Gui, regionGui:-Caption +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs +Border
	WinSet, Transparent, 100
	; 屏幕绝对坐标模式，作用于MouseGetPos
	CoordMode, Mouse, Screen
	; 拖拽
    MX := False, MY := False 
	Loop{
		if GetKeyState(button_, "P"){  ; button_ 按下后（松开前）
			; 鼠标当前位置
			MouseGetPos, MXend, MYend
            if (MX == False) or (MY == False){
				; 按下的起始位置
                MX := MXend
                MY := MYend
            }
			; 当前矩形: 宽，高，左上角
			W := abs(MX - MXend)
			H := abs(MY - MYend)
			X := Min(MX, MXend)
			Y := Min(MY, MYend)
			; 显示窗口
			Gui, regionGui:Show, x%X% y%Y% w%W% h%H%
			; 区域长宽提示
			str_ := "( " X " , " Y " ) " W " × " H " px"
			w_ := 10*(2+StrLen(str_))*55/70  ; 估算控件宽度（10对应字体大小:s10）
			GuiControl, Text, %textTipHwnd% , %str_%
			GuiControl, Move, %textTipHwnd%, w%w_%
			Gui, textTip:Show, % "NoActivate NA x" X " y" Y-30  " w" w_ 
		}else if (MX != False) and (MY != False) {
			; button_  按下后，再松开
			Break
        }else{
            ; 鼠标当前位置
			MouseGetPos, X_, Y_
            ; 区域长宽提示
			str_ := "( " X_ " , " Y_ " ) px"
			w_ := 10*(2+StrLen(str_))*55/70  ; 估算控件宽度（10对应字体大小:s10）
			GuiControl, Text, %textTipHwnd% , %str_%
			GuiControl, Move, %textTipHwnd%, w%w_%
			Gui, textTip:Show, % "NoActivate NA x" X_ " y" Y_-30  " w" w_ 
        }
	}
	; 销毁窗口
	Gui, regionGui:Destroy
	Gui, textTip:Destroy
	Gui, %hWND%:Destroy
	Return ( X "|" Y "|" W "|" H )
}



/*    贴图
参数:
	pBitmap, 位图
	crop，位图的特定区域（默认位图全区域）
	position, 贴图位置（默认居中布局）
	alpha， 贴图的透明度（默认255不透明）

返回:
	hWND, 贴图窗口句柄

需要GDI+的支持
#Include lib\TokenGdip.ahk
startupGdip()

scale 可能是 1(缩放比) w100（固定宽） h100（固定高）
*/
pasteImageToScreen(pBitmap, crop := False, position := False, alpha := 255, scale := 1){
    ; http://yfvb.com/help/gdiplus/index.htm
    ; https://www.autoahk.com/archives/34920

    Gui, New ; 必须开新窗口，才能开新图
    ; E0x80000  WS_EX_LAYERED   分层窗口 https://docs.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
    ; 创建一个分层窗口（+E0x80000 ：UpdateLayeredWindow必须用这个才能工作！）它总是在顶部（+AlwaysOnTop），没有任务栏条目或标题
    Gui, -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs
    Gui, Show
    ; 获取窗口句柄
    hWND := WinExist()

    ; 获取位图的长宽
    Width := Gdip_GetImageWidth(pBitmap)
    Height := Gdip_GetImageHeight(pBitmap)
    sx := 0, sy := 0, sw := Width, sh := Height ; 位图指定区域的位置尺寸（相对位图），默认位图
    dx := 0, dy := 0, dw := Width, dh := Height ; 画布指定区域的位置尺寸（相对画布），默认画布
    if crop {
        crops := StrSplit(crop, ",")
        if (crops.Length() == 4) {
            sx := crops[1], sy := crops[2], sw := crops[3], sh := crops[4]
            dw := crops[3], dh := crops[4]
        }
    }

    if (SubStr(scale, 1 , 1) = "w"){
        scale := SubStr(scale, 2)/dw
    }else if (SubStr(scale, 1 , 1) = "h"){
        scale := SubStr(scale, 2)/dh
    }
    dw := dw*scale
    dh := dh*scale

    ; DC :  设备上下文
    ; GDI : 图形设备接口
    ; DIB : 设备无关位图

    ; 获取DC（hdc）
    hdc := CreateCompatibleDC()
    ; 创建GDI对象（hbm）
    ; 这里具体为DIB，并设置画布尺寸
    hbm := CreateDIBSection(dw, dh)
    ; 将GDI对象（hbm）写入DC（hdc）
    ; 返回hdc老的对象obm
    obm := SelectObject(hdc, hbm)
    ; 从DC（hdc）创建画布（G）
    G := Gdip_GraphicsFromHDC(hdc)

    ; 设置图像对象G的插值模式。插值模式确定当图像缩放或旋转时使用的算法。
    ; 7:  高品质双三次
    Gdip_SetInterpolationMode(G, 7)
    ; 将位图GID对象（pBitmap）的指定部分绘制到画布（G）
    Gdip_DrawImage(G, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh)
    ; 删除位图GID对象（pBitmap）
    ;Gdip_DisposeImage(pBitmap) 
    ; 将图像对象G的世界变换矩阵设置为单位矩阵。
    ; 如果图像对象的世界变换矩阵是单位矩阵，则不会将世界变换应用于由图像对象绘制的项目。
    Gdip_ResetWorldTransform(G)
    ; ---------------------------
    ; 使用GDI位图的设备上下文句柄hdc更新分层窗口hwnd1 
    xpos := (A_ScreenWidth-dw)//2
    ypos := (A_ScreenHeight-dh)//2
    if position{
        pos_ := StrSplit(position, ",")
        if (pos_.Length() == 2) {
            xpos := pos_[1]
            ypos := pos_[2]
        }
    } 
    UpdateLayeredWindow(hwnd, hdc, xpos, ypos, dw, dh, alpha)

    ; 删除画布（G）
    Gdip_DeleteGraphics(G)
    ; 恢复DC（hdc）原来的GDI对象（obm）
    SelectObject(hdc, obm)
    ; 释放删除创建的GDI对象（hbm）
    DeleteObject(hbm)
    ; 释放删除DC（hdc）
    DeleteDC(hdc)

	return hWND
}

/*
    估算多行文本所占像素宽高

ByRef width  返回值:  像素宽
ByRef height 返回值:  像素高
texts 多行文本
https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/Gui.htm#Font
Options := "s10"  字体选项
FontName := "Courier New"  字体名称
*/
getTextsWidthHeight(ByRef width, ByRef height, texts, Options := "s10", FontName := "Courier New"){
    global tmpedit

    rows := 0
    Loop, parse, texts, `n, `r  ; 在 `r 之前指定 `n, 这样可以同时支持对 Windows 和 Unix 文件的解析.
    {
        rows := rows + 1
    }
    if (rows = 0) or (StrLen(texts) = 0) {
        width := 0
        height := 0
        return
    }
    ; 创建一个临时控件（用于获取字符串的实际像素长宽）, 用完后立刻销毁
    Gui, TmpGui:New
    Gui, TmpGui:Font, %Options%, %FontName%
    Gui, TmpGui:Add, Edit, x0 y0 r%rows% -Wrap -VScroll -HScroll vtmpedit,  %texts%
    Gui, TmpGui:-Caption +ToolWindow +AlwaysOnTop +LastFound
    GuiControlGet, tmp, Pos , tmpedit
    width := tmpW
    height := tmpH
    Gui, TmpGui:Destroy
}
/*
    估算文本列表所占像素宽高

ByRef width  返回值:  像素宽
ByRef height 返回值:  像素高
ByRef texts 返回值:  多行文本
textList 文本列表
https://www.autoahk.com/help/autohotkey/zh-cn/docs/commands/Gui.htm#Font
Options := "s10"  字体选项
FontName := "Courier New"  字体名称
*/
getTextListWidthHeight(ByRef width, ByRef height, ByRef texts, textList , Options := "s10", FontName := "Courier New"){
    texts := ""
    for i_, v_ in textList{
        texts := texts v_ "`n"
    }
    texts := Trim(texts, "`r`n")
    getTextsWidthHeight(width, height, texts, Options, FontName)
}

/*
    基于简单列表的跟随提示
    
用到此函数族的功能块： LaTeXHelper.ahk CtrlRich.ahk
下面这族函数，用户只需要调用ShowSuggestionsGui(...)
*/

; 显示列表提示窗口
ShowSuggestionsGui(_suggList_, _actionFun_){ 
    ; _suggList_   ; 提示列表数据（用`n分割的字符串）
    ; _actionFun_(index) ; 实际触发的动作函数，index是已选项的索引

    global suggMatchedID ; 提示窗口匹配项的控件ID
    global suggActionFun := _actionFun_

    ; 准备列表数据，并计算提示窗口的长宽
    getTextListWidthHeight(width, height, suggList, _suggList_ , "s10", "Courier New")
    width := Min(Max(width,100),600)
    height := Min(Max(height,40),200)
    ; 创建显示列表提示窗口(如果已创建，则利用已创建的窗口)
    SetupSuggestionsGui()
    Gui, Suggestions:Default
    if (suggList = ""){
        Gui, Suggestions:Hide
        return
    }
    GuiControl,, suggMatchedID, `n%suggList%
    GuiControl, Choose, suggMatchedID, 1
    GuiControl, Move, suggMatchedID, w%width% h%height% ;设置控件宽高
    ; 当前光标或鼠标位置
    CoordMode, Caret, Screen
    if (not A_CaretX){
        CoordMode, Mouse, Screen
        MouseGetPos, posX, posY
        posX := posX + 10
    }else {
        posX := A_CaretX
        posY := A_CaretY + 20
    }
    if (posX + width > A_ScreenWidth) {
        posX := posX - width
    }
    if (posY + height > A_ScreenHeight) {
        posY := posY - height
    }
    Gui, Show, x%posX% y%posY% w%width% h%height% ;  NoActivate
}

; 创建显示列表提示窗口
SetupSuggestionsGui(){

    global suggMatchedID    ; 提示窗口匹配项的控件ID
    global suggHWND         ; 提示窗口句柄

    if (not suggHWND) {
        ; 设置建议窗口
        Gui, Suggestions:Default
        Gui, Font, s10, Courier New
        Gui, +Delimiter`n
        Gui, Add, ListBox, x0 y0 0x100 vsuggMatchedID gSuggCompleteAction AltSubmit
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        suggHWND := WinExist()
        GuiControlGet, tmp, Pos , suggMatchedID
        Gui, Show, w%tmpW% h%tmpH% Hide, SuggCompleteWin
        Gui, Suggestions:Hide
        ; 提示窗口热键处理
        Hotkey, IfWinExist, SuggCompleteWin ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, SuggLButtonHandler
        Hotkey, Up, SuggUpHanler
        Hotkey, Down, SuggDownHanler
        Hotkey, Tab, SuggCompleteAction
        Hotkey, Enter, SuggCompleteAction
        Hotkey, IfWinExist
    }
}

; 根据提示窗口选择完成
SuggCompleteAction(){ 
    Critical

    global suggMatchedID    ; 提示窗口匹配项的控件ID
    global suggActionFun    ; suggActionFun(index), 实际触发的动作函数，index是已选项的索引

    ; {enter} {tab}   或 双击匹配项  触发粘贴
    If (A_GuiEvent != "" && A_GuiEvent != "DoubleClick")
        Return

    Gui, Suggestions:Default
    Gui, Suggestions:Hide

    ; 发送选择的内容
    GuiControlGet, index,, suggMatchedID
    ; 触发的动作函数
    %suggActionFun%(index)
    Gui, Suggestions:Hide
}

SuggUpHanler(){
    Gui, Suggestions:Default
    GuiControlGet, Temp1,, suggMatchedID
    if (Temp1 > 1) {
        GuiControl, Choose, suggMatchedID, % Temp1 - 1    
    }
}

SuggDownHanler(){
    Gui, Suggestions:Default
    GuiControlGet, Temp1,, suggMatchedID
    GuiControl, Choose, suggMatchedID, % Temp1 + 1
}

SuggLButtonHandler(){
    global suggHWND
    MouseGetPos,,, Temp1
    if (Temp1 != suggHWND){
        Gui, Suggestions:Hide
    }
}

/*
    简单的跟随搜索框
    
用到此函数族的功能块： CtrlRich.ahk
下面这族函数，用户只需要调用ShowFollowSearchBox(...)
*/

; 显示简单的跟随搜索框
ShowFollowSearchBox(_actionFun_){ 
    global searchBoxText  ; 搜索框文本内容的关联变量
    ; searchBoxActionFun(searchText) : 实际触发的动作函数，searchText是已输入的搜索关键词
    global searchBoxActionFun := _actionFun_

    ; 创建搜索框(只创建一次)
    SetupSearchBoxGui()
    ; 编辑框清空
    Gui, FollowSearchBoxWin:Default
    GuiControl,, searchBoxText, % ""
    ; 当前光标或鼠标位置
    CoordMode, Caret, Screen
    if (not A_CaretX){
        CoordMode, Mouse, Screen
        MouseGetPos, posX, posY
        posX := posX + 10
    }else {
        posX := A_CaretX
        posY := A_CaretY
    }
    GuiControlGet, tmp, Pos , searchBoxText
    if (posX + tmpW > A_ScreenWidth) {
        posX := posX - tmpW
        posY := posY + 20
    }
    if (posY + tmpH > A_ScreenHeight) {
        posY := posY - tmpH
    }
    ; 跟随光标显示搜索框
    Gui, Show, x%posX% y%posY% NoActivate
}

; 创建搜索框(只创建一次)
SetupSearchBoxGui(){
    global searchBoxText  ; 搜索框文本内容的关联变量
    global searchBoxHWND  ; 搜索框窗口句柄

    if (not searchBoxHWND) {
        ; 设置搜索框
        Gui, FollowSearchBoxWin:Default
        Gui, Font, s10, Courier New
        Gui, Add, Edit, x0 y0 w50 vsearchBoxText gupdateSearchBoxWidth
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        searchBoxHWND := WinExist()
        GuiControlGet, tmp, Pos , searchBoxText
        Gui, Show, w50 h%tmpH% Hide, FollowSearchBoxWin
        Gui, FollowSearchBoxWin:Hide
        ; 搜索框热键处理
        Hotkey, IfWinExist, FollowSearchBoxWin ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, SearchBoxLButtonHandler
        Hotkey, Enter, SearchBoxEnterHandler
        Hotkey, IfWinExist
    }
}

; 动态更新搜索框的长度
updateSearchBoxWidth(){
    global searchBoxText  ; 搜索框文本内容的关联变量

    ; 搜索框的宽
    GuiControlGet, searchBoxText
    getTextsWidthHeight(width, height, searchBoxText, "s10", "Courier New")
    width := Min(Max(width + 10, 50),200)
    ; 按指定宽重新显示窗口
    Gui, FollowSearchBoxWin:Default
    GuiControl, Move, searchBoxText, w%width% ;设置搜索框控件宽
    Gui, FollowSearchBoxWin:Show, w%width%
}

; 搜索框回车确认
SearchBoxEnterHandler(){ 
    Critical

    global searchBoxText   ; 搜索框文本内容的关联变量
    ; searchBoxActionFun(searchText) : 实际触发的动作函数，searchText是已输入的搜索关键词
    global searchBoxActionFun

    Gui, FollowSearchBoxWin:Default
    Gui, FollowSearchBoxWin:Submit
    Gui, FollowSearchBoxWin:Hide

    ; 触发的动作函数
    if (StrLen(Trim(searchBoxText)) > 0) {
        %searchBoxActionFun%(searchBoxText)
    }
}

; 搜索框窗口外鼠标点击关闭窗口
SearchBoxLButtonHandler(){
    global searchBoxHWND ; 搜索框窗口句柄

    MouseGetPos,,, Temp1
    if (Temp1 != searchBoxHWND){
        Gui, FollowSearchBoxWin:Hide
    }
}

/*
    简单的跟随编辑框

用到此函数族的功能块： CtrlRich.ahk
下面这族函数，用户只需要调用ShowFollowEditBox(...)
*/

; 显示简单的跟随编辑框
ShowFollowEditBox(clip, _actionFun_){
    global editBoxText  ; 编辑框文本内容的关联变量
    ; editBoxActionFun(editText) : 实际触发的动作函数，editText是已输入的内容
    global editBoxActionFun := _actionFun_

    ; 编辑框的宽高
    getTextsWidthHeight(width, height, clip, "s10", "Courier New")
    width := Min(Max(width + 10,100),600)
    height := Min(Max(height,20),200)
    ; 创建编辑框(只创建一次)
    SetupEditBoxGui()
    ; 填写编辑框
    Gui, FollowEditBoxWin:Default
    GuiControl,, editBoxText, %clip%
    ; 当前光标或鼠标位置
    CoordMode, Caret, Screen
    if (not A_CaretX){
        CoordMode, Mouse, Screen
        MouseGetPos, posX, posY
        posX := posX + 10
    }else {
        posX := A_CaretX
        posY := A_CaretY
    }
    if (posX + width > A_ScreenWidth) {
        posX := posX - width
        posY := posY + 20
    }
    if (posY + height > A_ScreenHeight) {
        posY := posY - height
    }
    ; 跟随光标显示搜索框
    GuiControl, Move, editBoxText, w%width% h%height% ;设置搜索框控件宽
    Gui, Show, x%posX% y%posY% w%width% h%height% ; NoActivate
}

; 创建搜索框(只创建一次)
SetupEditBoxGui(){
    global editBoxText  ; 搜索框文本内容的关联变量
    global editBoxHWND  ; 搜索框窗口句柄

    if (not editBoxHWND) {
        ; 设置搜索框
        Gui, FollowEditBoxWin:Default
        Gui, Font, s10, Courier New
        Gui, Add, Edit, x0 y0 r3 -Wrap -VScroll -HScroll veditBoxText gupdateEditBoxWidth
        Gui, -Caption +ToolWindow +AlwaysOnTop +LastFound
        editBoxHWND := WinExist()
        GuiControlGet, tmp, Pos , editBoxText
        Gui, Show, w%tmpW% h%tmpH% Hide, FollowEditBoxWin
        Gui, FollowEditBoxWin:Hide
        ; 搜索框热键处理
        Hotkey, IfWinExist, FollowEditBoxWin ahk_class AutoHotkeyGUI
        Hotkey, ~LButton, editBoxLButtonHandler
        Hotkey, ^s, editBoxCtrlSHandler
        Hotkey, IfWinExist
    }
}

; 动态更新编辑框的宽高
updateEditBoxWidth(){
    global editBoxText  ; 搜索框文本内容的关联变量

    ; 编辑框的宽高
    GuiControlGet, editBoxText
    getTextsWidthHeight(width, height, editBoxText, "s10", "Courier New")
    width := Min(Max(width + 10,100),600)
    height := Min(Max(height,20),200)
    ; 按指定宽高重新显示窗口
    Gui, FollowEditBoxWin:Default
    GuiControl, Move, editBoxText, w%width% h%height% ;设置搜索框控件宽
    Gui, FollowEditBoxWin:Show, w%width% h%height%
}

; 搜索框回车确认
editBoxCtrlSHandler(){
    Critical

    global editBoxText   ; 搜索框文本内容的关联变量
    ; editBoxActionFun(saveText) : 实际触发的动作函数，saveText是已输入的内容
    global editBoxActionFun
    global xMaxIEditBox := 0 ; 搜索框中光标相对搜索框窗口左端最大距离
    global xMinIEditBox := 0 ; 搜索框中光标相对搜索框窗口左端最小距离

    Gui, FollowEditBoxWin:Default
    Gui, FollowEditBoxWin:Submit
    Gui, FollowEditBoxWin:Hide

    ; 触发的动作函数
    %editBoxActionFun%(editBoxText)
}

; 搜索框窗口外鼠标点击关闭窗口
editBoxLButtonHandler(){
    global xMaxIEditBox := 0 ; 搜索框中光标相对搜索框窗口左端最大距离
    global xMinIEditBox := 0 ; 搜索框中光标相对搜索框窗口左端最小距离
    global editBoxHWND ; 搜索框窗口句柄

    MouseGetPos,,, Temp1
    if (Temp1 != editBoxHWND){
        Gui, FollowEditBoxWin:Hide
    }
}

