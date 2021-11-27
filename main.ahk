;---------------------------------------------------
; 模块注册
; --------------------------------------------------
;    据此可实现模块之间的相互调用
;---------------------------------------------------

FileEncoding , UTF-8
global modules := {}

; im_switch模块注册
modules["im_switch"] := True

; latex2unicode模块注册
modules["latex2unicode"] := True
; 加载热latex
loadHotlatex()

; action_play模块注册
modules["action_play"] := True


; 启动GDI+
#Include %A_ScriptDir%\lib\Gdip_All.ahk
If !pToken := Gdip_Startup()
{
	MsgBox "启动GDI+启动失败，请确保您的系统中存在GDI+"
	ExitApp
}
OnExit("ExitFunc")

ExitFunc(ExitReason, ExitCode)
{
   global
   Gdip_Shutdown(pToken)
}

Return ;  include中完全一样的代码不会重复执行


;---------------------------------------------------
; 微软拼音输入法辅助 （im_switch）
; --------------------------------------------------
; 假设：
;       1) 输入法采用微软拼音并且默认为英文
;       2) 本脚开机启动
;       3) 管住手，禁止鼠标点击切换中英文
;       4) 为每一个活动过的窗口记录中英文状态
;
;---------------------------------------------------
#include %A_ScriptDir%\im_switch.ahk


;---------------------------------------------------
; Latex对应的Unicode （latex2unicode）
; ----------------------------------------------
; 参考Katex，尽可能使用latex触发出对应的unicode字符
;
; https://katex.org/docs/supported.html
; 
; 只对不方便键盘输入的字符进行latex[TAB]替换， 如果没有替换说明输入错误或不支持
;
; 只支持单字符的latex触发（目前支持如下7类）
;    1) _n[TAB]             ₙ   【下标触发】
;    2) ^n[TAB]             ⁿ   【上标触发】
;    3) \alpha[TAB]         α   【单字符触发】
;    4) \mathbbR[TAB]       ℝ   【空心字符触发】
;    5) \mathfrakR[TAB]     ℜ   【Fraktur字符触发】
;    6) \mathcalR[TAB]      𝓡   【花体字符触发】
;    7) \hatR[TAB]          R̂   【戴帽花体字符触发】
; ----------------------------------------------
#include %A_ScriptDir%\latex2unicode.ahk

; -----------------------------------------------
; 自动演示
;------------------------------------------------
; Uncomment if Gdip.ahk is not in your standard library
#include %A_ScriptDir%\action_play.ahk

