import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_service.dart';
import 'library_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _completeOnboarding() {
    ref.read(settingsServiceProvider.notifier).setOnboardingComplete();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSplashPage(),
            _buildSlidePage(
              icon: Icons.auto_stories,
              gradientColors: const [Color(0xFFE91E63), Color(0xFFFF5252)],
              title: 'Открой мир историй',
              subtitle:
                  'Сотни интерактивных новелл — романтика, фэнтези, мистика и драма',
              dotIndex: 0,
              onNext: () => _goToPage(2),
            ),
            _buildSlidePage(
              icon: Icons.alt_route,
              gradientColors: const [Color(0xFF9C27B0), Color(0xFFCE93D8)],
              title: 'Влияй на сюжет',
              subtitle:
                  'Каждый выбор меняет историю. Твои решения определяют финал',
              dotIndex: 1,
              onNext: () => _goToPage(3),
            ),
            _buildSlidePage(
              icon: Icons.favorite,
              gradientColors: const [Color(0xFFE91E63), Color(0xFFFF5252)],
              title: 'Открой романтику',
              subtitle:
                  'Встречай незабываемых персонажей и переживай невероятные истории',
              dotIndex: 2,
              onNext: _completeOnboarding,
              buttonText: 'Начать приключение 💕',
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Splash / Welcome ──────────────────────────────────────────

  Widget _buildSplashPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Gradient "Amoria" text
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
          ).createShader(bounds),
          child: const Text(
            'Amoria',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Heart icon with glow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite,
            color: Color(0xFFE91E63),
            size: 40,
          ),
        ),
        const Spacer(),
        _gradientButton('Начать', () => _goToPage(1)),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── Slides 2-4 ────────────────────────────────────────────────────────

  Widget _buildSlidePage({
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required int dotIndex,
    required VoidCallback onNext,
    String buttonText = 'Далее →',
  }) {
    return Column(
      children: [
        // Skip button
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Пропустить',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        ),
        // Top 60% — icon composition
        Expanded(
          flex: 6,
          child: Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 120, color: Colors.white),
            ),
          ),
        ),
        // Bottom 40% — text, dots, button
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildDots(dotIndex),
                const Spacer(),
                _gradientButton(buttonText, onNext),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Dot indicators ────────────────────────────────────────────────────

  Widget _buildDots(int activePage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == activePage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color:
                i == activePage ? const Color(0xFFE91E63) : Colors.white24,
          ),
        ),
      ),
    );
  }

  // ── Gradient button ───────────────────────────────────────────────────

  Widget _gradientButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
