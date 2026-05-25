import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../main.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

part 'karaoke_view_model.g.dart';

/// 고유 ID 생성 유틸 - millisecond 충돌 방지용
String _generateId() =>
    '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode.abs()}';

@riverpod
class LibraryViewModel extends _$LibraryViewModel {
  @override
  Future<List<LibrarySong>> build() => database.getAllLibrarySongs();

  Future<bool> addSong({
    required String title,
    required String originalSinger,
    required String songNumber,
    required String machineBrand,
    required String highestNote,
  }) async {
    final songs = state.value ?? [];
    final isDuplicate = songs.any((s) =>
    s.title == title &&
        s.originalSinger == originalSinger &&
        s.songNumber == songNumber &&
        s.machineBrand == machineBrand &&
        s.highestNote == highestNote);

    if (isDuplicate) return false;

    final id = _generateId();
    await database.insertLibrarySong(LibrarySongsCompanion.insert(
      id: id,
      title: title,
      originalSinger: originalSinger,
      songNumber: songNumber,
      machineBrand: machineBrand,
      highestNote: highestNote,
    ));

    // 클라우드 동기화
    await SupabaseService.upsertSong(LibrarySong(
      id: id,
      title: title,
      originalSinger: originalSinger,
      songNumber: songNumber,
      machineBrand: machineBrand,
      highestNote: highestNote,
      isHighlighted: false,
    ));

    ref.invalidateSelf();
    return true;
  }

  Future<void> updateSong(LibrarySong song) async {
    await database.updateLibrarySong(song);
    await SupabaseService.upsertSong(song); // 클라우드 동기화
    ref.invalidateSelf();
  }

  Future<void> deleteSongWithUndo(BuildContext context, LibrarySong song) async {
    final entriesBackup = await (database.select(database.sessionEntries)
      ..where((t) => t.librarySongId.equals(song.id)))
        .get();

    await database.deleteLibrarySong(song.id);
    await SupabaseService.deleteSong(song.id); // 클라우드 동기화
    ref.invalidateSelf();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('"${song.title}" 삭제됨.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '복원',
          onPressed: () async {
            await database.insertLibrarySong(song.toCompanion(false));
            await SupabaseService.upsertSong(song); // 클라우드 복원
            for (final entry in entriesBackup) {
              await database.insertSessionEntry(entry.toCompanion(false));
              await SupabaseService.upsertSessionEntry(entry); // 클라우드 복원
            }
            ref.invalidateSelf();
            ref.invalidate(sessionViewModelProvider);
          },
        ),
      ));
  }

  Future<void> toggleHighlight(LibrarySong song) async {
    final newValue = !song.isHighlighted;
    // 로컬 DB 업데이트
    await database.updateSongHighlight(song.id, newValue);
    // 낙관적 UI 갱신: 전체 재조회 대신 메모리 상태만 변경
    final songs = state.value;
    if (songs != null) {
      state = AsyncValue.data(
        songs.map((s) => s.id == song.id ? s.copyWith(isHighlighted: newValue) : s).toList(),
      );
    }
    // 클라우드 동기화는 비동기로 fire-and-forget
    SupabaseService.updateSongHighlight(song.id, newValue);
  }
}

@riverpod
class SessionViewModel extends _$SessionViewModel {
  @override
  Future<List<Session>> build() => database.getAllSessions();

  Future<void> addSession(DateTime date) async {
    final id = _generateId();
    await database.insertSession(SessionsCompanion.insert(
      id: id,
      date: date,
    ));
    // 클라우드 동기화
    await SupabaseService.upsertSession(Session(
      id: id,
      date: date,
      title: '',
      rating: 0,
      memo: '',
    ));
    ref.invalidateSelf();
  }

  Future<void> updateSessionInfo(Session session) async {
    await database.updateSession(session);
    await SupabaseService.upsertSession(session); // 클라우드 동기화
    ref.invalidateSelf();
  }

  Future<void> deleteSession(String sessionId) async {
    await database.deleteSession(sessionId);
    await SupabaseService.deleteSessionAndEntries(sessionId); // 클라우드 동기화
    ref.invalidateSelf();
  }
}

@riverpod
class PerformerViewModel extends _$PerformerViewModel {
  @override
  Future<List<Performer>> build() => database.getAllPerformers();

  Future<void> addPerformer(String name) async {
    final id = _generateId();
    await database.insertPerformer(PerformersCompanion.insert(
      id: id,
      name: name,
    ));
    await SupabaseService.upsertPerformer(Performer(id: id, name: name)); // 클라우드 동기화
    ref.invalidateSelf();
  }

  Future<void> removePerformer(Performer performer) async {
    await database.clearPerformerNameFromEntries(performer.name);
    await SupabaseService.clearPerformerNameFromEntries(performer.name); // 클라우드 동기화
    await database.deletePerformer(performer.id);
    await SupabaseService.deletePerformer(performer.id); // 클라우드 동기화
    ref.invalidateSelf();
  }
}

@riverpod
class SessionDetailViewModel extends _$SessionDetailViewModel {
  @override
  Future<List<Map<String, dynamic>>> build(String sessionId) async {
    final results = await database.getSessionWithSongs(sessionId).get();
    return results
        .map((row) => {
      'entry': row.readTable(database.sessionEntries),
      'song': row.readTable(database.librarySongs),
    })
        .toList();
  }

  Future<void> addSongToSession(LibrarySong song) async {
    final current = state.value ?? [];
    final id = _generateId();
    final sortOrder = current.length;
    await database.insertSessionEntry(SessionEntriesCompanion.insert(
      id: id,
      sessionId: sessionId,
      librarySongId: song.id,
      sortOrder: drift.Value(sortOrder),
    ));
    // 클라우드 동기화
    await SupabaseService.upsertSessionEntry(SessionEntry(
      id: id,
      sessionId: sessionId,
      librarySongId: song.id,
      performer: '',
      sortOrder: sortOrder,
    ));
    ref.invalidateSelf();
  }

  Future<void> removeEntry(String entryId) async {
    await database.deleteSessionEntry(entryId);
    await SupabaseService.deleteSessionEntry(entryId); // 클라우드 동기화
    ref.invalidateSelf();
    ref.invalidate(sessionViewModelProvider);
  }

  Future<void> updatePerformer(String entryId, String name) async {
    await database.updateEntryPerformer(entryId, name);
    await SupabaseService.updateEntryPerformer(entryId, name); // 클라우드 동기화
    ref.invalidateSelf();
  }

  /// 트랜잭션으로 순서 변경을 한 번에 처리
  Future<void> reorderEntries(int oldIdx, int newIdx) async {
    final list = List<Map<String, dynamic>>.from(state.value ?? []);
    if (newIdx > oldIdx) newIdx -= 1;
    final item = list.removeAt(oldIdx);
    list.insert(newIdx, item);

    await database.transaction(() async {
      for (int i = 0; i < list.length; i++) {
        final entry = list[i]['entry'] as SessionEntry;
        await database.updateEntryOrder(entry.id, i);
      }
    });

    // 클라우드 동기화 (순서 변경된 항목들)
    for (int i = 0; i < list.length; i++) {
      final entry = list[i]['entry'] as SessionEntry;
      await SupabaseService.updateEntryOrder(entry.id, i);
    }

    ref.invalidateSelf();
  }
}

@riverpod
class DataManagementViewModel extends _$DataManagementViewModel {
  @override
  void build() {}

  Future<void> exportData() async {
    final songs = await database.getAllLibrarySongs();
    final sessions = await database.getAllSessions();
    final allEntries = await database.getAllSessionEntries();
    final performers = await database.getAllPerformers();

    final songIds = songs.map((s) => s.id).toSet();
    final sessionIds = sessions.map((s) => s.id).toSet();

    final validEntries = (allEntries
        .where((e) =>
    songIds.contains(e.librarySongId) &&
        sessionIds.contains(e.sessionId))
        .toList())
      ..sort((a, b) {
        final sComp = a.sessionId.compareTo(b.sessionId);
        return sComp != 0 ? sComp : a.sortOrder.compareTo(b.sortOrder);
      });

    final rows = <List<dynamic>>[
      ['#TYPE', 'ID(수정금지)', 'DATA1', 'DATA2', 'DATA3', 'DATA4', 'DATA5', 'DATA6'],
      ...songs.map((s) => [
        'SONG',
        'ID_${s.id}',
        s.title,
        s.originalSinger,
        s.songNumber,
        s.machineBrand,
        s.highestNote,
        s.isHighlighted ? 1 : 0,
      ]),
      ...sessions.map((s) => [
        'SESS',
        'ID_${s.id}',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(s.date),
        s.title,
        s.rating,
        s.memo,
      ]),
    ];

    String? lastSessId;
    int displayIdx = 1;
    for (final e in validEntries) {
      if (lastSessId != e.sessionId) {
        displayIdx = 1;
        lastSessId = e.sessionId;
      }
      rows.add([
        'ENTR',
        'ID_${e.id}',
        'ID_${e.sessionId}',
        'ID_${e.librarySongId}',
        e.performer,
        displayIdx
      ]);
      displayIdx++;
    }

    rows.addAll(performers.map((p) => ['PERF', 'ID_${p.id}', p.name]));

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/karaoke_backup_$timestamp.csv');
    await file.writeAsString('\uFEFF$csvData', encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: '노래방 일지 백업_$timestamp',
    );
  }

  Future<bool> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return false;

      var content =
      await File(result.files.single.path!).readAsString(encoding: utf8);
      if (content.startsWith('\uFEFF')) content = content.substring(1);

      final rows = const CsvToListConverter().convert(content);
      if (rows.isEmpty) return false;

      // 트랜잭션으로 감싸서 import 실패 시 데이터 유실 방지
      await database.transaction(() async {
        await database.clearAllData();

        for (final row in rows) {
          if (row.isEmpty || row[0].toString().startsWith('#')) continue;

          final type = row[0].toString();
          final id = row[1].toString().replaceAll('ID_', '');

          switch (type) {
            case 'SONG':
              await database.insertLibrarySong(LibrarySongsCompanion.insert(
                id: id,
                title: row[2].toString(),
                originalSinger: row[3].toString(),
                songNumber: row[4].toString(),
                machineBrand: row[5].toString(),
                highestNote: row[6].toString(),
                isHighlighted: drift.Value(row[7].toString() == '1'),
              ));
            case 'SESS':
              final dateStr = row[2].toString();
              final sessionDate = DateTime.tryParse(dateStr) ??
                  _tryParseDate(dateStr) ??
                  DateTime.now();
              await database.insertSession(SessionsCompanion.insert(
                id: id,
                date: sessionDate,
                title: drift.Value(row[3].toString()),
                rating: drift.Value(int.tryParse(row[4].toString()) ?? 0),
                memo: drift.Value(row[5].toString()),
              ));
            case 'ENTR':
              await database.insertSessionEntry(SessionEntriesCompanion.insert(
                id: id,
                sessionId: row[2].toString().replaceAll('ID_', ''),
                librarySongId: row[3].toString().replaceAll('ID_', ''),
                performer: drift.Value(row[4].toString()),
                sortOrder: drift.Value(
                    (int.tryParse(row[5].toString()) ?? 1) - 1),
              ));
            case 'PERF':
              await database.insertPerformer(PerformersCompanion.insert(
                id: id,
                name: row[2].toString(),
              ));
          }
        }
      });

      // CSV 가져오기 후 클라우드에도 반영
      await SupabaseService.pushAllToCloud();

      ref.invalidate(libraryViewModelProvider);
      ref.invalidate(sessionViewModelProvider);
      ref.invalidate(performerViewModelProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 날짜 파싱 헬퍼 - 여러 포맷 시도
  DateTime? _tryParseDate(String dateStr) {
    const formats = ['yyyy-MM-dd HH:mm', 'yyyy-MM-dd H:mm'];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(dateStr);
      } catch (_) {}
    }
    return null;
  }
}

@riverpod
class SongRankingViewModel extends _$SongRankingViewModel {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final results = await database.getAllEntriesWithSongs().get();

    final aggregation = <String, Map<String, dynamic>>{};
    for (final row in results) {
      final song = row.readTable(database.librarySongs);
      final entry = row.readTable(database.sessionEntries);
      final key = '${song.title}_${song.originalSinger}';
      aggregation.putIfAbsent(key, () => {
        'title': song.title,
        'singer': song.originalSinger,
        'total_count': 0,
        'my_count': 0,
      });
      aggregation[key]!['total_count'] =
          (aggregation[key]!['total_count'] as int) + 1;
      if (entry.performer.isEmpty) {
        aggregation[key]!['my_count'] =
            (aggregation[key]!['my_count'] as int) + 1;
      }
    }

    return aggregation.values.toList();
  }
}

@riverpod
Future<List<Session>> sessionsBySong(SessionsBySongRef ref, String songId) =>
    database.getSessionsBySongId(songId);