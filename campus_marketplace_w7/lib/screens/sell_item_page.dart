import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_vision_service.dart';
import '../models/listing_draft.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;

  // Controller สำหรับช่องกรอกข้อมูลทั้ง 3 ช่อง (ให้ผู้ใช้ตรวจสอบและแก้ไขได้ตามหลัก Human-in-the-loop)
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _visionService = GeminiVisionService();

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _errorMessage = null;
      // ล้างข้อมูลในฟอร์มเก่าเมื่อเปลี่ยนรูปใหม่
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกรูปภาพสินค้าก่อนให้ AI วิเคราะห์'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final draft = await _visionService.analyzeProductImage(_selectedImage!);

      // นำค่าที่ AI แนะนำมาใส่ลงใน TextField ทันทีเพื่อให้ผู้ใช้ตรวจสอบและแก้ไขได้
      setState(() {
        _titleController.text = draft.title;
        _categoryController.text = draft.category;
        _descriptionController.text = draft.description;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันยืนยันร่างประกาศ
  void _confirmDraft() {
    if (_titleController.text.isEmpty || _categoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลชื่อและหมวดหมู่ให้ครบถ้วน'),
        ),
      );
      return;
    }

    // แสดง SnackBar ยืนยันความสำเร็จตามโจทย์
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกร่างประกาศเรียบร้อยแล้ว')),
    );

    // ล้างฟอร์มและรูปภาพกลับสู่สถานะว่างเปล่าพร้อมเริ่มลงประกาศใหม่
    setState(() {
      _selectedImage = null;
      _titleController.clear();
      _categoryController.clear();
      _descriptionController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลงประกาศขายสินค้า')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // แสดงรูปภาพตัวอย่าง
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ยังไม่ได้เลือกรูปภาพสินค้า',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // ปุ่มเลือกรูปภาพ
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('เลือกรูปภาพสินค้า'),
            ),
            const SizedBox(height: 12),

            // ปุ่มให้ AI ช่วยแนะนำ
            ElevatedButton.icon(
              onPressed: (_selectedImage == null || _isLoading)
                  ? null
                  : _analyzeImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('ให้ AI ช่วยแนะนำ'),
            ),
            const SizedBox(height: 16),

            // แสดงสถานะ Loading
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'AI กำลังวิเคราะห์ภาพสินค้า...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // แสดง Error ถ้ามี
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'เกิดข้อผิดพลาด: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ฟอร์มสำหรับตรวจสอบและแก้ไขข้อมูล (TextFormField 3 ช่อง)
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่อประกาศสินค้า',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'หมวดหมู่',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'คำบรรยายสินค้า',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),

            // ปุ่มยืนยันร่างประกาศ
            ElevatedButton.icon(
              onPressed: _titleController.text.isEmpty && _selectedImage == null
                  ? null
                  : _confirmDraft,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text(
                'ยืนยันร่างประกาศ',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
