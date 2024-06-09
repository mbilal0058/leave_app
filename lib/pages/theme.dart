import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color.fromARGB(255, 53, 187, 207),
    textTheme: GoogleFonts.poppinsTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 53, 187, 207),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      buttonColor: const Color.fromARGB(255, 53, 187, 207),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 53, 187, 207),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
        textStyle: const TextStyle(color: Colors.white),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: const Color.fromARGB(255, 53, 187, 207)),
        borderRadius: BorderRadius.circular(12.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: const Color.fromARGB(255, 43, 157, 174)),
        borderRadius: BorderRadius.circular(12.0),
      ),
      labelStyle: TextStyle(color: const Color.fromARGB(255, 43, 157, 174)),
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: const Color.fromARGB(255, 53, 187, 207),
      secondary: const Color(0xFF00BCD4),
      primaryContainer: const Color.fromARGB(255, 43, 157, 174),
      secondaryContainer: const Color(0xFF0097A7),
      surface: Colors.white,
      background: Colors.white,
      error: const Color(0xFFB00020),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
  );
}
