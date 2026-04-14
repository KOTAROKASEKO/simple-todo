import 'package:flutter/material.dart';
import 'package:simpletodo/journal_ai_character_assets.dart';
import 'package:simpletodo/widgets/email_password_auth_card.dart';
import 'package:simpletodo/widgets/journal_ai_character_avatar.dart';

/// Logged-out experience: horizontal slides ending in email sign-in / register.
class IntroOnboardingPage extends StatefulWidget {
  const IntroOnboardingPage({super.key});

  @override
  State<IntroOnboardingPage> createState() => _IntroOnboardingPageState();
}

class _IntroOnboardingPageState extends State<IntroOnboardingPage> {
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _IntroSlide(
                      body: Text(
                        'Boost your productivity. Your smart todo manager will '
                        'help you develop a habit.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF161616),
                        ),
                      ),
                      footer: Text(
                        'Swipe right →',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    _IntroSlide(
                      body: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Share your journal with your funny AI character.',
                            textAlign: TextAlign.center,
                            style: textTheme.titleLarge?.copyWith(
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF161616),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const _IntroJournalCharacterAvatars(),
                        ],
                      ),
                      footer: Text(
                        'Swipe right →',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign in or create an account',
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF161616),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Swipe left anytime to review the intro.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const EmailPasswordAuthCard(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF111111)
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroJournalCharacterAvatars extends StatelessWidget {
  const _IntroJournalCharacterAvatars();

  static const double _avatarSize = 64;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < kJournalAiCharacterIds.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _IntroCharacterAvatar(
              id: kJournalAiCharacterIds[i],
              size: _avatarSize,
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroCharacterAvatar extends StatelessWidget {
  const _IntroCharacterAvatar({required this.id, required this.size});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E6EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: JournalAiCharacterAvatar(
          characterId: id,
          size: size,
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({required this.body, this.footer});

  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        body,
        if (footer != null) ...[
          const SizedBox(height: 32),
          footer!,
        ],
      ],
    );
  }
}
