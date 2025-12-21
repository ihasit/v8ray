@echo off
REM ============================================
REM V8Ray 自动更新测试脚本
REM 用于测试更新逻辑，无需实际运行应用
REM ============================================

chcp 65001 > nul
setlocal enabledelayedexpansion

REM 设置测试目录（模拟应用目录）
set APP_DIR=%~dp0test_app
set TEMP_DIR=%~dp0test_app\TEMP
set SOURCE_DIR=%~dp0test_source
set LOGFILE=%TEMP_DIR%\v8ray_update.log
set EXECUTABLE=%APP_DIR%\v8ray.exe

echo ========================================
echo V8Ray 自动更新测试脚本
echo ========================================
echo.

REM 创建测试目录结构
echo [准备] 创建测试目录结构...
if exist "%APP_DIR%" rmdir /S /Q "%APP_DIR%"
if exist "%SOURCE_DIR%" rmdir /S /Q "%SOURCE_DIR%"

mkdir "%APP_DIR%"
mkdir "%TEMP_DIR%"
mkdir "%SOURCE_DIR%"
mkdir "%SOURCE_DIR%\data"
mkdir "%SOURCE_DIR%\bin"

REM 在源目录创建模拟文件（模拟新版本）
echo 这是新版本的 v8ray.exe > "%SOURCE_DIR%\v8ray.exe"
echo 新版本 DLL > "%SOURCE_DIR%\flutter_windows.dll"
echo 新版本数据 > "%SOURCE_DIR%\data\app.json"
echo 新版本 xray > "%SOURCE_DIR%\bin\xray.exe"

REM 在应用目录创建旧文件（模拟当前版本）
echo 这是旧版本的 v8ray.exe > "%APP_DIR%\v8ray.exe"
echo 旧版本 DLL > "%APP_DIR%\flutter_windows.dll"

echo [准备] 测试目录创建完成
echo 源目录: %SOURCE_DIR%
echo 目标目录: %APP_DIR%
echo.

REM ============================================
REM 开始测试更新流程
REM ============================================

echo V8Ray Update Log > "%LOGFILE%"
echo 更新时间: %DATE% %TIME% >> "%LOGFILE%"
echo ======================================== >> "%LOGFILE%"

echo [1/5] 模拟等待 V8Ray 关闭（跳过实际等待）...
echo [1/5] 等待 V8Ray 关闭... >> "%LOGFILE%"

echo [2/5] 检查源目录...
echo 源目录: %SOURCE_DIR% >> "%LOGFILE%"
echo 目标目录: %APP_DIR% >> "%LOGFILE%"
echo. >> "%LOGFILE%"
echo 源目录内容: >> "%LOGFILE%"
dir "%SOURCE_DIR%" >> "%LOGFILE%" 2>&1

echo [3/5] 更新 V8Ray 文件...
echo 源目录: %SOURCE_DIR%
echo 目标目录: %APP_DIR%

REM 使用 robocopy 复制文件
echo. >> "%LOGFILE%"
echo 执行 robocopy: >> "%LOGFILE%"
echo robocopy "%SOURCE_DIR%" "%APP_DIR%" /E /IS /IT /R:3 /W:1 >> "%LOGFILE%"
echo. >> "%LOGFILE%"
robocopy "%SOURCE_DIR%" "%APP_DIR%" /E /IS /IT /R:3 /W:1 >> "%LOGFILE%" 2>&1
set ROBOCOPY_EXIT=%errorlevel%
echo Robocopy 退出代码: %ROBOCOPY_EXIT% >> "%LOGFILE%"

echo Robocopy 退出代码: %ROBOCOPY_EXIT%

REM robocopy 退出代码: 0-7 表示成功, >=8 表示失败
if %ROBOCOPY_EXIT% GEQ 8 (
    echo 错误：文件复制失败！退出代码: %ROBOCOPY_EXIT%
    echo 错误：文件复制失败！退出代码: %ROBOCOPY_EXIT% >> "%LOGFILE%"
    echo 请查看日志文件: %LOGFILE%
    goto :error
)

echo [4/5] 清理临时文件...
REM rmdir /S /Q "%SOURCE_DIR%" >> "%LOGFILE%" 2>&1
echo 跳过清理以便检查

echo [5/5] 模拟启动 V8Ray...
echo 启动命令: %EXECUTABLE% >> "%LOGFILE%"
echo 模拟启动: %EXECUTABLE%

echo.
echo ========================================
echo 更新测试完成！
echo ========================================
echo 更新完成！ >> "%LOGFILE%"

echo.
echo [验证] 检查目标目录内容...
echo.
echo 目标目录内容:
dir "%APP_DIR%"

echo.
echo [验证] 检查 v8ray.exe 内容:
type "%APP_DIR%\v8ray.exe"

echo.
echo [验证] 检查日志文件:
echo 日志文件位置: %LOGFILE%
echo.
type "%LOGFILE%"

echo.
echo ========================================
echo 测试完成，按任意键清理测试目录...
pause

REM 清理测试目录
rmdir /S /Q "%APP_DIR%"
rmdir /S /Q "%SOURCE_DIR%"
echo 测试目录已清理
goto :end

:error
echo.
echo ========================================
echo 测试失败！
echo ========================================
pause

:end
endlocal
