import 'package:uuid/uuid.dart';

import '../database/database_manager.dart';
import '../models/book_template.dart';

class BookTemplateRepository {
  static const _boxName = 'book_templates';

  Future<List<BookTemplate>> getAll() async {
    final box = await DatabaseManager.openBox<BookTemplate>(_boxName);
    return box.values.toList();
  }

  Future<BookTemplate?> getById(String id) async {
    final box = await DatabaseManager.openBox<BookTemplate>(_boxName);
    return box.get(id);
  }

  Future<void> save(BookTemplate template) async {
    final box = await DatabaseManager.openBox<BookTemplate>(_boxName);
    await box.put(template.id, template);
  }

  Future<void> delete(String id) async {
    final box = await DatabaseManager.openBox<BookTemplate>(_boxName);
    await box.delete(id);
  }

  /// Duplicate a template with a new ID and a modified name.
  Future<BookTemplate?> duplicate(String id) async {
    final box = await DatabaseManager.openBox<BookTemplate>(_boxName);
    final original = box.get(id);
    if (original == null) return null;

    final copy = BookTemplate(
      id: const Uuid().v4(),
      name: '${original.name} (עותק)',
      pageSize: original.pageSize,
      orientation: original.orientation,
      margins: original.margins,
      fontFamily: original.fontFamily,
      fontSize: original.fontSize,
      chordFontSize: original.chordFontSize,
      headerText: original.headerText,
      footerText: original.footerText,
      showPageNumbers: original.showPageNumbers,
      pageNumberPosition: original.pageNumberPosition,
      logoPath: original.logoPath,
      logoPosition: original.logoPosition,
      logoSize: original.logoSize,
      hasCoverPage: original.hasCoverPage,
      coverTitle: original.coverTitle,
      coverSubtitle: original.coverSubtitle,
      coverImagePath: original.coverImagePath,
      hasIntroPage: original.hasIntroPage,
      introText: original.introText,
      hasTOC: original.hasTOC,
      tocPosition: original.tocPosition,
      tocTitle: original.tocTitle,
      indexOptions: original.indexOptions,
      sections: List.from(original.sections),
      allowTwoColumns: original.allowTwoColumns,
      twoColumnThreshold: original.twoColumnThreshold,
      columnGap: original.columnGap,
      blankPagesAfterSections: original.blankPagesAfterSections,
      blankPagesCount: original.blankPagesCount,
      blankPageLabel: original.blankPageLabel,
      versionToExport: original.versionToExport,
      exportTransposeSteps: original.exportTransposeSteps,
    );

    await box.put(copy.id, copy);
    return copy;
  }
}
