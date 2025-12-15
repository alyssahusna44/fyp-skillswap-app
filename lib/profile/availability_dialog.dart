import 'package:flutter/material.dart';

class AvailabilityDialog extends StatefulWidget {
  const AvailabilityDialog({super.key});

  @override
  State<AvailabilityDialog> createState() => _AvailabilityDialogState();
}

class _AvailabilityDialogState extends State<AvailabilityDialog> {
  bool _isRecurring = true;
  String _selectedDay = 'MON';
  DateTime? _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  String _getDayOfWeek(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Availability'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle between recurring and specific date
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Recurring'),
                    value: true,
                    groupValue: _isRecurring,
                    onChanged: (value) {
                      setState(() {
                        _isRecurring = value!;
                        _selectedDate = null;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Specific Date'),
                    value: false,
                    groupValue: _isRecurring,
                    onChanged: (value) {
                      setState(() => _isRecurring = value!);
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Day selector or Date picker
            if (_isRecurring)
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: const InputDecoration(
                  labelText: 'Day of Week',
                  border: OutlineInputBorder(),
                ),
                items: _days
                    .map(
                      (day) => DropdownMenuItem(value: day, child: Text(day)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedDay = value!),
              )
            else
              ListTile(
                title: const Text('Select Date'),
                subtitle: Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'No date selected',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            const SizedBox(height: 16),

            // Time pickers
            ListTile(
              title: const Text('Start Time'),
              trailing: Text(
                _startTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (time != null) setState(() => _startTime = time);
              },
            ),
            ListTile(
              title: const Text('End Time'),
              trailing: Text(
                _endTime.format(context),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime,
                );
                if (time != null) setState(() => _endTime = time);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Validate
            if (!_isRecurring && _selectedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a date')),
              );
              return;
            }

            final dayOfWeek = _isRecurring
                ? _selectedDay
                : _getDayOfWeek(_selectedDate!);

            Navigator.pop(context, {
              'day_of_week': dayOfWeek,
              'start_time':
                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
              'end_time':
                  '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
              'is_recurring': _isRecurring,
              'date_specific': _isRecurring
                  ? null
                  : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
