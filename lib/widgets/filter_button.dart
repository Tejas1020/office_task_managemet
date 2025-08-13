import 'package:flutter/material.dart';
import 'package:office_task_managemet/utils/colors.dart';

class FilterButton extends StatelessWidget {
  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  const FilterButton({Key? key, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.gray200.withOpacity(0.6),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.work, size: 20, color: AppColors.gray700),
          ),
        ),
      ),
    );
  }
}
