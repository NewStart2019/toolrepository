Dim WshShell
Set WshShell=WScript.CreateObject("WScript.Shell")

Dim dict
Set dict = CreateObject("Scripting.Dictionary")

' 添加IP地址和密码对
dict.Add "172.16.0.197", "xxxx!"


If WScript.Arguments.Count < 1 Then
    WScript.Echo "Usage: sshpass <ip> [password]" & vbNewLine & "Example: sshpass 172.16.0.1 1234567"
    WScript.Quit 1 ' 退出脚本并返回错误码 1
End If

ip = WScript.Arguments.Item(0)
If WScript.Arguments.Count = 2 Then
    password = WScript.Arguments.Item(1)
End If

If Len(password) = 0 Then
    password = dict(ip)
End If

' 休眠 800ms
WScript.Sleep 800
WshShell.SendKeys "ssh root@" & ip & vbCr
' 休眠 800ms
WScript.Sleep 800
' 输入密码
WshShell.SendKeys password & vbCr

' 使用教程：
' 1. 打开 cmd 命令行
' 2、执行命令自动连接服务器 wscript sshpass.vbs <ip> [password]
