import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/karaoke_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/auth_state.dart';
import '../../database/database.dart';
import '../../services/supabase_service.dart';
import '../performer_screen.dart';
import '../song_ranking_screen.dart';
import '../course_generator_screen.dart';

class ExtraTab extends ConsumerStatefulWidget {
  const ExtraTab({super.key});
  @override
  ConsumerState<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends ConsumerState<ExtraTab> {
  LibrarySong? _recommendedSong;
  final List<String> _recentHistory = [];
  static const int _maxHistory = 10;

  Color _getDifficultyColor(String difficulty) {
    if (difficulty.contains('하')) return Colors.green;
    if (difficulty.contains('중')) return Colors.blue;
    if (difficulty.contains('상')) return Colors.red;
    return Colors.black;
  }

  LibrarySong? _weightedRandomPick(List<LibrarySong> songs) {
    final random = Random();
    final weights = songs.map((song) {
      final historyIndex = _recentHistory.indexOf(song.songNumber);
      if (historyIndex == -1) return 1.0;
      final recency = (_recentHistory.length - historyIndex) / _recentHistory.length;
      return recency * recency;
    }).toList();
    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    if (totalWeight == 0) return songs[random.nextInt(songs.length)];
    double pick = random.nextDouble() * totalWeight;
    for (int i = 0; i < songs.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return songs[i];
    }
    return songs.last;
  }

  void _recommendSong(List<LibrarySong> songs, String targetBrand) {
    final filtered = songs.where((s) => s.machineBrand == targetBrand).toList();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetBrand 노래가 하나도 없잖아! 좀 등록하고 눌러!')),
      );
      return;
    }
    final picked = _weightedRandomPick(filtered);
    if (picked == null) return;
    _recentHistory.remove(picked.songNumber);
    _recentHistory.add(picked.songNumber);
    if (_recentHistory.length > _maxHistory) _recentHistory.removeAt(0);
    setState(() => _recommendedSong = picked);
  }

  // ── 구글 로그인 ───────────────────────────────────────────
  Future<void> _handleGoogleLogin(BuildContext ctx) async {
    Navigator.pop(ctx);
    ref.read(syncLoadingProvider.notifier).state = true;
    try {
      final success = await SupabaseService.signInWithGoogle();
      if (!success) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인에 실패했어. 다시 시도해봐!')));
        return;
      }
      await SupabaseService.syncOnLogin();
      ref.invalidate(libraryViewModelProvider);
      ref.invalidate(sessionViewModelProvider);
      ref.invalidate(performerViewModelProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 로그인 및 동기화 완료!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      ref.read(syncLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _handleLogout(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하면 자동 동기화가 중단돼. 계속할까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('로그아웃', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await SupabaseService.signOut();
  }

  Future<void> _handlePullFromCloud(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('클라우드에서 불러오기'),
        content: const Text('클라우드 데이터로 로컬을 덮어씁니다.\n현재 로컬 데이터는 사라져요. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('덮어쓰기', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(syncLoadingProvider.notifier).state = true;
    try {
      await SupabaseService.pullFromCloud();
      ref.invalidate(libraryViewModelProvider);
      ref.invalidate(sessionViewModelProvider);
      ref.invalidate(performerViewModelProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 클라우드 → 로컬 동기화 완료!')));
    } finally {
      ref.read(syncLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _handlePushToCloud(BuildContext ctx) async {
    Navigator.pop(ctx);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('클라우드에 올리기'),
        content: const Text('로컬 데이터로 클라우드를 덮어씁니다.\n클라우드의 기존 데이터는 사라져요. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('올리기', style: TextStyle(color: Colors.blue))),
        ],
      ),
    );
    if (confirm != true) return;
    ref.read(syncLoadingProvider.notifier).state = true;
    try {
      await SupabaseService.pushAllToCloud();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 로컬 → 클라우드 동기화 완료!')));
    } finally {
      ref.read(syncLoadingProvider.notifier).state = false;
    }
  }

  // ── 기타 설정 다이얼로그 (백업 + 로그인 통합) ─────────────
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final currentTheme = ref.watch(appThemeModeProvider);
          final showHighestNote = ref.watch(showHighestNoteProvider);
          final authAsync = ref.watch(authUserProvider);
          final isSyncing = ref.watch(syncLoadingProvider);

          return AlertDialog(
            title: const Text('기타 설정'),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 테마 ─────────────────────────────────
                  const Text('테마', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  RadioListTile<ThemeMode>(
                    dense: true,
                    title: const Text('라이트 모드', style: TextStyle(fontSize: 13)),
                    value: ThemeMode.light,
                    groupValue: currentTheme,
                    onChanged: (v) => ref.read(appThemeModeProvider.notifier).setTheme(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    dense: true,
                    title: const Text('다크 모드', style: TextStyle(fontSize: 13)),
                    value: ThemeMode.dark,
                    groupValue: currentTheme,
                    onChanged: (v) => ref.read(appThemeModeProvider.notifier).setTheme(v!),
                  ),
                  RadioListTile<ThemeMode>(
                    dense: true,
                    title: const Text('시스템 설정 따르기', style: TextStyle(fontSize: 13)),
                    value: ThemeMode.system,
                    groupValue: currentTheme,
                    onChanged: (v) => ref.read(appThemeModeProvider.notifier).setTheme(v!),
                  ),
                  const Divider(height: 12),

                  // ── 최고음 ───────────────────────────────
                  CheckboxListTile(
                    dense: true,
                    title: const Text('최고음 보기', style: TextStyle(fontSize: 13)),
                    value: showHighestNote,
                    onChanged: (_) => ref.read(showHighestNoteProvider.notifier).toggle(),
                  ),
                  if (showHighestNote)
                    CheckboxListTile(
                      dense: true,
                      title: const Text('난이도로 표시', style: TextStyle(fontSize: 13)),
                      value: ref.watch(useDifficultyLabelProvider),
                      onChanged: (_) => ref.read(useDifficultyLabelProvider.notifier).toggle(),
                    ),
                  const Divider(height: 12),

                  // ── 백업 ─────────────────────────────────
                  const Text('데이터 백업', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(dataManagementViewModelProvider.notifier).exportData();
                          },
                          icon: const Icon(Icons.upload_file, size: 15),
                          label: const Text('백업 만들기', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final success = await ref.read(dataManagementViewModelProvider.notifier).importData();
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데이터 복원 성공!')));
                            }
                          },
                          icon: const Icon(Icons.file_open, size: 15),
                          label: const Text('백업 불러오기', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),

                  // ── 클라우드 동기화 ───────────────────────
                  const Text('클라우드 동기화', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  authAsync.when(
                    data: (user) {
                      if (user == null) {
                        return SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isSyncing ? null : () => _handleGoogleLogin(ctx),
                            icon: isSyncing
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.login, size: 15),
                            label: const Text('Google로 로그인', style: TextStyle(fontSize: 13)),
                          ),
                        );
                      }
                      // 로그인 상태
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_done, color: Colors.green, size: 15),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  user.email ?? user.id,
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _handleLogout(ctx),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('로그아웃', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isSyncing ? null : () => _handlePullFromCloud(ctx),
                                  icon: const Icon(Icons.cloud_download, size: 14),
                                  label: const Text('클라우드→로컬', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isSyncing ? null : () => _handlePushToCloud(ctx),
                                  icon: const Icon(Icons.cloud_upload, size: 14),
                                  label: const Text('로컬→클라우드', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final recommendBrand = ref.watch(recommendBrandProvider);
    final isSyncing = ref.watch(syncLoadingProvider);
    final showHighestNote = ref.watch(showHighestNoteProvider);
    final useDifficulty = ref.watch(useDifficultyLabelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('부가 정보'),
        centerTitle: true,
        bottom: isSyncing
            ? const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(),
        )
            : null,
      ),
      body: Column(
        children: [
          // ── 메뉴 리스트 ──────────────────────────────────
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('노래를 부른 사람 관리'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerformerScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('가장 많이 부른 노래 순위'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongRankingScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('랜덤 노래 코스 생성기'),
            subtitle: const Text('오늘 부를 노래 리스트를 한꺼번에 짜줄게!'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseGeneratorScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('기타 설정'),
            subtitle: const Text('테마 · 최고음 · 백업 · 클라우드 동기화'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showSettingsDialog,
          ),
          const Divider(height: 1),

          const Spacer(),

          // ── 추천 노래 카드 (컴팩트 가로형) ───────────────
          if (_recommendedSong != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.indigo, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _recommendedSong!.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _recommendedSong!.originalSinger,
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_recommendedSong!.machineBrand} ${_recommendedSong!.songNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _recommendedSong!.machineBrand == 'TJ' ? Colors.purple : Colors.orange,
                          ),
                        ),
                        Text(
                          showHighestNote && useDifficulty
                              ? (noteToDifficulty[_recommendedSong!.highestNote] ?? _recommendedSong!.highestNote)
                              : _recommendedSong!.highestNote,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: showHighestNote && useDifficulty
                                ? _getDifficultyColor(noteToDifficulty[_recommendedSong!.highestNote] ?? '')
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── 브랜드 선택 + 랜덤 버튼 (한 줄) ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Text('TJ', style: TextStyle(fontSize: 12)),
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: recommendBrand == 'TJ',
                  onChanged: (v) { if (v == true) ref.read(recommendBrandProvider.notifier).setBrand('TJ'); },
                ),
                const SizedBox(width: 2),
                const Text('금영', style: TextStyle(fontSize: 12)),
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: recommendBrand == 'KY',
                  onChanged: (v) { if (v == true) ref.read(recommendBrandProvider.notifier).setBrand('KY'); },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => libraryAsync.whenData((songs) => _recommendSong(songs, recommendBrand)),
                      icon: const Icon(Icons.casino, size: 18),
                      label: const Text('랜덤 추천!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}