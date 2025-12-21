/// V8Ray 服务器/节点状态管理
///
/// 管理服务器列表、节点选择和延迟测试

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ffi/bridge/api.dart' as api;
import '../utils/logger.dart';

/// 服务器延迟信息
class ServerLatency {
  final String serverId;
  final int? latencyMs;
  final bool isTesting;
  final String? error;
  final DateTime? testTime;

  const ServerLatency({
    required this.serverId,
    this.latencyMs,
    this.isTesting = false,
    this.error,
    this.testTime,
  });

  ServerLatency copyWith({
    int? latencyMs,
    bool? isTesting,
    String? error,
    DateTime? testTime,
    bool clearError = false,
  }) {
    return ServerLatency(
      serverId: serverId,
      latencyMs: latencyMs ?? this.latencyMs,
      isTesting: isTesting ?? this.isTesting,
      error: clearError ? null : (error ?? this.error),
      testTime: testTime ?? this.testTime,
    );
  }
}

/// 服务器信息状态
class ServerState {
  /// 服务器列表
  final List<api.ServerInfo> servers;

  /// 当前选中的服务器ID
  final String? selectedServerId;

  /// 是否正在加载
  final bool isLoading;

  /// 错误消息
  final String? errorMessage;

  /// 服务器延迟信息 Map (serverId -> ServerLatency)
  final Map<String, ServerLatency> latencies;

  /// 是否正在批量测试
  final bool isBatchTesting;

  /// 批量测试进度
  final double batchTestProgress;

  const ServerState({
    this.servers = const [],
    this.selectedServerId,
    this.isLoading = false,
    this.errorMessage,
    this.latencies = const {},
    this.isBatchTesting = false,
    this.batchTestProgress = 0.0,
  });

  ServerState copyWith({
    List<api.ServerInfo>? servers,
    String? selectedServerId,
    bool? isLoading,
    String? errorMessage,
    Map<String, ServerLatency>? latencies,
    bool? isBatchTesting,
    double? batchTestProgress,
  }) {
    return ServerState(
      servers: servers ?? this.servers,
      selectedServerId: selectedServerId ?? this.selectedServerId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      latencies: latencies ?? this.latencies,
      isBatchTesting: isBatchTesting ?? this.isBatchTesting,
      batchTestProgress: batchTestProgress ?? this.batchTestProgress,
    );
  }

  /// 获取当前选中的服务器
  api.ServerInfo? get selectedServer {
    if (selectedServerId == null) return null;
    try {
      return servers.firstWhere((s) => s.id == selectedServerId);
    } catch (e) {
      return null;
    }
  }

  /// 是否有可用服务器
  bool get hasServers => servers.isNotEmpty;

  /// 是否有选中的服务器
  bool get hasSelectedServer =>
      selectedServerId != null && selectedServer != null;

  /// 获取服务器延迟
  int? getServerLatency(String serverId) {
    return latencies[serverId]?.latencyMs;
  }

  /// 检查服务器是否正在测试延迟
  bool isServerTesting(String serverId) {
    return latencies[serverId]?.isTesting ?? false;
  }

  /// 按延迟排序的服务器列表（延迟低的在前）
  List<api.ServerInfo> get serversSortedByLatency {
    final sorted = List<api.ServerInfo>.from(servers);
    sorted.sort((a, b) {
      final latencyA = latencies[a.id]?.latencyMs;
      final latencyB = latencies[b.id]?.latencyMs;
      
      // 没有延迟数据的排在后面
      if (latencyA == null && latencyB == null) return 0;
      if (latencyA == null) return 1;
      if (latencyB == null) return -1;
      
      return latencyA.compareTo(latencyB);
    });
    return sorted;
  }

  /// 按名称排序的服务器列表
  List<api.ServerInfo> get serversSortedByName {
    final sorted = List<api.ServerInfo>.from(servers);
    sorted.sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  /// 按协议排序的服务器列表
  List<api.ServerInfo> get serversSortedByProtocol {
    final sorted = List<api.ServerInfo>.from(servers);
    sorted.sort((a, b) => a.protocol.compareTo(b.protocol));
    return sorted;
  }
}

/// 服务器状态Provider
final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((
  ref,
) {
  return ServerNotifier();
});

/// 服务器状态管理
class ServerNotifier extends StateNotifier<ServerState> {
  ServerNotifier() : super(const ServerState()) {
    // 初始化时加载服务器列表
    loadServers();
  }

  /// 加载所有服务器
  Future<void> loadServers() async {
    try {
      appLogger.info('Loading servers...');

      state = state.copyWith(isLoading: true, errorMessage: null);

      // 调用 Rust FFI 获取服务器列表
      final servers = await api.getServers();

      appLogger.info('Loaded ${servers.length} servers');

      state = state.copyWith(servers: servers, isLoading: false);

      // 如果有服务器但没有选中的，自动选择第一个
      if (servers.isNotEmpty && state.selectedServerId == null) {
        selectServer(servers.first.id);
      }
    } catch (e, stackTrace) {
      appLogger.error('Failed to load servers', e, stackTrace);

      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 加载指定订阅的服务器
  Future<void> loadServersForSubscription(String subscriptionId) async {
    try {
      appLogger.info('Loading servers for subscription: $subscriptionId');

      state = state.copyWith(isLoading: true, errorMessage: null);

      // 调用 Rust FFI 获取服务器列表
      final servers = await api.getServersForSubscription(
        subscriptionId: subscriptionId,
      );

      appLogger.info('Loaded ${servers.length} servers for subscription');

      state = state.copyWith(servers: servers, isLoading: false);

      // 如果有服务器但没有选中的，自动选择第一个
      if (servers.isNotEmpty && state.selectedServerId == null) {
        selectServer(servers.first.id);
      }
    } catch (e, stackTrace) {
      appLogger.error('Failed to load servers for subscription', e, stackTrace);

      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// 选择服务器
  void selectServer(String serverId) {
    appLogger.info('Selecting server: $serverId');

    state = state.copyWith(selectedServerId: serverId, errorMessage: null);
  }

  /// 测试单个服务器延迟
  Future<int?> testServerLatency(String serverId) async {
    try {
      appLogger.info('Testing latency for server: $serverId');

      // 更新状态为正在测试
      final newLatencies = Map<String, ServerLatency>.from(state.latencies);
      newLatencies[serverId] = (state.latencies[serverId] ?? 
          ServerLatency(serverId: serverId)).copyWith(
        isTesting: true,
        clearError: true,
      );
      state = state.copyWith(latencies: newLatencies);

      // 调用 FFI 测试延迟
      final latency = await api.testLatency(configId: serverId);

      // 更新延迟结果
      final updatedLatencies = Map<String, ServerLatency>.from(state.latencies);
      updatedLatencies[serverId] = ServerLatency(
        serverId: serverId,
        latencyMs: latency,
        isTesting: false,
        testTime: DateTime.now(),
      );
      state = state.copyWith(latencies: updatedLatencies);

      appLogger.info('Server $serverId latency: ${latency}ms');
      return latency;
    } catch (e, stackTrace) {
      appLogger.error('Failed to test latency for server $serverId', e, stackTrace);

      // 更新错误状态
      final updatedLatencies = Map<String, ServerLatency>.from(state.latencies);
      updatedLatencies[serverId] = ServerLatency(
        serverId: serverId,
        isTesting: false,
        error: e.toString(),
        testTime: DateTime.now(),
      );
      state = state.copyWith(latencies: updatedLatencies);
      return null;
    }
  }

  /// 批量测试所有服务器延迟
  Future<void> testAllServersLatency() async {
    if (state.servers.isEmpty) {
      appLogger.warning('No servers to test');
      return;
    }

    if (state.isBatchTesting) {
      appLogger.warning('Batch testing already in progress');
      return;
    }

    appLogger.info('Starting batch latency test for ${state.servers.length} servers');

    state = state.copyWith(isBatchTesting: true, batchTestProgress: 0.0);

    final totalServers = state.servers.length;
    int testedCount = 0;

    for (final server in state.servers) {
      await testServerLatency(server.id);
      testedCount++;
      state = state.copyWith(
        batchTestProgress: testedCount / totalServers,
      );
    }

    state = state.copyWith(isBatchTesting: false, batchTestProgress: 1.0);
    appLogger.info('Batch latency test completed');
  }

  /// 自动选择最优服务器（延迟最低）
  void selectBestServer() {
    if (state.servers.isEmpty) {
      appLogger.warning('No servers available for selection');
      return;
    }

    // 如果有延迟数据，选择延迟最低的
    final sortedServers = state.serversSortedByLatency;
    final bestServer = sortedServers.first;
    selectServer(bestServer.id);

    final latency = state.getServerLatency(bestServer.id);
    appLogger.info(
      'Auto-selected best server: ${bestServer.name} (latency: ${latency ?? "unknown"}ms)',
    );
  }

  /// 清空服务器列表
  void clearServers() {
    state = const ServerState();
  }

  /// 刷新服务器列表
  Future<void> refreshServers() async {
    await loadServers();
  }

  /// 清除所有延迟数据
  void clearLatencies() {
    state = state.copyWith(latencies: const {});
  }
}
