import 'package:hive/hive.dart';
part 'certificate_data.g.dart';

@HiveType(typeId: 11) // Use the typeId from main.dart
class CertificateData extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String organization;
  @HiveField(2)
  String date;

  CertificateData({
    required this.name,
    required this.organization,
    required this.date,
  });
}
