/// V8Ray 应用更新状态管理
///
/// 管理应用的版本检查和更新功能

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// 更新状态
enum UpdateStatus {
  /// 空闲状态
  idle,

  /// 检查更新中
  checking,

  /// 有可用更新
  available,

  /// 无可用更新
  upToDate,

  /// 下载中
  downloading,

  /// 下载完成
  downloaded,

  /// 已安装，需要重启
  installed,

  /// 检查失败
  checkFailed,

  /// 下载失败
  downloadFailed,

  /// 安装失败
  installFailed,
}

/// 更新信息
class UpdateInfo {
  /// 当前版本
  final String currentVersion;

  /// 最新版本
  final String? latestVersion;

  /// 更新状态
  final UpdateStatus status;

  /// 下载进度 (0.0 - 1.0)
  final double downloadProgress;

  /// 错误消息
  final String? errorMessage;

  /// 发布说明
  final String? releaseNotes;

  /// 下载URL
  final String? downloadUrl;

  /// 下载文件路径
  final String? downloadedFilePath;

  const UpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.status = UpdateStatus.idle,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.releaseNotes,
    this.downloadUrl,
    this.downloadedFilePath,
  });

  UpdateInfo copyWith({
    String? currentVersion,
    String? latestVersion,
    UpdateStatus? status,
    double? downloadProgress,
    String? errorMessage,
    String? releaseNotes,
    String? downloadUrl,
    String? downloadedFilePath,
  }) {
    return UpdateInfo(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
    );
  }

  /// 是否有可用更新
  bool get hasUpdate =>
      latestVersion != null &&
      latestVersion != currentVersion &&
      status == UpdateStatus.available;
}

/// 应用更新Provider
final appUpdateProvider = StateNotifierProvider<AppUpdateNotifier, UpdateInfo>((
  ref,
) {
  return AppUpdateNotifier();
});

/// 应用更新状态管理
class AppUpdateNotifier extends StateNotifier<UpdateInfo> {
  AppUpdateNotifier() : super(UpdateInfo(currentVersion: AppInfo.version)) {
    // 可以在这里自动检查更新
    // checkForUpdates();
  }

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': AppInfo.userAgent,
      },
    ),
  );

  /// 检查更新
  Future<void> checkForUpdates() async {
    if (state.status == UpdateStatus.checking) {
      appLogger.info('Already checking for updates');
      return;
    }

    state = state.copyWith(status: UpdateStatus.checking, errorMessage: null);

    try {
      appLogger.info('Checking for updates from: ${AppInfo.githubApiUrl}');

      final response = await _dio.get(AppInfo.githubApiUrl);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final tagName = data['tag_name'] as String?;
        final body = data['body'] as String?;

        if (tagName == null) {
          throw Exception('No tag_name found in response');
        }

        // 移除版本号前的 'v' 前缀
        final latestVersion =
            tagName.startsWith('v') ? tagName.substring(1) : tagName;

        appLogger.info(
          'Latest version: $latestVersion, Current version: ${state.currentVersion}',
        );

        // 获取下载URL
        String? downloadUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          // 根据平台选择合适的资源
          final platformAsset = _findPlatformAsset(assets);
          if (platformAsset != null) {
            downloadUrl = platformAsset['browser_download_url'] as String?;
          }
        }

        // 比较版本
        final hasUpdate = _compareVersions(latestVersion, state.currentVersion);

        state = state.copyWith(
          latestVersion: latestVersion,
          status: hasUpdate ? UpdateStatus.available : UpdateStatus.upToDate,
          releaseNotes: body,
          downloadUrl: downloadUrl,
        );

        appLogger.info(
          hasUpdate ? 'Update available: $latestVersion' : 'Already up to date',
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      appLogger.error('Failed to check for updates', e, stackTrace);
      state = state.copyWith(
        status: UpdateStatus.checkFailed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 下载更新
  Future<void> downloadUpdate() async {
    if (state.downloadUrl == null) {
      appLogger.error('No download URL available');
      state = state.copyWith(
        status: UpdateStatus.downloadFailed,
        errorMessage: 'No download URL available',
      );
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0.0,
      errorMessage: null,
    );

    try {
      // 使用应用目录下的 TEMP 文件夹作为下载目录
      final executablePath = Platform.resolvedExecutable;
      final appDir = File(executablePath).parent.path;
      final tempDir = Directory('$appDir/TEMP');
      
      // 创建 TEMP 目录（如果不存在）
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      final fileName = state.downloadUrl!.split('/').last;
      final savePath = '${tempDir.path}/$fileName';

      appLogger.info('Downloading update to: $savePath');

      // 下载文件
      await _dio.download(
        state.downloadUrl!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            state = state.copyWith(downloadProgress: progress);
            appLogger.info(
              'Download progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      appLogger.info('Download completed: $savePath');

      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedFilePath: savePath,
        downloadProgress: 1.0,
      );
    } catch (e, stackTrace) {
      appLogger.error('Failed to download update', e, stackTrace);
      state = state.copyWith(
        status: UpdateStatus.downloadFailed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 安装更新
  Future<void> installUpdate() async {
    if (state.downloadedFilePath == null) {
      appLogger.error('No downloaded file available');
      return;
    }

    try {
      final file = File(state.downloadedFilePath!);
      if (!await file.exists()) {
        throw Exception('Downloaded file not found');
      }

      appLogger.info('Installing update from: ${state.downloadedFilePath}');

      // 根据平台执行不同的安装逻辑
      if (Platform.isWindows) {
        await _installOnWindows(file);
      } else if (Platform.isLinux) {
        await _installOnLinux(file);
      } else if (Platform.isMacOS) {
        await _installOnMacOS(file);
      } else {
        throw UnsupportedError('Platform not supported for auto-update');
      }
    } catch (e, stackTrace) {
      appLogger.error('Failed to install update', e, stackTrace);
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Windows平台安装
  Future<void> _installOnWindows(File file) async {
    try {
      // 获取当前可执行文件的目录
      final executablePath = Platform.resolvedExecutable;
      final appDir = File(executablePath).parent.path;

      appLogger.info('Extracting update to: $appDir');
      appLogger.info('Archive file: ${file.path}');
      appLogger.info('Executable path: $executablePath');

      // 使用 PowerShell 解压 zip 文件到应用目录
      // 注意：需要先解压到临时目录，然后复制，避免覆盖正在运行的文件
      final tempExtractDir = '${file.parent.path}\\v8ray_update_temp';
      final tempDir = Directory(tempExtractDir);

      // 清理旧的临时目录
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create();

      // 解压到临时目录
      final extractResult = await Process.run('powershell', [
        '-Command',
        'Expand-Archive -Path "${file.path}" -DestinationPath "$tempExtractDir" -Force',
      ]);

      if (extractResult.exitCode != 0) {
        throw Exception('Failed to extract archive: ${extractResult.stderr}');
      }

      appLogger.info('Update extracted to temp directory successfully');
      appLogger.info('stdout: ${extractResult.stdout}');

      // 检查解压后的目录结构
      final extractedContents = await tempDir.list().toList();
      appLogger.info(
        'Extracted contents: ${extractedContents.map((e) => e.path).join(", ")}',
      );

      // 查找实际的更新文件目录
      // 如果解压后只有一个子目录，使用该子目录作为源
      String sourceDir = tempExtractDir;
      if (extractedContents.length == 1 && extractedContents[0] is Directory) {
        sourceDir = extractedContents[0].path;
        appLogger.info(
          'Found single subdirectory, using as source: $sourceDir',
        );
      }

      // 创建批处理脚本来完成更新
      // 这个脚本会在应用退出后执行，复制文件并重启应用
      // 注意：使用 Windows 路径分隔符，避免中文字符以防止编码问题
      
      // 确保路径使用 Windows 分隔符
      final sourceDirWin = sourceDir.replaceAll('/', '\\');
      final appDirWin = appDir.replaceAll('/', '\\');
      final tempExtractDirWin = tempExtractDir.replaceAll('/', '\\');
      final executablePathWin = executablePath.replaceAll('/', '\\');
      final logFileWin = '$appDirWin\\TEMP\\v8ray_update.log';
      
      final batchScript = '''@echo off
chcp 65001 > nul
set LOGFILE=$logFileWin
echo V8Ray Update Log > "%LOGFILE%"
echo Update Time: %DATE% %TIME% >> "%LOGFILE%"
echo ======================================== >> "%LOGFILE%"

echo ========================================
echo V8Ray Auto Update Script
echo ========================================
echo.

echo [1/5] Waiting for V8Ray to close...
echo [1/5] Waiting for V8Ray to close... >> "%LOGFILE%"
timeout /t 5 /nobreak > nul

echo [2/5] Checking source directory...
echo Source: $sourceDirWin >> "%LOGFILE%"
echo Target: $appDirWin >> "%LOGFILE%"
dir "$sourceDirWin" >> "%LOGFILE%" 2>&1

echo [3/5] Updating V8Ray files...
echo Source: $sourceDirWin
echo Target: $appDirWin

REM Use robocopy for reliable file copy
robocopy "$sourceDirWin" "$appDirWin" /E /IS /IT /R:3 /W:1 >> "%LOGFILE%" 2>&1
set ROBOCOPY_EXIT=%errorlevel%
echo Robocopy exit code: %ROBOCOPY_EXIT% >> "%LOGFILE%"

REM robocopy: 0-7 = success, >=8 = error
if %ROBOCOPY_EXIT% GEQ 8 (
    echo ERROR: File copy failed! Exit code: %ROBOCOPY_EXIT%
    echo ERROR: File copy failed! Exit code: %ROBOCOPY_EXIT% >> "%LOGFILE%"
    echo See log file: %LOGFILE%
    pause
    exit /b 1
)

echo [4/5] Cleaning temp files...
rmdir /S /Q "$tempExtractDirWin" >> "%LOGFILE%" 2>&1

echo [5/5] Starting V8Ray...
echo Start command: $executablePathWin >> "%LOGFILE%"
start "" "$executablePathWin"

echo.
echo ========================================
echo Update Complete!
echo ========================================
echo Update Complete! >> "%LOGFILE%"
echo Script end time: %DATE% %TIME% >> "%LOGFILE%"

timeout /t 3 /nobreak > nul

REM Delete this batch script
del "%~f0"
''';

      final batchFile = File('${file.parent.path}\\v8ray_update.bat');
      // 使用 Windows 默认编码写入，避免 UTF-8 BOM 问题
      await batchFile.writeAsString(batchScript);

      appLogger.info('Created update script: ${batchFile.path}');
      appLogger.info('Batch script content:\n$batchScript');

      // 直接使用 cmd.exe 启动批处理脚本（更可靠）
      // 使用 start 命令启动新窗口，/min 最小化窗口
      // 注意：不使用 VBScript 因为某些系统可能有安全限制
      appLogger.info('Created update script: ${batchFile.path}');
      
      // 使用 cmd /c start 启动批处理脚本
      // /min 最小化窗口, /wait 不等待
      await Process.start(
        'cmd',
        ['/c', 'start', '/min', '', batchFile.path],
        mode: ProcessStartMode.detached,
      );

      appLogger.info('Update script started via cmd.exe');

      // 更新状态为已安装
      // 注意：不再自动退出，让 UI 显示重启对话框，用户点击后再退出
      state = state.copyWith(
        status: UpdateStatus.installed,
        errorMessage: null,
      );

      // 不再自动退出！让 UI 层处理用户确认后再调用 exit(0)
      // 旧代码：await Future.delayed(const Duration(seconds: 1)); exit(0);
    } catch (e, stackTrace) {
      appLogger.error('Failed to install update on Windows', e, stackTrace);
      state = state.copyWith(
        status: UpdateStatus.installFailed,
        errorMessage: 'Installation failed: $e',
      );
      rethrow;
    }
  }

  /// Linux平台安装
  Future<void> _installOnLinux(File file) async {
    try {
      // 获取当前可执行文件的目录
      final executablePath = Platform.resolvedExecutable;
      final appDir = File(executablePath).parent.path;

      appLogger.info('Extracting update to: $appDir');
      appLogger.info('Archive file: ${file.path}');
      appLogger.info('Executable path: $executablePath');

      // 解压 tar.gz 文件到应用目录
      // 使用 --overwrite-dir 参数强制覆盖，如果不支持则使用基本参数
      final result = await Process.run('tar', [
        '-xzf',
        file.path,
        '-C',
        appDir,
        '--overwrite-dir', // 覆盖目录中的文件
      ]);

      if (result.exitCode != 0) {
        // 如果 --overwrite-dir 不支持，尝试不带该参数
        appLogger.warning('tar with --overwrite-dir failed, trying without it');
        final result2 = await Process.run('tar', [
          '-xzf',
          file.path,
          '-C',
          appDir,
        ]);

        if (result2.exitCode != 0) {
          throw Exception('Failed to extract archive: ${result2.stderr}');
        }
        appLogger.info('stdout: ${result2.stdout}');
      } else {
        appLogger.info('stdout: ${result.stdout}');
      }

      appLogger.info('Update extracted successfully');

      // 确保可执行文件有执行权限
      final newExecutable = File(executablePath);
      if (await newExecutable.exists()) {
        final chmodResult = await Process.run('chmod', ['+x', executablePath]);
        if (chmodResult.exitCode == 0) {
          appLogger.info('Set executable permission for: $executablePath');
        } else {
          appLogger.warning(
            'Failed to set executable permission: ${chmodResult.stderr}',
          );
        }
      }

      // 同时确保 bin 目录下的所有文件都有执行权限
      final binDir = Directory('$appDir/bin');
      if (await binDir.exists()) {
        await Process.run('chmod', ['+x', '$appDir/bin/*']);
        appLogger.info('Set executable permissions for bin directory');
      }

      // 更新成功，提示用户重启
      state = state.copyWith(
        status: UpdateStatus.installed,
        errorMessage: null,
      );

      appLogger.info(
        'Update installed successfully, please restart the application',
      );
    } catch (e, stackTrace) {
      appLogger.error('Failed to install update on Linux', e, stackTrace);
      state = state.copyWith(
        status: UpdateStatus.installFailed,
        errorMessage: 'Installation failed: $e',
      );
      rethrow;
    }
  }

  /// macOS平台安装
  Future<void> _installOnMacOS(File file) async {
    try {
      // 获取当前可执行文件的目录
      // macOS 路径: /path/to/v8ray.app/Contents/MacOS/v8ray
      final executablePath = Platform.resolvedExecutable;
      
      appLogger.info('Executable path: $executablePath');

      // 找到 .app 包的位置
      // 从 /path/to/v8ray.app/Contents/MacOS/v8ray 提取 /path/to/v8ray.app
      String? appBundlePath;
      if (executablePath.contains('.app/Contents/MacOS/')) {
        final appIndex = executablePath.indexOf('.app/Contents/MacOS/');
        appBundlePath = executablePath.substring(0, appIndex + 4); // +4 for ".app"
      }

      if (appBundlePath == null) {
        throw Exception('Could not determine .app bundle path from: $executablePath');
      }

      // 获取 .app 所在的目录（如 /Applications 或 ~/Downloads）
      final appParentDir = File(appBundlePath).parent.path;
      
      appLogger.info('App bundle path: $appBundlePath');
      appLogger.info('App parent directory: $appParentDir');
      appLogger.info('Archive file: ${file.path}');

      // 解压到临时目录
      final tempExtractDir = '${file.parent.path}/v8ray_update_temp';
      final tempDir = Directory(tempExtractDir);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create();

      appLogger.info('Extracting to temp directory: $tempExtractDir');

      // 解压 tar.gz 文件到临时目录
      final extractResult = await Process.run('tar', [
        '-xzf',
        file.path,
        '-C',
        tempExtractDir,
      ]);

      if (extractResult.exitCode != 0) {
        throw Exception('Failed to extract archive: ${extractResult.stderr}');
      }

      appLogger.info('Archive extracted successfully');

      // 找到解压后的 .app 包
      String? newAppPath;
      final tempDirList = await tempDir.list().toList();
      for (var entity in tempDirList) {
        if (entity.path.endsWith('.app')) {
          newAppPath = entity.path;
          break;
        }
      }

      if (newAppPath == null) {
        // 如果没有找到 .app，可能打包结构不同，尝试直接使用临时目录
        appLogger.warning('No .app found in extracted files, checking directory structure');
        throw Exception('No .app bundle found in update package');
      }

      appLogger.info('Found new app bundle: $newAppPath');

      // 备份旧的 .app
      final backupPath = '$appBundlePath.backup';
      final backupDir = Directory(backupPath);
      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }

      appLogger.info('Moving old app to backup: $backupPath');
      
      // 使用 mv 命令移动旧应用到备份
      final backupResult = await Process.run('mv', [appBundlePath, backupPath]);
      if (backupResult.exitCode != 0) {
        throw Exception('Failed to backup old app: ${backupResult.stderr}');
      }

      // 移动新的 .app 到原位置
      appLogger.info('Moving new app to: $appBundlePath');
      final moveResult = await Process.run('mv', [newAppPath!, appBundlePath]);
      if (moveResult.exitCode != 0) {
        // 恢复备份
        await Process.run('mv', [backupPath, appBundlePath]);
        throw Exception('Failed to install new app: ${moveResult.stderr}');
      }

      // 删除备份和临时目录
      appLogger.info('Cleaning up...');
      await Process.run('rm', ['-rf', backupPath]);
      await Process.run('rm', ['-rf', tempExtractDir]);

      // 确保可执行文件有执行权限
      final newExecutablePath = '$appBundlePath/Contents/MacOS/v8ray';
      await Process.run('chmod', ['+x', newExecutablePath]);
      appLogger.info('Set executable permission for: $newExecutablePath');

      // 更新成功，提示用户重启
      state = state.copyWith(
        status: UpdateStatus.installed,
        errorMessage: null,
      );

      appLogger.info(
        'macOS update installed successfully, please restart the application',
      );
    } catch (e, stackTrace) {
      appLogger.error('Failed to install update on macOS', e, stackTrace);
      state = state.copyWith(
        status: UpdateStatus.installFailed,
        errorMessage: 'Installation failed: $e',
      );
      rethrow;
    }
  }

  /// 查找适合当前平台的资源
  Map<String, dynamic>? _findPlatformAsset(List<dynamic> assets) {
    String platformPattern;
    String expectedExtension;

    if (Platform.isWindows) {
      platformPattern = 'windows-x64';
      expectedExtension = '.zip';
    } else if (Platform.isLinux) {
      platformPattern = 'linux-x64';
      expectedExtension = '.tar.gz';
    } else if (Platform.isMacOS) {
      platformPattern = 'macos-x64';
      expectedExtension = '.tar.gz';
    } else {
      appLogger.warning('Unsupported platform for auto-update');
      return null;
    }

    appLogger.info(
      'Looking for asset matching: $platformPattern with extension: $expectedExtension',
    );

    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      appLogger.info('Checking asset: $name');

      // 精确匹配平台和文件扩展名
      if (name.contains(platformPattern) && name.endsWith(expectedExtension)) {
        appLogger.info('Found matching asset: $name');
        return asset as Map<String, dynamic>;
      }
    }

    appLogger.warning('No matching asset found for platform: $platformPattern');
    return null;
  }

  /// 比较版本号
  bool _compareVersions(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // 补齐版本号长度
      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      // 逐位比较
      for (var i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }

      return false; // 版本相同
    } catch (e) {
      appLogger.error('Failed to compare versions', e);
      return false;
    }
  }

  /// 重置状态
  void reset() {
    state = UpdateInfo(currentVersion: AppInfo.version);
  }
}
