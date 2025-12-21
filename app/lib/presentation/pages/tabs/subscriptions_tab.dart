/// V8Ray 订阅管理标签页
///
/// 显示订阅列表和订阅管理功能

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/ffi/bridge/api.dart' as api;
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/responsive.dart';

/// 订阅管理标签页
class SubscriptionsTab extends ConsumerStatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  ConsumerState<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends ConsumerState<SubscriptionsTab> {
  List<api.SubscriptionInfo> _subscriptions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载订阅列表
  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subscriptions = await api.getSubscriptions();
      setState(() {
        _subscriptions = subscriptions;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      appLogger.error('Failed to load subscriptions', e, stackTrace);
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 过滤后的订阅列表
  List<api.SubscriptionInfo> get _filteredSubscriptions {
    if (_searchQuery.isEmpty) {
      return _subscriptions;
    }
    return _subscriptions.where((sub) {
      return sub.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sub.url.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // 工具栏
        _buildToolbar(context, l10n),
        const Divider(height: 1),

        // 内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorState(context, l10n)
                  : _filteredSubscriptions.isEmpty
                      ? _buildEmptyState(context, l10n)
                      : _buildSubscriptionList(context, l10n),
        ),
      ],
    );
  }

  /// 构建工具栏
  Widget _buildToolbar(BuildContext context, AppLocalizations l10n) {
    final responsive = Responsive(context);

    return Padding(
      padding: EdgeInsets.all(
        responsive.valueWhen(
          mobile: UIConstants.defaultPadding,
          tablet: UIConstants.largePadding,
        ),
      ),
      child: Row(
        children: [
          // 搜索框
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 操作按钮
          FilledButton.icon(
            onPressed: () => _showAddSubscriptionDialog(context, l10n),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.addSubscription),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isLoading ? null : _refreshAllSubscriptions,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            tooltip: l10n.refresh,
          ),
        ],
      ),
    );
  }

  /// 构建错误状态
  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.errorOccurred,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadSubscriptions,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.subscriptionList,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.pleaseAddSubscription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddSubscriptionDialog(context, l10n),
            icon: const Icon(Icons.add),
            label: Text(l10n.addSubscription),
          ),
        ],
      ),
    );
  }

  /// 构建订阅列表
  Widget _buildSubscriptionList(BuildContext context, AppLocalizations l10n) {
    final responsive = Responsive(context);

    return ListView.builder(
      padding: EdgeInsets.all(
        responsive.valueWhen(
          mobile: UIConstants.defaultPadding,
          tablet: UIConstants.largePadding,
        ),
      ),
      itemCount: _filteredSubscriptions.length,
      itemBuilder: (context, index) {
        final subscription = _filteredSubscriptions[index];
        return _buildSubscriptionCard(context, l10n, subscription);
      },
    );
  }

  /// 构建订阅卡片
  Widget _buildSubscriptionCard(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 格式化最后更新时间
    String lastUpdateText = l10n.neverUpdated;
    if (subscription.lastUpdate != null) {
      final timestamp = subscription.lastUpdate!.toInt();
      if (timestamp > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        lastUpdateText = _formatDateTime(date);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: UIConstants.defaultPadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSubscriptionDetails(context, l10n, subscription),
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：名称和状态
              Row(
                children: [
                  // 订阅图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.subscriptions,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 名称和URL
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subscription.url,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 状态指示器
                  _buildStatusChip(context, subscription.status),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 底部：统计信息和操作
              Row(
                children: [
                  // 节点数量
                  _buildInfoItem(
                    context,
                    Icons.dns,
                    '${subscription.serverCount} ${l10n.nodes}',
                  ),
                  const SizedBox(width: 16),

                  // 最后更新时间
                  _buildInfoItem(
                    context,
                    Icons.schedule,
                    lastUpdateText,
                  ),
                  const Spacer(),

                  // 操作按钮
                  IconButton(
                    onPressed: () =>
                        _updateSubscription(context, l10n, subscription),
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: l10n.refresh,
                  ),
                  IconButton(
                    onPressed: () =>
                        _showEditSubscriptionDialog(context, l10n, subscription),
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: l10n.edit,
                  ),
                  IconButton(
                    onPressed: () =>
                        _confirmDeleteSubscription(context, l10n, subscription),
                    icon: Icon(
                      Icons.delete,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    tooltip: l10n.delete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建状态芯片
  Widget _buildStatusChip(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    String text = status;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = 'Active';
        break;
      case 'updating':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        text = 'Updating';
        break;
      case 'error':
        backgroundColor = colorScheme.error.withOpacity(0.1);
        textColor = colorScheme.error;
        text = 'Error';
        break;
      default:
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  /// 显示添加订阅对话框
  Future<void> _showAddSubscriptionDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addSubscription),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionName,
                  hintText: 'My Subscription',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionUrl,
                  hintText: 'https://example.com/subscription',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final name = nameController.text.trim();
      final url = urlController.text.trim();

      if (name.isEmpty || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pleaseEnterUrl)),
        );
        return;
      }

      await _addSubscription(context, l10n, name, url);
    }

    nameController.dispose();
    urlController.dispose();
  }

  /// 添加订阅
  Future<void> _addSubscription(
    BuildContext context,
    AppLocalizations l10n,
    String name,
    String url,
  ) async {
    try {
      setState(() => _isLoading = true);

      await api.addSubscription(name: name, url: url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscriptionAdded)),
        );
      }

      // 刷新服务器列表
      ref.read(serverProvider.notifier).loadServers();

      await _loadSubscriptions();
    } catch (e, stackTrace) {
      appLogger.error('Failed to add subscription', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOccurred}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 显示编辑订阅对话框
  Future<void> _showEditSubscriptionDialog(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) async {
    final nameController = TextEditingController(text: subscription.name);
    final urlController = TextEditingController(text: subscription.url);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.edit),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: l10n.subscriptionUrl,
                  border: const OutlineInputBorder(),
                ),
                enabled: false,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // TODO: 实现订阅编辑 API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saved)),
      );
    }

    nameController.dispose();
    urlController.dispose();
  }

  /// 更新单个订阅
  Future<void> _updateSubscription(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.updating}...')),
      );

      await api.updateSubscription(id: subscription.id);

      // 刷新服务器列表
      ref.read(serverProvider.notifier).loadServers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.updateComplete)),
        );
      }

      await _loadSubscriptions();
    } catch (e, stackTrace) {
      appLogger.error('Failed to update subscription', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOccurred}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 刷新所有订阅
  Future<void> _refreshAllSubscriptions() async {
    setState(() => _isLoading = true);

    try {
      await api.updateAllSubscriptions();

      // 刷新服务器列表
      ref.read(serverProvider.notifier).loadServers();

      await _loadSubscriptions();
    } catch (e, stackTrace) {
      appLogger.error('Failed to refresh all subscriptions', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// 确认删除订阅
  Future<void> _confirmDeleteSubscription(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(
          '${l10n.deleteConfirmation}\n\n${subscription.name}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _deleteSubscription(context, l10n, subscription);
    }
  }

  /// 删除订阅
  Future<void> _deleteSubscription(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) async {
    try {
      await api.removeSubscription(id: subscription.id);

      // 刷新服务器列表
      ref.read(serverProvider.notifier).loadServers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleted)),
        );
      }

      await _loadSubscriptions();
    } catch (e, stackTrace) {
      appLogger.error('Failed to delete subscription', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorOccurred}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 显示订阅详情
  void _showSubscriptionDetails(
    BuildContext context,
    AppLocalizations l10n,
    api.SubscriptionInfo subscription,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 拖动手柄
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subscription.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 详情内容
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDetailItem(context, l10n.subscriptionUrl, subscription.url),
                  _buildDetailItem(
                    context,
                    l10n.nodes,
                    '${subscription.serverCount}',
                  ),
                  _buildDetailItem(context, 'Status', subscription.status),
                  if (subscription.lastUpdate != null)
                    _buildDetailItem(
                      context,
                      'Last Update',
                      _formatDateTime(
                        DateTime.fromMillisecondsSinceEpoch(
                          subscription.lastUpdate!.toInt() * 1000,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建详情项
  Widget _buildDetailItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
