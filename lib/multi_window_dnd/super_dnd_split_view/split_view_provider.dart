import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'split_view_provider.g.dart';

/// 전체영역 분할 버튼 상태
/// sAlignment: 해당 방향으로 분할버튼 Hover된 상태
/// 드랍하면 해당 방향으로 분할
/// bVisibility: 전체영역 분할버튼 노출 여부
class GlobalSplitState{
  final Alignment? align;
  final bool bVisibility;
  GlobalSplitState({this.align, this.bVisibility = false});

  GlobalSplitState copyWith({
    Alignment? align,
    bool? bVisibility
  }) {
    return GlobalSplitState(
        align: align,
        bVisibility: bVisibility ?? this.bVisibility
    );
  }
}

@riverpod
class GlobalSplitBtnNotifier extends _$GlobalSplitBtnNotifier {
  @override
  GlobalSplitState build(){
    return GlobalSplitState();
  }

  void setGlobalSplitAlign({Alignment? align}){
    state = state.copyWith(align: align);
  }

  void setGlobalSplitBtnVisible(bool bVisible){
    state = state.copyWith(align: state.align, bVisibility: bVisible);
  }
}

/// 영역에 분할 버튼 호버 상태 지정
/// Null: 겹치지 않음
/// top/right/bottom/left: 각 방향으로 분할
/// center: 해당 영역으로 병합
@riverpod
class HoverActionNotifier extends _$HoverActionNotifier{
  @override
  String? build(String nodeId){
    return null;
  }
  void set(String? value) {
    state = value;
  }
}

class GlobalDragState{
  final bool bDragging; // 현재 드래깅 여부
  final String? sDraggingNodeId; // 드래그 중인 탭의 Node id
  final bool bLeftHeader; // 드래그해서 탭 헤더 영역을 벗어났는지

  GlobalDragState({this.bDragging = false, this.sDraggingNodeId, this.bLeftHeader = false});

  GlobalDragState copyWith({
    bool? bDragging,
    bool? bLeftHeader,
    String? sDraggingNodeId,
  }) {
    return GlobalDragState(
      bDragging: bDragging ?? this.bDragging,
      bLeftHeader: bLeftHeader ?? this.bLeftHeader,
      sDraggingNodeId : sDraggingNodeId,
    );
  }

}

@riverpod
class SDNDGlobalDragStateNotifier extends _$SDNDGlobalDragStateNotifier{
  @override
  GlobalDragState build(){
    return GlobalDragState();
  }

  void startDrag({String? sDraggingNodeId}){
    state = state.copyWith(bDragging: true, bLeftHeader: false, sDraggingNodeId: sDraggingNodeId);
  }
  void endDrag(){
    state = state.copyWith(bDragging: false, bLeftHeader: false, sDraggingNodeId: null);
  }
  void setLeftTabHeader(){
    state = state.copyWith(bLeftHeader: true, sDraggingNodeId: state.sDraggingNodeId);
  }

}