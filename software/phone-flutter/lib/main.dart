import 'package:flutter/services.dart';

import 'ui.dart';
import 'module_details.dart';

import 'package:flutter/material.dart';

import 'core/settings.dart';
import 'core/connection.dart';

void main() => runApp(const HomaApp());

class HomaApp extends StatelessWidget {
  final PhoneController? controller;
  final bool autoStart;
  const HomaApp({super.key, this.controller, this.autoStart = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'هما | خانه هوشمند',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff0b1727),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    ),
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Dashboard(controller: controller, autoStart: autoStart),
  );
}

class Dashboard extends StatefulWidget {
  final PhoneController? controller;
  final bool autoStart;
  const Dashboard({super.key, this.controller, required this.autoStart});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  late final PhoneController controller;
  int page = 0;
  DateTime? _lastBack;
  void handleBack() {
    if (page != 0) {
      setState(() => page = 0);
      _lastBack = null;
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null &&
        now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("برای خروج دوباره Back را بزنید"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller =
        widget.controller ?? PhoneController(store: DeviceSettingsStore());
    if (widget.autoStart) controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.autoStart) {
      controller.suspend();
    }
    if (state == AppLifecycleState.resumed && widget.autoStart) {
      if (!controller.connected) {
        controller.reconnect();
      } else {
        controller.probeLocal();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xff133c43), Color(0xff111c31), Color(0xff211c3a)],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(Icons.home_rounded, color: mint, size: 36),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'هما',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'اتصال مجدد',
                      onPressed: () => controller.reconnect(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.status,
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.route == 'local'
                            ? 'متصل به بروکر داخلی'
                            : controller.route == 'external'
                            ? 'متصل به بروکر خارجی • فقط خواندن'
                            : 'اولویت: داخلی سپس خارجی',
                        style: const TextStyle(color: mint),
                      ),
                      if (controller.busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (page == 0) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ماژول‌های خانه',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'دریافت فهرست از رزبری',
                        onPressed: controller.connected
                            ? controller.requestCatalog
                            : null,
                        icon: const Icon(Icons.sync),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!controller.catalogLoaded)
                    const Text('در انتظار فهرست ماژول‌ها از رزبری…'),
                  for (final module in controller.modules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Glass(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            module.id.contains('refrigerator')
                                ? Icons.kitchen
                                : Icons.sensors,
                            color: mint,
                            size: 30,
                          ),
                          title: Text(
                            module.title,
                            style: const TextStyle(fontSize: 23),
                          ),
                          subtitle: Text(
                            module.online
                                ? 'پاسخ تازه موجود است'
                                : 'بدون پاسخ تازه',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _lastBack = null;
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ModuleDetails(
                                  id: module.id,
                                  controller: controller,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (controller.catalogLoaded && controller.modules.isEmpty)
                    const Text('ماژول فعالی در فهرست رزبری نیست.'),
                  const SizedBox(height: 16),
                  const Text(
                    'ماژول‌ها و ظاهر کارت‌ها در پنل رزبری تعریف می‌شوند؛ برای دیدن اطلاعات هر ماژول، آن را لمس کنید.',
                    style: TextStyle(color: Colors.white54, height: 1.8),
                  ),
                ],
                if (page == 1)
                  Glass(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: controller.messages
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(m),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (page == 2) settingsCard(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: page,
          onDestinationSelected: (v) => setState(() {
            page = v;
            _lastBack = null;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'خانه',
            ),
            NavigationDestination(icon: Icon(Icons.swap_vert), label: 'ارتباط'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'تنظیمات'),
          ],
        ),
      ),
    ),
  );

  Widget settingsCard() => Glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اتصال خانه',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'داخلی: ${controller.settings.local.host}:${controller.settings.local.port}',
        ),
        const SizedBox(height: 12),
        Text(
          'خارجی: ${controller.settings.external.host}:${controller.settings.external.port}',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: brokerEditor,
          icon: const Icon(Icons.settings_ethernet),
          label: const Text('تنظیم بروکرها و شناسهٔ خانه'),
        ),
        const SizedBox(height: 20),
        const Text(
          'بروکر خارجی فعلی عمومی و بدون رمزنگاری است. فقط دادهٔ غیرحساس را به اشتراک بگذارید. ارسال فرمان کنترلی از این مسیر غیرفعال است.',
          style: TextStyle(color: Colors.amber, height: 1.8),
        ),
      ],
    ),
  );
  Future<void> brokerEditor() async {
    final s = controller.settings;
    final fields = [
      s.local.host,
      '${s.local.port}',
      s.external.host,
      '${s.external.port}',
      s.installation,
    ].map((v) => TextEditingController(text: v)).toList();
    await editor(
      'تنظیمات ارتباط',
      fields,
      [
        'آدرس داخلی (بدون tcp://)',
        'پورت داخلی',
        'آدرس خارجی',
        'پورت خارجی',
        'شناسهٔ خانه در رزبری',
      ],
      () => PhoneSettings(
        local: Endpoint(
          fields[0].text.trim(),
          int.tryParse(fields[1].text) ?? 0,
        ),
        external: Endpoint(
          fields[2].text.trim(),
          int.tryParse(fields[3].text) ?? 0,
        ),
        installation: fields[4].text.trim(),
      ),
    );
  }

  Future<void> editor(
    String title,
    List<TextEditingController> fields,
    List<String> labels,
    PhoneSettings Function() result, {
    PhoneSettings Function()? onRemove,
  }) async {
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          Future<void> commit(PhoneSettings settings) async {
            final validation = settings.validate();
            if (validation != null) {
              update(() => error = validation);
              return;
            }
            update(() {
              saving = true;
              error = null;
            });
            try {
              // ذخیره قبل از شروع اتصال؛ شکست اتصال، تنظیمات را از بین نمی‌برد.
              await controller.save(settings);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (_) {
              if (context.mounted) {
                update(() {
                  saving = false;
                  error = 'ذخیرهٔ تنظیمات انجام نشد';
                });
              }
            }
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < fields.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18, top: 4),
                        child: TextField(
                          controller: fields[i],
                          enabled: !saving,
                          scrollPadding: const EdgeInsets.only(bottom: 160),
                          textDirection: labels[i] == 'نام نمایشی'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: labels[i],
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                        ),
                      ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.amber)),
                  ],
                ),
              ),
            ),
            actions: [
              if (onRemove != null)
                TextButton(
                  onPressed: saving ? null : () => commit(onRemove()),
                  child: const Text('حذف کارت'),
                ),
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: saving ? null : () => commit(result()),
                child: Text(saving ? 'در حال اتصال…' : 'ذخیره'),
              ),
            ],
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final field in fields) {
      field.dispose();
    }
  }
}
