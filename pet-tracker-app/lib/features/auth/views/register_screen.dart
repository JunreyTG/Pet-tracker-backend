import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxCardWidth = math.min(screenWidth * 0.95, 460.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Get Started',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your owner account to start tracking.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    Obx(
                      () => c.error.value.isEmpty
                          ? const SizedBox(height: 16)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                c.error.value,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => FilledButton(
                        onPressed: c.loading.value
                            ? null
                            : () => c.register(
                                email.text,
                                password.text,
                                name.text,
                              ),
                        child: c.loading.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
