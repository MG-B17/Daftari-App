import 'package:equatable/equatable.dart';

final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.shopName,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String? shopName;
  final bool emailVerified;

  @override
  List<Object?> get props => [id, email, shopName, emailVerified];
}
