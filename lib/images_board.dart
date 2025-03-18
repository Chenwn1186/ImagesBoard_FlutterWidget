import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // 新增导入
import 'dart:ui' as ui;

import 'package:provider/provider.dart';
import 'package:simple_canvas/images_board_item.dart';
import 'package:simple_canvas/images_board_item_button.dart';
import 'package:simple_canvas/images_board_item_img.dart';

class ImagesBoardManager with ChangeNotifier {
  static final ImagesBoardManager _instance = ImagesBoardManager._internal();

  ImagesBoardManager._internal();

  factory ImagesBoardManager() => _instance;

  Offset globalOffset = Offset.zero;

  Offset boardOffset = Offset.zero;

  var mousePosition = Offset.zero;

  double boardWidth = 0;

  double boardHeight = 0;

  double scale = 1;

  double oldScale = 1;

  double minScale = 0.25;

  double maxScale = 4;

  Offset backgroundLine = Offset.zero;

  int clickFresh = 0;

  ImageItem? currentItem;

  bool enableDragging = true;

  List<ImageItem> imageItems = [];

  List<BoardLine> lines = [];

  ImageItem? currentSelectedImgItem;

  ImageItem? preSelectedImgItem;

  BoardPoint? currentSelectedPoint;

  int lastItemCode = 0;

  bool showDeleteButton = false;

  BoardDeleteButton? deleteButton;

  Offset areaStart = Offset.zero;

  Offset areaEnd = Offset.zero;

  List<ImageItem> toAddinArea = [];

  List<BoardArea> areas = [];

  bool isCreatingArea = false;

  void checkInSelectedArea() {
    if (areaStart == areaEnd) {
      // print('未选择区域');
      return;
    }

    // 确保 areaStart 是左上角，areaEnd 是右下角
    double minX = min(areaStart.dx, areaEnd.dx);
    double minY = min(areaStart.dy, areaEnd.dy);
    double maxX = max(areaStart.dx, areaEnd.dx);
    double maxY = max(areaStart.dy, areaEnd.dy);

    // 清空 toAddinArea 列表
    toAddinArea.clear();

    // 遍历所有 ImageItem
    for (var item in imageItems) {
      // 获取 ImageItem 的中心位置
      Offset center = item.localPosition + globalOffset;
      // 检查中心位置是否在矩形区域内
      if (center.dx >= minX &&
          center.dx <= maxX &&
          center.dy >= minY &&
          center.dy <= maxY) {
        toAddinArea.add(item);
      }
    }

    // 如果 toAddinArea 不为空，则创建一个 BoardArea
    if (toAddinArea.isNotEmpty) {
      // 创建一个新的 BoardArea 对象
      BoardArea area = BoardArea(
        Offset((minX + maxX) / 2, (minY + maxY) / 2), // 区域中心位置
        1, // 初始缩放比例
        maxX - minX, // 区域宽度
        maxY - minY, // 区域高度
        DateTime.now().millisecondsSinceEpoch, // 区域代码
      );

      //todo: 后续添加弹窗设置区域的颜色，甚至标题
      // 将 toAddinArea 中的所有 ImageItem 添加到 BoardArea 中
      if (toAddinArea.length > 1) {
        area.items.addAll(toAddinArea);
        print('area items: ${area.items.length}');

        // 将新的 BoardArea 添加到 areas 列表中
        areas.add(area);
      }
    }
    isCreatingArea = false;
    areaStart = Offset.zero;
    areaEnd = Offset.zero;
    // 通知监听器数据已更新
    clickFresh++;
    notifyListeners();
  }

  Offset global2Local(Offset point) {
    return point - boardOffset - globalOffset;
  }

  void updateBoardOffset(Offset offset) {
    boardOffset = offset;
    notifyListeners();
  }

  void updateView() {
    clickFresh++;
    notifyListeners();
  }

  void addImageItem(ImageItem item) {
    oldScale = scale;
    imageItems.add(item);
    print('add item center: ${item.localPosition}');
    notifyListeners();
  }

  void addLine(BoardPoint start, BoardPoint end) {
    // print('add line');
    for (var l in lines) {
      if (l.points.first == start && l.points.last == end) {
        return;
      }
    }
    var line = BoardLine([start, end], DateTime.now().millisecondsSinceEpoch);
    lines.add(line);
    clickFresh++;
    for (var point in line.points) {
      point.unclick();
      // point.unclick();
    }
    notifyListeners();
  }

  void addScale(double s, Offset mousePosition) {
    oldScale = scale;
    scale += s;
    scale = min(max(scale, minScale), maxScale);
    backgroundLine = mousePosition -
        globalOffset +
        (backgroundLine - mousePosition + globalOffset) * (scale / oldScale);
    print(
        'backgroundLine: $backgroundLine mouse position: ${mousePosition - globalOffset}');
    for (var item in imageItems) {
      item.updatePosition();
    }
    for (var line in lines) {
      line.updatePointsPosition();
    }
    notifyListeners();
  }

  bool inBoardArea(Offset globalPoint) {
    var localPoint = globalPoint - boardOffset;
    return localPoint.dx >= 0 &&
        localPoint.dx <= boardWidth &&
        localPoint.dy >= 0 &&
        localPoint.dy <= boardHeight;
  }

  Future<ui.Image> loadImage(String imagePath) async {
    final image = FileImage(File(imagePath));
    final completer = Completer<ui.Image>();
    final listener = ImageStreamListener((ImageInfo info, _) {
      completer.complete(info.image);
    });
    final stream = image.resolve(ImageConfiguration.empty);
    stream.addListener(listener);
    return completer.future.whenComplete(() => stream.removeListener(listener));
  }

  void showAll() {
    print('boardOffset: $boardOffset');
    print('boardWidth: $boardWidth');
    print('boardHeight: $boardHeight');
    print('scale: $scale');
  }
}

//!白板

class ImagesBoard extends StatefulWidget {
  const ImagesBoard({super.key, required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<ImagesBoard> createState() => _ImagesBoardState();
}

class _ImagesBoardState extends State<ImagesBoard> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        ImagesBoardManager().boardWidth = renderBox.size.width;
        ImagesBoardManager().boardHeight = renderBox.size.height;
        ImagesBoardManager().boardOffset = renderBox.localToGlobal(Offset.zero);
        ImagesBoardManager().deleteButton =
            BoardDeleteButton(Offset.zero, 1, 40, 40, 0)
              ..setLeftMDCodePoint(Icons.delete.codePoint, color: Colors.red);
      } else {
        print('renderBox is null');
      }
    });
    return Listener(
      onPointerUp: (event) {
        var mng = ImagesBoardManager();

        if (mng.isCreatingArea) {
          mng.checkInSelectedArea();
        }
        ImagesBoardManager().clickFresh++;
        ImagesBoardManager().updateView();
      },
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          // 检测到滚轮滚动事件
          ImagesBoardManager().mousePosition = event.localPosition;
          timer?.cancel();
          timer = Timer(const Duration(milliseconds: 50), () {
            ImagesBoardManager().addScale(0, event.localPosition);
            ImagesBoardManager().clickFresh++;
            ImagesBoardManager().updateView();
          });

          if (ImagesBoardManager().enableDragging) {
            ImagesBoardManager()
                .addScale(-event.scrollDelta.dy * 0.0015, event.localPosition);
          } else {
            ImagesBoardManager()
                .currentItem
                ?.addScale(-event.scrollDelta.dy * 0.002);
          }
          ImagesBoardManager().clickFresh++;
          ImagesBoardManager().updateView();
        }
      },
      onPointerMove: (event) {
        var mng = ImagesBoardManager();
        mng.mousePosition = event.localPosition;
        mng.scale = mng.oldScale;
        if (event.buttons == 1) {
          // print('鼠标移动事件');

          // 检测到鼠标左键按下
          if (mng.enableDragging) {
            mng.globalOffset += event.delta;
          } else {
            mng.currentItem?.addOffset(event.delta);
            if(mng.currentItem == null) {
              mng.currentSelectedPoint?.addOffset(event.delta);
            }
          }
          mng.clickFresh++;
          mng.updateView();
        } else if (event.buttons == 2) {
          mng.isCreatingArea = true;
          if (mng.areaStart == Offset.zero) {
            mng.areaStart = event.localPosition;
          }
          mng.areaEnd = event.localPosition;
          mng.clickFresh++;
          mng.updateView();
        }
      },
      onPointerDown: (event) {
        // print('鼠标按下事件');
        ImagesBoardManager().mousePosition = event.localPosition;
        if (event.buttons == 2) {
          bool isClicked = false;
          for (var item in ImagesBoardManager().imageItems.reversed) {
            if (!isClicked && item.checkDelete(event.position)) {
              isClicked = true;
            }
          }

          for (var line in ImagesBoardManager().lines.reversed) {
            if (!isClicked && line.checkDelete(event.position)) {
              isClicked = true;
            }
          }

          for (var area in ImagesBoardManager().areas.reversed) {
            if (!isClicked && area.checkDelete(event.position)) {
              isClicked = true;
            }
          }
          ImagesBoardManager().showDeleteButton = isClicked;
          ImagesBoardManager().clickFresh++;
          ImagesBoardManager().updateView();
          return;
        }
        ImagesBoardManager().oldScale = ImagesBoardManager().scale;
        bool isClicked = false;
        if (ImagesBoardManager().showDeleteButton) {
          if (ImagesBoardManager()
              .deleteButton!
              .checkInArea(event.position, isClicked)) {
            isClicked = true;
          }
          ImagesBoardManager().showDeleteButton = false;
          ImagesBoardManager().clickFresh++;
        }
        for (var item in ImagesBoardManager().imageItems.reversed) {
          if (item.checkInArea(event.position, isClicked)) {
            ImagesBoardManager().currentItem = item;
            if (!item.enableBoardDragging()) {
              ImagesBoardManager().enableDragging = false;
            } else {
              ImagesBoardManager().enableDragging = true;
            }
            isClicked = true;
          }
          if (item.checkPointsOnTap(event.position)) {
            // print('点击了 点');
          }
          if (item.checkLabelsClick(event.position, context)) {
            // print('点击了 标签');
          }
        }
        if (!isClicked) {
          ImagesBoardManager().currentItem = null;
        }

        for (var line in ImagesBoardManager().lines.reversed) {
          if (line.isPointOnPath(event.position, isClicked)) {
            isClicked = true;
          }
        }

        for(var area in ImagesBoardManager().areas.reversed) {
          if (area.checkLabelsClick(event.position, context)) {
            // print('点击了 标签');
          }
        }

        if (!isClicked) {
          ImagesBoardManager().currentSelectedPoint = null;
          ImagesBoardManager().enableDragging = true;
        }
        ImagesBoardManager().clickFresh++;
        ImagesBoardManager().updateView();
      },
      child: Selector<ImagesBoardManager, (int, double, Offset, int)>(
        selector: (context, imagesBoardManager) => (
          imagesBoardManager.imageItems.length,
          imagesBoardManager.scale,
          imagesBoardManager.globalOffset,
          imagesBoardManager.clickFresh
        ),
        builder: (context, _, child) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              children: [
                CustomPaint(
                  painter: ImagesBoardPainter(),
                  size: Size(widget.width, widget.height),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                      onPressed: () {
                        Offset middle = Offset.zero;
                        if (ImagesBoardManager().imageItems.isEmpty) {
                          ImagesBoardManager().globalOffset =
                              Offset(widget.width / 2, widget.height / 2);
                          return;
                        }
                        for (var item in ImagesBoardManager().imageItems) {
                          middle += item.localPosition;
                        }
                        ImagesBoardManager().globalOffset = -middle /
                            ImagesBoardManager().imageItems.length.toDouble();
                        ImagesBoardManager().globalOffset +=
                            Offset(widget.width / 2, widget.height / 2);
                        ImagesBoardManager().updateView();
                      },
                      icon: Icon(Icons.center_focus_strong_outlined)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ImagesBoardPainter extends CustomPainter {
  Path createSmoothPath(List<Offset> points) {
    if (points.length < 2) {
      return Path();
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int index = 0; index < points.length - 1; index++) {
      final currentPoint = points[index];
      final nextPoint = points[index + 1];

      // 计算前一个点（边界处理）
      final Offset previousPoint;
      if (index == 0) {
        // 外推：2 * currentPoint - nextPoint
        previousPoint = Offset(
          2 * currentPoint.dx - nextPoint.dx,
          2 * currentPoint.dy - nextPoint.dy,
        );
      } else {
        previousPoint = points[index - 1];
      }

      // 计算后一个点（边界处理）
      final Offset nextNextPoint;
      if (index == points.length - 2) {
        // 外推：2 * nextPoint - currentPoint
        nextNextPoint = Offset(
          2 * nextPoint.dx - currentPoint.dx,
          2 * nextPoint.dy - currentPoint.dy,
        );
      } else {
        nextNextPoint = points[index + 2];
      }

      // 计算贝塞尔曲线的控制点
      final firstControlPoint = Offset(
        currentPoint.dx + (nextPoint.dx - previousPoint.dx) / 6,
        currentPoint.dy + (nextPoint.dy - previousPoint.dy) / 6,
      );
      final secondControlPoint = Offset(
        nextPoint.dx + (currentPoint.dx - nextNextPoint.dx) / 6,
        nextPoint.dy + (currentPoint.dy - nextNextPoint.dy) / 6,
      );

      path.cubicTo(
        firstControlPoint.dx,
        firstControlPoint.dy,
        secondControlPoint.dx,
        secondControlPoint.dy,
        nextPoint.dx,
        nextPoint.dy,
      );
    }

    return path;
  }

  void drawLine(
      BoardLine line, Canvas canvas, Offset globalOffset, double globalScale) {
    var points = line.points.map((e) => e.position + globalOffset).toList();
    var paint = Paint()
      ..color = line.color
      ..strokeWidth = line.width * globalScale * line.scale
      ..style = PaintingStyle.stroke;

    line.path = createSmoothPath(points);
    canvas.drawPath(line.path, paint);
    for (int i = 1; i < line.points.length - 1; i++) {
      drawPoint(line.points[i], canvas, globalOffset, globalScale);
    }
  }

  void drawArea(Canvas canvas, BoardArea area) {
    var mng = ImagesBoardManager();
    var golobalOffset = mng.globalOffset;

    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (var item in area.items) {
      var totalScale = mng.scale * item.scale;
      minX = min(minX, item.getLeft(totalScale) + golobalOffset.dx);
      minY = min(minY, item.getTop(totalScale) + golobalOffset.dy);
      maxX = max(maxX, item.getRight(totalScale) + golobalOffset.dx);
      maxY = max(maxY, item.getBottom(totalScale) + golobalOffset.dy);
    }

    // print(' minX: $minX, minY: $minY, maxX: $maxX, maxY: $maxY');

    // 确保计算出有效的矩形边界
    if (minX == double.infinity ||
        minY == double.infinity ||
        maxX == double.negativeInfinity ||
        maxY == double.negativeInfinity) {
      return;
    }

    area.minX = minX;
    area.minY = minY;
    area.maxX = maxX;
    area.maxY = maxY;

    var width = maxX - minX;
    var height = maxY - minY;

    area.localPosition = Offset((minX + maxX) / 2, (minY + maxY) / 2) - golobalOffset;
    area.width = width/mng.scale;
    area.height = height/mng.scale;

    var rect = Rect.fromCenter(
        center: Offset((minX + maxX) / 2, (minY + maxY) / 2),
        width: width * (1 + 0.05),
        height: height * (1 + 0.05));

    // 绘制背景填充
    var bgPaint = Paint()
      ..color = area.bgColor
      ..style = PaintingStyle.fill;
    double borderRadius = mng.scale * 2; // 圆角半径
    var rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    canvas.drawRRect(rrect, bgPaint);

    // 绘制边框
    var sidePaint = Paint()
      ..color = area.sideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = mng.scale * 2; // 边框宽度
    canvas.drawRRect(rrect, sidePaint);
  }

  void drawCreatingArea(Canvas canvas) {
    var mng = ImagesBoardManager();
    var start = mng.areaStart;
    var end = mng.areaEnd;
    var width = end.dx - start.dx;
    var height = end.dy - start.dy;
    var rect = Rect.fromLTWH(start.dx, start.dy, width, height);
    var paint = Paint()
      ..color = const Color.fromARGB(129, 54, 206, 244).withOpacity(0.3);
    canvas.drawRect(rect, paint);
  }

  void drawDeleteButton(Canvas canvas) {
    var mng = ImagesBoardManager();
    var button = mng.deleteButton!;
    var leftMDCodePoint = button.leftMDCodePoint;
    var position = mng.mousePosition;
    var width = button.width;
    var height = button.height;
    var iconColor = button.leftMDIconColor;

    // 计算矩形的位置和大小
    double left = position.dx - width / 2;
    double top = position.dy - height / 2;
    double right = position.dx + width / 2;
    double bottom = position.dy + height / 2;
    var rect = Rect.fromLTRB(left, top, right, bottom);

    // 绘制阴影
    var shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
    var shadowRRect = RRect.fromRectAndRadius(rect, Radius.circular(10));
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 绘制圆角矩形
    var rectPaint = Paint()..color = Colors.white;
    var rrect = RRect.fromRectAndRadius(rect, Radius.circular(10));
    canvas.drawRRect(rrect, rectPaint);

    // 绘制图标
    var textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(leftMDCodePoint),
        style: TextStyle(
          color: iconColor,
          fontSize: width * 0.6, // 调整字体大小
          fontFamily: 'MaterialIcons', // 使用 Material Icons 字体
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 计算文字的位置，使其居中
    double textX = position.dx - textPainter.width / 2;
    double textY = position.dy - textPainter.height / 2;
    button.localPosition = Offset(textX, textY);

    // 绘制文字
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void drawLabels(
      dynamic item, Canvas canvas, Offset globalOffset, double totalScale) {
    double standardLong =
        (item.width > item.height ? item.width : item.height) * totalScale;
    if(item is BoardArea){
      standardLong = (item.width > item.height ? item.width : item.height) * totalScale * 0.7;
    }
    var maxWidth = item.width * totalScale;
    var height = maxWidth * 0.1;
    var maxTextWidth = maxWidth * 0.9;
    // int lineIndex = 0;
    double lineOffset = 0;
    var fontSize = standardLong * 0.05;
    double yOffset = height * 0.5; // 用于记录当前行的垂直偏移

    // 计算图片左下角的位置
    double left =
        item.localPosition.dx - item.width * totalScale / 2 + globalOffset.dx;
    double bottom =
        item.localPosition.dy + item.height * totalScale / 2 + globalOffset.dy;

    for (var label in item.labels) {
      var textPainter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: label.textColor,
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(
          minWidth: 0,
          maxWidth: maxTextWidth,
        );

      double textHeight = 0;
      double textWidth = 0;
      for (var line in textPainter.computeLineMetrics()) {
        textHeight += line.height;
        textWidth = max(textWidth, line.width);
      }

      // 计算矩形的宽度和高度
      double rectWidth = textWidth + standardLong * 0.05; // 增加一些内边距
      double rectHeight = textHeight + standardLong * 0.05;

      // 检查是否需要换行
      if (lineOffset + rectWidth > maxWidth) {
        // lineIndex++;
        lineOffset = 0;
        yOffset += rectHeight + standardLong * 0.05; // 增加行间距
        // item.labelsHeight = yOffset + rectHeight + standardLong * 0.05;
      } else {
        //  item.labelsHeight = yOffset + rectHeight + standardLong * 0.05;
      }

      // 计算矩形的位置，从左下角开始
      double rectX = left + lineOffset;
      double rectY = bottom + yOffset;

      double borderRadius = standardLong * 0.01;

      // 绘制阴影
      var shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
      var shadowRect = Rect.fromLTWH(rectX + standardLong * 0.01,
          rectY + standardLong * 0.01, rectWidth, rectHeight);
      var shadowRRect =
          RRect.fromRectAndRadius(shadowRect, Radius.circular(10));
      canvas.drawRRect(shadowRRect, shadowPaint);

      // 绘制圆角矩形
      var rectPaint = Paint()..color = label.bgColor;
      var rect = Rect.fromLTWH(rectX, rectY, rectWidth, rectHeight);
      var rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, rectPaint);

      // 计算文字的位置，使其居中
      double textX = rectX + (rectWidth - textWidth) / 2;
      double textY = rectY + (rectHeight - textHeight) / 2;

      // 绘制文字
      textPainter.paint(canvas, Offset(textX, textY));

      // 更新 lineOffset
      lineOffset += rectWidth + item.width * totalScale * 0.02; // 增加间距

      // 设置当前label的width和height为矩形的长和宽
      label.width = rectWidth / totalScale;
      label.height = rectHeight / totalScale;

      if(item is ImageItem) {
        item.labelsHeight = yOffset + rectHeight + standardLong * 0.05;
      }

      // 设置当前label的localPosition为矩形中心
      label.localPosition = Offset(rectX + rectWidth / 2 - globalOffset.dx,
          rectY + rectHeight / 2 - globalOffset.dy);
      label.scale = item.scale;
    }
  }

  void drawPoint(
      BoardPoint point, Canvas canvas, Offset globalOffset, double totalScale) {
    // 绘制阴影
    var shadowPaint = Paint()
      ..color = point.color.withOpacity(0.3) // 阴影颜色，使用原颜色并降低透明度
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4); // 设置模糊效果，模拟阴影
    canvas.drawCircle(point.position + globalOffset,
        point.size * totalScale + 2, shadowPaint); // 阴影圆稍微大一点

    // 绘制实际的圆
    var paint = Paint()..color = point.color;
    canvas.drawCircle(
        point.position + globalOffset, point.size * totalScale, paint);
  }

  void drawImg(ImageItem item, Canvas canvas, Offset mousePosition,
      Offset globalOffset, double totalScale, double deltaScale) {
    var width = item.width;
    var height = item.height;

    // var newPosition =
    //     mousePosition + (item.localPosition - mousePosition) * deltaScale;
    // // print(
    // //     'old localPosition: ${item.localPosition} new localPosition: $newPosition');
    // item.localPosition = newPosition;

    // 添加圆角矩形裁切// 添加新变量记录圆角
    double borderRadius = 0.06 * (width > height ? width : height) * totalScale;
    double sideWidth = 0.03 * (width > height ? width : height) * totalScale;

    var rect = Rect.fromCenter(
        center: item.localPosition + globalOffset,
        width: width * totalScale,
        height: height * totalScale);

    var shadowRect = Rect.fromCenter(
        center: item.localPosition + globalOffset,
        width: width * totalScale + sideWidth,
        height: height * totalScale + sideWidth);

    var rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    var shadowRrect =
        RRect.fromRectAndRadius(shadowRect, Radius.circular(borderRadius));

    var paint = Paint()..color = item.sideColor;
    var shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawRRect(shadowRrect, shadowPaint);
    canvas.drawRRect(shadowRrect, paint);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(
      item.image!,
      Rect.fromLTWH(
          0, 0, item.image!.width.toDouble(), item.image!.height.toDouble()),
      rect,
      Paint(),
    );
    canvas.restore();
    item.updatePointsPosition();
    drawPoint(item.leftPoint, canvas, globalOffset, totalScale);
    drawPoint(item.rightPoint, canvas, globalOffset, totalScale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制白色背景
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // print('绘制');
    var imagesBoardManager = ImagesBoardManager();
    var globalOffset = imagesBoardManager.globalOffset;
    var mousePosition = imagesBoardManager.mousePosition - globalOffset;

    var scale = imagesBoardManager.scale;
    var oldScale = imagesBoardManager.oldScale;

    // 绘制背景网格
    final gridSpacing = 50.0 * scale; // 网格间距
    var backgroundLine = imagesBoardManager.backgroundLine;

    // 添加圆角矩形裁切
    final borderRadius = BorderRadius.circular(10); // 圆角半径
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      borderRadius.topLeft,
    );
    canvas.clipRRect(rrect);

// 绘制相同形状的边框
    final borderPaint = Paint()
      ..color = Colors.grey // 边框颜色
      ..strokeWidth = 2 // 边框宽度
      ..style = PaintingStyle.stroke; // 设置为描边样式
    canvas.drawRRect(rrect, borderPaint);

    final gridPaint = Paint()
      ..color = const Color.fromARGB(255, 198, 198, 198)
      ..strokeWidth = 1;
    double x1 = (backgroundLine.dx) % gridSpacing + globalOffset.dx;
    double y1 = (backgroundLine.dy) % gridSpacing + globalOffset.dy;
    while (x1 > 0) {
      x1 -= gridSpacing;
    }
    while (y1 > 0) {
      y1 -= gridSpacing;
    }
    for (double x = x1; x < size.width; x += gridSpacing) {
      for (double y = y1; y < size.height; y += gridSpacing) {
        canvas.drawCircle(
          Offset(x, y),
          3 * scale, // 格点半径
          gridPaint,
        );
      }
    }

    for (var area in imagesBoardManager.areas) {
      drawArea(canvas, area);
      drawLabels(area, canvas, globalOffset, scale);
    }

    for (var line in imagesBoardManager.lines) {
      drawLine(line, canvas, globalOffset, scale);
    }
    for (var item in ImagesBoardManager().imageItems) {
      if (item.image != null) {
        drawImg(item, canvas, mousePosition, globalOffset, scale * item.scale,
            scale / oldScale);
        drawLabels(item, canvas, globalOffset, scale * item.scale);
      }
    }
    if (ImagesBoardManager().showDeleteButton) {
      drawDeleteButton(canvas);
    }
    if (ImagesBoardManager().isCreatingArea) {
      drawCreatingArea(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    //todo: 优化性能
    return true;
  }
}
