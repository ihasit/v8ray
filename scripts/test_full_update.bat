@echo off
REM ============================================
REM V8Ray 完整更新流程测试
REM 模拟从下载到安装的完整流程
REM ============================================

chcp 65001 > nul
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set APP_DIR=%SCRIPT_DIR%test_app_full
set TEMP_DIR=%APP_DIR%\TEMP
set EXTRACT_TEMP=%TEMP_DIR%\v8ray_update_temp
set EXECUTABLE=%APP_DIR%\v8ray.exe
set LOGFILE=%TEMP_DIR%\v8ray_update.log

echo ========================================
echo V8Ray 完整更新流程测试
echo ========================================
echo.

REM 1. 创建模拟的应用目录（旧版本）
echo [准备] 创建模拟应用目录（旧版本）...
if exist "%APP_DIR%" rmdir /S /Q "%APP_DIR%"
mkdir "%APP_DIR%"
mkdir "%TEMP_DIR%"
mkdir "%APP_DIR%\data"

echo 旧版本 v8ray.exe - v0.2.4 > "%APP_DIR%\v8ray.exe"
echo 旧版本 flutter.dll > "%APP_DIR%\flutter_windows.dll"
echo 旧数据 > "%APP_DIR%\data\config.json"

echo 当前应用目录内容 (旧版本):
dir "%APP_DIR%" /B

REM 2. 创建模拟的解压临时目录（新版本）
echo.
echo [准备] 创建解压临时目录（新版本）...
mkdir "%EXTRACT_TEMP%"
mkdir "%EXTRACT_TEMP%\data"
mkdir "%EXTRACT_TEMP%\bin"

echo 新版本 v8ray.exe - v0.2.5 > "%EXTRACT_TEMP%\v8ray.exe"
echo 新版本 flutter.dll > "%EXTRACT_TEMP%\flutter_windows.dll"
echo 新数据 > "%EXTRACT_TEMP%\data\config.json"
echo 新的 xray.exe > "%EXTRACT_TEMP%\bin\xray.exe"

echo 解压临时目录内容 (新版本):
dir "%EXTRACT_TEMP%" /B

REM 3. 创建更新脚本（与 Dart 代码生成的一致）
echo.
echo [准备] 创建更新脚本...

set UPDATE_BAT=%TEMP_DIR%\v8ray_update.bat
set UPDATE_VBS=%TEMP_DIR%\v8ray_update_launcher.vbs

(
echo @echo off
echo chcp 65001 ^> nul
echo set LOGFILE=%LOGFILE%
echo echo V8Ray Update Log ^> "%%LOGFILE%%"
echo echo 更新时间: %%DATE%% %%TIME%% ^>^> "%%LOGFILE%%"
echo echo ======================================== ^>^> "%%LOGFILE%%"
echo.
echo echo ========================================
echo echo V8Ray 自动更新脚本
echo echo ========================================
echo echo.
echo.
echo echo [1/5] 等待 V8Ray 关闭...
echo echo [1/5] 等待 V8Ray 关闭... ^>^> "%%LOGFILE%%"
echo timeout /t 2 /nobreak ^> nul
echo.
echo echo [2/5] 检查源目录...
echo echo 源目录: %EXTRACT_TEMP% ^>^> "%%LOGFILE%%"
echo echo 目标目录: %APP_DIR% ^>^> "%%LOGFILE%%"
echo dir "%EXTRACT_TEMP%" ^>^> "%%LOGFILE%%" 2^>^&1
echo.
echo echo [3/5] 更新 V8Ray 文件...
echo echo 源目录: %EXTRACT_TEMP%
echo echo 目标目录: %APP_DIR%
echo.
echo REM 使用 robocopy 复制文件
echo robocopy "%EXTRACT_TEMP%" "%APP_DIR%" /E /IS /IT /R:3 /W:1 ^>^> "%%LOGFILE%%" 2^>^&1
echo set ROBOCOPY_EXIT=%%errorlevel%%
echo echo Robocopy 退出代码: %%ROBOCOPY_EXIT%% ^>^> "%%LOGFILE%%"
echo.
echo if %%ROBOCOPY_EXIT%% GEQ 8 ^(
echo     echo 错误：文件复制失败！退出代码: %%ROBOCOPY_EXIT%%
echo     echo 错误：文件复制失败！退出代码: %%ROBOCOPY_EXIT%% ^>^> "%%LOGFILE%%"
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo [4/5] 清理临时文件...
echo rmdir /S /Q "%EXTRACT_TEMP%" ^>^> "%%LOGFILE%%" 2^>^&1
echo.
echo echo [5/5] 启动 V8Ray...
echo echo 启动命令: %EXECUTABLE% ^>^> "%%LOGFILE%%"
echo echo 模拟启动: %EXECUTABLE%
echo REM start "" "%EXECUTABLE%"
echo.
echo echo.
echo echo ========================================
echo echo 更新完成！
echo echo ========================================
echo echo 更新完成！ ^>^> "%%LOGFILE%%"
echo timeout /t 2 /nobreak ^> nul
echo.
echo set SCRIPT_DIR=%%~dp0
echo del /F /Q "%%SCRIPT_DIR%%v8ray_update_launcher.vbs" 2^>nul
echo REM del "%%~f0"
) > "%UPDATE_BAT%"

echo 更新脚本已创建: %UPDATE_BAT%

REM 4. 创建 VBScript 启动器
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run """%UPDATE_BAT%""", 1, True
echo Set WshShell = Nothing
) > "%UPDATE_VBS%"

echo VBScript 启动器已创建: %UPDATE_VBS%

REM 5. 执行更新
echo.
echo ========================================
echo 开始执行更新
echo ========================================
echo.
echo 使用 wscript 启动更新脚本...
wscript "%UPDATE_VBS%"
set VBS_EXIT=%errorlevel%
echo wscript 退出代码: %VBS_EXIT%

REM 6. 等待并检查结果
echo.
echo 等待更新完成...
timeout /t 3 /nobreak > nul

echo.
echo ========================================
echo 检查更新结果
echo ========================================
echo.

echo 更新后应用目录内容:
dir "%APP_DIR%" /B /S

echo.
echo 检查 v8ray.exe 版本:
type "%APP_DIR%\v8ray.exe"

echo.
echo 检查日志文件:
if exist "%LOGFILE%" (
    echo 日志文件内容:
    echo ----------------------------------------
    type "%LOGFILE%"
    echo ----------------------------------------
) else (
    echo 警告：日志文件不存在！
)

echo.
echo ========================================
echo 测试完成
echo ========================================
echo 按任意键清理测试目录...
pause

rmdir /S /Q "%APP_DIR%"
echo 测试目录已清理

endlocal
