// Hanagram — web File stub
// Web platformunda dart:io kullanılamaz, basit stub.
import 'dart:typed_data';

class FileStat {
  FileStat._();
  int get size => 0;
  DateTime get modified => DateTime(2024);
  DateTime get accessed => DateTime(2024);
  DateTime get changed => DateTime(2024);
  FileEntityType get type => FileEntityType.file;
}

enum FileEntityType { file, directory, link, socket, pipe, notFound }

class File {
  File(String path);
  String get absolutePath => '';
  String get path => '';

  bool existsSync() => false;
  int lengthSync() => 0;
  Future<int> length() async => 0;
  List<int> readAsBytesSync() => [];
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  String readAsStringSync() => '';
  Future<String> readAsString() async => '';
  FileStat statSync() => FileStat._();
  Future<FileStat> stat() async => FileStat._();
  bool deleteSync({bool recursive = false}) => false;

  /// Write methods (stubs — no-op on web)
  void writeAsBytesSync(List<int> bytes, {bool flush = false}) {}
  void writeAsStringSync(String contents, {bool flush = false}) {}
}

/// Path separator — web'de her zaman /
const String pathSeparator = '/';
