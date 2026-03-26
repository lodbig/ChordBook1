// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IndexOptionsAdapter extends TypeAdapter<IndexOptions> {
  @override
  final int typeId = 4;

  @override
  IndexOptions read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IndexOptions(
      includeAlphaIndex: fields[0] as bool,
      includeArtistIndex: fields[1] as bool,
      includeTagIndex: fields[2] as bool,
      alphaIndexTitle: fields[3] as String,
      artistIndexTitle: fields[4] as String,
      tagIndexTitle: fields[5] as String,
      tagsToInclude: (fields[6] as List?)?.cast<String>(),
      showPageNumbers: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, IndexOptions obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.includeAlphaIndex)
      ..writeByte(1)
      ..write(obj.includeArtistIndex)
      ..writeByte(2)
      ..write(obj.includeTagIndex)
      ..writeByte(3)
      ..write(obj.alphaIndexTitle)
      ..writeByte(4)
      ..write(obj.artistIndexTitle)
      ..writeByte(5)
      ..write(obj.tagIndexTitle)
      ..writeByte(6)
      ..write(obj.tagsToInclude)
      ..writeByte(7)
      ..write(obj.indexPositionIndex)
      ..writeByte(8)
      ..write(obj.showPageNumbers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexOptionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookSectionAdapter extends TypeAdapter<BookSection> {
  @override
  final int typeId = 5;

  @override
  BookSection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookSection(
      sectionType: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BookSection obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.sectionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookSectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SectionDividerAdapter extends TypeAdapter<SectionDivider> {
  @override
  final int typeId = 6;

  @override
  SectionDivider read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SectionDivider(
      title: fields[1] as String,
      subtitle: fields[2] as String?,
      backgroundImagePath: fields[3] as String?,
      fullPage: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SectionDivider obj) {
    writer
      ..writeByte(5)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subtitle)
      ..writeByte(3)
      ..write(obj.backgroundImagePath)
      ..writeByte(4)
      ..write(obj.fullPage)
      ..writeByte(0)
      ..write(obj.sectionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionDividerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SongEntryAdapter extends TypeAdapter<SongEntry> {
  @override
  final int typeId = 7;

  @override
  SongEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SongEntry(
      songId: fields[1] as String,
      versionOverride: fields[2] as String?,
      transposeOverride: fields[3] as int?,
      forceNewPage: fields[4] as bool,
      twoColumnsOverride: fields[5] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SongEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(1)
      ..write(obj.songId)
      ..writeByte(2)
      ..write(obj.versionOverride)
      ..writeByte(3)
      ..write(obj.transposeOverride)
      ..writeByte(4)
      ..write(obj.forceNewPage)
      ..writeByte(5)
      ..write(obj.twoColumnsOverride)
      ..writeByte(0)
      ..write(obj.sectionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BookTemplateAdapter extends TypeAdapter<BookTemplate> {
  @override
  final int typeId = 8;

  @override
  BookTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      fontFamily: fields[5] as String,
      fontSize: fields[6] as double,
      chordFontSize: fields[7] as double,
      headerText: fields[8] as String,
      footerText: fields[9] as String,
      showPageNumbers: fields[10] as bool,
      logoPath: fields[12] as String?,
      logoSize: fields[14] as double,
      hasCoverPage: fields[15] as bool,
      coverTitle: fields[16] as String,
      coverSubtitle: fields[17] as String,
      coverImagePath: fields[18] as String?,
      hasIntroPage: fields[19] as bool,
      introText: fields[20] as String,
      hasTOC: fields[21] as bool,
      tocTitle: fields[23] as String,
      indexOptions: fields[24] as IndexOptions?,
      sections: (fields[25] as List?)?.cast<BookSection>(),
      allowTwoColumns: fields[26] as bool,
      twoColumnThreshold: fields[27] as int,
      columnGap: fields[28] as double,
      blankPagesAfterSections: fields[29] as bool,
      blankPagesCount: fields[30] as int,
      blankPageLabel: fields[31] as String,
      versionToExport: fields[32] as String,
      exportTransposeSteps: fields[33] as int,
    )
      ..pageSizeIndex = fields[2] as int
      ..orientationIndex = fields[3] as int
      ..marginsLTRB = (fields[4] as List).cast<double>()
      ..pageNumberPositionIndex = fields[11] as int
      ..logoPositionIndex = fields[13] as int
      ..tocPositionIndex = fields[22] as int;
  }

  @override
  void write(BinaryWriter writer, BookTemplate obj) {
    writer
      ..writeByte(34)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.pageSizeIndex)
      ..writeByte(3)
      ..write(obj.orientationIndex)
      ..writeByte(4)
      ..write(obj.marginsLTRB)
      ..writeByte(5)
      ..write(obj.fontFamily)
      ..writeByte(6)
      ..write(obj.fontSize)
      ..writeByte(7)
      ..write(obj.chordFontSize)
      ..writeByte(8)
      ..write(obj.headerText)
      ..writeByte(9)
      ..write(obj.footerText)
      ..writeByte(10)
      ..write(obj.showPageNumbers)
      ..writeByte(11)
      ..write(obj.pageNumberPositionIndex)
      ..writeByte(12)
      ..write(obj.logoPath)
      ..writeByte(13)
      ..write(obj.logoPositionIndex)
      ..writeByte(14)
      ..write(obj.logoSize)
      ..writeByte(15)
      ..write(obj.hasCoverPage)
      ..writeByte(16)
      ..write(obj.coverTitle)
      ..writeByte(17)
      ..write(obj.coverSubtitle)
      ..writeByte(18)
      ..write(obj.coverImagePath)
      ..writeByte(19)
      ..write(obj.hasIntroPage)
      ..writeByte(20)
      ..write(obj.introText)
      ..writeByte(21)
      ..write(obj.hasTOC)
      ..writeByte(22)
      ..write(obj.tocPositionIndex)
      ..writeByte(23)
      ..write(obj.tocTitle)
      ..writeByte(24)
      ..write(obj.indexOptions)
      ..writeByte(25)
      ..write(obj.sections)
      ..writeByte(26)
      ..write(obj.allowTwoColumns)
      ..writeByte(27)
      ..write(obj.twoColumnThreshold)
      ..writeByte(28)
      ..write(obj.columnGap)
      ..writeByte(29)
      ..write(obj.blankPagesAfterSections)
      ..writeByte(30)
      ..write(obj.blankPagesCount)
      ..writeByte(31)
      ..write(obj.blankPageLabel)
      ..writeByte(32)
      ..write(obj.versionToExport)
      ..writeByte(33)
      ..write(obj.exportTransposeSteps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
