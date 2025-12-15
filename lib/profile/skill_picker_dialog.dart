import 'package:flutter/material.dart';

class SkillPickerDialog extends StatefulWidget {
  final List<String> availableSkills;
  final List<String> selectedSkills;

  const SkillPickerDialog({
    super.key,
    required this.availableSkills,
    required this.selectedSkills,
  });

  @override
  State<SkillPickerDialog> createState() => _SkillPickerDialogState();
}

class _SkillPickerDialogState extends State<SkillPickerDialog> {
  final _searchController = TextEditingController();
  List<String> _filteredSkills = [];

  @override
  void initState() {
    super.initState();
    _filteredSkills = widget.availableSkills
        .where((s) => !widget.selectedSkills.contains(s))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSkills(String query) {
    setState(() {
      _filteredSkills = widget.availableSkills
          .where(
            (s) =>
                !widget.selectedSkills.contains(s) &&
                s.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Skill'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search or add new skill',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterSkills,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredSkills.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_filteredSkills[index]),
                    onTap: () => Navigator.pop(context, _filteredSkills[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_searchController.text.isNotEmpty &&
            !widget.availableSkills.contains(_searchController.text))
          TextButton(
            onPressed: () => Navigator.pop(context, _searchController.text),
            child: const Text('Add New'),
          ),
      ],
    );
  }
}