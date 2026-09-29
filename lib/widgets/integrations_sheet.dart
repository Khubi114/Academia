// lib/widgets/integrations_sheet.dart
//
// "Connections" bottom sheet: connect / reconnect / disconnect Google
// Calendar and Canvas, trigger a manual sync and toggle the Canvas → Google
// Calendar mirror. Opened from the dashboard header and the connect banners.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_config.dart';
import '../services/canvas_service.dart';
import '../services/google_calendar_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

class IntegrationsSheet extends StatefulWidget {
  const IntegrationsSheet({super.key});

  /// Shows the sheet; completes when it is dismissed.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const IntegrationsSheet(),
    );
  }

  @override
  State<IntegrationsSheet> createState() => _IntegrationsSheetState();
}

class _IntegrationsSheetState extends State<IntegrationsSheet> {
  final _google = GoogleCalendarService.instance;
  final _canvas = CanvasService.instance;

  final _urlController =
      TextEditingController(text: AppConfig.canvasDefaultBaseUrl);
  final _tokenController = TextEditingController();

  bool _googleBusy = false;
  bool _canvasBusy = false;
  String? _canvasError;
  bool _hideToken = true;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _connectGoogle() async {
    setState(() => _googleBusy = true);
    final error = await _google.signIn();
    if (!mounted) return;
    setState(() => _googleBusy = false);

    if (error == null) {
      SyncService.instance.syncAll(force: true);
      _toast('Google Calendar connected');
    } else if (error != 'cancelled') {
      _toast(GoogleCalendarService.describeError(error));
    }
  }

  Future<void> _connectCanvas() async {
    setState(() {
      _canvasBusy = true;
      _canvasError = null;
    });
    final error = await _canvas.connect(_urlController.text, _tokenController.text);
    if (!mounted) return;
    setState(() {
      _canvasBusy = false;
      _canvasError = error;
    });

    if (error == null) {
      _tokenController.clear();
      SyncService.instance.syncCanvas(force: true);
      _toast('Canvas connected — syncing your courses');
    }
  }

  Future<void> _disconnectCanvas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Canvas?'),
        content: const Text(
          'Your access token is removed from this device and the server. '
          'Assignments already synced stay until you reconnect.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _canvasBusy = true);
    await _canvas.disconnect();
    if (mounted) setState(() => _canvasBusy = false);
  }

  Future<void> _toggleMirror(bool enabled) async {
    try {
      await _canvas.setMirrorToCalendar(enabled);
      // Push (or leave) existing due dates straight away.
      if (enabled) SyncService.instance.syncCanvas(force: true);
    } catch (_) {
      _toast('Could not save that setting. Try again.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ListenableBuilder(
      listenable: Listenable.merge([_google, _canvas]),
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connections', style: theme.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Keep your timetable and coursework in sync automatically.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildGoogleCard(theme),
            const SizedBox(height: AppSpacing.md),
            _buildCanvasCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleCard(ThemeData theme) {
    final connected = _google.isConnected;
    final upgrade = _google.needsReconnect;

    final String status;
    final Color statusColor;
    if (!connected) {
      status = 'Not connected';
      statusColor = theme.colorScheme.onSurfaceVariant;
    } else if (upgrade) {
      status = 'Reconnect to allow adding events';
      statusColor = AppTheme.warning;
    } else {
      status = 'Connected${_syncedSuffix(_google.lastSynced)}';
      statusColor = AppTheme.success;
    }

    return _IntegrationCard(
      icon: Icons.event_available_rounded,
      iconColor: AppTheme.secondary,
      iconBackground: AppTheme.secondaryContainer,
      title: 'Google Calendar',
      status: status,
      statusColor: statusColor,
      children: [
        Text(
          'Classes and events appear here, and new events you add in Google '
          'Calendar show up within minutes.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _googleBusy ? null : _connectGoogle,
                child: _googleBusy
                    ? const _ButtonSpinner()
                    : Text(!connected
                        ? 'Connect Google Calendar'
                        : upgrade
                            ? 'Reconnect'
                            : 'Reconnect account'),
              ),
            ),
            if (connected && !upgrade) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => SyncService.instance.syncCalendar(force: true),
                child: const Text('Sync now'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCanvasCard(ThemeData theme) {
    final connected = _canvas.isConnected;
    final googleReady = _google.isConnected && !_google.needsReconnect;

    return _IntegrationCard(
      icon: Icons.school_rounded,
      iconColor: AppTheme.canvasAmber,
      iconBackground: AppTheme.canvasAmberContainer,
      title: 'Canvas LMS',
      status: connected
          ? 'Connected${_syncedSuffix(_canvas.lastSynced)}'
          : 'Not connected',
      statusColor:
          connected ? AppTheme.success : theme.colorScheme.onSurfaceVariant,
      children: [
        if (!connected) ...[
          Text(
            'In Canvas open Account → Settings → “New Access Token”, then '
            'paste it below. Your token is stored in your device keychain.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Canvas address',
              hintText: 'https://school.instructure.com',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _tokenController,
            obscureText: _hideToken,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Access token',
              suffixIcon: IconButton(
                icon: Icon(_hideToken
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hideToken = !_hideToken),
              ),
            ),
          ),
          if (_canvasError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _canvasError!,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canvasBusy ? null : _connectCanvas,
              child: _canvasBusy ? const _ButtonSpinner() : const Text('Connect Canvas'),
            ),
          ),
        ] else ...[
          Text(
            _canvas.baseUrl ?? '',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Add due dates to Google Calendar',
                style: theme.textTheme.titleSmall),
            subtitle: Text(
              googleReady
                  ? 'Each assignment becomes a 30-minute event that ends at its deadline.'
                  : 'Connect Google Calendar (with edit access) to use this.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            value: _canvas.mirrorToCalendar && googleReady,
            onChanged: googleReady ? _toggleMirror : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: SyncService.instance.canvasSyncing,
                  builder: (context, syncing, _) => FilledButton(
                    onPressed: syncing
                        ? null
                        : () => SyncService.instance.syncCanvas(force: true),
                    child: syncing ? const _ButtonSpinner() : const Text('Sync now'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: _canvasBusy ? null : _disconnectCanvas,
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _syncedSuffix(DateTime? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return ' · just synced';
    if (diff.inMinutes < 60) return ' · synced ${diff.inMinutes}m ago';
    return ' · synced ${diff.inHours}h ago';
  }
}

class _IntegrationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String status;
  final Color statusColor;
  final List<Widget> children;

  const _IntegrationCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      Text(
                        status,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
