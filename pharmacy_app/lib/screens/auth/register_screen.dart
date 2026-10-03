import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/route_names.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final errorMessage = await AuthService.register(
      username: _usernameController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (errorMessage == null) {
      context.go(RouteNames.login);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully. Please log in.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _errorMessage = errorMessage;
    });
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required.';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    const Icon(
                      Icons.local_pharmacy,
                      size: 64,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'JoseKiarie Pharmacy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Create your account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
                    ),

                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      Container(
                        padding:
                            const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(8),
                          color: Theme.of(context)
                              .colorScheme
                              .errorContainer,
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _usernameController,
                      textInputAction:
                          TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Username',
                        icon: Icons.person_outline,
                      ),
                      validator: _validateUsername,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: 'First name',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: 'Last name',
                              icon: Icons.badge_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Email',
                        icon: Icons.email_outlined,
                      ),
                      validator: _validateEmail,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction:
                          TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Phone Number (optional)',
                        icon: Icons.phone_outlined,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction:
                          TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Password',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _register();
                        }
                      },
                      decoration: _inputDecoration(
                        label: 'Confirm Password',
                        icon: Icons.lock_reset_outlined,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator:
                          _validateConfirmPassword,
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _register,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create Account',
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              context.go(
                                RouteNames.login,
                              );
                            },
                      child: const Text(
                        'Already have an account? Log in',
                      ),
                    ),

                    const SizedBox(height: 20),
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