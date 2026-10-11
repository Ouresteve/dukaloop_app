import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../products/products_screen.dart';
import '../sales/sales_screen.dart';
import '../more/more_screen.dart';
import '../pos/pos_screen.dart';
import '../pos/pos_screen_desktop.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Products'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Sales'),
    _NavItem(icon: Icons.people_alt_rounded, label: 'Customers'),
    _NavItem(icon: Icons.more_horiz_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ===================== DESKTOP LAYOUT =====================
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Logo / Brand
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DukaLoop',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Shop Manager',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(color: AppColors.border, height: 1),

                const SizedBox(height: 16),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildDesktopNavItem(0, Icons.home_rounded, 'Dashboard'),
                      _buildDesktopNavItem(1, Icons.inventory_2_rounded, 'Products'),
                      _buildDesktopNavItem(2, Icons.receipt_long_rounded, 'Sales'),
                      _buildDesktopNavItem(3, Icons.people_alt_rounded, 'Customers'),
                      _buildDesktopNavItem(4, Icons.bar_chart_rounded, 'Analytics'),
                      _buildDesktopNavItem(5, Icons.settings_rounded, 'Settings'),
                    ],
                  ),
                ),

                // Sell Button (Desktop)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                     onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PosScreenDesktop()),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 22),
                      label: const Text(
                        'New Sale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _buildPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== MOBILE LAYOUT =====================
  Widget _buildMobileLayout() {
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: _NotchedBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            // Center button → POS
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PosScreen()),
            );
          } else {
            setState(() => _currentIndex = index > 2 ? index - 1 : index);
          }
        },
      ),
    );
  }

  Widget _buildPage() {
    // Map index correctly for both layouts
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ProductsScreen();
      case 2:
        return const SalesScreen();
      case 3:
        return const MoreScreen(); // Temporary - will become Customers
      case 4:
        return const MoreScreen();
      case 5:
        return const MoreScreen();
      default:
        return const HomeScreen();
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ===================== NOTCHED BOTTOM BAR =====================
class _NotchedBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NotchedBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Background with notch
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 90),
            painter: _NotchPainter(),
          ),

          // Navigation items
          SizedBox(
            height: 70,
            child: Row(
              children: [
                _buildItem(0, Icons.home_rounded, 'Home'),
                _buildItem(1, Icons.inventory_2_rounded, 'Products'),
                const SizedBox(width: 80), // Center space
                _buildItem(3, Icons.receipt_long_rounded, 'Sales'),
                _buildItem(4, Icons.menu_rounded, 'More'),
              ],
            ),
          ),

          // Floating Center Button
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF9A3C),
                      AppColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == (index > 2 ? index - 1 : index);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;

    final path = Path();

    final centerX = size.width / 2;
    const notchRadius = 42.0;
    const topOffset = 22.0;

    path.moveTo(0, topOffset);

    // Left side
    path.lineTo(centerX - notchRadius - 16, topOffset);

    // Left curve into notch
    path.quadraticBezierTo(
      centerX - notchRadius - 4,
      topOffset,
      centerX - notchRadius + 4,
      topOffset + 12,
    );

    // Arc under the button
    path.arcToPoint(
      Offset(centerX + notchRadius - 4, topOffset + 12),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // Right curve out of notch
    path.quadraticBezierTo(
      centerX + notchRadius + 4,
      topOffset,
      centerX + notchRadius + 16,
      topOffset,
    );

    // Right side
    path.lineTo(size.width, topOffset);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Soft shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.35), 12, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}