import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

// Shows a Flushbar toast with message and icon
void showFlushBar(
  BuildContext context,
  //helps to send the notifcations toasts using the flushbar 
  String message, {
  IconData icon = Icons.info,
  Color? color,
}) {
  Flushbar(
    margin: const EdgeInsets.all(12),
    borderRadius: BorderRadius.circular(8),
    backgroundColor: color ?? Colors.black87,
    duration: const Duration(seconds: 3),
    icon: Icon(icon, color: Colors.white),
    messageText: Text(message, style: const TextStyle(color: Colors.white)),
  ).show(context);
}
