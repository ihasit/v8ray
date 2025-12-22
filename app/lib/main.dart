import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';

import 'core/error/index.dart';
import 'core/ffi/bridge/api.dart' as api;
import 'core/ffi/frb_generated.dart';
import 'core/l10n/app_localizations.dart';
import 'core/providers/index.dart';
import 'core/router/index.dart';
import 'core/theme/index.dart';
import 'core/utils/index.dart';

/// V8Ray 应用入口
Future<void> main() async {
  // 确保 Flutter 绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化错误处理器
  ErrorHandler.initialize();

  // 初始化日志
  appLogger.info('V8Ray application starting...');

  // 初始化 Rust Bridge
  try {
    // 创建自定义库加载器，支持从应用程序目录加载
    final externalLibrary = _createExternalLibrary();
    await V8RayBridge.init(externalLibrary: externalLibrary);
    appLogger.info('Rust Bridge initialized successfully');

    // 初始化 Rust Core（包括日志系统）
    await api.initV8Ray();
    appLogger.info('Rust Core initialized successfully');
  } catch (e, stackTrace) {
    appLogger.error('Failed to initialize Rust Bridge', e, stackTrace);
    _showErrorAndExit(
      ErrorType.initializationFailed,
      errorDetails: e.toString(),
    );
    return;
  }

  // 检查管理员权限（仅在 macOS 上需要，Linux 和 Windows 不需要）
  try {
    final hasAdminPrivileges = api.hasAdminPrivileges();
    final platformInfo = api.getPlatformInfo();

    // 只有 macOS 需要管理员权限（networksetup 命令需要）
    if (platformInfo.os == 'macos' && !hasAdminPrivileges) {
      appLogger.warning(
        'macOS requires administrator privileges for system proxy settings',
      );
      _showErrorAndExit(ErrorType.adminPrivilegesRequired);
      return;
    }

    if (hasAdminPrivileges) {
      appLogger.info('Running with administrator privileges');
    } else {
      appLogger.info(
        'Running as normal user (sufficient for ${platformInfo.os})',
      );
    }
  } catch (e, stackTrace) {
    appLogger.error('Failed to check admin privileges', e, stackTrace);
    // 不退出，继续运行
    appLogger.warning('Continuing without privilege check');
  }

  // 初始化订阅管理器
  try {
    // 获取程序当前目录
    final exePath = Platform.resolvedExecutable;
    final exeDir = Directory(File(exePath).parent.path);

    // 数据库文件直接放在程序目录下
    final dbPath = '${exeDir.path}/v8ray_subscriptions.db';
    appLogger.info('Initializing subscription manager with database: $dbPath');

    await api.initSubscriptionManager(dbPath: dbPath);
    appLogger.info('Subscription manager initialized successfully');

    // 如果数据库文件存在，加载保存的订阅和服务器配置
    final dbFile = File(dbPath);
    if (dbFile.existsSync()) {
      appLogger.info('Database file exists, loading saved configurations...');
      try {
        await api.loadSubscriptionsFromStorage();
        appLogger.info('Loaded subscriptions and servers from database');
      } catch (e, stackTrace) {
        appLogger.warning(
          'Failed to load configurations from database',
          e,
          stackTrace,
        );
        // 不退出应用，继续运行
      }
    } else {
      appLogger.info('Database file does not exist, starting with empty state');
    }
  } catch (e, stackTrace) {
    appLogger.error('Failed to initialize subscription manager', e, stackTrace);
    _showErrorAndExit(
      ErrorType.initializationFailed,
      errorDetails: 'Failed to initialize database: ${e.toString()}',
    );
    return;
  }

  runApp(const ProviderScope(child: V8RayApp()));
}

/// 错误类型枚举
enum ErrorType {
  adminPrivilegesRequired,
  initializationFailed,
  permissionCheckFailed,
}

/// 显示错误对话框并退出程序
void _showErrorAndExit(ErrorType errorType, {String? errorDetails}) {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _ErrorPage(errorType: errorType, errorDetails: errorDetails),
    ),
  );

  // 10秒后自动退出
  Future.delayed(const Duration(seconds: 10), () => exit(1));
}

/// 错误页面 Widget
class _ErrorPage extends StatelessWidget {
  final ErrorType errorType;
  final String? errorDetails;

  const _ErrorPage({required this.errorType, this.errorDetails});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String title;
    String message;

    switch (errorType) {
      case ErrorType.adminPrivilegesRequired:
        title = l10n.errorAdminPrivilegesRequired;
        message = l10n.errorAdminPrivilegesMessage;
        break;
      case ErrorType.initializationFailed:
        title = l10n.errorInitializationFailed;
        message =
            errorDetails != null
                ? 'Failed to initialize application: $errorDetails'
                : 'Failed to initialize application';
        break;
      case ErrorType.permissionCheckFailed:
        title = l10n.errorPermissionCheckFailed;
        message =
            errorDetails != null
                ? 'Failed to verify administrator privileges: $errorDetails'
                : 'Failed to verify administrator privileges';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => exit(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text(l10n.exit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// V8Ray 应用主类
class V8RayApp extends ConsumerWidget {
  const V8RayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题模式
    final themeMode = ref.watch(themeModeProvider);
    // 监听语言设置
    final locale = ref.watch(localeProvider);

    appLogger.info('Building app with theme: $themeMode, locale: $locale');

    return MaterialApp.router(
      // 应用标题
      title: 'V8Ray',
      debugShowCheckedModeBanner: false,

      // 路由配置
      routerConfig: AppRouter.router,

      // 主题配置
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // 国际化配置
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('zh'), // 简体中文
      ],
      locale: locale,
    );
  }
}

/// 创建外部库加载器
///
/// 在开发模式下，从 core/target/[debug|release] 加载
/// 在发布模式下，从应用程序目录加载
ExternalLibrary? _createExternalLibrary() {
  // 在 Web 平台上不需要加载本地库
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return null;
  }

  try {
    // 获取可执行文件所在目录
    final executablePath = Platform.resolvedExecutable;
    final executableDir = File(executablePath).parent.path;

    appLogger.info('Executable path: $executablePath');
    appLogger.info('Executable dir: $executableDir');

    // 确定库文件名
    String libraryName;
    if (Platform.isWindows) {
      libraryName = 'v8ray_core.dll';
    } else if (Platform.isMacOS) {
      libraryName = 'libv8ray_core.dylib';
    } else {
      libraryName = 'libv8ray_core.so';
    }

    // 收集所有可能的库路径
    final possiblePaths = <String>[];

    if (Platform.isMacOS) {
      // macOS: 可执行文件在 v8ray.app/Contents/MacOS/v8ray
      // 动态库也在 v8ray.app/Contents/MacOS/libv8ray_core.dylib
      possiblePaths.add('$executableDir/$libraryName');
      
      // 也尝试 Frameworks 目录
      possiblePaths.add('$executableDir/../Frameworks/$libraryName');
      
      // 尝试从 .app 包的根目录计算路径
      if (executablePath.contains('.app/Contents/MacOS/')) {
        final appIndex = executablePath.indexOf('.app/Contents/MacOS/');
        final appBundlePath = executablePath.substring(0, appIndex + 4);
        possiblePaths.add('$appBundlePath/Contents/MacOS/$libraryName');
        possiblePaths.add('$appBundlePath/Contents/Frameworks/$libraryName');
      }
    } else {
      // Windows/Linux: 直接从可执行文件目录加载
      possiblePaths.add('$executableDir/$libraryName');
    }

    // 开发模式路径
    final buildMode =
        const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug';
    possiblePaths.add('$executableDir/../../core/target/$buildMode/$libraryName');

    // 尝试每个路径
    for (final path in possiblePaths) {
      appLogger.info('Trying library path: $path');
      final file = File(path);
      final exists = file.existsSync();
      appLogger.info('  File exists: $exists');
      
      if (exists) {
        appLogger.info('Found Rust library at: $path');
        try {
          // 先尝试用 dart:ffi 直接加载，看看有什么错误
          final lib = DynamicLibrary.open(path);
          appLogger.info('DynamicLibrary.open succeeded');
          lib.close();
        } catch (e) {
          appLogger.warning('DynamicLibrary.open failed: $e');
          // 继续尝试 ExternalLibrary.open
        }
        return ExternalLibrary.open(path);
      }
    }

    // 如果都找不到，记录所有尝试过的路径
    appLogger.warning(
      'Rust library not found in any of the expected locations:\n'
      '${possiblePaths.map((p) => '  - $p').join('\n')}\n'
      'Will try default loader...',
    );
    return null;
  } catch (e, stackTrace) {
    appLogger.error('Failed to create external library loader', e, stackTrace);
    return null;
  }
}
