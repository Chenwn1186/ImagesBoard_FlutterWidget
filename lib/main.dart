import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:simple_canvas/draggable_image.dart';
import 'package:simple_canvas/images_board.dart';
import 'file_utils.dart';
// 在文件顶部添加
// ... 已有导入 ...



void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImagesBoardManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ImagePickerScreen(),
    );
  }
}

// 修改界面显示部分
class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ImagePickerScreenState();
  }
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  List<String>? imagePaths = []; // 存储选择的图片路径
  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.sizeOf(context).width;
    var height = MediaQuery.sizeOf(context).height;

    return Scaffold(
      appBar: AppBar(title: const Text('白板测试')),
      body: Stack(
        children: [
          SizedBox(
            width: width,
            height: height,
            child: ImagesBoard(
              width: width,
              height: height,
            ),
          ),
          Positioned(
            bottom: 300,
            child: IconButton(
                onPressed: () async {
                  var paths = FileUtils.pickFile(context);
                  paths.then((imgPaths) {
                    setState(() {
                      if(imgPaths == null) return;
                      imagePaths!.addAll(imgPaths);
                    });
                  });
                },
                icon: Icon(Icons.add)),
          ),
          Positioned(
            bottom: 10,
            child: Container(
              height: 100,
              width: width,
              color: const Color.fromARGB(178, 255, 255, 255),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: imagePaths?.length ?? 0,
                itemBuilder: (BuildContext context, int index) {
                  return DraggableImage(
                      width: 100, height: 100, imgPath: imagePaths![index], onTap: (){}, onRightTap: () {  },);
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}

