import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key});

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final name = TextEditingController();
  final species = TextEditingController();
  final breed = TextEditingController();
  final age = TextEditingController();
  final photo = TextEditingController();
  bool saving = false;
  bool uploading = false;
  PetModel? editing;

  static const List<Map<String, String>> _petPresets = [
    {
      'label': 'Golden Retriever',
      'url': 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Playful Puppy',
      'url': 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Husky',
      'url': 'https://images.unsplash.com/photo-1605568427561-40dd23c2acea?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Bulldog',
      'url': 'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Fluffy Cat',
      'url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Orange Tabby',
      'url': 'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Cute Rabbit',
      'url': 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?w=400&auto=format&fit=crop&q=80',
    },
    {
      'label': 'Parrot / Bird',
      'url': 'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=400&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    editing = Get.arguments is PetModel ? Get.arguments as PetModel : null;
    final p = editing;
    if (p != null) {
      name.text = p.name;
      species.text = p.species;
      breed.text = p.breed ?? '';
      age.text = p.age?.toString() ?? '';
      photo.text = p.photoUrl ?? '';
    }
  }

  @override
  void dispose() {
    name.dispose();
    species.dispose();
    breed.dispose();
    age.dispose();
    photo.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => uploading = true);
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 80,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          photo.text = base64String;
        });
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Get.snackbar(
          'Photo Updated',
          'Pet picture selected successfully.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Photo Selection Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _openPhotoPicker() {
    final customUrlController = TextEditingController(text: photo.text.startsWith('data:') ? '' : photo.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: .4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose Pet Photo',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // File / Camera Upload Options
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppTheme.green, width: 1.5),
                      ),
                      icon: const Icon(Icons.photo_library, color: AppTheme.green),
                      label: const Text(
                        'Upload File / Gallery',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.camera_alt, color: AppTheme.ink),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Text(
                'Or Choose Quick Avatar',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _petPresets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final preset = _petPresets[index];
                    final isSelected = photo.text == preset['url'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          photo.text = preset['url']!;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppTheme.green : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: PetAvatar(
                              photoUrl: preset['url'],
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preset['label']!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Or Image Web Link',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: customUrlController,
                decoration: InputDecoration(
                  hintText: 'https://example.com/pet.jpg',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle, color: AppTheme.green),
                    onPressed: () {
                      setState(() {
                        photo.text = customUrlController.text.trim();
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    photo.text = customUrlController.text.trim();
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply Web Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxCardWidth = math.min(screenWidth * 0.95, 520.0);

    return Scaffold(
      appBar: AppBar(title: Text(editing == null ? 'Add Pet' : 'Edit Pet')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _openPhotoPicker,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.green,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: PetAvatar(
                                photoUrl: photo.text,
                                size: 96,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _openPhotoPicker,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(
                          photo.text.isEmpty ? 'Upload Photo' : 'Change Photo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Pet Name',
                        prefixIcon: Icon(Icons.pets),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: species,
                      decoration: const InputDecoration(
                        labelText: 'Species (e.g. Dog, Cat)',
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: breed,
                      decoration: const InputDecoration(
                        labelText: 'Breed',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age (years)',
                        prefixIcon: Icon(Icons.cake),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: saving ? null : () => _save(data),
                      child: Text(saving ? 'Saving...' : (editing == null ? 'Create Pet' : 'Save Changes')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(AppDataController data) async {
    setState(() => saving = true);
    final body = {
      'name': name.text.trim(),
      'species': species.text.trim(),
      'breed': breed.text.trim().isEmpty ? null : breed.text.trim(),
      'age': int.tryParse(age.text),
      'photo_url': photo.text.trim().isEmpty ? null : photo.text.trim(),
    };
    try {
      if (editing == null) {
        await data.petsRepo.create(body);
      } else {
        await data.petsRepo.update(editing!.id, body);
      }
      await data.refreshAll();
      Get.offNamed(Routes.pets);
    } catch (e) {
      Get.snackbar('Save failed', e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}
