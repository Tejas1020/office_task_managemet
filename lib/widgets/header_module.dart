import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/widgets/filter_button.dart';

class HeaderModule extends StatelessWidget {
  final String userName;
  final Color bgcolor;
  final VoidCallback onMenuTap;

  const HeaderModule({
    Key? key,
    required this.userName,
    required this.bgcolor,
    required this.onMenuTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: BottomWaveClipper(),
      child: Container(        
        height: MediaQuery.of(context).size.height * 0.27,
        padding: const EdgeInsets.only(
          top: 32,
          left: 24,
          right: 24,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: bgcolor,
          // borderRadius: BorderRadius.circular(35),
          image: const DecorationImage(
            image: AssetImage('assets/img/bg1.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            opacity: 0.18,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FilterButton(onPressed: onMenuTap),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Hey $userName!',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Let's be Productive!",
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A CustomClipper that draws two connected quadratic beziers
/// to form a wave at the bottom of the widget.
class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at top-left
    path.lineTo(0, size.height - 40);

    // First control point and end point
    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - 40);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Second control point and end point
    final secondControlPoint = Offset(size.width * 0.75, size.height - 80);
    final secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    // Finish at top-right
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
