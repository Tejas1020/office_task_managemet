// lib/src/widgets/date_display.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:office_task_managemet/utils/colors.dart';

class DateDisplay extends StatelessWidget {
  const DateDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final formatted = DateFormat(
      'MMMM d, yyyy',
    ).format(today); // e.g. “June 20, 2022”

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.gray600),
        const SizedBox(width: 4),
        Text(
          formatted,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.gray600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
