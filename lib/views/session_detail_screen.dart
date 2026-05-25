import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../viewmodels/karaoke_view_model.dart';
import '../viewmodels/ui_state.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});
  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  Color _getNoteColor(String note) {
    if (note.contains('~2옥타브 솔#')) return Colors.green;
    if (note.contains('2옥타브 라~시')) return Colors.blue;
    if (note.contains('3옥타브 도~')) return Colors.red;
    return Colors.black;
  }

  Color _getBrandColor(String brand) {
    return brand == 'TJ' ? Colors.purple : Colors.orange;
  }

  void _updateRating(double dx, Session session, WidgetRef ref) {
    if (dx < 0) dx = 0;
    if (dx > 140) dx = 140;
    int newRating = (dx / 14.0).ceil();
    if (newRating > 10) newRating = 10;
    if (newRating < 0) newRating = 0;

    if (session.rating != newRating) {
      ref.read(sessionViewModelProvider.notifier).updateSessionInfo(
          session.copyWith(rating: newRating)
      );
    }
  }

  Widget _buildInteractiveStarRating(Session currentSession, WidgetRef ref) {
    double starCount = currentSession.rating / 2.0;
    int fullStars = starCount.floor();
    bool hasHalfStar = (starCount - fullStars) >= 0.5;

    return GestureDetector(
      onTapDown: (details) => _updateRating(details.localPosition.dx, currentSession, ref),
      onPanUpdate: (details) => _updateRating(details.localPosition.dx, currentSession, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          if (index < fullStars) {
            return const Icon(Icons.star, color: Colors.orange, size: 28);
          } else if (index == fullStars && hasHalfStar) {
            return const Icon(Icons.star_half, color: Colors.orange, size: 28);
          } else {
            return const Icon(Icons.star_border, color: Colors.orange, size: 28);
          }
        }),
      ),
    );
  }

  void _confirmDeleteSession(BuildContext context) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('세션 삭제'),
      content: const Text('이 날의 기록을 전부 지울 거야?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () {
          ref.read(sessionViewModelProvider.notifier).deleteSession(widget.session.id);
          Navigator.pop(context);
          Navigator.pop(context);
        }, child: const Text('지워', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showPerformerPicker(String entryId, List<Performer> performers) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('누가 불렀어?'),
      content: SizedBox(
        width: double.maxFinite,
        child: performers.isEmpty
            ? const Text('부가 정보에서 사람을 먼저 등록해!')
            : ListView.builder(
          shrinkWrap: true,
          itemCount: performers.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(performers[i].name),
            onTap: () {
              ref.read(sessionDetailViewModelProvider(widget.session.id).notifier).updatePerformer(entryId, performers[i].name);
              Navigator.pop(context);
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          ref.read(sessionDetailViewModelProvider(widget.session.id).notifier).updatePerformer(entryId, '');
          Navigator.pop(context);
        }, child: const Text('선택 해제')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sessionDataAsync = ref.watch(sessionDetailViewModelProvider(widget.session.id));
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final sessions = ref.watch(sessionViewModelProvider).value ?? [];
    final performersAsync = ref.watch(performerViewModelProvider);
    final currentSession = sessions.firstWhere((s) => s.id == widget.session.id, orElse: () => widget.session);
    final showHighestNote = ref.watch(showHighestNoteProvider);
    final useDifficulty = ref.watch(useDifficultyLabelProvider);

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: currentSession.date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              ref.read(sessionViewModelProvider.notifier).updateSessionInfo(
                currentSession.copyWith(date: picked),
              );
            }
          },
          child: Text(
            '${currentSession.date.year}년 ${currentSession.date.month}월 ${currentSession.date.day}일 상세',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDeleteSession(context))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: '라이브러리 검색...', prefixIcon: Icon(Icons.search, size: 20), isDense: true, border: OutlineInputBorder()),
            ),
          ),
          if (_query.isNotEmpty)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: libraryAsync.when(
                data: (songs) {
                  final filtered = songs.where((s) => s.title.toLowerCase().contains(_query.toLowerCase()) || s.originalSinger.toLowerCase().contains(_query.toLowerCase())).toList();
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return ListTile(
                        dense: true, visualDensity: const VisualDensity(vertical: -4),
                        onTap: () {
                          ref.read(sessionDetailViewModelProvider(widget.session.id).notifier).addSongToSession(s);
                          setState(() { _query = ''; _searchController.clear(); });
                        },
                        title: Row(children: [
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                children: [
                                  TextSpan(text: s.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  TextSpan(text: " - ${s.originalSinger}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                ],
                              ),
                            ),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (showHighestNote)
                              Text(
                                useDifficulty ? (noteToDifficulty[s.highestNote] ?? s.highestNote) : s.highestNote,
                                style: TextStyle(color: _getNoteColor(s.highestNote), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            Text('${s.machineBrand} ${s.songNumber}', style: TextStyle(color: _getBrandColor(s.machineBrand), fontSize: 9, fontWeight: FontWeight.bold)),
                          ]),
                        ]),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _buildInteractiveStarRating(currentSession, ref),
          ),
          const Divider(height: 1),
          Expanded(
            child: sessionDataAsync.when(
              data: (items) => ReorderableListView.builder(
                itemCount: items.length,
                onReorder: (o, n) => ref.read(sessionDetailViewModelProvider(widget.session.id).notifier).reorderEntries(o, n),
                itemBuilder: (context, index) {
                  final song = items[index]['song'] as LibrarySong;
                  final entry = items[index]['entry'] as SessionEntry;
                  return InkWell(
                    key: ValueKey(entry.id),
                    onTap: () => performersAsync.whenData((list) => _showPerformerPicker(entry.id, list)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                Text(song.originalSinger, style: const TextStyle(fontSize: 12, color: Colors.blueGrey), overflow: TextOverflow.ellipsis),
                                if (entry.performer.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text('🎤 ${entry.performer}', style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (showHighestNote)
                                Text(
                                  useDifficulty ? (noteToDifficulty[song.highestNote] ?? song.highestNote) : song.highestNote,
                                  style: TextStyle(color: _getNoteColor(song.highestNote), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              Text('${song.machineBrand} ${song.songNumber}', style: TextStyle(color: _getBrandColor(song.machineBrand), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                            onPressed: () {
                              ref.read(sessionDetailViewModelProvider(widget.session.id).notifier).removeEntry(entry.id);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('에러: $e')),
            ),
          ),
        ],
      ),
    );
  }
}