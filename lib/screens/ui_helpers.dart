import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF00C896);
const kPrimaryDark = Color(0xFF00875A);
const kTextDark = Color(0xFF1B4332);
const kBackground = Color(0xFFF4F7F6);

BoxDecoration kCardDecoration({double radius = 18, Color? color}) {
  return BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

Widget kGradientHeader({
  required BuildContext context,
  required Widget child,
  double topPadding = 70,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + topPadding, 20, 30),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [kPrimaryColor, kPrimaryDark],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    ),
    child: child,
  );
}

InputDecoration kFieldDecoration(String label, IconData icon, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

InputDecoration kInputDecoration({
  required String label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon) : null,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}