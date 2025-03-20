import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:simple_canvas/images_board.dart';
import 'package:simple_canvas/images_board_item_img.dart';

class DraggableImage extends StatefulWidget {
  const DraggableImage({
    super.key,
    required this.width,
    required this.height,
    required this.imgPath,
    required this.onTap,
    required this.onRightTap,
    this.isSelected = false,
  });

  final double width;
  final double height;
  final String imgPath;
  final void Function() onTap;
  final void Function() onRightTap;
  final bool isSelected;
  @override
  State<StatefulWidget> createState() {
    return _DraggableImageState();
  }
}

class _DraggableImageState extends State<DraggableImage> {
  bool isDragging = false;
  Offset draggingPosition = Offset.zero;
  Offset globalDraggingPosition = Offset.zero;
  Offset firstDraggingPosition = Offset.zero;
  Offset globalFirstDraggingPosition = Offset.zero;
  double scale = 1.0; // 新增变量，用于控制缩放比例

  bool isSelected = false;

  double draggingAreaWidth = 0;
  double draggingAreaHeight = 0;
  Offset draggingAreaOffset = Offset.zero;

  bool inDraggingImageArea(Offset globalPoint) {
    // 将全局坐标转换为局部坐标
    var localOffset = globalPoint - draggingAreaOffset;
    return localOffset.dy >= 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ImagesBoardManager().loadImage(widget.imgPath),
      builder: (BuildContext context, AsyncSnapshot<ui.Image> img) {
        isSelected = widget.isSelected;
        if(mounted) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            draggingAreaWidth = renderBox.size.width;
            draggingAreaHeight = renderBox.size.height;
            draggingAreaOffset = renderBox.localToGlobal(Offset.zero);
          } else {
            print('renderBox is null');
          }
        });
        }
        if (img.hasData) {
          return MouseRegion(
            onEnter: (_) {
              if (!isDragging) {
                setState(() {
                  scale = 2.5;
                });
              }
            },
            onExit: (_) {
              if (!isDragging) {
                setState(() {
                  scale = 1.0;
                });
              }
            },
            child: Listener(
              onPointerDown: (event) {
                setState(() {
                  if (event.buttons == 1) {
                    widget.onTap();
                    isSelected = true;
                  } else if (event.buttons == 2) {
                    widget.onRightTap();
                    isSelected = false;
                  }
                  draggingPosition = event.localPosition;
                  globalDraggingPosition = event.position;
                  firstDraggingPosition = event.localPosition;
                  globalFirstDraggingPosition = event.position;
                  // scale = 2.5;
                });
              },
              onPointerUp: (event) {
                if (isDragging) {
                  setState(() {
                    isDragging = false;
                    double localScale = min(
                      (widget.width - 15) / img.data!.width,
                      (widget.height - 15) / img.data!.height,
                    );
                    var scaleImgWidth = img.data!.width.toDouble() * localScale;
                    var scaleImgHeight =
                        img.data!.height.toDouble() * localScale;
                    var centerXOffset = (widget.width - scaleImgWidth) / 2;
                    var centerYOffset = (widget.height - scaleImgHeight) / 2;
                    Offset center = Offset(
                      globalDraggingPosition.dx -
                          firstDraggingPosition.dx +
                          centerXOffset +
                          scaleImgWidth / 2,
                      globalDraggingPosition.dy -
                          firstDraggingPosition.dy +
                          centerYOffset +
                          scaleImgHeight / 2 -
                          (scale * widget.height - widget.height) / 2,
                    );
                    var inBoardArea =
                        ImagesBoardManager().inBoardArea(event.position);
                    if (inBoardArea && !inDraggingImageArea(event.position)) {
                      var imageItem = ImageItem(
                        imgPath: widget.imgPath,
                        globalPosition: center,
                        scale: 1 / ImagesBoardManager().scale,
                        width: scaleImgWidth * scale,
                        height: scaleImgHeight * scale,
                        image: img.data!,
                        code: DateTime.now().millisecondsSinceEpoch,
                      );
                      ImagesBoardManager().addImageItem(imageItem);
                    }
                    scale = 1.0;
                  });
                }
              },
              onPointerMove: (event) {
                if (event.buttons == 1) {
                  isDragging = true;
                  setState(() {
                    draggingPosition = event.localPosition;
                    globalDraggingPosition = event.position;
                    // scale = 2.5;
                  });
                }
              },
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 140),
                alignment: Alignment.bottomCenter,
                curve: Curves.easeOut,
                child: CustomPaint(
                  painter: DraggableImagePainter(
                    image: img.data!,
                    isDragging: isDragging,
                    draggingPosition: draggingPosition,
                    imgWidth: widget.width,
                    imgHeight: widget.height,
                    firstDraggingPositon: firstDraggingPosition,
                    scale: scale, // 传递当前缩放比例
                    isSelected: isSelected,
                  ),
                  size: Size(widget.width, widget.height),
                ),
              ),
            ),
          );
        }
        return Container();
      },
    );
  }
}

class DraggableImagePainter extends CustomPainter {
  ui.Image image;
  bool isDragging;
  Offset draggingPosition;
  Offset firstDraggingPositon;
  double imgWidth;
  double imgHeight;
  double scale; // 新增参数，用于接收当前缩放比例
  bool isSelected;

  DraggableImagePainter({
    required this.image,
    this.isDragging = false,
    this.draggingPosition = Offset.zero,
    this.imgWidth = 100,
    this.imgHeight = 100,
    this.firstDraggingPositon = Offset.zero,
    required this.scale, // 新增参数
    required this.isSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Rect src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    double localScale = min(
      (imgWidth - 15) / image.width,
      (imgHeight - 15) / image.height,
    );
    var scaleImgWidth = image.width.toDouble() * localScale;
    var scaleImgHeight = image.height.toDouble() * localScale;
    Rect dst = Rect.fromLTWH(
      (imgWidth - scaleImgWidth) / 2,
      (imgHeight - scaleImgHeight) / 2,
      scaleImgWidth,
      scaleImgHeight,
    );
    RRect rrect = RRect.fromRectAndRadius(dst, Radius.circular(10));

    Rect shadowRec =
        Rect.fromLTWH(dst.left, dst.top, scaleImgWidth, scaleImgHeight);
    var shadowRRec = RRect.fromRectAndRadius(shadowRec, Radius.circular(10));
    canvas.drawRRect(
      shadowRRec,
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 如果 isSelected 为 true，绘制蓝色边缘
    if (isSelected) {
      var borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rrect, borderPaint);
    }

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawImageRect(image, src, dst, Paint());
    canvas.restore();

    // 绘制静止图片下的小蓝点
    if (isSelected) {
      var blueDotPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      var blueDotRadius = 3.0;
      var blueDotOffset = Offset(
        dst.left + dst.width / 2,
        dst.bottom + blueDotRadius * 2,
      );
      canvas.drawCircle(blueDotOffset, blueDotRadius, blueDotPaint);
    }

    if (isDragging) {
      var draggingDx = draggingPosition.dx;
      var draggingDy = draggingPosition.dy;

      // 考虑缩放比例
      var scaledDraggingDx = (draggingDx - firstDraggingPositon.dx) / scale;
      var scaledDraggingDy = (draggingDy - firstDraggingPositon.dy) / scale;

      dst = Rect.fromLTWH(
        scaledDraggingDx + dst.left,
        scaledDraggingDy + dst.top,
        dst.width,
        dst.height,
      );
      RRect rrect = RRect.fromRectAndRadius(dst, Radius.circular(10));

      Rect shadowRec = Rect.fromLTWH(dst.left, dst.top, dst.width, dst.height);
      var shadowRRec = RRect.fromRectAndRadius(shadowRec, Radius.circular(10));
      canvas.drawRRect(
        shadowRRec,
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
      );

      // 如果 isSelected 为 true，绘制蓝色边缘
      if (isSelected) {
        var borderPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(rrect, borderPaint);
      }

      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(image, src, dst, Paint());
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
