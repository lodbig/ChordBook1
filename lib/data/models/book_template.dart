import 'package:flutter/painting.dart';
import 'package:hive/hive.dart';

part 'book_template.g.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum PageSize { a4, a5, letter }

enum Orientation { portrait, landscape }

enum PageNumberPosition { topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight }

enum LogoPosition { topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight }

enum TocPosition { beforeContent, afterContent }

enum IndexPosition { beforeContent, afterContent }

// ─── IndexOptions (typeId: 4) ─────────────────────────────────────────────────

@HiveType(typeId: 4)
class IndexOptions {
  @HiveField(0)
  final bool includeAlphaIndex;

  @HiveField(1)
  final bool includeArtistIndex;

  @HiveField(2)
  final bool includeTagIndex;

  @HiveField(3)
  final String alphaIndexTitle;

  @HiveField(4)
  final String artistIndexTitle;

  @HiveField(5)
  final String tagIndexTitle;

  @HiveField(6)
  final List<String>? tagsToInclude;

  @HiveField(7)
  final int indexPositionIndex; // IndexPosition enum index

  @HiveField(8)
  final bool showPageNumbers;

  IndexOptions({
    this.includeAlphaIndex = false,
    this.includeArtistIndex = false,
    this.includeTagIndex = false,
    this.alphaIndexTitle = 'אינדקס א-ב',
    this.artistIndexTitle = 'אינדקס אמנים',
    this.tagIndexTitle = 'אינדקס תגיות',
    this.tagsToInclude,
    IndexPosition indexPosition = IndexPosition.afterContent,
    this.showPageNumbers = true,
  }) : indexPositionIndex = indexPosition.index;

  IndexPosition get indexPosition => IndexPosition.values[indexPositionIndex];

  IndexOptions copyWith({
    bool? includeAlphaIndex,
    bool? includeArtistIndex,
    bool? includeTagIndex,
    String? alphaIndexTitle,
    String? artistIndexTitle,
    String? tagIndexTitle,
    List<String>? tagsToInclude,
    IndexPosition? indexPosition,
    bool? showPageNumbers,
  }) {
    return IndexOptions(
      includeAlphaIndex: includeAlphaIndex ?? this.includeAlphaIndex,
      includeArtistIndex: includeArtistIndex ?? this.includeArtistIndex,
      includeTagIndex: includeTagIndex ?? this.includeTagIndex,
      alphaIndexTitle: alphaIndexTitle ?? this.alphaIndexTitle,
      artistIndexTitle: artistIndexTitle ?? this.artistIndexTitle,
      tagIndexTitle: tagIndexTitle ?? this.tagIndexTitle,
      tagsToInclude: tagsToInclude ?? this.tagsToInclude,
      indexPosition: indexPosition ?? this.indexPosition,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
    );
  }
}

// ─── BookSection base (typeId: 5) ────────────────────────────────────────────

@HiveType(typeId: 5)
class BookSection {
  @HiveField(0)
  final String sectionType; // 'divider' | 'song'

  const BookSection({required this.sectionType});
}

// ─── SectionDivider (typeId: 6) ──────────────────────────────────────────────

@HiveType(typeId: 6)
class SectionDivider extends BookSection {
  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? subtitle;

  @HiveField(3)
  final String? backgroundImagePath;

  @HiveField(4)
  final bool fullPage;

  const SectionDivider({
    required this.title,
    this.subtitle,
    this.backgroundImagePath,
    this.fullPage = false,
  }) : super(sectionType: 'divider');

  SectionDivider copyWith({
    String? title,
    String? subtitle,
    String? backgroundImagePath,
    bool? fullPage,
  }) {
    return SectionDivider(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
      fullPage: fullPage ?? this.fullPage,
    );
  }
}

// ─── SongEntry (typeId: 7) ───────────────────────────────────────────────────

@HiveType(typeId: 7)
class SongEntry extends BookSection {
  @HiveField(1)
  final String songId;

  @HiveField(2)
  final String? versionOverride;

  @HiveField(3)
  final int? transposeOverride;

  @HiveField(4)
  final bool forceNewPage;

  @HiveField(5)
  final bool? twoColumnsOverride;

  const SongEntry({
    required this.songId,
    this.versionOverride,
    this.transposeOverride,
    this.forceNewPage = false,
    this.twoColumnsOverride,
  }) : super(sectionType: 'song');

  SongEntry copyWith({
    String? songId,
    String? versionOverride,
    int? transposeOverride,
    bool? forceNewPage,
    bool? twoColumnsOverride,
  }) {
    return SongEntry(
      songId: songId ?? this.songId,
      versionOverride: versionOverride ?? this.versionOverride,
      transposeOverride: transposeOverride ?? this.transposeOverride,
      forceNewPage: forceNewPage ?? this.forceNewPage,
      twoColumnsOverride: twoColumnsOverride ?? this.twoColumnsOverride,
    );
  }
}

// ─── BookTemplate (typeId: 8) ─────────────────────────────────────────────────

@HiveType(typeId: 8)
class BookTemplate {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int pageSizeIndex; // PageSize enum index

  @HiveField(3)
  late int orientationIndex; // Orientation enum index

  // Margins stored as [left, top, right, bottom] in points
  @HiveField(4)
  late List<double> marginsLTRB;

  @HiveField(5)
  late String fontFamily;

  @HiveField(6)
  late double fontSize;

  @HiveField(7)
  late double chordFontSize;

  @HiveField(8)
  late String headerText;

  @HiveField(9)
  late String footerText;

  @HiveField(10)
  late bool showPageNumbers;

  @HiveField(11)
  late int pageNumberPositionIndex;

  @HiveField(12)
  String? logoPath;

  @HiveField(13)
  late int logoPositionIndex;

  @HiveField(14)
  late double logoSize;

  @HiveField(15)
  late bool hasCoverPage;

  @HiveField(16)
  late String coverTitle;

  @HiveField(17)
  late String coverSubtitle;

  @HiveField(18)
  String? coverImagePath;

  @HiveField(19)
  late bool hasIntroPage;

  @HiveField(20)
  late String introText;

  @HiveField(21)
  late bool hasTOC;

  @HiveField(22)
  late int tocPositionIndex;

  @HiveField(23)
  late String tocTitle;

  @HiveField(24)
  late IndexOptions indexOptions;

  @HiveField(25)
  late List<BookSection> sections;

  @HiveField(26)
  late bool allowTwoColumns;

  @HiveField(27)
  late int twoColumnThreshold;

  @HiveField(28)
  late double columnGap;

  @HiveField(29)
  late bool blankPagesAfterSections;

  @HiveField(30)
  late int blankPagesCount;

  @HiveField(31)
  late String blankPageLabel;

  @HiveField(32)
  late String versionToExport;

  @HiveField(33)
  late int exportTransposeSteps;

  BookTemplate({
    required this.id,
    required this.name,
    PageSize pageSize = PageSize.a4,
    Orientation orientation = Orientation.portrait,
    EdgeInsets? margins,
    this.fontFamily = 'Rubik',
    this.fontSize = 14.0,
    this.chordFontSize = 12.0,
    this.headerText = '',
    this.footerText = '',
    this.showPageNumbers = true,
    PageNumberPosition pageNumberPosition = PageNumberPosition.bottomCenter,
    this.logoPath,
    LogoPosition logoPosition = LogoPosition.topRight,
    this.logoSize = 40.0,
    this.hasCoverPage = false,
    this.coverTitle = '',
    this.coverSubtitle = '',
    this.coverImagePath,
    this.hasIntroPage = false,
    this.introText = '',
    this.hasTOC = false,
    TocPosition tocPosition = TocPosition.beforeContent,
    this.tocTitle = 'תוכן עניינים',
    IndexOptions? indexOptions,
    List<BookSection>? sections,
    this.allowTwoColumns = false,
    this.twoColumnThreshold = 50,
    this.columnGap = 20.0,
    this.blankPagesAfterSections = false,
    this.blankPagesCount = 1,
    this.blankPageLabel = '',
    this.versionToExport = 'רגיל',
    this.exportTransposeSteps = 0,
  })  : pageSizeIndex = pageSize.index,
        orientationIndex = orientation.index,
        marginsLTRB = [
          margins?.left ?? 56.7,
          margins?.top ?? 56.7,
          margins?.right ?? 56.7,
          margins?.bottom ?? 56.7,
        ],
        pageNumberPositionIndex = pageNumberPosition.index,
        logoPositionIndex = logoPosition.index,
        tocPositionIndex = tocPosition.index,
        indexOptions = indexOptions ?? IndexOptions(),
        sections = sections ?? [];

  PageSize get pageSize => PageSize.values[pageSizeIndex];
  Orientation get orientation => Orientation.values[orientationIndex];
  EdgeInsets get margins => EdgeInsets.fromLTRB(
        marginsLTRB[0],
        marginsLTRB[1],
        marginsLTRB[2],
        marginsLTRB[3],
      );
  PageNumberPosition get pageNumberPosition =>
      PageNumberPosition.values[pageNumberPositionIndex];
  LogoPosition get logoPosition => LogoPosition.values[logoPositionIndex];
  TocPosition get tocPosition => TocPosition.values[tocPositionIndex];
}
