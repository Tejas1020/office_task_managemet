// lib/src/widgets/app_shell.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:office_task_managemet/utils/colors.dart';
import 'package:office_task_managemet/widgets/app_drawer.dart';

class CreateTaskButton extends StatelessWidget {
  final Widget child;
  const CreateTaskButton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(), // optional
      body: SafeArea(child: child),
      floatingActionButton: FloatingActionButton(
        onPressed: () => GoRouter.of(context).go('/create-task'),
        backgroundColor: AppColors.gray900,
        child: const Icon(Icons.add, size: 28, color: AppColors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
