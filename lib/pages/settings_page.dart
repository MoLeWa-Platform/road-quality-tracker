import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/version_update.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  @override
  void initState() {
    super.initState();
    loadCredentials();
    loadPackageInfo();
  }

  Future<void> loadPackageInfo() async {
    var packageInfos = await PackageInfo.fromPlatform();
    setState(() {
      packageInfo = packageInfos;
    });
    return;
  }

  Future<void> loadCredentials() async {
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
  }

  void _checkForChanges() {
    final changed =
        serverUrlController.text != _originalServerUrl ||
        usernameController.text != _originalUsername ||
        passwordController.text != _originalPassword;

    if (changed != _hasChanged) {
      setState(() {
        _hasChanged = changed;
      });
    }
  }

  Future<void> _saveAndTestConnection() async {
    final url = Uri.parse(serverUrlController.text);
    final username = usernameController.text;
    final password = passwordController.text;

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

  void showUpdateSnackbar(){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "You're already on the latest version.",
        ),
        duration: const Duration(
          milliseconds: 1500,
        ),
        backgroundColor: Colors.green[800],
      ),
    );
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
    await storage.write(key: 'serverUrl', value: serverUrlController.text);
    await storage.write(key: 'username', value: usernameController.text);
    await storage.write(key: 'password', value: passwordController.text);

    _originalServerUrl = serverUrlController.text;
    _originalUsername = usernameController.text;
    _originalPassword = passwordController.text;
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
              Text(
                'Connection Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
          mainAxisAlignment: MainAxisAlignment.end, // Push down
          children: [
            const SizedBox(height: 25),
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
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TestConnectionButton(
                  isRequesting: _isRequesting,
                  connectionSuccess: _connectionSuccess,
                  showErrorColor: _showErrorColor,
                  onPressed: _saveAndTestConnection,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _CheckUpdateButton(
                  checkingUpdate: _checkingUpdate,
                  onPressed: () async {
                    setState(() => _checkingUpdate = true);
                    final available =
                        await AppUpdater.updateAvailable();

                    if (available == true) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        AppUpdater.showUpdateDialog(context);
                      });
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        showUpdateSnackbar();
                      });  
                    }

                    if (mounted) {
                      setState(() => _checkingUpdate = false);
                    }
                  },
                ),
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
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
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
        const SizedBox(height: 40),
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
      icon: isRequesting
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
              color: connectionSuccess
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
      icon: checkingUpdate
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

  const _SaveButton({
    required this.hasChanged,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: hasChanged ? onPressed : null,
      icon: const Icon(Icons.save),
      label: const Text("Save Settings"),
      style: !hasChanged
          ? ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              elevation: 3,
            )
          : ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              elevation: 3,
            ),
    );
  }
}
