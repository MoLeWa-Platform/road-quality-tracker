import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:road_quality_tracker/services/device_meta_service.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import '../services/version_update.dart';

class SettingsPage extends StatefulWidget {
  final RunLogger logger;
  const SettingsPage({super.key, required this.logger});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late RunLogger logger;
  final TextEditingController serverUrlController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final storage = FlutterSecureStorage();

  bool _connectionSuccess = false;
  bool _showErrorColor = false;
  bool _isRequesting = false;
  bool _showPassword = false;

  String _originalServerUrl = '';
  String _originalUsername = '';
  String _originalPassword = '';
  bool _hasChanged = false;
  bool _checkingUpdate = false;

  PackageInfo? packageInfo;

  bool sendDeviceHash = false;
  bool sendDeviceInfo = false;
  bool _originalSendDeviceHash = false;
  bool _originalSendDeviceInfo = false;

  String? _deviceHash;

  @override
  void initState() {
    super.initState();
    logger = widget.logger;
    loadCredentials();
    loadPackageInfo();
    loadDeviceSettings();
    loadDeviceHash();
    _checkForChanges();
  }

  Future<void> loadDeviceHash() async {
    _deviceHash = await storage.read(key: 'deviceHash');

    String? alreadyUpdatedStr = await storage.read(key: 'deviceHashVersion2');
    bool alreadyUpdated = alreadyUpdatedStr == 'true';

    if (_deviceHash == null || !alreadyUpdated) {
      final hash = await DeviceMetaService.generateDeviceHash();
      await storage.write(key: 'deviceHash', value: hash);
      await storage.write(key: 'deviceHashVersion2', value: 'true');
      setState(() {
        _deviceHash = hash;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> loadDeviceSettings() async {
    final hashVal = await storage.read(key: 'sendDeviceHash');
    final infoVal = await storage.read(key: 'sendDeviceInfo');

    final currentHash = hashVal == 'true';
    final currentInfo = infoVal == 'true';

    setState(() {
      sendDeviceHash = currentHash;
      sendDeviceInfo = currentInfo;
      _originalSendDeviceHash = currentHash;
      _originalSendDeviceInfo = currentInfo;
    });

    _checkForChanges(); 
  }

  Future<void> saveDeviceSettings() async {
    await storage.write(
      key: 'sendDeviceHash',
      value: sendDeviceHash.toString(),
    );
    await storage.write(
      key: 'sendDeviceInfo',
      value: sendDeviceInfo.toString(),
    );
  }

  Future<void> loadPackageInfo() async {
    var packageInfos = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = packageInfos;
    });
    return;
  }

  Future<void> loadCredentials() async {
    logger.log('[SETTINGS PAGE] Loading Credentials.');
    serverUrlController.text = await storage.read(key: 'serverUrl') ?? '';
    usernameController.text = await storage.read(key: 'username') ?? '';
    passwordController.text = await storage.read(key: 'password') ?? '';

    _originalServerUrl = serverUrlController.text;
    _originalUsername = usernameController.text;
    _originalPassword = passwordController.text;

    serverUrlController.addListener(_checkForChanges);
    usernameController.addListener(_checkForChanges);
    passwordController.addListener(_checkForChanges);

    _hasChanged = false;
    _checkForChanges();
  }

  void _checkForChanges() {
    final trimmedServerUrl = serverUrlController.text.trim();
    final trimmedUsername = usernameController.text.trim();
    final password = passwordController.text;

    final connectionChanged =
        trimmedServerUrl != _originalServerUrl.trim() ||
        trimmedUsername != _originalUsername.trim() ||
        password != _originalPassword;

    final metadataChanged =
        sendDeviceHash != _originalSendDeviceHash ||
        sendDeviceInfo != _originalSendDeviceInfo;

    final changed = connectionChanged || metadataChanged;

    if (changed != _hasChanged) {
      setState(() {
        _hasChanged = changed;
      });
    }
  }

  Future<void> _saveAndTestConnection() async {
    logger.log('[SETTINGS PAGE] Testing connection after button press.');
    final url = Uri.parse(serverUrlController.text);
    final username = usernameController.text;
    final password = passwordController.text;

    if (serverUrlController.text.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Please fill out all credentials before connecting.",
          ),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isRequesting = true;
    });
    try {
      final response = await HttpClient().postUrl(url).then((request) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        );
        return request.close();
      });
      dev.log(
        'response: ${response.statusCode} ${response.connectionInfo}',
        name: 'Settingspage',
      );
      if (response.statusCode > 400) {
        showConnectionError(response.statusCode);
      } else {
        showConnectionSuccess();
      }
    } catch (e) {
      dev.log('response: ${e.toString()}', name: 'Settingspage');
      showConnectionError(null);
    } finally {
      dev.log('ended', name: 'Settingspage');
    }
  }

  void showConnectionError(int? code) async {
    final newError = !_showErrorColor;
    setState(() {
      _isRequesting = false;
      _connectionSuccess = false;
      _showErrorColor = true;
    });
    if (newError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              code == null
                  ? Text('Connection could not be established.')
                  : Text('Connection could not be established. (Code: $code)'),
          duration: const Duration(milliseconds: 1300),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _showErrorColor = false;
        });
      }
    }
  }

  void showUpdateSnackbar(bool? available) {
    if (available == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("You're already on the latest version."),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.green[800],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Could not connect to the Repository!"),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void showConnectionSuccess() async {
    setState(() {
      _isRequesting = false;
      _connectionSuccess = true; //response.statusCode == 200;
      _showErrorColor = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Connection successful.'),
        duration: const Duration(milliseconds: 1300),
        backgroundColor: Colors.green[800],
      ),
    );
  }

  void saveSettings() async {
    logger.log('[SETTINGS PAGE] Saving Settings after button press.');
    await storage.write(key: 'serverUrl', value: serverUrlController.text);
    await storage.write(key: 'username', value: usernameController.text);
    await storage.write(key: 'password', value: passwordController.text);

    _originalServerUrl = serverUrlController.text;
    _originalUsername = usernameController.text;
    _originalPassword = passwordController.text;

    _originalSendDeviceHash = sendDeviceHash; 
    _originalSendDeviceInfo = sendDeviceInfo;

    await saveDeviceSettings();

    _checkForChanges();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceBright,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Divider(
                thickness: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1,
              ),
            ],
          ),
          toolbarHeight: 70,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Push down
          children: [
            // Connection Section
            SettingsCard(
              title: "Connection",
              children: [
                _LoginCredentialsSection(
                  serverUrlController: serverUrlController,
                  usernameController: usernameController,
                  passwordController: passwordController,
                  showPassword: _showPassword,
                  toggleShowPassword: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TestConnectionButton(
                    isRequesting: _isRequesting,
                    connectionSuccess: _connectionSuccess,
                    showErrorColor: _showErrorColor,
                    onPressed: _saveAndTestConnection,
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
            // Advanced Section
            SettingsCard(
              title: "Advanced",
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Share Device Hash'),
                              if (sendDeviceHash && _deviceHash != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "Hash suffix: ${_deviceHash!.substring(_deviceHash!.length - 6)}",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          value: sendDeviceHash,
                          onChanged: (val) {
                            setState(() {
                              sendDeviceHash = val;
                              _checkForChanges();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Share Device Info'),
                              if (sendDeviceInfo)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "(Model, Manufacturer, OS Version)",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          value: sendDeviceInfo,
                          onChanged: (val) {
                            setState(() {
                              sendDeviceInfo = val;
                              _checkForChanges();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: _CheckUpdateButton(
                    checkingUpdate: _checkingUpdate,
                    onPressed: () async {
                      setState(() => _checkingUpdate = true);
                      final available = await AppUpdater.updateAvailable();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        available == true
                            ? AppUpdater.showUpdateDialog(context)
                            : showUpdateSnackbar(available);
                      });
                      if (mounted) setState(() => _checkingUpdate = false);
                    },
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),

            const Spacer(),
            Align(
              alignment: Alignment.bottomCenter,
              child: _SaveButton(
                hasChanged: _hasChanged,
                onPressed: saveSettings,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _LoginCredentialsSection extends StatelessWidget {
  final TextEditingController serverUrlController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool showPassword;
  final VoidCallback toggleShowPassword;

  const _LoginCredentialsSection({
    required this.serverUrlController,
    required this.usernameController,
    required this.passwordController,
    required this.showPassword,
    required this.toggleShowPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: serverUrlController,
                  decoration: const InputDecoration(labelText: 'Server URL'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.lock_outline),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: toggleShowPassword,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TestConnectionButton extends StatelessWidget {
  final bool isRequesting;
  final bool connectionSuccess;
  final bool showErrorColor;
  final VoidCallback onPressed;

  const _TestConnectionButton({
    required this.isRequesting,
    required this.connectionSuccess,
    required this.showErrorColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon:
          isRequesting
              ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
              : Icon(
                connectionSuccess
                    ? Icons.check_circle_outline
                    : showErrorColor
                    ? Icons.link_off
                    : Icons.link,
                color:
                    connectionSuccess
                        ? Colors.green[800]
                        : showErrorColor
                        ? Theme.of(context).colorScheme.error
                        : null,
              ),
      label: const Text('Check Connection'),
    );
  }
}

class _CheckUpdateButton extends StatelessWidget {
  final bool checkingUpdate;
  final Future<void> Function() onPressed;

  const _CheckUpdateButton({
    required this.checkingUpdate,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: checkingUpdate ? null : onPressed,
      icon:
          checkingUpdate
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.system_update),
      label: const Text("Check for App Updates"),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool hasChanged;
  final VoidCallback onPressed;

  const _SaveButton({required this.hasChanged, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (hasChanged) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Saved changes."),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
        onPressed();
      },
      icon: const Icon(Icons.save),
      label: const Text("Save Settings"),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasChanged
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.inverseSurface.withAlpha(30),
        foregroundColor:
            hasChanged
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withAlpha(100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: hasChanged ? 3 : 0, // <- No shadow when not changed
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const SettingsCard({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

