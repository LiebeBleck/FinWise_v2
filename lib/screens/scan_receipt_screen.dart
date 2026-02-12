import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import '../models/receipt.dart';
import 'receipt_preview_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  String _selectedMethod = ''; // 'qr' или 'photo'
  MobileScannerController? _qrController;
  bool _isProcessing = false;

  @override
  void dispose() {
    _qrController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMethod.isEmpty) {
      return _buildMethodSelection();
    } else if (_selectedMethod == 'qr') {
      return _buildQRScanner();
    } else {
      // 'photo' method будет обрабатываться через _scanFromPhoto()
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _buildMethodSelection() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать чек'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Выберите способ сканирования',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Отсканируйте QR-код или сфотографируйте весь чек',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // QR-код кнопка
            _buildMethodButton(
              icon: Icons.qr_code_scanner,
              title: 'QR-код',
              subtitle: 'Быстрое сканирование',
              recommended: true,
              onTap: () {
                setState(() {
                  _selectedMethod = 'qr';
                  _qrController = MobileScannerController();
                });
              },
            ),
            const SizedBox(height: 16),

            // Фото чека кнопка
            _buildMethodButton(
              icon: Icons.camera_alt,
              title: 'Фото чека',
              subtitle: 'Распознавание текста',
              onTap: _scanFromPhoto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodButton({
    required IconData icon,
    required String title,
    required String subtitle,
    bool recommended = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: recommended ? AppTheme.primaryColor : Colors.grey.shade300,
              width: recommended ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Быстрее',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать QR-код'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedMethod = '';
              _qrController?.dispose();
              _qrController = null;
            });
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _qrController,
            onDetect: _onQRDetected,
          ),
          // Рамка для QR-кода
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Подсказка
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: const Text(
                'Наведите камеру на QR-код чека',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? qrData = barcode.rawValue;

    if (qrData == null || qrData.isEmpty) return;

    setState(() => _isProcessing = true);

    // Парсинг QR-кода
    try {
      final receipt = Receipt.fromQR(qrData);

      // Переход к экрану предпросмотра
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ReceiptPreviewScreen(receipt: receipt),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка парсинга QR: $e')),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _scanFromPhoto() async {
    final ImagePicker picker = ImagePicker();

    // Выбор источника
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите источник'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      setState(() => _selectedMethod = '');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile? image = await picker.pickImage(source: source);

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _selectedMethod = '';
        });
        return;
      }

      // OCR распознавание
      final inputImage = InputImage.fromFilePath(image.path);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final ocrText = recognizedText.text;

      if (ocrText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось распознать текст')),
          );
        }
        setState(() {
          _isProcessing = false;
          _selectedMethod = '';
        });
        return;
      }

      // Парсинг OCR текста
      final receipt = Receipt.fromOCR(ocrText);

      if (mounted) {
        // Переход к экрану предпросмотра
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReceiptPreviewScreen(receipt: receipt),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обработки фото: $e')),
        );
      }
      setState(() {
        _isProcessing = false;
        _selectedMethod = '';
      });
    }
  }
}
