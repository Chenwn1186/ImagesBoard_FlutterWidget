import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class FloatingComponentController {
  // 静态私有实例变量
  static final FloatingComponentController _instance =
      FloatingComponentController._internal();

  // 私有构造函数
  FloatingComponentController._internal();

  // 静态访问方法
  static FloatingComponentController get instance => _instance;

  Future<void> showAddLabelDialog(
    BuildContext context,
    void Function(String, Color, Color) onSubmitted,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return FloatingComponent(
          onSubmitted: onSubmitted,
        );
      },
    );
  }

  // 移除了 hideOverlay 方法，因为对话框会自动关闭
}

class FloatingComponent extends StatefulWidget {
  final void Function(String, Color, Color) onSubmitted;

  const FloatingComponent({
    super.key,
    required this.onSubmitted,
  });

  @override
  FloatingComponentState createState() => FloatingComponentState();
}

class FloatingComponentState extends State<FloatingComponent> {
  Color textColor = Colors.black;
  Color bgColor = const Color.fromARGB(255, 255, 255, 255);
  TextEditingController textEditingController = TextEditingController();
  // 创建 FocusNode
  FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 在组件初始化完成后，使用 Future.microtask 确保在 build 方法执行后再请求焦点
    Future.microtask(() {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }

  @override
  void dispose() {
    // 释放 FocusNode
    focusNode.dispose();
    textEditingController.dispose();
    super.dispose();
  }

  void _onBGColorChanged(Color color) {
    setState(() {
      bgColor = color;
    });
  }

  void _onTextColorChanged(Color color) {
    setState(() {
      textColor = color;
    });
  }

  // 弹出颜色选择器的函数
  Future<void> _showColorPicker(void Function(Color) onColorCHanged) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: const Text('选择颜色')),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: Colors.blue,
              onColorChanged: onColorCHanged,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(context) {
    return AlertDialog(
      title: Center(child: const Text('输入标签')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 50,
                child: TextField(
                  // 将 FocusNode 关联到 TextField
                  focusNode: focusNode,
                  controller: textEditingController,
                  onChanged: (value) {},
                  onSubmitted: (value) {
                    widget.onSubmitted(
                        textEditingController.text, bgColor, textColor);
                    textEditingController.clear();
                    Navigator.of(context).pop();
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  _showColorPicker(_onTextColorChanged);
                },
                icon: Icon(
                  Icons.text_format,
                  color: textColor,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: const Color.fromARGB(255, 84, 84, 84),
                      offset: Offset(0.0, 0.0),
                    )
                  ],
                ),
                tooltip: '文字颜色',
              ),
              IconButton(
                onPressed: () {
                  _showColorPicker(_onBGColorChanged);
                },
                icon: Icon(
                  Icons.format_color_fill,
                  color: bgColor,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: const Color.fromARGB(255, 100, 100, 100),
                      offset: Offset(0.0, 0.0),
                    )
                  ],
                ),
                tooltip: '背景颜色',
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            textEditingController.clear();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (textEditingController.text.isNotEmpty) {
              widget.onSubmitted(
                  textEditingController.text, bgColor, textColor);
            }
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
