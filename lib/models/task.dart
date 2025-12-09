import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

part 'task.g.dart';

@HiveType(typeId: 1)
class Task extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String description;
  @HiveField(3)
  DateTime date;
  @HiveField(4)
  String source; // 'manual' or 'canvas'
  @HiveField(5)
  bool isCompleted;
  @HiveField(6)
  String notes; // <-- Add this field

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.source = 'manual',
    this.isCompleted = false,
    this.notes = '', // <-- Add this default
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'source': source,
        'isCompleted': isCompleted,
        'notes': notes, // <-- Add this
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    // --- START: SURGICAL FIX - Handle Firestore Timestamp type for 'date' field ---
    DateTime parsedDate;
    final dynamic dateData = json['date'];

    if (dateData is Timestamp) {
      parsedDate = dateData.toDate();
    } else if (dateData is String) {
      parsedDate = DateTime.parse(dateData);
    } else {
      // Fallback for corrupt or missing data
      parsedDate = DateTime.now();
      debugPrint('DEBUG (Task): Invalid date format received. Using current time.');
    }
    // --- END: SURGICAL FIX ---
    
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      date: parsedDate,
      source: json['source'] ?? 'manual',
      isCompleted: json['isCompleted'] ?? false,
      notes: json['notes'] ?? '',
    );
  }
}
