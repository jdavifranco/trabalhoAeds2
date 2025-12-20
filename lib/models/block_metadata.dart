/// Representa os metadados de um bloco
class BlockMetadata {
  final int blockIndex;
  int usedBytes;
  int freeBytes;
  final List<DeletedRecordInfo> deletedRecords;

  BlockMetadata({
    required this.blockIndex,
    required this.usedBytes,
    required this.freeBytes,
    List<DeletedRecordInfo>? deletedRecords,
  }) : deletedRecords = deletedRecords ?? [];

  int get availableSpace => freeBytes;

  bool get hasDeletedRecords => deletedRecords.isNotEmpty;

  bool get hasSpace => freeBytes > 0;

  /// Converte para JSON para persistência
  Map<String, dynamic> toJson() => {
    'blockIndex': blockIndex,
    'usedBytes': usedBytes,
    'freeBytes': freeBytes,
    'deletedRecords': deletedRecords.map((e) => e.toJson()).toList(),
  };

  /// Cria a partir de JSON
  factory BlockMetadata.fromJson(Map<String, dynamic> json) {
    return BlockMetadata(
      blockIndex: json['blockIndex'] as int,
      usedBytes: json['usedBytes'] as int,
      freeBytes: json['freeBytes'] as int,
      deletedRecords: (json['deletedRecords'] as List<dynamic>)
          .map((e) => DeletedRecordInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'Bloco $blockIndex: $usedBytes bytes usados, $freeBytes bytes livres, ${deletedRecords.length} registros excluídos';
  }
}

/// Informação sobre um registro excluído
class DeletedRecordInfo {
  final int offset; // Posição no bloco onde começa o registro excluído
  final int size; // Tamanho do registro excluído

  DeletedRecordInfo({required this.offset, required this.size});

  /// Converte para JSON para persistência
  Map<String, dynamic> toJson() => {'offset': offset, 'size': size};

  /// Cria a partir de JSON
  factory DeletedRecordInfo.fromJson(Map<String, dynamic> json) {
    return DeletedRecordInfo(
      offset: json['offset'] as int,
      size: json['size'] as int,
    );
  }

  @override
  String toString() {
    return 'Offset: $offset, Size: $size bytes';
  }
}
