import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_preview_screen.dart';
import 'skill_picker_dialog.dart';
import 'availability_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  // Profile data
  String? _profilePictureUrl;
  XFile? _selectedImage;
  List<String> _skillsToTeach = [];
  List<String> _skillsToLearn = [];
  List<Map<String, dynamic>> _availability = [];
  double _averageRating = 0.0;

  // Available skills for selection
  List<String> _availableSkills = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAvailableSkills();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSkills() async {
    try {
      final response = await _supabase
          .from('skills')
          .select('name')
          .order('name');

      setState(() {
        _availableSkills = (response as List)
            .map((skill) => skill['name'] as String)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading skills: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        _showError('User not authenticated');
        return;
      }

      // Load profile and user data
      final profileResponse = await _supabase
          .from('profiles')
          .select(
            'bio, profile_picture_url, location, phone_number, average_rating',
          )
          .eq('id', userId)
          .maybeSingle();

      final userResponse = await _supabase
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();

      // Load user skills with proper join syntax
      final skillsData = await _supabase
          .from('user_skills')
          .select('''
            skill_id,
            skill_level,
            skills!inner(name)
          ''')
          .eq('user_id', userId);

      // Load availability
      final availabilityData = await _supabase
          .from('availability')
          .select(
            'day_of_week, start_time, end_time, is_recurring, date_specific',
          )
          .eq('user_id', userId);

      setState(() {
        // Handle potentially null profile data
        if (userResponse != null) {
          _nameController.text = userResponse['name'] ?? '';
        }

        if (profileResponse != null) {
          _bioController.text = profileResponse['bio'] ?? '';
          _locationController.text = profileResponse['location'] ?? '';
          _phoneController.text = profileResponse['phone_number'] ?? '';
          _profilePictureUrl = profileResponse['profile_picture_url'];
          _averageRating = (profileResponse['average_rating'] ?? 0.0)
              .toDouble();
        }

        // Separate skills by level
        _skillsToTeach = (skillsData as List)
            .where((s) => s['skill_level'] == 'TEACH')
            .map((s) => s['skills']['name'] as String)
            .toList();

        _skillsToLearn = (skillsData as List)
            .where((s) => s['skill_level'] == 'LEARN')
            .map((s) => s['skills']['name'] as String)
            .toList();

        _availability = (availabilityData as List)
            .map(
              (a) => {
                'day_of_week': a['day_of_week'],
                'start_time': a['start_time'],
                'end_time': a['end_time'],
                'is_recurring': a['is_recurring'] ?? true,
                'date_specific': a['date_specific'],
              },
            )
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading profile: $e');
      debugPrint('Profile load error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  Future<String?> _uploadProfilePicture() async {
    if (_selectedImage == null) return _profilePictureUrl;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final fileExt = _selectedImage!.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      // Organize by user ID folder for better security
      final filePath = '$userId/$fileName';

      // Read file as bytes for cross-platform compatibility
      final bytes = await _selectedImage!.readAsBytes();

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/${fileExt == 'jpg' ? 'jpeg' : fileExt}',
            ),
          );

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      _showError('Error uploading image: $e');
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Upload image if selected
      String? newProfilePictureUrl;
      if (_selectedImage != null) {
        newProfilePictureUrl = await _uploadProfilePicture();
      }

      // Prepare availability data
      final availabilityJson = _availability
          .map(
            (a) => {
              'day_of_week': a['day_of_week'],
              'start_time': a['start_time'],
              'end_time': a['end_time'],
              'is_recurring': a['is_recurring'],
              'date_specific': a['date_specific'],
            },
          )
          .toList();

      // Call the upsert function
      await _supabase.rpc(
        'upsert_user_profile',
        params: {
          'p_user_id': userId,
          'p_name': _nameController.text.trim(),
          'p_bio': _bioController.text.trim().isEmpty
              ? null
              : _bioController.text.trim(),
          'p_location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'p_phone_number': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'p_profile_picture_url': newProfilePictureUrl ?? _profilePictureUrl,
          'p_skills_to_teach': _skillsToTeach,
          'p_skills_to_learn': _skillsToLearn,
          'p_availability': availabilityJson,
        },
      );

      setState(() {
        _isSaving = false;
        _selectedImage = null;
        if (newProfilePictureUrl != null) {
          _profilePictureUrl = newProfilePictureUrl;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error saving profile: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _addSkill(bool isTeach) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SkillPickerDialog(
        availableSkills: _availableSkills,
        selectedSkills: isTeach ? _skillsToTeach : _skillsToLearn,
      ),
    );

    if (result != null) {
      setState(() {
        if (isTeach) {
          _skillsToTeach.add(result);
        } else {
          _skillsToLearn.add(result);
        }
      });
    }
  }

  void _addAvailability() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AvailabilityDialog(),
    );

    if (result != null) {
      setState(() {
        _availability.add(result);
      });
    }
  }

  void _showProfilePreview() async {
    // Get the current image for preview
    Uint8List? imageBytes;
    if (_selectedImage != null) {
      imageBytes = await _selectedImage!.readAsBytes();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePreviewScreen(
          name: _nameController.text.trim().isEmpty
              ? 'Your Name'
              : _nameController.text.trim(),
          bio: _bioController.text.trim(),
          location: _locationController.text.trim(),
          profilePictureUrl: _profilePictureUrl,
          selectedImageBytes: imageBytes,
          skillsToTeach: _skillsToTeach,
          skillsToLearn: _skillsToLearn,
          averageRating: _averageRating,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _showProfilePreview,
            icon: const Icon(Icons.visibility, color: Colors.white),
            label: const Text('Preview', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
        backgroundColor: _isSaving ? Colors.grey : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  FutureBuilder<Uint8List?>(
                    future: _selectedImage?.readAsBytes(),
                    builder: (context, snapshot) {
                      return CircleAvatar(
                        radius: 60,
                        backgroundImage: snapshot.hasData
                            ? MemoryImage(snapshot.data!)
                            : (_profilePictureUrl != null
                                      ? NetworkImage(_profilePictureUrl!)
                                      : null)
                                  as ImageProvider?,
                        child: !snapshot.hasData && _profilePictureUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Bio
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // Optional: Add phone validation
                  if (!RegExp(r'^\+?[0-9\s\-\(\)]+$').hasMatch(value)) {
                    return 'Invalid phone number format';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Skills to Teach
            _buildSkillSection('Skills to Teach', _skillsToTeach, true),
            const SizedBox(height: 24),

            // Skills to Learn
            _buildSkillSection('Skills to Learn', _skillsToLearn, false),
            const SizedBox(height: 24),

            // Availability
            _buildAvailabilitySection(),
            const SizedBox(height: 80), // Extra space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSkillSection(String title, List<String> skills, bool isTeach) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: () => _addSkill(isTeach),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: skills
              .map(
                (skill) => Chip(
                  label: Text(skill),
                  onDeleted: () {
                    setState(() => skills.remove(skill));
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Availability', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: _addAvailability,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_availability.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No availability set. Add your available times.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ..._availability.map((avail) {
            final isRecurring = avail['is_recurring'] ?? true;
            final dateSpecific = avail['date_specific'];

            String subtitle = '${avail['start_time']} - ${avail['end_time']}';
            String title = avail['day_of_week'];

            if (!isRecurring && dateSpecific != null) {
              // Parse and format the specific date
              final date = DateTime.parse(dateSpecific);
              title =
                  '${date.day}/${date.month}/${date.year} (${avail['day_of_week']})';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isRecurring ? Icons.repeat : Icons.event,
                  color: isRecurring ? Colors.blue : Colors.green,
                ),
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() => _availability.remove(avail));
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}
