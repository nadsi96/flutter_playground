import 'package:flutter/material.dart';

/// 노드 타입: 분할된 화면(split)인지, 실제 탭이 있는 말단 화면(leaf)인지 구분
enum NodeType { split, leaf }

/// 개별 탭 데이터
class TabData {
  String id; // 탭 구분용 id
  String title; // 탭 헤더에 표기될 타이틀
  String categoryId; // 탭 컨텐츠에 작성될 메뉴id

  TabData({required this.id, required this.title, required this.categoryId});

  // JSON 직렬화/역직렬화
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'categoryId': categoryId};

  factory TabData.fromJson(Map<String, dynamic> json) => TabData(
      id: json['id'], title: json['title'], categoryId: json['categoryId']);
}

/// 레이아웃 트리 노드 (재귀적 구조)
class LayoutNode {
  String id;
  NodeType type;
  Axis? axis; // 분할 방향 (가로/세로)
  List<LayoutNode> children; // 자식 노드들 (split 타입일 경우)
  List<double>? ratios; // 자식 노드 간의 비율
  List<TabData> tabs; // 포함된 탭들 (leaf 타입일 경우)
  int selectedTabIndex; // 현재 선택된 탭 인덱스

  LayoutNode({
    required this.id,
    required this.type,
    this.axis,
    List<LayoutNode>? children,
    this.ratios,
    List<TabData>? tabs,
    this.selectedTabIndex = 0,
  })  : children = children ?? [],
        tabs = tabs ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'axis': axis == Axis.horizontal ? 'horizontal' : 'vertical',
    'children': children.map((c) => c.toJson()).toList(),
    'ratios': ratios,
    'tabs': tabs.map((t) => t.toJson()).toList(),
    'selectedTabIndex': selectedTabIndex,
  };

  factory LayoutNode.fromJson(Map<String, dynamic> json) {
    NodeType type =
    json['type'] == 'NodeType.split' ? NodeType.split : NodeType.leaf;
    var node = LayoutNode(
      id: json['id'],
      type: type,
      axis: json['axis'] == 'horizontal' ? Axis.horizontal : Axis.vertical,
      selectedTabIndex: json['selectedTabIndex'] ?? 0,
      ratios: json['ratios'] != null ? List<double>.from(json['ratios']) : null,
    );
    if (json['children'] != null) {
      node.children = (json['children'] as List)
          .map((c) => LayoutNode.fromJson(c))
          .toList();
    }
    if (json['tabs'] != null) {
      node.tabs =
          (json['tabs'] as List).map((t) => TabData.fromJson(t)).toList();
    }
    return node;
  }
}