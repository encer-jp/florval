import 'package:freezed_annotation/freezed_annotation.dart';

import 'category.dart';
import 'tag.dart';

part 'pet.freezed.dart';
part 'pet.g.dart';

@freezed
abstract class Pet with _$Pet {
  const factory Pet({
    int? id,
    required String name,
    Category? category,
    required List<String> photoUrls,
    List<Tag>? tags,
    String? status,
  }) = _Pet;

  factory Pet.fromJson(Map<String, dynamic> json) => _$PetFromJson(json);
}
