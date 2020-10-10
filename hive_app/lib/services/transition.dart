import 'package:flutter/material.dart';

class Transition {
  static PageRouteBuilder getFadeTransition(Widget w) {
    return new PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => w,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
