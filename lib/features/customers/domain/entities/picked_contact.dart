import 'package:equatable/equatable.dart';

class PickedContact extends Equatable {
  const PickedContact({required this.name, required this.phone});

  final String? name;
  final String? phone;

  @override
  List<Object?> get props => [name, phone];
}
