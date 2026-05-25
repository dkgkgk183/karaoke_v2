// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'karaoke_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sessionsBySongHash() => r'a859c18811a859e14d2579865143325c3ae4d3de';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [sessionsBySong].
@ProviderFor(sessionsBySong)
const sessionsBySongProvider = SessionsBySongFamily();

/// See also [sessionsBySong].
class SessionsBySongFamily extends Family<AsyncValue<List<Session>>> {
  /// See also [sessionsBySong].
  const SessionsBySongFamily();

  /// See also [sessionsBySong].
  SessionsBySongProvider call(String songId) {
    return SessionsBySongProvider(songId);
  }

  @override
  SessionsBySongProvider getProviderOverride(
    covariant SessionsBySongProvider provider,
  ) {
    return call(provider.songId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionsBySongProvider';
}

/// See also [sessionsBySong].
class SessionsBySongProvider extends AutoDisposeFutureProvider<List<Session>> {
  /// See also [sessionsBySong].
  SessionsBySongProvider(String songId)
    : this._internal(
        (ref) => sessionsBySong(ref as SessionsBySongRef, songId),
        from: sessionsBySongProvider,
        name: r'sessionsBySongProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sessionsBySongHash,
        dependencies: SessionsBySongFamily._dependencies,
        allTransitiveDependencies:
            SessionsBySongFamily._allTransitiveDependencies,
        songId: songId,
      );

  SessionsBySongProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.songId,
  }) : super.internal();

  final String songId;

  @override
  Override overrideWith(
    FutureOr<List<Session>> Function(SessionsBySongRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SessionsBySongProvider._internal(
        (ref) => create(ref as SessionsBySongRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        songId: songId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Session>> createElement() {
    return _SessionsBySongProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionsBySongProvider && other.songId == songId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, songId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionsBySongRef on AutoDisposeFutureProviderRef<List<Session>> {
  /// The parameter `songId` of this provider.
  String get songId;
}

class _SessionsBySongProviderElement
    extends AutoDisposeFutureProviderElement<List<Session>>
    with SessionsBySongRef {
  _SessionsBySongProviderElement(super.provider);

  @override
  String get songId => (origin as SessionsBySongProvider).songId;
}

String _$libraryViewModelHash() => r'3a708829b03e5003f8f6ce86244ef9a41a0bfd81';

/// See also [LibraryViewModel].
@ProviderFor(LibraryViewModel)
final libraryViewModelProvider =
    AutoDisposeAsyncNotifierProvider<
      LibraryViewModel,
      List<LibrarySong>
    >.internal(
      LibraryViewModel.new,
      name: r'libraryViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$libraryViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LibraryViewModel = AutoDisposeAsyncNotifier<List<LibrarySong>>;
String _$sessionViewModelHash() => r'e51fff8145fde7f08240e671938427f4d3b0c50e';

/// See also [SessionViewModel].
@ProviderFor(SessionViewModel)
final sessionViewModelProvider =
    AutoDisposeAsyncNotifierProvider<SessionViewModel, List<Session>>.internal(
      SessionViewModel.new,
      name: r'sessionViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionViewModel = AutoDisposeAsyncNotifier<List<Session>>;
String _$performerViewModelHash() =>
    r'727c7c0895ff929afac88155e1e41d2f649f032d';

/// See also [PerformerViewModel].
@ProviderFor(PerformerViewModel)
final performerViewModelProvider =
    AutoDisposeAsyncNotifierProvider<
      PerformerViewModel,
      List<Performer>
    >.internal(
      PerformerViewModel.new,
      name: r'performerViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$performerViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PerformerViewModel = AutoDisposeAsyncNotifier<List<Performer>>;
String _$sessionDetailViewModelHash() =>
    r'92e2e23c3e0dc2d221a4fd90ade202854d1e13e7';

abstract class _$SessionDetailViewModel
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String sessionId;

  FutureOr<List<Map<String, dynamic>>> build(String sessionId);
}

/// See also [SessionDetailViewModel].
@ProviderFor(SessionDetailViewModel)
const sessionDetailViewModelProvider = SessionDetailViewModelFamily();

/// See also [SessionDetailViewModel].
class SessionDetailViewModelFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [SessionDetailViewModel].
  const SessionDetailViewModelFamily();

  /// See also [SessionDetailViewModel].
  SessionDetailViewModelProvider call(String sessionId) {
    return SessionDetailViewModelProvider(sessionId);
  }

  @override
  SessionDetailViewModelProvider getProviderOverride(
    covariant SessionDetailViewModelProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sessionDetailViewModelProvider';
}

/// See also [SessionDetailViewModel].
class SessionDetailViewModelProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          SessionDetailViewModel,
          List<Map<String, dynamic>>
        > {
  /// See also [SessionDetailViewModel].
  SessionDetailViewModelProvider(String sessionId)
    : this._internal(
        () => SessionDetailViewModel()..sessionId = sessionId,
        from: sessionDetailViewModelProvider,
        name: r'sessionDetailViewModelProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sessionDetailViewModelHash,
        dependencies: SessionDetailViewModelFamily._dependencies,
        allTransitiveDependencies:
            SessionDetailViewModelFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  SessionDetailViewModelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant SessionDetailViewModel notifier,
  ) {
    return notifier.build(sessionId);
  }

  @override
  Override overrideWith(SessionDetailViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: SessionDetailViewModelProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    SessionDetailViewModel,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _SessionDetailViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionDetailViewModelProvider &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SessionDetailViewModelRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _SessionDetailViewModelProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          SessionDetailViewModel,
          List<Map<String, dynamic>>
        >
    with SessionDetailViewModelRef {
  _SessionDetailViewModelProviderElement(super.provider);

  @override
  String get sessionId => (origin as SessionDetailViewModelProvider).sessionId;
}

String _$dataManagementViewModelHash() =>
    r'045bc1c89e3306cc29096641f88cd047b1ffb086';

/// See also [DataManagementViewModel].
@ProviderFor(DataManagementViewModel)
final dataManagementViewModelProvider =
    AutoDisposeNotifierProvider<DataManagementViewModel, void>.internal(
      DataManagementViewModel.new,
      name: r'dataManagementViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dataManagementViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DataManagementViewModel = AutoDisposeNotifier<void>;
String _$songRankingViewModelHash() =>
    r'0afc7c94c746eab4ed8b4e9f9cba142554c84e70';

/// See also [SongRankingViewModel].
@ProviderFor(SongRankingViewModel)
final songRankingViewModelProvider =
    AutoDisposeAsyncNotifierProvider<
      SongRankingViewModel,
      List<Map<String, dynamic>>
    >.internal(
      SongRankingViewModel.new,
      name: r'songRankingViewModelProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$songRankingViewModelHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SongRankingViewModel =
    AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
