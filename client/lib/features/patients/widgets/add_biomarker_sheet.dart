import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/patient_provider.dart';

class AddBiomarkerSheet extends ConsumerStatefulWidget {
  const AddBiomarkerSheet({super.key});

  @override
  ConsumerState<AddBiomarkerSheet> createState() => _AddBiomarkerSheetState();
}

class _AddBiomarkerSheetState extends ConsumerState<AddBiomarkerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitController = TextEditingController(text: 'mg/dL');
  String _name = 'Glucose';
  double _value = 0.0;
  DateTime _recordedAt = DateTime.now();
  String? _notes;

  final Map<String, String> _biomarkerUnits = {
    'Glucose': 'mg/dL',
    'Blood Pressure (Systolic)': 'mmHg',
    'Blood Pressure (Diastolic)': 'mmHg',
    'Weight': 'kg',
    'Hemoglobin': 'g/dL',
    'PSA': 'ng/mL',
    'Cholesterol': 'mg/dL',
    'Body Temperature': '°C',
    'Heart Rate': 'bpm',
  };

  @override
  void dispose() {
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Record Lab Result',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _name,
                decoration: const InputDecoration(labelText: 'Biomarker Name'),
                items: _biomarkerUnits.keys.map((name) {
                  return DropdownMenuItem(value: name, child: Text(name));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _name = val!;
                    if (_biomarkerUnits.containsKey(_name)) {
                      _unitController.text = _biomarkerUnits[_name]!;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Value'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                      onSaved: (val) => _value = double.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date of Measurement'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_recordedAt)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _recordedAt,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _recordedAt = picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
                onSaved: (val) => _notes = val,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      try {
                        await ref.read(biomarkerActionsProvider).addBiomarker(
                              name: _name,
                              value: _value,
                              unit: _unitController.text,
                              recordedAt: _recordedAt,
                              notes: _notes,
                            );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Result'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
