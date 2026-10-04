import 'dart:async';

import 'package:flutter/material.dart';
import 'package:book_bridge/features/listings/domain/entities/academic_lookups.dart';
import 'package:book_bridge/features/listings/presentation/viewmodels/academic_filters_mixin.dart';
import 'package:book_bridge/l10n/app_localizations.dart';

/// Wraps a picker selection so "cleared" (null value) differs from "dismissed"
/// (null result).
class PickerResult<T> {
  final T value;
  const PickerResult(this.value);
}

/// Bottom-sheet picker over a fixed list of options with a leading "any/none"
/// entry that yields `PickerResult(null)`.
Future<PickerResult<String?>?> showOptionPicker(
  BuildContext context, {
  required String title,
  required String clearLabel,
  required List<({String id, String label})> options,
  required String? selectedId,
}) {
  return showModalBottomSheet<PickerResult<String?>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              title,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                _optionTile(
                  sheetContext,
                  label: clearLabel,
                  selected: selectedId == null,
                  result: const PickerResult<String?>(null),
                ),
                for (final option in options)
                  _optionTile(
                    sheetContext,
                    label: option.label,
                    selected: option.id == selectedId,
                    result: PickerResult<String?>(option.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _optionTile<T>(
  BuildContext context, {
  required String label,
  required bool selected,
  required PickerResult<T> result,
}) {
  return ListTile(
    title: Text(label),
    trailing: selected
        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
        : null,
    onTap: () => Navigator.of(context).pop(result),
  );
}

Future<PickerResult<String?>?> showClassLevelPicker(
  BuildContext context, {
  required List<ClassLevel> levels,
  required String? selectedId,
  required String clearLabel,
}) {
  return showOptionPicker(
    context,
    title: AppLocalizations.of(context)!.classLevelLabel,
    clearLabel: clearLabel,
    options: [for (final l in levels) (id: l.id, label: l.label)],
    selectedId: selectedId,
  );
}

Future<PickerResult<String?>?> showSubjectPicker(
  BuildContext context, {
  required List<Subject> subjects,
  required String? selectedId,
  required String clearLabel,
}) {
  return showOptionPicker(
    context,
    title: AppLocalizations.of(context)!.subjectLabel,
    clearLabel: clearLabel,
    options: [for (final s in subjects) (id: s.id, label: s.name)],
    selectedId: selectedId,
  );
}

/// Searchable school picker backed by [searchSchools].
Future<PickerResult<School?>?> showSchoolPicker(
  BuildContext context, {
  required Future<List<School>> Function(String query) searchSchools,
  required School? selected,
  required String clearLabel,
}) {
  return showModalBottomSheet<PickerResult<School?>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SchoolPickerSheet(
      searchSchools: searchSchools,
      selected: selected,
      clearLabel: clearLabel,
    ),
  );
}

class _SchoolPickerSheet extends StatefulWidget {
  final Future<List<School>> Function(String query) searchSchools;
  final School? selected;
  final String clearLabel;

  const _SchoolPickerSheet({
    required this.searchSchools,
    required this.selected,
    required this.clearLabel,
  });

  @override
  State<_SchoolPickerSheet> createState() => _SchoolPickerSheetState();
}

class _SchoolPickerSheetState extends State<_SchoolPickerSheet> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _timer;
  List<School> _results = const [];
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() => _loading = true);
    final results = await widget.searchSchools(query);
    if (!mounted || id != _requestId) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchSchoolsHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                children: [
                  _optionTile(
                    context,
                    label: widget.clearLabel,
                    selected: widget.selected == null,
                    result: const PickerResult<School?>(null),
                  ),
                  for (final school in _results)
                    _optionTile(
                      context,
                      label: school.displayName,
                      selected: school.id == widget.selected?.id,
                      result: PickerResult<School?>(school),
                    ),
                  if (!_loading && _results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.noSchoolsFound)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable form field showing [value] (or [hint]) that opens a picker.
class PickerFormField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  final String? errorText;

  const PickerFormField({
    super.key,
    required this.value,
    required this.hint,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          filled: true,
          fillColor: theme.colorScheme.surface,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: value == null
            ? null
            : Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Horizontal chip row for filtering a feed by class level, subject, school.
class AcademicFilterBar extends StatelessWidget {
  final AcademicFiltersMixin viewModel;

  const AcademicFilterBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = viewModel;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _FilterChip(
            icon: Icons.school_outlined,
            label: vm.selectedClassLevel?.label ?? l10n.classLevelLabel,
            selected: vm.selectedClassLevelId != null,
            onTap: () async {
              await vm.loadAcademicLookups();
              if (!context.mounted) return;
              final pick = await showClassLevelPicker(
                context,
                levels: vm.classLevels,
                selectedId: vm.selectedClassLevelId,
                clearLabel: l10n.anyClassLevel,
              );
              if (pick != null) await vm.setClassLevelFilter(pick.value);
            },
          ),
          _FilterChip(
            icon: Icons.menu_book_outlined,
            label: vm.selectedSubject?.name ?? l10n.subjectLabel,
            selected: vm.selectedSubjectId != null,
            onTap: () async {
              await vm.loadAcademicLookups();
              if (!context.mounted) return;
              final pick = await showSubjectPicker(
                context,
                subjects: vm.subjects,
                selectedId: vm.selectedSubjectId,
                clearLabel: l10n.anySubject,
              );
              if (pick != null) await vm.setSubjectFilter(pick.value);
            },
          ),
          _FilterChip(
            icon: Icons.location_city_outlined,
            label: vm.selectedSchool?.name ?? l10n.schoolLabel,
            selected: vm.selectedSchool != null,
            onTap: () async {
              final pick = await showSchoolPicker(
                context,
                searchSchools: vm.searchSchools,
                selected: vm.selectedSchool,
                clearLabel: l10n.anySchool,
              );
              if (pick != null) await vm.setSchoolFilter(pick.value);
            },
          ),
          if (vm.hasAcademicFilters)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ActionChip(
                avatar: const Icon(Icons.close, size: 18),
                label: Text(l10n.clearAll),
                onPressed: vm.clearAcademicFilters,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
