class AppUser {
  String email;
  String? token;

  AppUser({required this.email, this.token});

  Map<String, dynamic> toJson() => {
    'email': email,
    'token': token,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    email: json['email'],
    token: json['token'],
  );
}