import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Print settings model
class PrintSettings {
  final int copies;
  final bool isMonochromatic;
  final String paperSize;
  final String orientation;
  final double quality;
  final bool duplex;
  final bool collate;
  final String printRange;
  final List<int> customPages;
  final Map<String, dynamic> advancedSettings;

  const PrintSettings({
    this.copies = 1,
    this.isMonochromatic = false,
    this.paperSize = 'A4',
    this.orientation = 'portrait',
    this.quality = 1.0,
    this.duplex = false,
    this.collate = true,
    this.printRange = 'all',
    this.customPages = const [],
    this.advancedSettings = const {},
  });

  PrintSettings copyWith({
    int? copies,
    bool? isMonochromatic,
    String? paperSize,
    String? orientation,
    double? quality,
    bool? duplex,
    bool? collate,
    String? printRange,
    List<int>? customPages,
    Map<String, dynamic>? advancedSettings,
  }) {
    return PrintSettings(
      copies: copies ?? this.copies,
      isMonochromatic: isMonochromatic ?? this.isMonochromatic,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      quality: quality ?? this.quality,
      duplex: duplex ?? this.duplex,
      collate: collate ?? this.collate,
      printRange: printRange ?? this.printRange,
      customPages: customPages ?? this.customPages,
      advancedSettings: advancedSettings ?? Map.from(this.advancedSettings),
    );
  }

  double calculateCost({
    required int totalPages,
    Map<String, double>? customRates,
  }) {
    final rates =
        customRates ??
        {
          'base_bw': 1.0,
          'color_surcharge': 0.5,
          'duplex_discount': 0.1,
          'bulk_discount': 0.05,
        };

    final effectivePages = printRange == 'all'
        ? totalPages
        : customPages.length;

    final totalSheets = effectivePages * copies;
    final baseCost = totalSheets * rates['base_bw']!;
    final colorCost = isMonochromatic
        ? 0.0
        : totalSheets * rates['color_surcharge']!;

    double discount = 0.0;
    if (duplex) discount += (baseCost + colorCost) * rates['duplex_discount']!;
    if (totalSheets >= 10)
      discount += (baseCost + colorCost) * rates['bulk_discount']!;

    return (baseCost + colorCost - discount).clamp(0.0, double.infinity);
  }
}

class PrintSettingsWidget extends StatefulWidget {
  final PrintSettings settings;
  final int totalPages;
  final Function(PrintSettings)? onSettingsChanged;
  final VoidCallback? onResetSettings;
  final bool showAdvancedOptions;
  final Map<String, double>? customRates;

  const PrintSettingsWidget({
    super.key,
    required this.settings,
    required this.totalPages,
    this.onSettingsChanged,
    this.onResetSettings,
    this.showAdvancedOptions = false,
    this.customRates,
  });

  @override
  State<PrintSettingsWidget> createState() => _PrintSettingsWidgetState();
}

class _PrintSettingsWidgetState extends State<PrintSettingsWidget>
    with TickerProviderStateMixin {
  late PrintSettings _currentSettings;
  late TabController _tabController;
  final TextEditingController _customPagesController = TextEditingController();
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.settings;
    _tabController = TabController(length: 3, vsync: this);
    _updateCustomPagesText();
    _showAdvanced = widget.showAdvancedOptions;
  }

  @override
  void didUpdateWidget(PrintSettingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      _currentSettings = widget.settings;
      _updateCustomPagesText();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customPagesController.dispose();
    super.dispose();
  }

  void _updateSettings(PrintSettings newSettings) {
    setState(() {
      _currentSettings = newSettings;
    });
    widget.onSettingsChanged?.call(newSettings);
  }

  void _updateCustomPagesText() {
    _customPagesController.text = _currentSettings.customPages.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (_showAdvanced) ...[
            _buildTabBar(),
            _buildTabContent(),
          ] else
            _buildBasicSettings(),
          _buildCostSummary(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.print, color: Colors.green.shade600, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Print Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),

          // Advanced toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showAdvanced = !_showAdvanced;
              });
            },
            icon: Icon(
              _showAdvanced ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(_showAdvanced ? 'Basic' : 'Advanced'),
            style: TextButton.styleFrom(foregroundColor: Colors.green.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.green.shade600,
      unselectedLabelColor: Colors.grey.shade600,
      indicatorColor: Colors.green.shade600,
      tabs: const [
        Tab(text: 'Basic', icon: Icon(Icons.settings, size: 16)),
        Tab(text: 'Layout', icon: Icon(Icons.view_quilt, size: 16)),
        Tab(text: 'Quality', icon: Icon(Icons.high_quality, size: 16)),
      ],
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 300,
      child: TabBarView(
        controller: _tabController,
        children: [_buildBasicTab(), _buildLayoutTab(), _buildQualityTab()],
      ),
    );
  }

  Widget _buildBasicSettings() {
    return Padding(padding: const EdgeInsets.all(16), child: _buildBasicTab());
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Copies
          _buildSection(
            title: 'Number of Copies',
            child: Row(
              children: [
                IconButton(
                  onPressed: _currentSettings.copies > 1
                      ? () => _updateSettings(
                          _currentSettings.copyWith(
                            copies: _currentSettings.copies - 1,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.green.shade600,
                ),
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    '${_currentSettings.copies}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _currentSettings.copies < 100
                      ? () => _updateSettings(
                          _currentSettings.copyWith(
                            copies: _currentSettings.copies + 1,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green.shade600,
                ),
                const Spacer(),
                Text(
                  'Max: 100',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Color Mode
          _buildSection(
            title: 'Color Mode',
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleCard(
                    title: 'Full Color',
                    subtitle: 'Best quality',
                    icon: Icons.color_lens,
                    isSelected: !_currentSettings.isMonochromatic,
                    onTap: () => _updateSettings(
                      _currentSettings.copyWith(isMonochromatic: false),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleCard(
                    title: 'Black & White',
                    subtitle: 'Cost effective',
                    icon: Icons.filter_b_and_w,
                    isSelected: _currentSettings.isMonochromatic,
                    onTap: () => _updateSettings(
                      _currentSettings.copyWith(isMonochromatic: true),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Print Range
          _buildSection(
            title: 'Print Range',
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text('All pages (1-${widget.totalPages})'),
                  value: 'all',
                  groupValue: _currentSettings.printRange,
                  onChanged: (value) => _updateSettings(
                    _currentSettings.copyWith(printRange: value),
                  ),
                  activeColor: Colors.green.shade600,
                  // REMOVED: dense: true - this parameter doesn't exist
                ),
                RadioListTile<String>(
                  title: const Text('Custom pages'),
                  value: 'custom',
                  groupValue: _currentSettings.printRange,
                  onChanged: (value) => _updateSettings(
                    _currentSettings.copyWith(printRange: value),
                  ),
                  activeColor: Colors.green.shade600,
                  // REMOVED: dense: true - this parameter doesn't exist
                ),
                if (_currentSettings.printRange == 'custom') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customPagesController,
                    decoration: const InputDecoration(
                      labelText: 'Pages (e.g., 1, 3, 5-10)',
                      border: OutlineInputBorder(),
                      isDense: true, // This parameter exists for TextField
                    ),
                    onChanged: _parseCustomPages,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paper Size
          _buildSection(
            title: 'Paper Size',
            child: Wrap(
              spacing: 8,
              children: ['A4', 'A3', 'Letter', 'Legal'].map((size) {
                return ChoiceChip(
                  label: Text(size),
                  selected: _currentSettings.paperSize == size,
                  onSelected: (selected) {
                    if (selected) {
                      _updateSettings(
                        _currentSettings.copyWith(paperSize: size),
                      );
                    }
                  },
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: _currentSettings.paperSize == size
                        ? Colors.green.shade700
                        : Colors.grey.shade700,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Orientation
          _buildSection(
            title: 'Orientation',
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleCard(
                    title: 'Portrait',
                    icon: Icons.crop_portrait,
                    isSelected: _currentSettings.orientation == 'portrait',
                    onTap: () => _updateSettings(
                      _currentSettings.copyWith(orientation: 'portrait'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleCard(
                    title: 'Landscape',
                    icon: Icons.crop_landscape,
                    isSelected: _currentSettings.orientation == 'landscape',
                    onTap: () => _updateSettings(
                      _currentSettings.copyWith(orientation: 'landscape'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Duplex printing
          _buildSection(
            title: 'Two-sided Printing',
            child: SwitchListTile(
              title: const Text('Print on both sides'),
              subtitle: const Text('Save paper (10% discount)'),
              value: _currentSettings.duplex,
              onChanged: (value) =>
                  _updateSettings(_currentSettings.copyWith(duplex: value)),
              activeColor: Colors.green.shade600,
              // REMOVED: dense: true - this parameter doesn't exist
            ),
          ),

          const SizedBox(height: 20),

          // Collate
          _buildSection(
            title: 'Collate',
            child: SwitchListTile(
              title: const Text('Collate copies'),
              subtitle: const Text('Keep pages in order'),
              value: _currentSettings.collate,
              onChanged: (value) =>
                  _updateSettings(_currentSettings.copyWith(collate: value)),
              activeColor: Colors.green.shade600,
              // REMOVED: dense: true - this parameter doesn't exist
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Print Quality
          _buildSection(
            title: 'Print Quality',
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Draft'),
                    Expanded(
                      child: Slider(
                        value: _currentSettings.quality,
                        min: 0.3,
                        max: 1.0,
                        divisions: 7,
                        label: _getQualityLabel(_currentSettings.quality),
                        onChanged: (value) => _updateSettings(
                          _currentSettings.copyWith(quality: value),
                        ),
                        activeColor: Colors.green.shade600,
                      ),
                    ),
                    const Text('High'),
                  ],
                ),
                Text(
                  _getQualityDescription(_currentSettings.quality),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quality presets
          _buildSection(
            title: 'Quick Presets',
            child: Column(
              children: [
                _buildPresetButton('Draft', 'Fast, economical', () {
                  _updateSettings(
                    _currentSettings.copyWith(
                      quality: 0.3,
                      isMonochromatic: true,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildPresetButton('Normal', 'Balanced quality', () {
                  _updateSettings(
                    _currentSettings.copyWith(
                      quality: 0.7,
                      isMonochromatic: false,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _buildPresetButton('High Quality', 'Best appearance', () {
                  _updateSettings(
                    _currentSettings.copyWith(
                      quality: 1.0,
                      isMonochromatic: false,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildToggleCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green.shade300 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.green.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.green.shade600
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostSummary() {
    final cost = _currentSettings.calculateCost(
      totalPages: widget.totalPages,
      customRates: widget.customRates,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Cost Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildCostRow('Pages:', '${_getEffectivePages()}'),
          _buildCostRow('Copies:', '${_currentSettings.copies}'),
          _buildCostRow(
            'Total sheets:',
            '${_getEffectivePages() * _currentSettings.copies}',
          ),
          _buildCostRow(
            'Color mode:',
            _currentSettings.isMonochromatic ? 'B&W' : 'Color',
          ),

          if (_currentSettings.duplex)
            _buildCostRow('Two-sided:', '10% discount'),

          const Divider(height: 20),

          Row(
            children: [
              const Text(
                'Total Cost:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '₹${cost.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.onResetSettings != null) ...[
            OutlinedButton(
              onPressed: widget.onResetSettings,
              child: const Text('Reset'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _saveAndApplySettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.check),
              label: const Text('Apply Settings'),
            ),
          ),
        ],
      ),
    );
  }

  void _parseCustomPages(String text) {
    final pages = <int>[];
    final parts = text.split(',');

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              if (i >= 1 && i <= widget.totalPages) {
                pages.add(i);
              }
            }
          }
        }
      } else {
        final page = int.tryParse(trimmed);
        if (page != null && page >= 1 && page <= widget.totalPages) {
          pages.add(page);
        }
      }
    }

    _updateSettings(_currentSettings.copyWith(customPages: pages));
  }

  int _getEffectivePages() {
    return _currentSettings.printRange == 'all'
        ? widget.totalPages
        : _currentSettings.customPages.length;
  }

  String _getQualityLabel(double quality) {
    if (quality <= 0.4) return 'Draft';
    if (quality <= 0.7) return 'Normal';
    return 'High';
  }

  String _getQualityDescription(double quality) {
    if (quality <= 0.4) return 'Fast printing, lower ink usage';
    if (quality <= 0.7) return 'Balanced quality and speed';
    return 'Best quality, slower printing';
  }

  void _saveAndApplySettings() {
    HapticFeedback.mediumImpact();
    // Settings are already updated through onSettingsChanged
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Print settings applied successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
