import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import '../../viewmodels/karaoke_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../database/database.dart';

class AddSongTab extends ConsumerStatefulWidget {
  const AddSongTab({super.key});
  @override
  ConsumerState<AddSongTab> createState() => _AddSongTabState();
}

bool _showOnlyHighlighted = false;

class SongResult {
  final String number;
  final String title;
  final String singer;
  final List<String> tags;

  SongResult({
    required this.number,
    required this.title,
    required this.singer,
    this.tags = const [],
  });
}

class _AddSongTabState extends ConsumerState<AddSongTab> {
  final List<String> _notes = ['~2옥타브 솔#', '2옥타브 라~시', '3옥타브 도~'];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _getNoteColor(String note) {
    if (note == _notes[0]) return Colors.green;
    if (note == _notes[1]) return Colors.blue;
    if (note == _notes[2]) return Colors.red;
    return Colors.black;
  }

  Color _getBrandColor(String brand) {
    return brand == 'TJ' ? Colors.purple : Colors.orange;
  }

  int _compareTitles(String a, String b) {
    int groupA = _getCharGroup(a);
    int groupB = _getCharGroup(b);

    if (groupA != groupB) return groupA.compareTo(groupB);

    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  int _getCharGroup(String str) {
    if (str.isEmpty) return 6;
    final first = str[0];
    if (RegExp(r'^[가-힣ㄱ-ㅎㅏ-ㅣ]').hasMatch(first)) return 1;
    if (RegExp(r'^[0-9]').hasMatch(first)) return 2;
    if (RegExp(r'^[a-zA-Z]').hasMatch(first)) return 3;
    if (RegExp(r'^[一-龥]').hasMatch(first)) return 5;
    if (RegExp(r'^[ぁ-んァ-ン]').hasMatch(first)) return 4;
    return 6;
  }

  String _getIndexLabel(String title) {
    if (title.isEmpty) return '#';
    final first = title[0];
    if (RegExp(r'^[가-힣]').hasMatch(first)) {
      final code = first.codeUnitAt(0);
      final cho = (code - 0xAC00) ~/ 28 ~/ 21;
      const choList = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
      return choList[cho.clamp(0, choList.length - 1)];
    }
    if (RegExp(r'^[a-zA-Z]').hasMatch(first)) return first.toUpperCase();
    if (RegExp(r'^[0-9]').hasMatch(first)) return '#';
    if (RegExp(r'^[一-龥]').hasMatch(first)) return '漢';
    if (RegExp(r'^[ぁ-んァ-ン]').hasMatch(first)) return 'あ';
    return '#';
  }

  String _getSmartText(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      return node.text ?? '';
    } else if (node.nodeType == dom.Node.ELEMENT_NODE) {
      dom.Element el = node as dom.Element;
      bool isInline = ['span', 'mark', 'b', 'strong', 'font', 'i', 'em', 'a'].contains(el.localName?.toLowerCase());

      String inner = el.nodes.map((n) => _getSmartText(n)).join('');

      if (isInline) {
        return inner;
      } else {
        return ' | $inner | ';
      }
    }
    return '';
  }

  Future<List<SongResult>> _searchKaraoke(String keyword, int pageNo, int searchType) async {
    final url = Uri.parse(
        'https://www.tjmedia.com/song/accompaniment_search?pageNo=$pageNo&searchTxt=$keyword&strType=$searchType');

    try {
      final response = await http.get(
        url,
        headers: {
          "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
      );

      if (response.statusCode == 200) {
        var document = parse(response.body);
        var songList = document.querySelectorAll('ul.chart-list-area > li');

        List<SongResult> results = [];

        for (var songLi in songList) {
          String rawText = _getSmartText(songLi);
          List<String> rawParts = rawText.split('|');

          List<String> cleaned = [];
          List<String> tags = [];

          for (String part in rawParts) {
            String text = part.replaceAll(RegExp(r'\s+'), ' ').trim();

            if (text.isEmpty) continue;

            if (text == 'MR' || text == 'MV' || text.contains('반주기 전용곡')) {
              tags.add(text);
              continue;
            }

            text = text.replaceAll('곡번호', '').trim();
            if (text.isEmpty) continue;

            if ((text.startsWith('(') || text.startsWith('[')) && cleaned.isNotEmpty) {
              cleaned[cleaned.length - 1] += ' $text';
            } else {
              cleaned.add(text);
            }
          }

          if (cleaned.length >= 3) {
            String number = cleaned[0];
            String title = cleaned[1];
            String singer = cleaned[2];

            if (title == '곡제목' || singer == '가수') continue;

            results.add(SongResult(
                number: number,
                title: title,
                singer: singer,
                tags: tags
            ));
          }
        }
        return results;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  void _showSearchResultsPopup(String keyword, int searchType, List<SongResult> initialResults, Function(SongResult) onSelect) {
    int currentPage = 1;
    List<SongResult> results = initialResults;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.all(16),
              title: const Text('검색 결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    if (isLoading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (results.isEmpty)
                      const Expanded(child: Center(child: Text('검색 결과가 없어, 뜌땨!')))
                    else
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final song = results[index];
                            return ListTile(
                              title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(song.singer, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                  if (song.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 4,
                                        children: song.tags.map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.grey.shade400, width: 0.5),
                                          ),
                                          child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                        )).toList(),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(song.number, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
                              onTap: () {
                                onSelect(song);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: currentPage > 1 && !isLoading
                              ? () async {
                            setPopupState(() => isLoading = true);
                            final newResults = await _searchKaraoke(keyword, currentPage - 1, searchType);
                            setPopupState(() {
                              currentPage--;
                              results = newResults;
                              isLoading = false;
                            });
                          }
                              : null,
                          child: const Text('이전 페이지'),
                        ),
                        Text('$currentPage 페이지', style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: !isLoading && results.isNotEmpty
                              ? () async {
                            setPopupState(() => isLoading = true);
                            final newResults = await _searchKaraoke(keyword, currentPage + 1, searchType);
                            setPopupState(() {
                              currentPage++;
                              results = newResults;
                              isLoading = false;
                            });
                          }
                              : null,
                          child: const Text('다음 페이지'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDialog() {
    final tCtrl = TextEditingController();
    final sCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final searchCtrl = TextEditingController();

    String bVal = ref.read(selectedBrandProvider);
    String noteVal = _notes[0];
    String? tErr, sErr;
    bool isDup = false;
    int searchType = 1;
    final showHighestNote = ref.read(showHighestNoteProvider);
    final useDifficulty = ref.read(useDifficultyLabelProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) {
          void validate() {
            final songs = ref.read(libraryViewModelProvider).value ?? [];
            final dup = songs.any((s) =>
            s.title == tCtrl.text &&
                s.originalSinger == sCtrl.text &&
                s.songNumber == nCtrl.text &&
                s.machineBrand == bVal &&
                s.highestNote == noteVal);
            setST(() {
              isDup = dup;
              if (tCtrl.text.isNotEmpty) tErr = null;
              if (sCtrl.text.isNotEmpty) sErr = null;
            });
          }

          return AlertDialog(
            title: const Text('새 노래 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('TJ', style: TextStyle(color: _getBrandColor('TJ'), fontWeight: FontWeight.bold)),
                      Checkbox(value: bVal == 'TJ', onChanged: (v) { setST(() => bVal = 'TJ'); validate(); }),
                      const SizedBox(width: 15),
                      Text('금영', style: TextStyle(color: _getBrandColor('KY'), fontWeight: FontWeight.bold)),
                      Checkbox(value: bVal == 'KY', onChanged: (v) { setST(() => bVal = 'KY'); validate(); }),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('곡 제목', style: TextStyle(fontSize: 12)),
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: searchType == 1,
                        onChanged: (v) { if (v == true) setST(() => searchType = 1); },
                      ),
                      const SizedBox(width: 8),
                      const Text('가수', style: TextStyle(fontSize: 12)),
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        value: searchType == 2,
                        onChanged: (v) { if (v == true) setST(() => searchType = 2); },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(labelText: 'TJ 온라인 검색', isDense: true, hintText: '검색어 입력'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          if (searchCtrl.text.isEmpty) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(child: CircularProgressIndicator()),
                          );

                          final results = await _searchKaraoke(searchCtrl.text, 1, searchType);

                          if (mounted) Navigator.pop(context);

                          if (results.isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색 결과가 없어, 뜌땨!')));
                            }
                          } else {
                            _showSearchResultsPopup(searchCtrl.text, searchType, results, (selectedSong) {
                              setST(() {
                                tCtrl.text = selectedSong.title;
                                sCtrl.text = selectedSong.singer;
                                nCtrl.text = selectedSong.number;
                                bVal = 'TJ';
                                validate();
                              });
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tCtrl,
                    onChanged: (_) => validate(),
                    decoration: InputDecoration(labelText: '노래 제목 *', isDense: true, errorText: tErr),
                  ),
                  TextField(
                    controller: sCtrl,
                    onChanged: (_) => validate(),
                    decoration: InputDecoration(labelText: '가수 *', isDense: true, errorText: sErr),
                  ),
                  TextField(controller: nCtrl, onChanged: (_) => validate(), decoration: const InputDecoration(labelText: '번호', isDense: true)),
                  DropdownButtonFormField<String>(
                    value: noteVal,
                    items: _notes.map((n) => DropdownMenuItem(
                      value: n,
                      child: Text(
                        useDifficulty ? (noteToDifficulty[n] ?? n) : n,
                        style: TextStyle(color: showHighestNote ? _getNoteColor(n) : Colors.grey),
                      ),
                    )).toList(),
                    onChanged: showHighestNote ? (v) { setST(() => noteVal = v!); validate(); } : null,
                    decoration: const InputDecoration(labelText: '최고음 영역', isDense: true),
                    disabledHint: Text(
                      useDifficulty ? (noteToDifficulty[noteVal] ?? noteVal) : noteVal,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  if (!showHighestNote)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text('이 기능을 사용하려면 기타 설정에서 최고음 표시를 켜시오.', style: TextStyle(color: Colors.red, fontSize: 10)),
                    ),
                  if (isDup)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('이미 똑같은 노래가 라이브러리에 있어!', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: isDup ? null : () async {
                  if (tCtrl.text.isEmpty) { setST(() => tErr = '제목을 입력해!'); return; }
                  if (sCtrl.text.isEmpty) { setST(() => sErr = '가수를 입력해!'); return; }
                  await ref.read(libraryViewModelProvider.notifier).addSong(
                    title: tCtrl.text,
                    originalSinger: sCtrl.text,
                    songNumber: nCtrl.text,
                    machineBrand: bVal,
                    highestNote: noteVal,
                  );
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: isDup ? Colors.red : null),
                child: Text(isDup ? '중복 불가' : '저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(LibrarySong song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 삭제할 거야?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${song.title}"을(를) 삭제하면 아래 세션들의 기록도 함께 사라져! 진짜 지울 거야?'),
              const SizedBox(height: 10),
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final sessionsAsync = ref.watch(sessionsBySongProvider(song.id));
                    return sessionsAsync.when(
                      data: (sessions) {
                        if (sessions.isEmpty) return const Text('기록된 세션이 없어.', style: TextStyle(color: Colors.grey));
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final dateStr = "${session.date.year}-${session.date.month.toString().padLeft(2, '0')}-${session.date.day.toString().padLeft(2, '0')}";
                              final titleStr = session.title.isNotEmpty ? session.title : '제목 없음';
                              return ListTile(
                                visualDensity: VisualDensity.compact,
                                title: Text(dateStr, style: const TextStyle(fontSize: 14)),
                                subtitle: Text(titleStr, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                      error: (e, s) => const Text('데이터를 불러오는데 실패했어.'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ref.read(libraryViewModelProvider.notifier).deleteSongWithUndo(context, song);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('응, 다 지워줘', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(LibrarySong song) {
    final tCtrl = TextEditingController(text: song.title);
    final sCtrl = TextEditingController(text: song.originalSinger);
    final nCtrl = TextEditingController(text: song.songNumber);
    String bVal = song.machineBrand;
    String noteVal = _notes.contains(song.highestNote) ? song.highestNote : _notes[0];
    final showHighestNote = ref.read(showHighestNoteProvider);
    final useDifficulty = ref.read(useDifficultyLabelProvider);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          title: const Text('노래 정보 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: tCtrl, decoration: const InputDecoration(labelText: '제목', isDense: true)),
                TextField(controller: sCtrl, decoration: const InputDecoration(labelText: '가수', isDense: true)),
                TextField(controller: nCtrl, decoration: const InputDecoration(labelText: '번호', isDense: true)),
                DropdownButtonFormField<String>(
                  value: noteVal,
                  items: _notes.map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(
                      useDifficulty ? (noteToDifficulty[n] ?? n) : n,
                      style: TextStyle(color: showHighestNote ? _getNoteColor(n) : Colors.grey),
                    ),
                  )).toList(),
                  onChanged: showHighestNote ? (v) => setST(() => noteVal = v!) : null,
                  decoration: const InputDecoration(labelText: '최고음 영역', isDense: true),
                  disabledHint: Text(
                    useDifficulty ? (noteToDifficulty[noteVal] ?? noteVal) : noteVal,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                if (!showHighestNote)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text('이 기능을 사용하려면 기타 설정에서 최고음 표시를 켜시오.', style: TextStyle(color: Colors.red, fontSize: 10)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TJ', style: TextStyle(color: _getBrandColor('TJ'), fontWeight: FontWeight.bold)),
                    Checkbox(value: bVal == 'TJ', onChanged: (v) => setST(() => bVal = 'TJ')),
                    const SizedBox(width: 10),
                    Text('금영', style: TextStyle(color: _getBrandColor('KY'), fontWeight: FontWeight.bold)),
                    Checkbox(value: bVal == 'KY', onChanged: (v) => setST(() => bVal = 'KY')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => _confirmDelete(song), child: const Text('삭제', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (tCtrl.text.isEmpty || sCtrl.text.isEmpty) return;
                ref.read(libraryViewModelProvider.notifier).updateSong(song.copyWith(
                  title: tCtrl.text,
                  originalSinger: sCtrl.text,
                  songNumber: nCtrl.text,
                  machineBrand: bVal,
                  highestNote: noteVal,
                ));
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final isSortByNote = ref.watch(isSortByNoteProvider);
    final showHighestNote = ref.watch(showHighestNoteProvider);
    final useDifficulty = ref.watch(useDifficultyLabelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('노래 라이브러리', style: TextStyle(fontSize: 18)),
        actions: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 12)),
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: _showOnlyHighlighted,
                onChanged: (_) => setState(() => _showOnlyHighlighted = !_showOnlyHighlighted),
              ),
              if (showHighestNote) ...[
                const SizedBox(width: 4),
                const Text('난이도로 분류', style: TextStyle(fontSize: 12)),
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: isSortByNote,
                  onChanged: (_) => ref.read(isSortByNoteProvider.notifier).toggle(),
                ),
              ],
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: libraryAsync.when(
        data: (songs) {
          final sortedSongs = List<LibrarySong>.from(songs);
          if (isSortByNote && showHighestNote) {
            sortedSongs.sort((a, b) {
              int cmp = _notes.indexOf(a.highestNote).compareTo(_notes.indexOf(b.highestNote));
              if (cmp != 0) return cmp;
              return _compareTitles(a.title, b.title);
            });
          } else {
            sortedSongs.sort((a, b) => _compareTitles(a.title, b.title));
          }
          final displaySongs = _showOnlyHighlighted
              ? sortedSongs.where((s) => s.isHighlighted).toList()
              : sortedSongs;

          // 인덱스 바용 Map 생성
          final Map<String, int> indexMap = {};
          for (int i = 0; i < displaySongs.length; i++) {
            final label = _getIndexLabel(displaySongs[i].title);
            if (!indexMap.containsKey(label)) {
              indexMap[label] = i;
            }
          }

          return Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(right: 28),
                itemCount: displaySongs.length + 1,
                itemBuilder: (context, index) {
                  if (index == displaySongs.length) {
                    return const SizedBox(height: 80);
                  }
                  final song = displaySongs[index];
                  return InkWell(
                    onTap: () {
                      if (song.isHighlighted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('즐겨찾기 제거', style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Text('"${song.title}"를 즐겨찾기에서 제거할까?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                              TextButton(
                                onPressed: () {
                                  ref.read(libraryViewModelProvider.notifier).toggleHighlight(song);
                                  Navigator.pop(ctx);
                                },
                                child: const Text('제거', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      } else {
                        ref.read(libraryViewModelProvider.notifier).toggleHighlight(song);
                      }
                    },
                    onLongPress: () => _showEditDialog(song),
                    child: Container(
                      height: 50.0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: song.isHighlighted ? Colors.yellow.withOpacity(0.3) : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade400,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                children: [
                                  TextSpan(text: song.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  TextSpan(text: " - ${song.originalSinger}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showHighestNote)
                                Text(
                                  useDifficulty ? (noteToDifficulty[song.highestNote] ?? song.highestNote) : song.highestNote,
                                  style: TextStyle(color: _getNoteColor(song.highestNote), fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              Text('${song.machineBrand} ${song.songNumber}', style: TextStyle(fontSize: 9, color: _getBrandColor(song.machineBrand), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: indexMap.keys.map((label) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final targetIndex = indexMap[label];
                              if (targetIndex != null) {
                                _scrollController.animateTo(
                                  targetIndex * 50.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            child: Container(
                              width: 24,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                right: 36,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _showAddDialog,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('에러 발생: $e')),
      ),
    );
  }
}