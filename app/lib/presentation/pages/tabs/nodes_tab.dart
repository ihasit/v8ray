/// V8Ray 节点管理标签页
///
/// 显示节点列表，支持搜索、过滤、排序和测试

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/ffi/bridge/api.dart' as api;
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/utils/responsive.dart';

/// 节点管理标签页
class NodesTab extends ConsumerStatefulWidget {
  const NodesTab({super.key});

  @override
  ConsumerState<NodesTab> createState() => _NodesTabState();
}

class _NodesTabState extends ConsumerState<NodesTab> {
  String _searchQuery = '';
  String _filterBy = 'all';
  String _sortBy = 'name';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverState = ref.watch(serverProvider);

    // 过滤和排序服务器列表
    var servers = _getFilteredAndSortedServers(serverState);

    return Column(
      children: [
        // 工具栏
        _buildToolbar(context, l10n, serverState),

        // 服务器列表
        Expanded(
          child: serverState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : servers.isEmpty
                  ? _buildEmptyState(context, l10n)
                  : _buildServerList(context, l10n, servers, serverState),
        ),
      ],
    );
  }

  /// 获取过滤和排序后的服务器列表
  List<api.ServerInfo> _getFilteredAndSortedServers(ServerState serverState) {
    var servers = serverState.servers.toList();

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      servers = servers.where((server) {
        return server.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            server.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            server.protocol.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 状态过滤
    if (_filterBy == 'available') {
      servers = servers.where((server) {
        final latency = serverState.getServerLatency(server.id);
        return latency != null && latency > 0;
      }).toList();
    } else if (_filterBy == 'unavailable') {
      servers = servers.where((server) {
        final latency = serverState.getServerLatency(server.id);
        return latency == null || latency <= 0;
      }).toList();
    }

    // 排序
    switch (_sortBy) {
      case 'latency':
        servers.sort((a, b) {
          final latencyA = serverState.getServerLatency(a.id);
          final latencyB = serverState.getServerLatency(b.id);
          if (latencyA == null && latencyB == null) return 0;
          if (latencyA == null) return 1;
          if (latencyB == null) return -1;
          return latencyA.compareTo(latencyB);
        });
        break;
      case 'name':
        servers.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'protocol':
        servers.sort((a, b) => a.protocol.compareTo(b.protocol));
        break;
    }

    return servers;
  }

  /// 构建工具栏
  Widget _buildToolbar(
    BuildContext context,
    AppLocalizations l10n,
    ServerState serverState,
  ) {
    return Container(
      padding: EdgeInsets.all(
        Responsive(context).valueWhen(
          mobile: UIConstants.defaultPadding,
          tablet: UIConstants.largePadding,
        ),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 搜索框和操作按钮
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.search,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 批量测试按钮（带进度显示）
              _buildBatchTestButton(context, l10n, serverState),
            ],
          ),
          const SizedBox(height: 12),

          // 过滤和排序选项
          Row(
            children: [
              // 过滤选项
              Text(
                '${l10n.filterBy}: ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'all', label: Text(l10n.all)),
                  ButtonSegment(
                    value: 'available',
                    label: Text(l10n.available),
                  ),
                  ButtonSegment(
                    value: 'unavailable',
                    label: Text(l10n.unavailable),
                  ),
                ],
                selected: {_filterBy},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _filterBy = newSelection.first);
                },
              ),
              const Spacer(),

              // 排序选项
              Text(
                '${l10n.sortBy}: ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                items: [
                  DropdownMenuItem(value: 'latency', child: Text(l10n.latency)),
                  DropdownMenuItem(value: 'name', child: Text(l10n.currentNode)),
                  const DropdownMenuItem(value: 'protocol', child: Text('Protocol')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建批量测试按钮
  Widget _buildBatchTestButton(
    BuildContext context,
    AppLocalizations l10n,
    ServerState serverState,
  ) {
    if (serverState.isBatchTesting) {
      // 显示进度
      return SizedBox(
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: serverState.batchTestProgress),
            const SizedBox(height: 4),
            Text(
              '${(serverState.batchTestProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: serverState.servers.isEmpty
          ? null
          : () => ref.read(serverProvider.notifier).testAllServersLatency(),
      icon: const Icon(Icons.speed),
      label: Text(l10n.testLatency),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dns_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noServersAvailable,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pleaseAddSubscription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建服务器列表
  Widget _buildServerList(
    BuildContext context,
    AppLocalizations l10n,
    List<api.ServerInfo> servers,
    ServerState serverState,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(
        Responsive(context).valueWhen(
          mobile: UIConstants.defaultPadding,
          tablet: UIConstants.largePadding,
        ),
      ),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isSelected = server.id == serverState.selectedServerId;

        return _buildServerCard(context, l10n, server, isSelected, serverState);
      },
    );
  }

  /// 构建服务器卡片
  Widget _buildServerCard(
    BuildContext context,
    AppLocalizations l10n,
    api.ServerInfo server,
    bool isSelected,
    ServerState serverState,
  ) {
    final latency = serverState.getServerLatency(server.id);
    final isTesting = serverState.isServerTesting(server.id);
    final hasLatency = latency != null && latency > 0;
    final latencyColor = hasLatency ? _getLatencyColor(context, latency) : 
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () {
          ref.read(serverProvider.notifier).selectServer(server.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // 选中指示器
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 16),

              // 服务器信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${server.address}:${server.port}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 协议标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  server.protocol.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 延迟显示
              SizedBox(
                width: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            hasLatency ? '${latency}ms' : '∞',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: latencyColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: hasLatency ? _getLatencyProgress(latency) : 0,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: latencyColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 操作按钮
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleServerAction(context, l10n, server, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'test',
                    child: Row(
                      children: [
                        const Icon(Icons.speed, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.test),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.delete,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理服务器操作
  void _handleServerAction(
    BuildContext context,
    AppLocalizations l10n,
    api.ServerInfo server,
    String action,
  ) {
    switch (action) {
      case 'test':
        ref.read(serverProvider.notifier).testServerLatency(server.id);
        break;
      case 'edit':
        // TODO: 实现编辑功能
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit feature coming soon')),
        );
        break;
      case 'delete':
        // TODO: 实现删除功能
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete feature coming soon')),
        );
        break;
    }
  }

  /// 获取延迟颜色
  Color _getLatencyColor(BuildContext context, int latency) {
    if (latency < 100) {
      return Colors.green;
    } else if (latency < 300) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// 获取延迟进度值
  double _getLatencyProgress(int latency) {
    if (latency < 100) return 0.9;
    if (latency < 200) return 0.7;
    if (latency < 300) return 0.5;
    if (latency < 500) return 0.3;
    return 0.1;
  }
}
