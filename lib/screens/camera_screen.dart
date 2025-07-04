import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  XFile? _imageFile;
  bool _isProcessing = false;
  List? _recognitions;
  
  final Map<String, String> fruitInfo = {
    'Apple': '🍎 Calories: 52\nRich in fiber and vitamin C',
    'Avocado': '🥑 Calories: 160\nRich in healthy fats and potassium',
    'Banana': '🍌 Calories: 89\nGood source of potassium and vitamin B6',
    'Cherry': '🍒 Calories: 50\nContains antioxidants and vitamin C',
    'Kiwi': '🥝 Calories: 61\nRich in vitamin C and K',
    'Mango': '🥭 Calories: 60\nRich in vitamin A and C',
    'Orange': '🍊 Calories: 47\nExcellent source of vitamin C',
    'Pineapple': '🍍 Calories: 50\nContains bromelain enzyme',
    'Strawberries': '🍓 Calories: 32\nRich in antioxidants and vitamin C',
    'Watermelon': '🍉 Calories: 30\nHydrating and rich in lycopene',
  };

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/model/model_unquant.tflite",
        labels: "assets/model/labels.txt",
      );
    } catch (e) {
      _showError('Failed to load model: ${e.toString()}');
    }
  }

  Future<void> _processImage(File image) async {
    if (!mounted) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final imageBytes = await image.readAsBytes();
      final imageTemp = img.decodeImage(imageBytes);
      final imageResized = img.copyResize(imageTemp!, width: 224, height: 224);
      
      final recognitions = await Tflite.runModelOnBinary(
        binary: Uint8List.fromList(img.encodeJpg(imageResized)),
        numResults: 1,
        threshold: 0.5,
      );
      
      if (!mounted) return;
      
      setState(() {
        _recognitions = recognitions;
        _isProcessing = false;
      });
    } catch (e) {
      _showError('Image processing error: ${e.toString()}');
    }
  }

  Future<void> _takePicture() async {
    try {
      final status = await Permission.camera.request();
      
      if (status.isGranted) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          setState(() => _imageFile = image);
          await _processImage(File(image.path));
        }
      } else {
        _showError('Camera permission required');
      }
    } catch (e) {
      _showError('Camera error: ${e.toString()}');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final status = await Permission.photos.request();
      
      if (status.isGranted) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          setState(() => _imageFile = image);
          await _processImage(File(image.path));
        }
      } else {
        _showError('Gallery access required');
      }
    } catch (e) {
      _showError('Gallery error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildResultCard() {
    if (_recognitions == null || _recognitions!.isEmpty) return Container();

    final label = _recognitions![0]['label'].toString().split(' ')[1];
    final confidence = _recognitions![0]['confidence'] * 100;

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '🍎 $label',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${confidence.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                fruitInfo[label] ?? 'No information available',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fruit Recognition'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _isProcessing ? null : _pickFromGallery,
            tooltip: 'Choose from gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_imageFile != null)
            Center(
              child: Image.file(
                File(_imageFile!.path),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No image captured',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
          if (_recognitions != null && _recognitions!.isNotEmpty)
            _buildResultCard(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _takePicture,
        tooltip: 'Take picture',
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}