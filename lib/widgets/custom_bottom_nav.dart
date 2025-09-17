import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedNavigationBar(
      index: currentIndex.clamp(0, 3), // Ensure index is always valid
      height: 60.0,
      items: const <Widget>[
        Icon(Icons.home_outlined, size: 30, color: Colors.white),
        Icon(Icons.add_circle_outline, size: 30, color: Colors.white),
        Icon(Icons.message_outlined, size: 30, color: Colors.white),
        Icon(Icons.person_outline, size: 30, color: Colors.white),
      ],
      color: Theme.of(context).primaryColor,
      buttonBackgroundColor: Theme.of(context).primaryColor,
      backgroundColor: Colors.transparent,
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 150), // Even faster animation
      onTap: onTap, // Remove debouncing - pass tap directly
    );
  }
}

class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.label,
  });
}

class MaterialBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const MaterialBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<BottomNavItem> _items = [
    BottomNavItem(icon: Icons.home_outlined, label: 'Home'),
    BottomNavItem(icon: Icons.add_circle_outline, label: 'Add Item'),
    BottomNavItem(icon: Icons.message_outlined, label: 'Messages'),
    BottomNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      items: _items.map((item) => BottomNavigationBarItem(
        icon: Icon(item.icon),
        label: item.label,
      )).toList(),
    );
  }
}
