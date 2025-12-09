import 'package:hive/hive.dart';
import 'contact_info_data.dart';
import 'education_data.dart';
import 'experience_data.dart';
import 'certificate_data.dart';

part 'resume_data.g.dart';

@HiveType(typeId: 12)
class ResumeData extends HiveObject {
  @HiveField(0)
  ContactInfoData contactInfo;

  @HiveField(1)
  List<String> skills;

  @HiveField(2)
  List<EducationData> education;

  @HiveField(3)
  List<ExperienceData> experience;

  @HiveField(4)
  List<CertificateData> certificates;

  ResumeData({
    required this.contactInfo,
    required this.skills,
    required this.education,
    required this.experience,
    required this.certificates,
  });
}
