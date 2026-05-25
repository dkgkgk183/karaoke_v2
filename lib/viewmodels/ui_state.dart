import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../main.dart';

part 'ui_state.g.dart';

@Riverpod(keepAlive: true)
class TabIndex extends _$TabIndex {
  @override
  int build() => 1;
  void setTab(int index) => state = index;
}

@Riverpod(keepAlive: true)
class SelectedDate extends _$SelectedDate {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  void setDate(DateTime date) => state = DateTime(date.year, date.month, date.day);
}

@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';
  void setQuery(String query) => state = query;
  void clear() => state = '';
}

@Riverpod(keepAlive: true)
class SelectedBrand extends _$SelectedBrand {
  @override
  String build() => 'TJ';
  void setBrand(String brand) => state = brand;
}

@Riverpod(keepAlive: true)
class IsSortByNote extends _$IsSortByNote {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

@Riverpod(keepAlive: true)
class RecommendBrand extends _$RecommendBrand {
  @override
  String build() => 'TJ';
  void setBrand(String brand) => state = brand;
}

@Riverpod(keepAlive: true)
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;
  void setTheme(ThemeMode mode) => state = mode;
}

@Riverpod(keepAlive: true)
class ShowHighestNote extends _$ShowHighestNote {
  @override
  bool build() => prefs.getBool('showHighestNote') ?? false;
  void toggle() {
    state = !state;
    prefs.setBool('showHighestNote', state);
  }
}

@Riverpod(keepAlive: true)
class UseDifficultyLabel extends _$UseDifficultyLabel {
  @override
  bool build() => prefs.getBool('useDifficultyLabel') ?? false;
  void toggle() {
    state = !state;
    prefs.setBool('useDifficultyLabel', state);
  }
}

/// 최고음 → 난이도 매핑
const Map<String, String> noteToDifficulty = {
  '~2옥타브 솔#': '난이도 하',
  '2옥타브 라~시': '난이도 중',
  '3옥타브 도~': '난이도 상',
};

/// 난이도 → 최고음 매핑
const Map<String, String> difficultyToNote = {
  '난이도 하': '~2옥타브 솔#',
  '난이도 중': '2옥타브 라~시',
  '난이도 상': '3옥타브 도~',
};