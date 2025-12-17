// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GlobalSplitBtnNotifier)
const globalSplitBtnProvider = GlobalSplitBtnNotifierProvider._();

final class GlobalSplitBtnNotifierProvider
    extends $NotifierProvider<GlobalSplitBtnNotifier, GlobalSplitState> {
  const GlobalSplitBtnNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalSplitBtnProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalSplitBtnNotifierHash();

  @$internal
  @override
  GlobalSplitBtnNotifier create() => GlobalSplitBtnNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalSplitState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalSplitState>(value),
    );
  }
}

String _$globalSplitBtnNotifierHash() =>
    r'462bcadbb6c98fe351b85f7a9447a8a33b005510';

abstract class _$GlobalSplitBtnNotifier extends $Notifier<GlobalSplitState> {
  GlobalSplitState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GlobalSplitState, GlobalSplitState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GlobalSplitState, GlobalSplitState>,
              GlobalSplitState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// 영역에 분할 버튼 호버 상태 지정
/// Null: 겹치지 않음
/// top/right/bottom/left: 각 방향으로 분할
/// center: 해당 영역으로 병합

@ProviderFor(HoverActionNotifier)
const hoverActionProvider = HoverActionNotifierFamily._();

/// 영역에 분할 버튼 호버 상태 지정
/// Null: 겹치지 않음
/// top/right/bottom/left: 각 방향으로 분할
/// center: 해당 영역으로 병합
final class HoverActionNotifierProvider
    extends $NotifierProvider<HoverActionNotifier, String?> {
  /// 영역에 분할 버튼 호버 상태 지정
  /// Null: 겹치지 않음
  /// top/right/bottom/left: 각 방향으로 분할
  /// center: 해당 영역으로 병합
  const HoverActionNotifierProvider._({
    required HoverActionNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hoverActionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hoverActionNotifierHash();

  @override
  String toString() {
    return r'hoverActionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  HoverActionNotifier create() => HoverActionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HoverActionNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hoverActionNotifierHash() =>
    r'a1909eb45d86d9c47836fca65983b09f8cb0f333';

/// 영역에 분할 버튼 호버 상태 지정
/// Null: 겹치지 않음
/// top/right/bottom/left: 각 방향으로 분할
/// center: 해당 영역으로 병합

final class HoverActionNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          HoverActionNotifier,
          String?,
          String?,
          String?,
          String
        > {
  const HoverActionNotifierFamily._()
    : super(
        retry: null,
        name: r'hoverActionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 영역에 분할 버튼 호버 상태 지정
  /// Null: 겹치지 않음
  /// top/right/bottom/left: 각 방향으로 분할
  /// center: 해당 영역으로 병합

  HoverActionNotifierProvider call(String nodeId) =>
      HoverActionNotifierProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'hoverActionProvider';
}

/// 영역에 분할 버튼 호버 상태 지정
/// Null: 겹치지 않음
/// top/right/bottom/left: 각 방향으로 분할
/// center: 해당 영역으로 병합

abstract class _$HoverActionNotifier extends $Notifier<String?> {
  late final _$args = ref.$arg as String;
  String get nodeId => _$args;

  String? build(String nodeId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(SDNDGlobalDragStateNotifier)
const sDNDGlobalDragStateProvider = SDNDGlobalDragStateNotifierProvider._();

final class SDNDGlobalDragStateNotifierProvider
    extends $NotifierProvider<SDNDGlobalDragStateNotifier, GlobalDragState> {
  const SDNDGlobalDragStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sDNDGlobalDragStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sDNDGlobalDragStateNotifierHash();

  @$internal
  @override
  SDNDGlobalDragStateNotifier create() => SDNDGlobalDragStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlobalDragState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlobalDragState>(value),
    );
  }
}

String _$sDNDGlobalDragStateNotifierHash() =>
    r'e39cc532598c3cf785f78d455dd1d018745ee726';

abstract class _$SDNDGlobalDragStateNotifier
    extends $Notifier<GlobalDragState> {
  GlobalDragState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GlobalDragState, GlobalDragState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GlobalDragState, GlobalDragState>,
              GlobalDragState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
