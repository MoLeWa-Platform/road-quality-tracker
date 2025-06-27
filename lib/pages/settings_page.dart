import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  @override
  void initState() {
    super.initState();
    loadCredentials();
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
      dev.log('response: ${response.statusCode} ${response.connectionInfo}', name:'Settingspage');
      if (response.statusCode > 400) {
        showConnectionError(response.statusCode);
      }
      else{
        showConnectionSuccess();
      }
    } catch (e) {
      dev.log('response: ${e.toString()}', name:'Settingspage');
      showConnectionError(null);

    } finally {
      dev.log('ended', name:'Settingspage');
    }
  }

  void showConnectionError(int? code) async{
    final newError = !_showErrorColor;
      setState(() {
        _isRequesting = false;
        _connectionSuccess = false;
        _showErrorColor = true;
      });
      if (newError){
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: code==null? Text('Connection could not be established.'): Text('Connection could not be established. (Code: $code)'),
              duration: const Duration(milliseconds: 1300),
              backgroundColor: Colors.red[400],
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

  void showConnectionSuccess() async{
    setState(() {
        _isRequesting = false;
        _connectionSuccess = true; //response.statusCode == 200;
        _showErrorColor = false;
      });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connection successful.'),
          duration: const Duration(milliseconds: 1300),
          backgroundColor: Colors.green,
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
        body:  Column(
            mainAxisAlignment: MainAxisAlignment.end, // Push down
              children: [
                const SizedBox(height: 25),
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
                          decoration: const InputDecoration(
                            labelText: 'Username',
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
                      const Icon(Icons.lock_outline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _saveAndTestConnection,
                      icon: _isRequesting
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
                            _connectionSuccess
                                ? Icons.check_circle_outline
                                : _showErrorColor
                                    ? Icons.link_off
                                    : Icons.link,
                            color: _connectionSuccess
                                ? Colors.green
                                : _showErrorColor
                                    ? Colors.red[400]
                                    : null,
                          ),
                      label: const Text('Check Connection'),
                    ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton.icon(
                    onPressed: _hasChanged ? saveSettings : null,
                    icon: Icon(Icons.save),
                    label: const Text("Save Settings"),
                    style: !_hasChanged
                      ? ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 3,
                        )
                      : ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 3,
                        ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
      ),
      );
    }
  }
  
