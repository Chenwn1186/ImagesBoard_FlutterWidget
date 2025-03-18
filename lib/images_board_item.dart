import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:simple_canvas/images_board.dart';
import 'package:simple_canvas/images_board_item_img.dart';
import 'package:simple_canvas/images_board_item_text.dart';

class BoardItem {
  ///全局坐标
  Offset globalPosition;
  late Offset localPosition;
  double scale;
  double minScale = 0.25;
  double maxScale = 4;
  double width;
  double height;
  int isSelected = 0;
  int code;
  BoardItem(
      this.globalPosition, this.scale, this.width, this.height, this.code) {
    localPosition = ImagesBoardManager().global2Local(globalPosition);
  }

  bool inArea(Offset globalPoint) {
    // 将全局坐标转换为局部坐标
    var localOffset = ImagesBoardManager().global2Local(globalPoint);

    var totalScale = scale * ImagesBoardManager().scale;
    // 应用缩放因子计算缩放后的宽度和高度
    double scaledWidth = width * totalScale;
    double scaledHeight = height * totalScale;

    // 计算图片矩形的边界
    double left = localPosition.dx - scaledWidth / 2;
    double top = localPosition.dy - scaledHeight / 2;
    double right = localPosition.dx + scaledWidth / 2;
    double bottom = localPosition.dy + scaledHeight / 2;

    // 检查局部坐标是否在图片矩形范围内
    return localOffset.dx >= left &&
        localOffset.dx <= right &&
        localOffset.dy >= top &&
        localOffset.dy <= bottom;
  }

  void addOffset(Offset offset) {
    localPosition += offset;
  }

  void click() {
    isSelected++;
  }

  void unclick() {
    isSelected = 0;
  }

  bool checkInArea(Offset globalPoint, bool isClicked) {
    if (isClicked) {
      unclick();
      return false;
    }
    bool result = inArea(globalPoint);
    if (result) {
      click();
    } else {
      unclick();
    }
    return result;
  }

  void updateLocalPosition(Offset globalPoint) {
    var localPoint = ImagesBoardManager().global2Local(globalPoint);
    localPosition = localPoint;
    // ImagesBoardManager().updateView();
  }

  void addScale(double s) {
    scale += s;
    scale = min(max(scale, minScale), maxScale);
    // print('scale: $scale');
  }
}

class BoardPoint {
  Offset position;
  double size = 4;
  bool isEmpty = false;
  Color color = const Color.fromARGB(255, 90, 90, 90);
  double scale = 1;
  double minScale = 0.25;
  double maxScale = 4;
  ImageItem? parent;
  BoardLine? parentLine;
  int isSelected = 0;
  int code;
  BoardPoint(this.position, this.code);

  void click() {
    isSelected++;
    var mng = ImagesBoardManager();
    var lastImg = mng.preSelectedImgItem;
    lastImg = mng.currentSelectedImgItem;
    mng.currentSelectedImgItem = parent;
    if (isSelected == 1) {
      color = Colors.blue;

      if (lastImg != null && parent != lastImg) {
        if (lastImg.canBeLinked()) {
          print('连接');
          // var line = BoardLine([this, lastImg.getLinkedPoint()],
          //     DateTime.now().millisecondsSinceEpoch);
          ImagesBoardManager().currentSelectedImgItem = null;
          ImagesBoardManager().addLine(this, lastImg.getLinkedPoint());
        } else {
          print('无法连接');
          lastImg.leftPoint.unclick();
          lastImg.rightPoint.unclick();
        }
      } else if (lastImg != null && parent == lastImg) {
        if (this == lastImg.leftPoint) {
          parent!.rightPoint.unclick();
          print('取消点击 右');
        } else {
          parent!.leftPoint.unclick();
          print('取消点击 左');
        }
      } else {
        print('设置为parent');
        ImagesBoardManager().currentSelectedImgItem = parent;
      }
    } else if (isSelected == 2) {
      color = Colors.red;
      ImagesBoardManager().currentSelectedImgItem = parent;
      print('选中, 设置为parent');
    } else {
      unclick();
    }
  }

  void unclick() {
    isSelected = 0;
    color = const Color.fromARGB(255, 90, 90, 90);
  }

  bool inArea(Offset globalPoint) {
    var localOffset = ImagesBoardManager().global2Local(globalPoint);
    var totalScale = scale * ImagesBoardManager().scale;
    return (localOffset - position).distance < size * totalScale;
  }

  bool checkInArea(Offset globalPoint) {
    bool result = inArea(globalPoint);
    if (result) {
      click();
    } else {
      //不unclick防止无法连接（selected=0，无法连接）
      // unclick();
    }
    return result;
  }

  void addOffset(Offset offset) {
    position += offset;
  }

  void addScale(double s) {
    scale += s;
    scale = min(max(scale, minScale), maxScale);
  }

  bool checkOnLine(Offset globalPoint, {Offset delta = Offset.zero}) {
    if (parentLine == null) return false;
    bool result = inArea(globalPoint);
    if (!result) {
      unclick();
      return false;
    }
    ImagesBoardManager().currentSelectedPoint = this;
    isSelected++;
    // print('check on line');
    if (isSelected == 1) {
      ImagesBoardManager().enableDragging = false;
      print('ban drag');
      position += delta;
      color = Colors.blue;
    } else if (isSelected == 2) {
      color = Colors.red;
      parentLine!.removePoint(code);
    } else if (isSelected == 3) {
    } else {
      isSelected = 0;
      color = const Color.fromARGB(255, 90, 90, 90);
    }
    return result;
  }
}

class BoardLine {
  List<BoardPoint> points;
  int code;
  int selectedPoint = -1;
  Color color = const Color.fromARGB(255, 81, 81, 81);
  double scale = 1;
  double minScale = 0.25;
  double maxScale = 4;
  double width = 4;
  int isSelected = 0;
  Path path = Path();
  BoardLine(this.points, this.code);

  void updatePointsPosition() {
    var mng = ImagesBoardManager();
    var globalOffset = mng.globalOffset;
    var mousePosition = mng.mousePosition - globalOffset;
    var deltaScale = mng.scale / mng.oldScale;

    for (int i = 1; i < points.length - 1; i++) {
      var point = points[i];
      point.position =
          (point.position - mousePosition) * deltaScale + mousePosition;
    }
  }

  void addPoint() {
    double distance = 0;
    int index = 0;
    for (int i = 1; i < points.length; i++) {
      if (distance < (points[i].position - points[i - 1].position).distance) {
        distance = (points[i].position - points[i - 1].position).distance;
        index = i;
      }
    }
    var boardScale = ImagesBoardManager().scale;
    // 计算间隔最大的两个点之间的中点
    Offset midPoint = (points[index].position + points[index - 1].position) / 2;
    points.insert(
        index,
        BoardPoint(midPoint, DateTime.now().millisecondsSinceEpoch)
          ..parentLine = this
          ..scale = boardScale
          ..size=8);
  }

  void removePoint(int code) {
    for (int i = 0; i < points.length; i++) {
      if (points[i].code == code) {
        points.removeAt(i);
        return;
      }
    }
  }

  bool checkPointsInArea(Offset globalPoint, {Offset delta = Offset.zero}) {
    for (int i = 1; i < points.length - 1; i++) {
      if (points[i].checkOnLine(globalPoint, delta: delta)) {
        selectedPoint = i;
        return true;
      }
    }

    return false;
  }

  bool inTail(Offset globalPoint) {
    return points.first.inArea(globalPoint) || points.last.inArea(globalPoint);
  }

  void click() {
    if (selectedPoint != -1) {
      points[selectedPoint].click();
    }
  }

  void unclick() {
    if (selectedPoint != -1) {
      points[selectedPoint].unclick();
    }
  }

  bool isPointOnPath(Offset position, bool isClicked,
      {bool rightClick = false}) {
    if (!rightClick) {
      if (inTail(position)) return false;
      if (checkPointsInArea(position)) return true;
    }
    double tolerance = width * scale * ImagesBoardManager().scale * 2;
    final metrics = path.computeMetrics();
    var localPosition = position - ImagesBoardManager().boardOffset;
    for (final metric in metrics) {
      // 计算点击位置到当前路径段的最短距离
      final distance = _getMinDistanceToPathSegment(metric, localPosition);
      if (distance <= tolerance) {
        // print('点击了 线条');
        isSelected++;
        if (isSelected == 1) {
          color = Colors.blue;
        } else if (isSelected == 2) {
          addPoint();
        } else {
          isSelected = 0;
          color = const Color.fromARGB(255, 81, 81, 81);
        }
        return true;
      }
    }
    color = const Color.fromARGB(255, 81, 81, 81);
    isSelected = 0;
    return false;
  }

  double _getMinDistanceToPathSegment(PathMetric metric, Offset point) {
    const double precision = 0.01; // 迭代精度
    double minDistance = double.infinity;
    double t = 0.0;

    while (t <= 1.0) {
      final Tangent? tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent == null) {
        print('没有切线');
        break;
      }

      // 计算当前采样点的距离
      final currentDistance = (tangent.position - point).distance;
      if (currentDistance < minDistance) minDistance = currentDistance;

      // 根据斜率调整步长（距离变化大时步长小，变化小时步长大）
      final double deltaT = (currentDistance > 2 * precision) ? 0.01 : 0.001;
      t += deltaT;
    }
    // print('最小距离: $minDistance');
    return minDistance;
  }

  bool checkDelete(Offset globalPoint) {
    if (isPointOnPath(globalPoint,false, rightClick: true)) {
      ImagesBoardManager().lastItemCode = code;
      print(' set code line');
      unclick();
      click();
      return true;
    }
    return false;
  }
}




class BoardArea extends BoardItem {
  List<ImageItem> items = [];
  Color bgColor = const Color.fromARGB(161, 255, 255, 255);
  Color sideColor = const Color.fromARGB(255, 174, 174, 174);
  double minX=0;
  double minY=0;
  double maxX=0;
  double maxY=0;
  List<BoardText> labels = [];
  List<BoardText> toDeletLabels = [];
  List<BoardText> toAddLabels = [];
  BoardArea(super.globalPosition, super.scale, super.width, super.height, super.code){
    if (labels.isEmpty) {
      var addButton = BoardText(
          Offset(localPosition.dx, localPosition.dy),
          scale * ImagesBoardManager().scale,
          width,
          height,
          DateTime.now().millisecondsSinceEpoch,
          '添加标签',
          Colors.white,
          Colors.black,
          this,
          leftMDCodePoint: Icons.add.codePoint);
      labels.add(addButton);
    }
  }

  @override
  bool inArea(Offset globalPoint) {
    var localPosition = ImagesBoardManager().global2Local(globalPoint)+ ImagesBoardManager().globalOffset;
    return localPosition.dx >= minX &&
        localPosition.dx <= maxX &&
        localPosition.dy >= minY &&
        localPosition.dy <= maxY;
  }


  bool checkDelete(Offset globalPoint) {
    if (inArea(globalPoint)) {
      ImagesBoardManager().lastItemCode = code;
      print('set code img');

      unclick();
      click();
      // ImagesBoardManager().imageItems.remove(this);
      return true;
    }
    return false;
  }

  bool checkLabelsClick(Offset globalPoint, BuildContext context) {
    bool result = false;
    for (int i = 0; i < labels.length; i++) {
        var element = labels[i];
        if (element.checkInArea(globalPoint, false, context: context)) {
            result = true;
        }
    }
    labels.insertAll(0, toAddLabels);
    toAddLabels.clear();
    labels.removeWhere((element) => toDeletLabels.contains(element));
    toDeletLabels.clear();
    return result;
}

  void addLabel(String text, Color bgColor, Color textColor) {
    var label = BoardText(
        Offset(localPosition.dx, localPosition.dy),
        scale * ImagesBoardManager().scale,
        width,
        height,
        DateTime.now().millisecondsSinceEpoch,
        text,
        bgColor,
        textColor,
        this);

    // toAddLabels.add(label);
    labels.insert(labels.length-1, label);
  }

  void deleteLabel(String text) {
    if (text != '添加标签') {
      labels.removeWhere((element) => element.text == text);
    }
  }
}