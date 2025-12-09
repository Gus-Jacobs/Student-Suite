import 'package:hive/hive.dart';
part 'contact_info_data.g.dart';

@HiveType(typeId: 8) // Use the typeId from main.dart
class ContactInfoData extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String email;
  @HiveField(2)
  String phone;
  @HiveField(3)
  String linkedin;
  @HiveField(4)
  String github;
  @HiveField(5)
  String portfolio;

  ContactInfoData({
    required this.name,
    required this.email,
    required this.phone,
    required this.linkedin,
    required this.github,
    required this.portfolio,
  });
}
