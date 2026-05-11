import 'dart:convert';

/// Placeholder User model for local auth. When you connect Firebase or Supabase,
/// replace usages of this User with the provider-specific user model.
class User {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? city;
  final String? photoUrl;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.city,
    this.photoUrl,
    this.isAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  User copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    String? city,
    String? photoUrl,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => User(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        displayName: displayName ?? this.displayName,
        city: city ?? this.city,
        photoUrl: photoUrl ?? this.photoUrl,
        isAdmin: isAdmin ?? this.isAdmin,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'city': city,
        'photoUrl': photoUrl,
        'isAdmin': isAdmin,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        uid: json['uid'] as String,
        email: json['email'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        displayName: json['displayName'] as String?,
        city: json['city'] as String?,
        photoUrl: json['photoUrl'] as String?,
        isAdmin: (json['isAdmin'] as bool?) ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  // Stubs to satisfy AuthManager interface when using local auth
  Future<void> sendEmailVerification() async {}
  Future<void> refreshUser() async {}

  @override
  String toString() => jsonEncode(toJson());
}
