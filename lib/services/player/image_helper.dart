import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider? getProfileImage(String? data) {
  if (data == null || data.isEmpty) return null;

  if (data.startsWith('http')) {
    return NetworkImage(data);
  }

  if (data.startsWith('data:image')) {
    try {
      final base64Data = data.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    } catch (_) {}
  }

  if (data.startsWith('/9j') || data.length > 1000) {
    try {
      return MemoryImage(base64Decode(data));
    } catch (_) {}
  }

  return null;
}
