import 'package:hive/hive.dart';
part 'education_data.g.dart';

@HiveType(typeId: 9) // Use the typeId from main.dart
class EducationData extends HiveObject {
  @HiveField(0)
  String school;
  @HiveField(1)
  String degree;
  @HiveField(2)
  String gradDate;

  EducationData({
    required this.school,
    required this.degree,
    required this.gradDate,
  });
}
