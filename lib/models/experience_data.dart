import 'package:hive/hive.dart';
part 'experience_data.g.dart';

@HiveType(typeId: 10) // Use the typeId from main.dart
class ExperienceData extends HiveObject {
  @HiveField(0)
  String company;
  @HiveField(1)
  String title;
  @HiveField(2)
  String dates;
  @HiveField(3)
  String responsibilities;

  ExperienceData({
    required this.company,
    required this.title,
    required this.dates,
    required this.responsibilities,
  });
}
