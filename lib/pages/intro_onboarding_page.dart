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

  void _goNextPage() {
    if (_page >= _pageCount - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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
                      body: const _IntroAppOverviewCard(),
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE6E8EE),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _IntroOverviewItem(
                                  icon: Icons.auto_awesome_rounded,
                                  iconColor: Color(0xFF7C3AED),
                                  leadingImageAsset:
                                      'assets/images/robotchan.png',
                                  title:
                                      'Share journal with funny AI characters!',
                                  description:
                                      "You can't believe there is such a funny AI characters! Unlock them with your task coin!",
                                ),
                                SizedBox(height: 10),
                                _IntroOverviewItem(
                                  icon: Icons.lock_open_rounded,
                                  iconColor: Color(0xFF0F766E),
                                  title: 'Unlock more characters 🤩',
                                  description:
                                      'Unlock more characters to go through your life with!!',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
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
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Row(
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
                  ),
                  SizedBox(
                    width: 40,
                    child: _page < _pageCount - 1
                        ? IconButton(
                            onPressed: _goNextPage,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            tooltip: 'Next',
                          )
                        : null,
                  ),
                ],
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
        child: JournalAiCharacterAvatar(characterId: id, size: size),
      ),
    );
  }
}

class _IntroAppOverviewCard extends StatelessWidget {
  const _IntroAppOverviewCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This app helps you',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Plan tasks, stay consistent, and reflect with AI.',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          const _IntroOverviewItem(
            icon: Icons.task_alt_rounded,
            iconColor: Color(0xFF2563EB),
            title: 'Manage Tasks & Earn task coins 📝',
            description: 'Earn task coins whenever you finish your tasks.',
          ),
          const SizedBox(height: 10),
          const _IntroOverviewItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: Color(0xFFEA580C),
            title: 'Build habit with fun!🔥',
            description: 'As you keep going through more, you will earn more⛳️',
          ),
        ],
      ),
    );
  }
}

class _IntroOverviewItem extends StatelessWidget {
  const _IntroOverviewItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.leadingImageAsset,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? leadingImageAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: leadingImageAsset != null
              ? ClipOval(
                  child: Image.asset(
                    leadingImageAsset!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
        if (footer != null) ...[const SizedBox(height: 32), footer!],
      ],
    );
  }
}
