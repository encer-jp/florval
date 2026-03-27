import 'package:recase/recase.dart';

import '../model/api_type.dart';

/// Adds model import entries for a [FlorvalType] to [imports].
///
/// Resolves `$ref` names to snake_case file names and recurses into list item types.
void addTypeImport(Set<String> imports, FlorvalType type) {
  if (type.ref != null) {
    final refName = type.ref!.split('/').last;
    imports.add(ReCase(refName).snakeCase);
  }
  if (type.isList && type.itemType != null) {
    addTypeImport(imports, type.itemType!);
  }
}
