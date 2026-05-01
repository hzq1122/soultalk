import 'dart:io';
import '../../models/contact.dart';
import '../import/import_service.dart';

class CharacterCardService {
  static Future<Contact?> fromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return fromJsonString(raw);
    } catch (e) {
      return null;
    }
  }

  static Contact? fromJsonString(String raw) {
    try {
      final validation = ImportService.validateCharacterCard(raw);
      if (!validation.isValid) return null;
      return ImportService.buildContactFromCard(validation.data!, raw);
    } catch (e) {
      return null;
    }
  }

  static ImportValidationResult validateAndParse(String raw) {
    return ImportService.validateCharacterCard(raw);
  }

  static bool isValidCardJson(String raw) {
    try {
      final validation = ImportService.validateCharacterCard(raw);
      return validation.isValid;
    } catch (_) {
      return false;
    }
  }
}
