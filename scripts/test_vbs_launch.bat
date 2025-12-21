@echo off
REM ============================================
REM V8Ray VBScript 启动测试
REM 测试 VBScript 是否能正确启动批处理脚本
REM ============================================

chcp 65001 > nul
setlocal

set SCRIPT_DIR=%~dp0
set TEST_BAT=%SCRIPT_DIR%test_vbs_target.bat
set TEST_VBS=%SCRIPT_DIR%test_vbs_launcher.vbs
set LOG_FILE=%SCRIPT_DIR%vbs_test.log

echo ========================================
echo VBScript 启动测试
echo ========================================
echo.

REM 创建目标批处理脚本
echo 创建目标批处理脚本: %TEST_BAT%
(
echo @echo off
echo chcp 65001 ^> nul
echo echo VBScript 成功启动了这个批处理脚本！ ^> "%LOG_FILE%"
echo echo 时间: %%DATE%% %%TIME%% ^>^> "%LOG_FILE%"
echo echo 当前目录: %%CD%% ^>^> "%LOG_FILE%"
echo echo 脚本路径: %%~f0 ^>^> "%LOG_FILE%"
echo echo. ^>^> "%LOG_FILE%"
echo echo 测试完成，等待2秒后退出... ^>^> "%LOG_FILE%"
echo timeout /t 2 /nobreak ^> nul
) > "%TEST_BAT%"

echo 目标批处理脚本内容:
type "%TEST_BAT%"
echo.

REM 创建 VBScript 启动器
echo 创建 VBScript 启动器: %TEST_VBS%
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run """%TEST_BAT%""", 1, False
echo Set WshShell = Nothing
) > "%TEST_VBS%"

echo VBScript 内容:
type "%TEST_VBS%"
echo.

REM 删除旧的日志文件
if exist "%LOG_FILE%" del "%LOG_FILE%"

echo ========================================
echo 开始测试
echo ========================================
echo.
echo 使用 wscript 启动 VBScript...
wscript "%TEST_VBS%"
set VBS_EXIT=%errorlevel%
echo wscript 退出代码: %VBS_EXIT%

echo.
echo 等待 5 秒让脚本执行...
timeout /t 5 /nobreak > nul

echo.
echo ========================================
echo 检查结果
echo ========================================
echo.

if exist "%LOG_FILE%" (
    echo 日志文件存在！内容:
    echo ----------------------------------------
    type "%LOG_FILE%"
    echo ----------------------------------------
    echo.
    echo 测试成功！VBScript 正确启动了批处理脚本。
) else (
    echo 错误：日志文件不存在！
    echo 这意味着 VBScript 没有成功启动批处理脚本。
    echo.
    echo 可能的原因:
    echo 1. Windows 安全策略阻止了 VBScript
    echo 2. 路径中有特殊字符
    echo 3. 权限问题
)

echo.
echo ========================================
echo 清理测试文件
echo ========================================
del "%TEST_BAT%" 2>nul
del "%TEST_VBS%" 2>nul
del "%LOG_FILE%" 2>nul
echo 清理完成

echo.
pause
endlocal
