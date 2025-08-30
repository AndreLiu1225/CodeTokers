import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_vision/google_vision.dart' as vision;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tf;
import 'package:image/image.dart' as img;

final GlobalKey repaintBoundaryKey = GlobalKey();

class LocationPrivacy extends StatefulWidget {
  const LocationPrivacy({super.key});

  @override
  State<LocationPrivacy> createState() => _LocationPrivacyState();
}

class _LocationPrivacyState extends State<LocationPrivacy> {
  File? imageFile;
  List<Rect> boxes = [];
  List<String> landmarksDetected = [];
  List<String> censoredTexts = [];
  List<Rect> licensePlateBoxes = [];

  final ImagePicker picker = ImagePicker();
  final TextRecognizer textRecognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
  );

  Future<void> pickImage() async {
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      log("No image selected");
      return;
    }

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await googleVisionCall(File(file.path));
    // await runYoloOnImage(File(file.path));

    // Extract bounding boxes of recognizedText
    List<Rect> localBoxes = [];
    for (final block in recognizedText.blocks) {
      localBoxes.add(block.boundingBox);
      censoredTexts.add(block.text);
    }
    log("Recognized ${localBoxes} text blocks");

    setState(() {
      imageFile = File(file.path);
      boxes = localBoxes;
    });
  }

  Rect boundingPolyToRect(List<Map<String, dynamic>> vertices) {
    if (vertices.isEmpty) return Rect.zero;

    // Get all x and y values
    final xs = vertices.map((v) => v['x']?.toDouble() ?? 0.0);
    final ys = vertices.map((v) => v['y']?.toDouble() ?? 0.0);

    final left = xs.reduce((a, b) => a < b ? a : b);
    final top = ys.reduce((a, b) => a < b ? a : b);
    final right = xs.reduce((a, b) => a > b ? a : b);
    final bottom = ys.reduce((a, b) => a > b ? a : b);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future googleVisionCall(File file) async {
    final bytes = await file.readAsBytes();
    final jsonImage = vision.JsonImage.fromBuffer(bytes.buffer);

    final googleVision = vision.GoogleVision().withApiKey(
      "AIzaSyC1gE3IaO6eLXKmJc1DsSSKSklFmUF5oX0",
    );
    final landmarkDetection = await googleVision.image.landmarkDetection(
      jsonImage,
    );

    for (var landmark in landmarkDetection) {
      log('Landmark: ${landmark.description}');
      log('Score: ${landmark.score}');
      log(
        'Bounding Poly: ${boundingPolyToRect(landmark.boundingPoly?.vertices.map((v) => {'x': v.x, 'y': v.y}).toList() ?? [])}',
      );
      landmarksDetected.add(landmark.description);
    }
  }

  Float32List imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 112 * 112 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 112; i++) {
      for (var j = 0; j < 112; j++) {
        int pixel = image.getPixel(j, i) as int;
        // Extract RGBA components from pixel value
        int r = (pixel >> 24) & 0xFF;
        int g = (pixel >> 16) & 0xFF;
        int b = (pixel >> 8) & 0xFF;

        // Normalize and store pixel values
        buffer[pixelIndex++] = (r - 128) / 128.0;
        buffer[pixelIndex++] = (g - 128) / 128.0;
        buffer[pixelIndex++] = (b - 128) / 128.0;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }

  Future runYoloOnImage(File imageFile) async {
    final interpreter = await tf.Interpreter.fromAsset('yolo11n.tflite');
    final bytes = await imageFile.readAsBytes();
    img.Image image = img.decodeImage(bytes)!;

    final inputImage = imageToByteListFloat32(image);

    var output = List.filled(1 * 25200 * 6, 0).reshape([1, 25200, 6]);

    interpreter.run(inputImage, output);

    for (var bbox in output[0]) {
      double xMin = bbox[0] * image.width;
      double yMin = bbox[1] * image.height;
      double xMax = bbox[2] * image.width;
      double yMax = bbox[3] * image.height;
      licensePlateBoxes.add(Rect.fromLTRB(xMin, yMin, xMax, yMax));
    }
  }

  Future<ui.Image> loadUiImage(File file) async {
    final data = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeaeceb),
      appBar: AppBar(backgroundColor: const Color(0xffeaeceb)),
      body:
          imageFile == null
              ? Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20,
                  top: 20,
                  bottom: 20,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: "You can ",
                        style: GoogleFonts.poppins(
                          textStyle: TextStyle(
                            color: const Color(0xff747a7a),
                            fontSize: 40,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        children: [
                          TextSpan(
                            text: "select ",
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: const Color(0xff000000),
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextSpan(
                            text:
                                "an image from your gallery to censor location data.",
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: const Color(0xff747a7a),
                                fontSize: 40,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Center(
                        child: GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffeaeceb),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xff212121),
                              ),
                            ),
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8.0, 8, 8, 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.cloud_upload),
                                  Text(
                                    "Select Image",
                                    style: GoogleFonts.poppins(
                                      textStyle: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8.0,
                                      20,
                                      8,
                                      0,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xffeaeceb),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: const Color(0xff212121),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "Browse Images",
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : FutureBuilder<ui.Image>(
                future: loadUiImage(imageFile!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RepaintBoundary(
                          key: repaintBoundaryKey,
                          child: CustomPaint(
                            foregroundPainter: CensorPainter(
                              boxes: boxes,
                              imageWidth: snapshot.data!.width.toDouble(),
                              imageHeight: snapshot.data!.height.toDouble(),
                            ),
                            child: Center(child: Image.file(imageFile!)),
                          ),
                        ),
                        Center(
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                RenderRepaintBoundary boundary =
                                    repaintBoundaryKey.currentContext!
                                            .findRenderObject()
                                        as RenderRepaintBoundary;

                                // Capture the widget as an image
                                ui.Image image = await boundary.toImage(
                                  pixelRatio: 3.0,
                                );
                                ByteData? byteData = await image.toByteData(
                                  format: ui.ImageByteFormat.png,
                                );

                                Uint8List pngBytes =
                                    byteData!.buffer.asUint8List();

                                // Save it to local storage
                                final directory =
                                    await getApplicationDocumentsDirectory();
                                final filePath =
                                    '${directory.path}/censored.png';
                                final file = File(filePath);

                                await file.writeAsBytes(pngBytes);
                                log("Saved censored image to $filePath");
                              } catch (e) {
                                log("Error saving: $e");
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xffeaeceb),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xff212121),
                                  ),
                                ),
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8.0,
                                    8,
                                    8,
                                    20,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.floppy_disk),
                                      Text(
                                        "Save Image",
                                        style: GoogleFonts.poppins(
                                          textStyle: TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0, top: 20.0),
                          child: Text(
                            "Texts Censored",
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 20.0,
                            top: 20.0,
                            right: 20,
                            bottom: 20,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffeaeaea),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xff212121),
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: censoredTexts.length,
                              itemBuilder: (context, index) {
                                return index % 2 == 0
                                    ? Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        right: 20.0,
                                        bottom: 10,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          censoredTexts[index],
                                          style: GoogleFonts.poppins(
                                            color: Colors.black,
                                            fontSize: 25,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    )
                                    : Padding(
                                      padding: const EdgeInsets.only(
                                        left: 20.0,
                                        bottom: 10,
                                      ),
                                      child: Text(
                                        "${censoredTexts[index]}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontSize: 25,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                              },
                            ),
                          ),
                        ),
                        landmarksDetected.isNotEmpty
                            ? Padding(
                              padding: const EdgeInsets.only(
                                left: 20.0,
                                top: 20.0,
                              ),
                              child: Text(
                                "Landmarks Detected (High Risk of Detection)",
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30,
                                ),
                              ),
                            )
                            : Padding(
                              padding: const EdgeInsets.only(
                                left: 20.0,
                                top: 20.0,
                              ),
                              child: Text(
                                "No landmarks detected",
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30,
                                ),
                              ),
                            ),
                        landmarksDetected.isNotEmpty
                            ? Padding(
                              padding: const EdgeInsets.only(
                                left: 20.0,
                                top: 20.0,
                                right: 20,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xffeaeaea),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xff212121),
                                  ),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: landmarksDetected.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        "- ${landmarksDetected[index]}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                            : const SizedBox(),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}

class CensorPainter extends CustomPainter {
  final List<Rect> boxes; // boxes from ML Kit (image pixel coords)
  final double imageWidth, imageHeight; // original image size in pixels

  CensorPainter({
    required this.boxes,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The Image is painted with BoxFit.contain inside `size`.
    final paint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;

    final scale = math.min(size.width / imageWidth, size.height / imageHeight);
    final drawnW = imageWidth * scale;
    final drawnH = imageHeight * scale;

    // Letterbox offsets (the empty margins around the centered image)
    final dx = (size.width - drawnW) / 2.0;
    final dy = (size.height - drawnH) / 2.0;

    for (final r in boxes) {
      final mapped = Rect.fromLTWH(
        dx + r.left * scale,
        dy + r.top * scale,
        r.width * scale,
        r.height * scale,
      );
      canvas.drawRect(mapped, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CensorPainter old) =>
      old.boxes != boxes ||
      old.imageWidth != imageWidth ||
      old.imageHeight != imageHeight;
}
