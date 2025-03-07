import 'dart:io';
import 'dart:typed_data';
import 'package:deepar_flutter/deepar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:pixora/constants/api_constants.dart';
import '../data/filter_data.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final deepArController = DeepArController();
  bool isRecording = false;

  Future<void> initializeController() async {
    await deepArController.initialize(
      androidLicenseKey: licenseKey,
      iosLicenseKey: '',
      resolution: Resolution.high,
    );
  }

  Future<bool> checkAndRequestPermissions({required bool skipIfExists}) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false; // Only Android and iOS platforms are supported
    }
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      if (skipIfExists) {
        // Read permission is required to check if the file already exists
        return sdkInt >= 33
            ? await Permission.photos.request().isGranted
            : await Permission.storage.request().isGranted;
      } else {
        // No read permission required for Android SDK 29 and above
        return sdkInt >= 29
            ? true
            : await Permission.storage.request().isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS permission for saving images to the gallery
      return skipIfExists
          ? await Permission.photos.request().isGranted
          : await Permission.photosAddOnly.request().isGranted;
    }
    return false; // Unsupported platforms
  }

  Future<void> captureAndSavePhoto() async {
    try {
      // Assuming takeScreenshot() returns a File
      File? imageFile = await deepArController.takeScreenshot();

      if (imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
        );
        return;
      }

      // Convert the File to Uint8List
      Uint8List imageData = await imageFile.readAsBytes();

      // Request storage permission
      final hasPermission =
          await checkAndRequestPermissions(skipIfExists: false);
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to save photo')),
        );
        return;
      }

      // Save the image to local storage
      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/pixora_${DateTime.now().millisecondsSinceEpoch}.png';
      File savedImageFile = File(imagePath);
      await savedImageFile.writeAsBytes(imageData);

      // Save to gallery
      final result = await SaverGallery.saveFile(
        filePath: imagePath,
        fileName: 'pixora_${DateTime.now().millisecondsSinceEpoch}.png',
        androidRelativePath: "Pictures/Pixora",
        skipIfExists: false,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved successfully')),
        );
      }
    } catch (e) {
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }

  Future<void> startRecording() async {
    try {
      final hasPermission =
          await checkAndRequestPermissions(skipIfExists: false);
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to save video')),
        );
        return;
      }

      await deepArController.startVideoRecording();
      setState(() {
        isRecording = true;
      });
    } catch (e) {
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> stopRecordingAndSave() async {
    try {
      final String? videoPath =
          (await deepArController.stopVideoRecording()) as String?;
      setState(() {
        isRecording = false;
      });

      if (videoPath != null) {
        // Request permissions before saving
        final hasPermission =
            await checkAndRequestPermissions(skipIfExists: false);
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied to save video')),
          );
          return;
        }

        final String fileName =
            "pixora_video_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final result = await SaverGallery.saveFile(
          androidRelativePath: "Movies/Pixora",
          skipIfExists: false,
          filePath: videoPath,
          fileName: fileName,
        );

        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video saved to gallery')),
          );
        }
      }
    } catch (e) {
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save video: $e')),
      );
    }
  }

  Widget buildButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            color: Colors.white,
            onPressed: deepArController.flipCamera,
            icon: const Icon(
              Icons.flip_camera_ios_outlined,
              size: 34,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: isRecording ? null : captureAndSavePhoto,
            onLongPress: isRecording ? null : startRecording,
            onLongPressUp: isRecording ? stopRecordingAndSave : null,
            child: FilledButton(
              onPressed: null, // Disable button's own tap handling
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                    isRecording ? Colors.red : Colors.white),
              ),
              child: Icon(
                isRecording ? Icons.videocam : Icons.camera,
              ),
            ),
          ),
          IconButton(
            onPressed: deepArController.toggleFlash,
            icon: const Icon(
              Icons.flash_on,
              size: 34,
              color: Colors.white,
            ),
          ),
        ],
      );

  Widget buildCameraPreview() => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Transform.scale(
          scale: 1.5,
          child: DeepArPreview(deepArController),
        ),
      );

  Widget buildFilters() => SizedBox(
        height: MediaQuery.of(context).size.height * 0.1,
        child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final effectFile =
                  File('assets/filters/${filter.filterPath}').path;
              return InkWell(
                onTap: () => deepArController.switchEffect(effectFile),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      image: DecorationImage(
                        image:
                            AssetImage('assets/previews/${filter.imagePath}'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            }),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: initializeController(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                buildCameraPreview(),
                buildButtons(),
                buildFilters(),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
