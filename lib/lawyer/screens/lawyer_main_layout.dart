import 'package:flutter/material.dart';
// استيراد الشاشات الحقيقية المرتبطة بالفايربيز
import 'package:mezaan/lawyer/screens/lawyer_dashboard_screen.dart';
import 'package:mezaan/lawyer/screens/lawyer_calendar_schedule_screen.dart'; 
import 'package:mezaan/lawyer/widgets/lawyer_bottom_nav_bar.dart'; // استيراد الناف بار الخاص بك

class LawyerMainLayout extends StatefulWidget {
  const LawyerMainLayout({super.key});

  @override
  State<LawyerMainLayout> createState() => _LawyerMainLayoutState();
}

class _LawyerMainLayoutState extends State<LawyerMainLayout> {
  // جعلنا الصفحة الافتراضية هي الـ Home (Index 3)
  int _selectedIndex = 3; 

  // القائمة التي تحتوي على الشاشات الفعلية
  final List<Widget> _screens = [
    const Center(child: Text('Rescue Screen')),    // Index 0
    const LawyerCalendarScheduleScreen(),         // Index 1: شاشة المواعيد الحقيقية
    const Center(child: Text('Cases Screen')),     // Index 2
    const LawyerDashboardScreen(),                // Index 3: شاشة الداشبورد الحقيقية
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // استخدام IndexedStack للحفاظ على حالة الشاشات عند التنقل
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      // استخدام الـ Custom NavBar الذي أرسلت كوده سابقاً
      bottomNavigationBar: LawyerBottomNavBar(
        currentIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        onOpenDrawer: () {
          // هنا يمكنك إضافة فتح الـ Drawer إذا كان لديك واحد
          Scaffold.of(context).openDrawer();
        },
      ),
    );
  }
}