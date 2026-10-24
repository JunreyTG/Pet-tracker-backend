import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_config.dart';
import '../../../data/models/models.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/app_data_controller.dart';
import '../services/tracker_local_setup.dart';

class DeviceWifiSetupScreen extends StatefulWidget {
  const DeviceWifiSetupScreen({
    super.key,
    this.localSetup,
    this.browserOverride,
  });
  final TrackerLocalSetup? localSetup;
  final bool? browserOverride;

  @override
  State<DeviceWifiSetupScreen> createState() => _DeviceWifiSetupScreenState();
}

class _DeviceWifiSetupScreenState extends State<DeviceWifiSetupScreen> {
  final data = Get.find<AppDataController>();
  final code = TextEditingController();
  final wifiName = TextEditingController();
  final wifiPassword = TextEditingController();
  final savedSecret = TextEditingController();
  final backendUrl = TextEditingController(text: AppConfig.baseUrl);
  final setupAddress = TextEditingController(text: 'http://192.168.4.1/config');
  final scrollController = ScrollController();
  late final TrackerLocalSetup localSetup =
      widget.localSetup ?? TrackerLocalSetup();
  List<PetModel> pets = [];
  String? petId;
  DeviceProvisioningModel? provisioning;
  DeviceModel? reportedDevice;
  DateTime? sentAt;
  Timer? pollTimer;
  int pollCount = 0;
  int step = 0;
  bool loadingPets = true, busy = false, checking = false;
  bool addressAnswered = false,
      uncertainDelivery = false,
      confirmedOnline = false;
  bool revealPassword = false,
      revealSecret = false,
      showHelp = false,
      allowPop = false;
  String? error, detail, notice;

  bool get browser => widget.browserOverride ?? kIsWeb;
  String get trackerId => code.text.trim();
  String get expectedNetwork =>
      provisioning?.setupHotspotSsid ?? 'PET_TRACKER_SETUP_$trackerId';
  String get storageKey {
    final uid =
        Get.find<AuthController>().backendUser.value?.uid ?? 'signed_out';
    return 'tracker_setup_$uid';
  }

  @override
  void initState() {
    super.initState();
    final argument = Get.arguments;
    if (argument is String && argument.isNotEmpty) code.text = argument;
    restoreProgress();
    loadPets();
  }

  Future<void> loadPets() async {
    if (mounted) setState(() => loadingPets = true);
    try {
      final loaded = await data.petsRepo.list();
      if (!mounted) return;
      setState(() {
        pets = loaded;
        if (petId == null && pets.length == 1) petId = pets.first.id;
        notice = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => notice =
              'We could not load your pets. Check your internet connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loadingPets = false);
    }
  }

  Future<void> restoreProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (code.text.isEmpty) {
        code.text = prefs.getString('${storageKey}_code') ?? '';
      }
      setState(() => petId = prefs.getString('${storageKey}_pet'));
    } catch (_) {}
  }

  Future<void> saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${storageKey}_code', trackerId);
      if (petId != null) await prefs.setString('${storageKey}_pet', petId!);
    } catch (_) {}
  }

  Future<void> clearProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${storageKey}_code');
      await prefs.remove('${storageKey}_pet');
    } catch (_) {}
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    scrollController.dispose();
    if (widget.localSetup == null) localSetup.close();
    for (final c in [
      code,
      wifiName,
      wifiPassword,
      savedSecret,
      backendUrl,
      setupAddress,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void fail(String message, [String? technical]) {
    if (mounted) {
      setState(() {
        error = message;
        detail = technical;
      });
    }
  }

  void goTo(int next) {
    setState(() {
      step = next;
      error = null;
      detail = null;
      notice = null;
    });
    saveProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) scrollController.jumpTo(0);
    });
  }

  Future<void> exitSetup() async {
    if (allowPop) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave tracker setup?'),
        content: Text(
          provisioning == null
              ? 'Your tracker code will be saved. WiFi details will be cleared.'
              : 'Your tracker code will be saved, but the new one-time recovery key will be lost. Save it privately from Advanced Settings before leaving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Setting Up'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave Setup'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    pollTimer?.cancel();
    await saveProgress();
    if (!mounted) return;
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void back() {
    if (busy || checking) return;
    if (step == 0) {
      exitSetup();
      return;
    }
    pollTimer?.cancel();
    if (step == 3) {
      addressAnswered = false;
      goTo(1);
    } else {
      goTo(step - 1);
    }
  }

  Future<void> findTracker() async {
    if (busy) return;
    if (trackerId.isEmpty) {
      fail('Enter the tracker code supplied with your device.');
      return;
    }
    if (loadingPets) return;
    if (browser) {
      goTo(1);
      return;
    }
    if (pets.isEmpty || petId == null || !pets.any((p) => p.id == petId)) {
      fail(
        'Add a pet and choose who will wear this tracker before continuing.',
      );
      return;
    }
    final backend = Uri.tryParse(backendUrl.text.trim());
    if (backend == null ||
        !{'http', 'https'}.contains(backend.scheme) ||
        backend.host.isEmpty) {
      fail('The service address in Advanced Settings is invalid.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      detail = null;
    });
    try {
      DeviceModel? registered;
      if (provisioning == null) {
        try {
          registered = await data.devicesRepo.get(trackerId);
        } on ApiException catch (e) {
          if (e.statusCode != 404) rethrow;
        }
        if (registered == null && savedSecret.text.trim().isEmpty) {
          provisioning = await data.devicesRepo.provision(
            trackerId,
            backendUrl: backendUrl.text.trim(),
          );
        } else if (registered != null && savedSecret.text.trim().isEmpty) {
          fail(
            'This tracker is already linked. To reconnect it, enter its saved recovery key in Advanced Settings.',
            'The backend returns a tracker key only when first registered.',
          );
          return;
        } else if (registered == null) {
          fail(
            'We could not find this tracker in your account. Check its code or clear the saved recovery key.',
          );
          return;
        }
      }
      if (!mounted) return;
      registered ??= await data.devicesRepo.get(trackerId);
      if (registered.petId != null && registered.petId != petId) {
        fail(
          'This tracker is assigned to another pet. Change the assignment in Tracker Details first.',
        );
        return;
      }
      if (registered.petId == null) {
        await data.devicesRepo.assign(trackerId, petId!);
      }
      if (mounted) goTo(1);
    } on ApiException catch (e) {
      fail(
        e.statusCode == 409
            ? 'This tracker is already registered. Enter its saved recovery key in Advanced Settings.'
            : 'We could not prepare your tracker. Check your internet connection and try again.',
        'Backend status: ${e.statusCode ?? 'unavailable'}',
      );
    } catch (e) {
      fail(
        'We could not prepare your tracker. Please try again.',
        e.runtimeType.toString(),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Uri? endpoint() {
    final uri = Uri.tryParse(setupAddress.text.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.path != '/config' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final parts = uri.host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((n) => n == null || n < 0 || n > 255)) {
      return null;
    }
    final a = parts[0]!, b = parts[1]!;
    if (a != 10 &&
        !(a == 172 && b >= 16 && b <= 31) &&
        !(a == 192 && b == 168)) {
      return null;
    }
    return uri;
  }

  Future<void> checkConnection() async {
    if (busy) return;
    if (browser) {
      fail(
        'A browser cannot reliably check this local setup address. Join the tracker network in WiFi settings, then continue for the guided alternative.',
      );
      return;
    }
    final target = endpoint();
    if (target == null) {
      fail('The tracker setup address in Advanced Settings is invalid.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      detail = null;
    });
    try {
      final answered = await localSetup.checkConnection(target);
      if (!mounted) return;
      setState(() {
        addressAnswered = answered;
        if (answered) {
          notice =
              'The setup address answered. Make sure you joined the tracker network shown above.';
        } else {
          error =
              'We reached a device, but its setup page is unavailable. Check the tracker network and try again.';
        }
      });
    } catch (e) {
      fail(
        'Connect to your tracker’s WiFi in device settings, then return and check again.',
        e.runtimeType.toString(),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendWifi() async {
    if (busy || browser) return;
    if (wifiName.text.trim().isEmpty) {
      fail('Enter the name of the WiFi network your tracker should use.');
      return;
    }
    if (!addressAnswered) {
      fail('Check your connection to the tracker before sending WiFi details.');
      return;
    }
    final target = endpoint();
    if (target == null) {
      fail('The tracker setup address in Advanced Settings is invalid.');
      return;
    }
    final secret = provisioning?.deviceSecret ?? savedSecret.text.trim();
    if (secret.isEmpty) {
      fail(
        'The tracker recovery key is missing. Return to the first step and prepare the tracker again.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      detail = null;
    });
    try {
      final started = DateTime.now();
      final delivery = await localSetup.sendConfiguration(
        endpoint: target,
        wifiName: wifiName.text.trim(),
        wifiPassword: wifiPassword.text,
        deviceId: trackerId,
        deviceSecret: secret,
        backendUrl: provisioning?.backendUrl ?? backendUrl.text.trim(),
      );
      wifiPassword.clear();
      if (!mounted) return;
      sentAt = started;
      uncertainDelivery = delivery == TrackerDelivery.unconfirmed;
      confirmedOnline = false;
      reportedDevice = null;
      goTo(3);
      startPolling();
    } on TrackerConfigurationRejected catch (e) {
      wifiPassword.clear();
      fail(
        'Your tracker did not accept the WiFi details. Check the network name and password, then try again.',
        'Tracker response: HTTP ${e.statusCode}',
      );
    } catch (e) {
      wifiPassword.clear();
      fail(
        'We could not send WiFi details. Reconnect to the tracker network and try again.',
        e.runtimeType.toString(),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startPolling() {
    pollTimer?.cancel();
    pollCount = 0;
    checkStatus();
    pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (step != 3 || confirmedOnline || pollCount >= 20) {
        pollTimer?.cancel();
      } else {
        checkStatus();
      }
    });
  }

  Future<void> checkStatus() async {
    if (checking || sentAt == null || step != 3) return;
    setState(() {
      checking = true;
      error = null;
    });
    pollCount++;
    try {
      final device = await data.devicesRepo.get(trackerId);
      if (!mounted || step != 3) return;
      setState(() {
        reportedDevice = device;
        confirmedOnline = hasFreshOnlineReport(device, sentAt!);
        notice = confirmedOnline
            ? null
            : 'We have not received a new connection from your tracker yet.';
      });
      if (confirmedOnline) {
        pollTimer?.cancel();
        clearProgress();
        data.refreshAll();
      }
    } catch (e) {
      if (mounted && step == 3) {
        setState(() {
          notice =
              'We cannot check your tracker yet. Reconnect this phone to your usual WiFi or mobile data, then check again.';
          detail = e is ApiException
              ? 'Backend status: ${e.statusCode ?? 'unavailable'}'
              : e.runtimeType.toString();
        });
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> renameTracker() async {
    final nameField = TextEditingController(text: data.deviceName(trackerId));
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name your tracker'),
        content: TextField(
          controller: nameField,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Tracker name',
            hintText: 'e.g. Milo’s Tracker',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameField.text.trim()),
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
    nameField.dispose();
    if (name == null || name.isEmpty) return;
    await data.setDeviceName(trackerId, name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Up Tracker'),
          leading: IconButton(
            tooltip: step == 0 ? 'Leave setup' : 'Previous step',
            onPressed: busy || checking ? null : back,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    'Step ${step + 1} of 4',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (step + 1) / 4,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: .12,
                    ),
                    color: AppTheme.green,
                    semanticsLabel: 'Setup progress, step ${step + 1} of 4',
                  ),
                  const SizedBox(height: 24),
                  header(theme),
                  const SizedBox(height: 24),
                  panel(context, switch (step) {
                    0 => findStep(context),
                    1 => connectStep(context),
                    2 => wifiStep(context),
                    _ => completeStep(context),
                  }),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    messageBox(
                      error!,
                      Icons.error_outline,
                      theme.colorScheme.error,
                    ),
                  ],
                  if (notice != null) ...[
                    const SizedBox(height: 16),
                    messageBox(
                      notice!,
                      Icons.info_outline,
                      Colors.amber.shade800,
                    ),
                  ],
                  if (detail != null)
                    ExpansionTile(
                      title: const Text('Technical details for support'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(detail!),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  actions(),
                  if (step < 3) ...[
                    const SizedBox(height: 16),
                    advancedSettings(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget header(ThemeData theme) {
    final title = switch (step) {
      0 => "Let's Set Up Your Pet Tracker",
      1 => 'Connect to Your Tracker',
      2 => 'Choose Your WiFi Network',
      _ =>
        confirmedOnline
            ? 'Your Pet Tracker Is Ready!'
            : 'Connecting Your Tracker',
    };
    final description = switch (step) {
      0 => "We'll help you connect your tracker in just a few simple steps.",
      1 =>
        "Connect your phone or computer to your tracker's temporary WiFi network.",
      2 =>
        'Choose the WiFi network your tracker will use to send location updates.',
      _ =>
        confirmedOnline
            ? 'Your tracker has sent a fresh update and is online.'
            : 'Your tracker may restart now. Reconnect this phone to your usual internet connection.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(description, style: theme.textTheme.bodyLarge),
      ],
    );
  }

  Widget panel(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget messageBox(String text, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget findStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 42,
            backgroundColor: AppTheme.green.withValues(alpha: .12),
            child: const Icon(Icons.pets, size: 43, color: AppTheme.green),
          ),
        ),
        const SizedBox(height: 20),
        Text('Turn on your tracker', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
          'Stay on your usual internet connection for now. Turn on the tracker; we will tell you when to join its temporary WiFi network. If that network does not appear later, restart the tracker and follow its hardware guide.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: code,
          enabled: provisioning == null,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Tracker code',
            hintText: 'Code supplied with your tracker',
            prefixIcon: Icon(Icons.qr_code),
          ),
          onChanged: (_) => setState(() {
            provisioning = null;
            addressAnswered = false;
            error = null;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'The current hardware cannot be discovered automatically. This code links the tracker to your account.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (loadingPets)
          const LinearProgressIndicator()
        else if (pets.isEmpty) ...[
          messageBox(
            'Add your pet first. The backend needs a pet assignment before it can accept location updates.',
            Icons.pets,
            Colors.amber.shade800,
          ),
          TextButton.icon(
            onPressed: () {
              saveProgress();
              Get.toNamed(Routes.addPet);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add a Pet'),
          ),
          TextButton(
            onPressed: loadPets,
            child: const Text('I added my pet — refresh list'),
          ),
        ] else if (pets.length > 1)
          DropdownButtonFormField<String>(
            initialValue: pets.any((p) => p.id == petId) ? petId : null,
            decoration: const InputDecoration(
              labelText: 'Which pet will wear this tracker?',
            ),
            items: pets
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                .toList(),
            onChanged: (value) => setState(() => petId = value),
          )
        else
          Text('For ${pets.first.name}', style: theme.textTheme.titleMedium),
        if (browser) ...[
          const SizedBox(height: 16),
          messageBox(
            'This browser cannot scan nearby trackers or reliably send settings to their local setup page. Follow the guide here, then finish in the Android app.',
            Icons.info_outline,
            Colors.amber.shade800,
          ),
        ],
        TextButton.icon(
          onPressed: () => setState(() => showHelp = !showHelp),
          icon: const Icon(Icons.help_outline),
          label: const Text('Need help finding your tracker?'),
        ),
        if (showHelp)
          const Text(
            'Check the code supplied with the tracker and look for a WiFi network beginning PET_TRACKER_SETUP_. The exact setup-button behavior is not documented in this project; check your hardware guide if the network does not appear.',
          ),
      ],
    );
  }

  Widget connectStep(BuildContext context) {
    final instructions = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        'Open Android Settings → WiFi and join the tracker network. Return to this app afterward.',
      TargetPlatform.iOS =>
        'Open iPhone Settings → WiFi and join the tracker network. Return to this app afterward.',
      TargetPlatform.windows =>
        'Open Windows Quick Settings → WiFi and join the tracker network. Return to this app afterward.',
      TargetPlatform.macOS =>
        'Open the Mac WiFi menu and join the tracker network. Return to this app afterward.',
      _ =>
        'Open your device’s WiFi settings and join the tracker network. Return to this app afterward.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.wifi_tethering, size: 48, color: AppTheme.green),
        const SizedBox(height: 14),
        const Text('Tracker setup network'),
        const SizedBox(height: 5),
        SelectableText(
          expectedNetwork,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const Text(
          'This is the tracker’s temporary network, not your home WiFi. Confirm the name matches the network you see.',
        ),
        const SizedBox(height: 16),
        messageBox(instructions, Icons.settings, AppTheme.green),
        const SizedBox(height: 12),
        messageBox(
          'A “No Internet” warning is normal while connected to the tracker. Keep the connection and come back here.',
          Icons.info_outline,
          Colors.amber.shade800,
        ),
        if (addressAnswered) ...[
          const SizedBox(height: 12),
          messageBox(
            'The setup address responded. You can continue.',
            Icons.check_circle_outline,
            AppTheme.green,
          ),
        ],
        if (browser) ...[
          const SizedBox(height: 12),
          const Text(
            'Browser security may block a connection check even when you joined the correct network. Continue for the guided alternative.',
          ),
        ],
      ],
    );
  }

  Widget wifiStep(BuildContext context) {
    if (browser) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.phonelink_setup, size: 52, color: AppTheme.green),
          const SizedBox(height: 16),
          Text(
            'Finish setup in the Android app',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const Text(
            'This website uses HTTPS, while the tracker currently accepts setup details over local HTTP. Browsers may block that request. Install the Android app, sign in, and start setup again there. Your tracker code is saved; WiFi passwords and recovery keys are not.',
          ),
          const SizedBox(height: 16),
          const Text('Open this download address on your Android phone:'),
          const SizedBox(height: 4),
          SelectableText('${AppConfig.baseUrl}/download-apk'),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.router_outlined, size: 48, color: AppTheme.green),
        const SizedBox(height: 14),
        TextField(
          controller: wifiName,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Home WiFi network name',
            hintText: 'The network your tracker will use',
            prefixIcon: Icon(Icons.wifi),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: wifiPassword,
          autocorrect: false,
          obscureText: !revealPassword,
          decoration: InputDecoration(
            labelText: 'WiFi password',
            helperText: 'Leave blank if this network has no password.',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: revealPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => revealPassword = !revealPassword),
              icon: Icon(
                revealPassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        messageBox(
          'Most ESP32 trackers need a 2.4 GHz WiFi network. Check your router if the tracker does not come online.',
          Icons.info_outline,
          Colors.amber.shade800,
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password is sent directly to the tracker over its temporary local network. It is not saved in this app.',
        ),
      ],
    );
  }

  Widget completeStep(BuildContext context) {
    final device = reportedDevice;
    if (!confirmedOnline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: CircularProgressIndicator(color: AppTheme.green)),
          const SizedBox(height: 18),
          const Text('Waiting for a fresh location update from your tracker.'),
          const SizedBox(height: 10),
          if (uncertainDelivery)
            messageBox(
              'The tracker connection closed during setup. It may be restarting; we will confirm through the backend before calling setup complete.',
              Icons.info_outline,
              Colors.amber.shade800,
            ),
          const SizedBox(height: 10),
          const Text(
            'If this phone still shows “No Internet,” reconnect it to your usual WiFi or mobile data. Make sure the tracker is powered on and near your home router.',
          ),
          if (pollCount >= 20) ...[
            const SizedBox(height: 12),
            messageBox(
              'Your tracker is still offline. Check the WiFi name and password, then try again.',
              Icons.warning_amber,
              Colors.amber.shade800,
            ),
            TextButton(
              onPressed: () {
                pollTimer?.cancel();
                addressAnswered = false;
                goTo(1);
              },
              child: const Text('Edit WiFi Details'),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: .65, end: 1),
            duration: const Duration(milliseconds: 500),
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: const CircleAvatar(
              radius: 42,
              backgroundColor: AppTheme.green,
              child: Icon(Icons.check, color: Colors.white, size: 50),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          data.deviceName(trackerId),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        messageBox(
          'Online — a new update was received.',
          Icons.sensors,
          AppTheme.green,
        ),
        if (device?.batteryLevel != null) ...[
          const SizedBox(height: 10),
          Text('Battery: ${device!.batteryLevel}%'),
        ],
        if (device?.lastSeen != null)
          Text(
            'Last seen: ${DateFormat.yMMMd().add_jm().format(device!.lastSeen!)}',
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: renameTracker,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Rename tracker'),
        ),
      ],
    );
  }

  Widget actions() {
    final label = switch (step) {
      0 => busy ? 'Preparing your tracker...' : 'Find My Tracker',
      1 =>
        addressAnswered || browser
            ? 'Continue'
            : busy
            ? 'Checking connection...'
            : 'Check Connection',
      2 =>
        busy
            ? 'Connecting your tracker...'
            : browser
            ? 'Copy Android App Link'
            : 'Connect Tracker to WiFi',
      _ =>
        confirmedOnline
            ? 'Go to My Tracker'
            : checking
            ? 'Checking...'
            : 'Check Again',
    };
    final VoidCallback? action = busy || checking
        ? null
        : switch (step) {
            0 => findTracker,
            1 => addressAnswered || browser ? () => goTo(2) : checkConnection,
            2 =>
              browser
                  ? () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: '${AppConfig.baseUrl}/download-apk',
                        ),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Android app download link copied.'),
                          ),
                        );
                      }
                    }
                  : sendWifi,
            _ =>
              confirmedOnline
                  ? () =>
                        Get.offNamed(Routes.deviceDetails, arguments: trackerId)
                  : startPolling,
          };
    return Column(
      children: [
        FilledButton.icon(
          onPressed: action,
          icon: busy || checking
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  step == 3 && confirmedOnline
                      ? Icons.arrow_forward
                      : Icons.wifi_tethering,
                ),
          label: Text(label),
        ),
        if (step == 1 && !browser && addressAnswered) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : checkConnection,
            child: const Text('Check Connection Again'),
          ),
        ],
        if (step > 0 && step < 3) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy || checking ? null : back,
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }

  Widget advancedSettings() => ExpansionTile(
    title: const Text('Advanced Settings'),
    subtitle: const Text('For support or a previously registered tracker'),
    childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
    children: [
      TextField(
        controller: backendUrl,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Backend Server URL'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: setupAddress,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Tracker setup address'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: savedSecret,
        autocorrect: false,
        obscureText: !revealSecret,
        decoration: InputDecoration(
          labelText: 'Saved tracker recovery key',
          suffixIcon: IconButton(
            tooltip: revealSecret ? 'Hide recovery key' : 'Show recovery key',
            onPressed: () => setState(() => revealSecret = !revealSecret),
            icon: Icon(revealSecret ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      ),
      if (provisioning != null) ...[
        const SizedBox(height: 12),
        const Text(
          'New tracker key — shown only during this setup. Save it privately if you may need to reconnect later.',
        ),
        TextButton(
          onPressed: () => setState(() => revealSecret = !revealSecret),
          child: Text(revealSecret ? 'Hide new key' : 'Reveal new key'),
        ),
        if (revealSecret) SelectableText(provisioning!.deviceSecret),
      ],
      const SizedBox(height: 8),
      const Text(
        'Only use a setup address supplied with your tracker. The current firmware contract uses local HTTP; it does not encrypt WiFi details on the tracker network.',
      ),
    ],
  );
}
