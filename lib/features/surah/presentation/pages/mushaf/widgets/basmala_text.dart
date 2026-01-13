import 'package:flutter/material.dart';

class BasmalaText extends TextSpan {
  BasmalaText({
    required double fontSize,
    required double lineHeight,
    required Color color,
  }) : super(
         text: "\u0021\u0022\u0023\n",
         style: TextStyle(
           fontFamily: "QCF_P000",
           fontSize: fontSize,
           color: color,
         ),
       );
}
