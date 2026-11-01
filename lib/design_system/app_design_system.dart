import 'package:flutter/material.dart';

/// Centralized Design System for Mbois Gym
/// Matching 70% Figma Mockups (logo.png, Login.png, Sign Up.png, Home Profile.png, page add client, PROFIL.png)
/// + 30% Functional UI/UX Improvisations (Responsiveness, State Feedback, CRUD Controls)

class AppColors {
  // Brand Primary & Accents from Figma
  static const Color primaryRoyalBlue = Color(
    0xFF0002C1,
  ); // Login & Sign Up Title & Action Buttons
  static const Color vibrantBlue = Color(
    0xFF0088FF,
  ); // Home "Client" pill button & active chips
  static const Color cyanAccent = Color(
    0xFF00C0E8,
  ); // Profile Floating Summary Card & Update Button
  static const Color skyBlueSoft = Color(0xFFD4ECFF); // Bottom Nav active badge
  static const Color navyBrand = Color(0xFF001F54); // Mbois Gym logo navy
  static const Color badgeYellowLime = Color(
    0xFFA3E635,
  ); // Profile avatar edit pencil badge

  // Dark & Neutral Colors from Figma
  static const Color darkCharcoal = Color(
    0xFF212322,
  ); // Login/Sign Up & Add Client Input Boxes
  static const Color darkSlate = Color(0xFF1A1D1E); // + Tambah Client button
  static const Color cardMetallicStart = Color(
    0xFF262C31,
  ); // Client Card metallic gradient
  static const Color cardMetallicEnd = Color(0xFF192126);
  static const Color textBlack = Color(0xFF111827);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF919191);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color inputLightFill = Color(
    0xFFF1F5F9,
  ); // Profile screen inputs

  // Functional & Analytics Accents (Preserved from Proven Implementation)
  static const Color mboisTeal = Color(0xFF0F8780);
  static const Color mboisMint = Color(0xFFE0F4F0);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);
}

class AppTypography {
  static const TextStyle welcomeTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
    color: AppColors.primaryRoyalBlue,
    height: 1.15,
  );

  static const TextStyle screenHeader = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textBlack,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textBlack,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

class AppRadius {
  static final BorderRadius small = BorderRadius.circular(8.0);
  static final BorderRadius medium = BorderRadius.circular(12.0);
  static final BorderRadius large = BorderRadius.circular(16.0);
  static final BorderRadius pill = BorderRadius.circular(30.0);
}

class AppAssets {
  static const String logo = 'assets/images/mbois_logo.png';
  static const String logoClean = 'assets/images/mbois_logo_clean.png';
  static const String logoFigma = 'assets/images/mbois_logo_figma.png';
  static const String coachAvatar = 'assets/images/coach_avatar_figma.png';
  static const String defaultAvatar = 'assets/images/default_avatar.png';
}

/// Reusable Pill Action Button (as in Login, Sign Up, Profile Update)
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor = AppColors.primaryRoyalBlue,
    this.textColor = Colors.white,
    this.isLoading = false,
    this.height = 48.0,
    this.hasGlow = true,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final bool isLoading;
  final double height;
  final bool hasGlow;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        boxShadow: hasGlow && onPressed != null
            ? [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(
                    text,
                    style: AppTypography.buttonText.copyWith(color: textColor),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Reusable Full-Width Dark Button (e.g. "+ TAMBAH CLIENT BARU")
class AppDarkButton extends StatelessWidget {
  const AppDarkButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon = Icons.add,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkSlate,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        elevation: 1,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Reusable High-Contrast Form Field Matching Figma Dark-Box & Light-Pill Styles
class AppCustomTextField extends StatelessWidget {
  const AppCustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.isDarkFill = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final bool isDarkFill;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final fill = isDarkFill
        ? AppColors.darkCharcoal
        : (isDarkTheme ? const Color(0xFF262C30) : AppColors.inputLightFill);
    final textColor = isDarkFill || isDarkTheme
        ? Colors.white
        : AppColors.textBlack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.fieldLabel.copyWith(
            color: isDarkTheme ? Colors.white70 : AppColors.textBlack,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDarkFill ? Colors.white38 : AppColors.textMuted,
              fontSize: 13,
            ),
            filled: true,
            fillColor: fill,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: const BorderSide(
                color: AppColors.vibrantBlue,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.medium,
              borderSide: const BorderSide(color: AppColors.dangerRed),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable Client Card in Home Matching Figma Metallic Design
class AppClientCard extends StatelessWidget {
  const AppClientCard({
    super.key,
    required this.name,
    required this.sessionsRemaining,
    required this.totalSessions,
    required this.onTapDetail,
    this.avatarUrl,
  });

  final String name;
  final int sessionsRemaining;
  final int totalSessions;
  final VoidCallback onTapDetail;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.large,
        gradient: const LinearGradient(
          colors: [AppColors.cardMetallicStart, AppColors.cardMetallicEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: onTapDetail,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Circular avatar with red or vibrant background
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Client details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(Sisa $sessionsRemaining Sesi dari $totalSessions)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pill "Client" button in bottom right of card
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vibrantBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: const Size(64, 32),
                    elevation: 0,
                  ),
                  onPressed: onTapDetail,
                  child: const Text(
                    'Client',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Bottom Navigation Bar Matching Figma 3-Tab Architecture
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF192126) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
              ),
              _buildNavItem(
                index: 1,
                label: 'client',
                icon: Icons.badge_outlined,
                activeIcon: Icons.badge,
              ),
              _buildNavItem(
                index: 2,
                label: 'Profil',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.skyBlueSoft : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.textBlack : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.textBlack : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
