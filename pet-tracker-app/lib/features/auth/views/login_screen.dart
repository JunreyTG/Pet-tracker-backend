import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final PageController _pageController = PageController();

  bool _obscurePassword = true;
  bool _showLoginForm = false;
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  static const List<Map<String, String>> _carouselCards = [
    {
      'tag': 'REAL-TIME TRACKING',
      'title': 'Live GPS Tracking',
      'subtitle': 'Real-time pinpoint accuracy.',
      'image': 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'GEO-FENCING',
      'title': 'Smart Safe Zones',
      'subtitle': 'Instant boundary alerts.',
      'image': 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=800&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'ACTIVITY & TRAILS',
      'title': 'Location History & Daily Routes',
      'subtitle': 'Walk trails and adventure waypoints.',
      'image': 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=800&auto=format&fit=crop&q=80',
    },
    {
      'tag': 'DEVICE STATUS',
      'title': 'Battery & Hardware Alerts',
      'subtitle': 'Device telemetry and low battery warnings.',
      'image': 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=800&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_pageController.hasClients) {
        final nextIndex = (_currentCarouselIndex + 1) % _carouselCards.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final heroHeight = math.max(220.0, math.min(300.0, screenHeight * 0.35));
    final maxCardWidth = math.min(screenWidth * 0.95, 460.0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxCardWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 10-Second Animated Carousel Hero
                  Container(
                    height: heroHeight,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .15),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _carouselCards.length,
                          onPageChanged: (index) {
                            setState(() => _currentCarouselIndex = index);
                            _startCarouselTimer(); // Reset 10s timer on manual swipe
                          },
                          itemBuilder: (context, index) {
                            final card = _carouselCards[index];
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  card['image']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.pets, color: AppTheme.green, size: 64),
                                    ),
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: .15),
                                        Colors.black.withValues(alpha: .5),
                                        Colors.black.withValues(alpha: .9),
                                      ],
                                      stops: const [0.0, 0.45, 1.0],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.green,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.pets,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            card['tag']!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        card['title']!,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          height: 1.12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        card['subtitle']!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        // Carousel Dots Indicator
                        Positioned(
                          top: 16,
                          right: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_carouselCards.length, (index) {
                                final isSelected = index == _currentCarouselIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: isSelected ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.green : Colors.white.withValues(alpha: .5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Animated Switcher between Landing View & Login Credentials Form
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 350),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    crossFadeState: _showLoginForm ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    // View 1: Initial Landing - Only Login & Sign Up buttons visible
                    firstChild: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome to Pet Tracker',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Keep your pets safe and sound with real-time location monitoring and boundary alerts.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() => _showLoginForm = true);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.login),
                              label: const Text(
                                'Login',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => Get.toNamed(Routes.register),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: const BorderSide(color: AppTheme.green, width: 1.5),
                              ),
                              icon: const Icon(Icons.person_add_outlined, color: AppTheme.green),
                              label: const Text(
                                'Sign Up',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // View 2: Login Form - Email & Password credentials
                    secondChild: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  tooltip: 'Back',
                                  onPressed: () {
                                    setState(() => _showLoginForm = false);
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Login to Account',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'Enter your credentials to continue',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
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
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                                  ? const SizedBox(height: 14)
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Obx(
                                    () => FilledButton(
                                      onPressed: c.loading.value
                                          ? null
                                          : () => c.login(
                                                email.text,
                                                password.text,
                                              ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.green,
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Get.toNamed(Routes.register),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => c.forgotPassword(email.text),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
