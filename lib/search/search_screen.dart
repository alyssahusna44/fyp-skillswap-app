// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/user_profile_view_screen.dart';

class SearchScreen extends StatefulWidget {
  // Add these optional parameters
  final String? initialSkillName;
  final String? initialSkillLevel;

  const SearchScreen({
    super.key, 
    this.initialSkillName, 
    this.initialSkillLevel,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<String> _availableSkills = [];

  bool _isLoading = false;
  bool _isInitialLoad = true;

  // Filter states
  String? _selectedSkillFilter;
  String? _selectedLocationFilter;
  String _skillLevelFilter = 'ALL'; // ALL, TEACH, LEARN

  @override
  void initState() {
    super.initState();
    _selectedSkillFilter = widget.initialSkillName;
    _skillLevelFilter = widget.initialSkillLevel ?? 'ALL';
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // Load all available skills
      final skillsResponse = await _supabase
          .from('skills')
          .select('name')
          .order('name');

      setState(() {
        _availableSkills = (skillsResponse as List)
            .map((skill) => skill['name'] as String)
            .toList();
        _isInitialLoad = false;
      });

      // Load initial results (all users)
      await _performSearch();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // STEP 1: Get profiles
      var profileQuery = _supabase.from('profiles').select('''
            id,
            bio,
            location,
            profile_picture_url,
            average_rating
          ''');

      // Exclude current user
      if (currentUserId != null) {
        profileQuery = profileQuery.neq('id', currentUserId);
      }

      // Apply location filter
      if (_selectedLocationFilter != null &&
          _selectedLocationFilter!.isNotEmpty) {
        profileQuery = profileQuery.ilike(
          'location',
          '%$_selectedLocationFilter%',
        );
      }

      final profilesData = await profileQuery;

      // STEP 2: Get all user names in one query
      final userIds = (profilesData as List).map((p) => p['id']).toList();

      final usersData = await _supabase
          .from('users')
          .select('id, name')
          .inFilter('id', userIds);

      // Create a map for quick lookup
      final usersMap = {
        for (var user in usersData as List) user['id']: user['name'],
      };

      // STEP 3: Process each profile
      List<Map<String, dynamic>> results = [];

      for (var profile in profilesData) {
        final userId = profile['id'];
        final userName = usersMap[userId] ?? 'Unknown';

        // Apply text search filter on name
        if (_searchController.text.isNotEmpty &&
            !userName.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            )) {
          continue;
        }

        // Get user skills
        var skillsQuery = _supabase
            .from('user_skills')
            .select('''
              skill_level,
              skills!inner(name)
            ''')
            .eq('user_id', userId);

        // Apply skill level filter
        if (_skillLevelFilter != 'ALL') {
          skillsQuery = skillsQuery.eq('skill_level', _skillLevelFilter);
        }

        final skillsData = await skillsQuery;

        // Apply skill name filter
        if (_selectedSkillFilter != null && _selectedSkillFilter!.isNotEmpty) {
          final hasSkill = (skillsData as List).any(
            (s) => s['skills']['name'] == _selectedSkillFilter!,
          );
          if (!hasSkill) {
            continue;
          }
        }

        // Only include users who match skill filters (if any applied)
        if ((_selectedSkillFilter != null &&
                _selectedSkillFilter!.isNotEmpty) ||
            _skillLevelFilter != 'ALL') {
          if ((skillsData as List).isEmpty) {
            continue;
          }
        }

        // Separate skills by level
        final skillsToTeach = (skillsData as List)
            .where((s) => s['skill_level'] == 'TEACH')
            .map((s) => s['skills']['name'] as String)
            .toList();

        final skillsToLearn = (skillsData as List)
            .where((s) => s['skill_level'] == 'LEARN')
            .map((s) => s['skills']['name'] as String)
            .toList();

        results.add({
          'id': userId,
          'name': userName,
          'bio': profile['bio'],
          'location': profile['location'],
          'profile_picture_url': profile['profile_picture_url'],
          'average_rating': profile['average_rating'],
          'skills_to_teach': skillsToTeach,
          'skills_to_learn': skillsToLearn,
        });
      }

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint('Error performing search: $e');
      _showError('Search failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSkillFilter = null;
      _selectedLocationFilter = null;
      _skillLevelFilter = 'ALL';
      _searchController.clear();
    });
    _performSearch();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterBottomSheet(
        availableSkills: _availableSkills,
        selectedSkill: _selectedSkillFilter,
        selectedLocation: _selectedLocationFilter,
        skillLevel: _skillLevelFilter,
        onApply: (skill, location, level) {
          setState(() {
            _selectedSkillFilter = skill;
            _selectedLocationFilter = location;
            _skillLevelFilter = level;
          });
          _performSearch();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Skills'), elevation: 0),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
                const SizedBox(height: 12),

                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter button
                      ActionChip(
                        avatar: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).primaryColor, // Uses the dark blue (#114A99)
                        ),
                        label: Text(
                          'Filters',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).primaryColor, // Uses the dark blue (#114A99)
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // backgroundColor uses the accent color (#FEBD59) defined in main.dart
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondary,
                        onPressed: _showFilterDialog,
                        side: BorderSide
                            .none, // Removes the border for a cleaner look
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Active filter chips (Updated for better readability)
                      if (_selectedSkillFilter != null) ...[
                        Chip(
                          label: Text(
                            _selectedSkillFilter!,
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          deleteIcon: Icon(
                            Icons.close,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          onDeleted: () {
                            setState(() => _selectedSkillFilter = null);
                            _performSearch();
                          },
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                        ),
                        const SizedBox(width: 8),
                      ],

                      if (_skillLevelFilter != 'ALL') ...[
                        Chip(
                          label: Text(
                            _skillLevelFilter == 'TEACH'
                                ? 'Teaching'
                                : 'Learning',
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _skillLevelFilter = 'ALL');
                            _performSearch();
                          },
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Clear all
                      if (_selectedSkillFilter != null ||
                          _selectedLocationFilter != null ||
                          _skillLevelFilter != 'ALL' ||
                          _searchController.text.isNotEmpty)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading && _isInitialLoad
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _UserCard(user: user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Filter Bottom Sheet
class _FilterBottomSheet extends StatefulWidget {
  final List<String> availableSkills;
  final String? selectedSkill;
  final String? selectedLocation;
  final String skillLevel;
  final Function(String?, String?, String) onApply;

  const _FilterBottomSheet({
    required this.availableSkills,
    required this.selectedSkill,
    required this.selectedLocation,
    required this.skillLevel,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _selectedSkill;
  late String? _selectedLocation;
  late String _skillLevel;
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSkill = widget.selectedSkill;
    _selectedLocation = widget.selectedLocation;
    _skillLevel = widget.skillLevel;
    _locationController.text = _selectedLocation ?? '';
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSkill = null;
                        _selectedLocation = null;
                        _skillLevel = 'ALL';
                        _locationController.clear();
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filters content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skill type filter
                      Text(
                        'Skill Type',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _skillLevel == 'ALL',
                            onSelected: (_) =>
                                setState(() => _skillLevel = 'ALL'),
                          ),
                          ChoiceChip(
                            label: const Text('Teaching'),
                            selected: _skillLevel == 'TEACH',
                            onSelected: (_) =>
                                setState(() => _skillLevel = 'TEACH'),
                          ),
                          ChoiceChip(
                            label: const Text('Learning'),
                            selected: _skillLevel == 'LEARN',
                            onSelected: (_) =>
                                setState(() => _skillLevel = 'LEARN'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Skill filter
                      Text(
                        'Skill',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSkill,
                        decoration: const InputDecoration(
                          hintText: 'Select a skill',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Any skill'),
                          ),
                          ...widget.availableSkills.map((skill) {
                            return DropdownMenuItem(
                              value: skill,
                              child: Text(skill),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSkill = value);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Location filter
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          hintText: 'Enter location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        onChanged: (value) {
                          _selectedLocation = value.isEmpty ? null : value;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Apply button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _selectedSkill,
                      _selectedLocation,
                      _skillLevel,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// User Card Widget
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final skillsToTeach = user['skills_to_teach'] as List<String>;
    final skillsToLearn = user['skills_to_learn'] as List<String>;
    final rating = user['average_rating'] ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to user profile detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileViewScreen(userId: user['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header
              Row(
                children: [
                  // Profile picture
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user['profile_picture_url'] != null
                        ? NetworkImage(user['profile_picture_url'])
                        : null,
                    child: user['profile_picture_url'] == null
                        ? Text(
                            (user['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name and location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (user['location'] != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user['location'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Rating
                  if (rating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Bio
              if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  user['bio'],
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Skills to teach
              if (skillsToTeach.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.school, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Can teach:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skillsToTeach.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (skillsToTeach.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${skillsToTeach.length - 3} more',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],

              // Skills to learn
              if (skillsToLearn.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Wants to learn:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skillsToLearn.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        skill,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (skillsToLearn.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${skillsToLearn.length - 3} more',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
