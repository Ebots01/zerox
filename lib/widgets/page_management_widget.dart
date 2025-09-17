// lib/widgets/page_management_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Page item data structure
class PageItem {
  final int id;
  final int originalIndex;
  final String type; // 'photo' or 'pdf'
  final File sourceFile;
  final String? thumbnailPath;
  bool isSelected;
  Map<String, dynamic> transformations;

  PageItem({
    required this.id,
    required this.originalIndex,
    required this.type,
    required this.sourceFile,
    this.thumbnailPath,
    this.isSelected = false,
    Map<String, dynamic>? transformations,
  }) : transformations = transformations ?? {};

  PageItem copyWith({bool? isSelected, Map<String, dynamic>? transformations}) {
    return PageItem(
      id: id,
      originalIndex: originalIndex,
      type: type,
      sourceFile: sourceFile,
      thumbnailPath: thumbnailPath,
      isSelected: isSelected ?? this.isSelected,
      transformations: transformations ?? Map.from(this.transformations),
    );
  }
}

class PageManagementWidget extends StatefulWidget {
  final List<PageItem> pages;
  final int? selectedPageIndex;
  final Function(List<PageItem>)? onPagesReordered;
  final Function(int)? onPageSelected;
  final Function(int)? onPageDuplicated;
  final Function(int)? onPageDeleted;
  final Function(List<int>)? onBulkAction;
  final bool allowMultiSelect;
  final bool allowReorder;
  final bool allowDelete;
  final double itemHeight;

  const PageManagementWidget({
    super.key,
    required this.pages,
    this.selectedPageIndex,
    this.onPagesReordered,
    this.onPageSelected,
    this.onPageDuplicated,
    this.onPageDeleted,
    this.onBulkAction,
    this.allowMultiSelect = true,
    this.allowReorder = true,
    this.allowDelete = true,
    this.itemHeight = 80,
  });

  @override
  State<PageManagementWidget> createState() => _PageManagementWidgetState();
}

class _PageManagementWidgetState extends State<PageManagementWidget>
    with TickerProviderStateMixin {
  List<PageItem> _pages = [];
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  int? _hoveredIndex;

  late AnimationController _selectionController;
  late Animation<double> _selectionAnimation;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.pages);

    _selectionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _selectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PageManagementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages != oldWidget.pages) {
      _pages = List.from(widget.pages);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIndices.clear();
      }
    });

    if (_isSelectionMode) {
      _selectionController.forward();
    } else {
      _selectionController.reverse();
    }
  }

  void _togglePageSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }

      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
        _selectionController.reverse();
      }
    });
  }

  void _selectAllPages() {
    setState(() {
      _selectedIndices.clear();
      _selectedIndices.addAll(List.generate(_pages.length, (index) => index));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
    _selectionController.reverse();
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
        children: [
          _buildHeader(),
          _buildPagesList(),
          if (_isSelectionMode) _buildSelectionActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isSelectionMode ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers,
            color: _isSelectionMode
                ? Colors.blue.shade600
                : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),

          if (_isSelectionMode) ...[
            AnimatedBuilder(
              animation: _selectionAnimation,
              child: Text(
                '${_selectedIndices.length} selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (_selectionAnimation.value * 0.2),
                  child: child,
                );
              },
            ),
          ] else ...[
            const Text(
              'Pages',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_pages.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Header actions
          if (_isSelectionMode) ...[
            if (_selectedIndices.length < _pages.length)
              TextButton(
                onPressed: _selectAllPages,
                child: const Text('Select All'),
              ),
            const SizedBox(width: 8),
            TextButton(onPressed: _clearSelection, child: const Text('Cancel')),
          ] else ...[
            if (widget.allowMultiSelect)
              IconButton(
                onPressed: _toggleSelectionMode,
                icon: const Icon(Icons.checklist, size: 20),
                tooltip: 'Multi-select',
              ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                if (widget.allowReorder)
                  const PopupMenuItem(
                    value: 'auto_arrange',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 8),
                        Text('Auto Arrange'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'reset_all',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 16),
                      SizedBox(width: 8),
                      Text('Reset All'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagesList() {
    return Expanded(
      child: widget.allowReorder
          ? ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _pages.length,
              onReorder: _handleReorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.05,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) => _buildPageItem(index),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _pages.length,
              itemBuilder: (context, index) => _buildPageItem(index),
            ),
    );
  }

  Widget _buildPageItem(int index) {
    final page = _pages[index];
    final isSelected = _selectedIndices.contains(index);
    final isActive = widget.selectedPageIndex == index;
    final isHovered = _hoveredIndex == index;

    return Container(
      key: ValueKey(page.id),
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        borderRadius: BorderRadius.circular(8),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handlePageTap(index),
            onLongPress: widget.allowMultiSelect
                ? () => _handleLongPress(index)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: widget.itemHeight,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade100
                    : isActive
                    ? Colors.blue.shade50
                    : isHovered
                    ? Colors.grey.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue.shade300
                      : isActive
                      ? Colors.blue.shade200
                      : Colors.grey.shade200,
                  width: isSelected || isActive ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    // Selection checkbox or reorder handle
                    if (_isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _togglePageSelection(index),
                        activeColor: Colors.blue.shade600,
                      ),
                    ] else if (widget.allowReorder) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.drag_indicator,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                    ],

                    const SizedBox(width: 12),

                    // Page thumbnail/preview
                    _buildPageThumbnail(page),

                    const SizedBox(width: 12),

                    // Page info
                    Expanded(child: _buildPageInfo(page, index)),

                    // Page actions
                    if (!_isSelectionMode) _buildPageActions(index),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageThumbnail(PageItem page) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            if (page.type == 'photo')
              Image.file(
                page.sourceFile,
                fit: BoxFit.cover,
                width: 48,
                height: 64,
                errorBuilder: (context, error, stackTrace) =>
                    _buildThumbnailError(),
              )
            else
              _buildPdfThumbnail(page),

            // Page type indicator
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(179),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(
                  page.type == 'photo' ? Icons.image : Icons.picture_as_pdf,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailError() {
    return Container(
      width: 48,
      height: 64,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey.shade400, size: 16),
          const SizedBox(height: 2),
          Text(
            'Error',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfThumbnail(PageItem page) {
    return Container(
      width: 48,
      height: 64,
      color: Colors.red.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red.shade600, size: 20),
          const SizedBox(height: 2),
          Text(
            'PDF',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageInfo(PageItem page, int index) {
    final hasTransformations = page.transformations.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              'Page ${index + 1}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (hasTransformations) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Modified',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 2),

        Text(
          page.sourceFile.path.split('/').last,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        if (hasTransformations) ...[
          const SizedBox(height: 2),
          Text(
            _getTransformationSummary(page.transformations),
            style: TextStyle(fontSize: 10, color: Colors.orange.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  String _getTransformationSummary(Map<String, dynamic> transformations) {
    final parts = <String>[];

    if (transformations.containsKey('rotation') &&
        transformations['rotation'] != 0) {
      parts.add('${transformations['rotation']}°');
    }

    if (transformations.containsKey('scale') &&
        transformations['scale'] != 1.0) {
      parts.add('${(transformations['scale'] * 100).round()}%');
    }

    if (transformations.containsKey('cropped') &&
        transformations['cropped'] == true) {
      parts.add('Cropped');
    }

    return parts.isEmpty ? 'Modified' : parts.join(' • ');
  }

  Widget _buildPageActions(int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onPageDuplicated != null)
          IconButton(
            onPressed: () => widget.onPageDuplicated!(index),
            icon: const Icon(Icons.content_copy, size: 16),
            tooltip: 'Duplicate page',
            visualDensity: VisualDensity.compact,
          ),

        if (widget.allowDelete && widget.onPageDeleted != null)
          IconButton(
            onPressed: _pages.length > 1
                ? () => _confirmDeletePage(index)
                : null,
            icon: Icon(
              Icons.delete_outline,
              size: 16,
              color: _pages.length > 1
                  ? Colors.red.shade600
                  : Colors.grey.shade400,
            ),
            tooltip: 'Delete page',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildSelectionActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.content_copy,
            label: 'Duplicate',
            onPressed: _selectedIndices.isNotEmpty
                ? () => _handleBulkAction('duplicate')
                : null,
          ),

          _buildActionButton(
            icon: Icons.refresh,
            label: 'Reset',
            onPressed: _selectedIndices.isNotEmpty
                ? () => _handleBulkAction('reset')
                : null,
          ),

          if (widget.allowDelete)
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: Colors.red.shade600,
              onPressed:
                  (_selectedIndices.isNotEmpty &&
                      _selectedIndices.length < _pages.length)
                  ? () => _handleBulkAction('delete')
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onPressed != null
                ? (color ?? Colors.blue.shade300)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: onPressed != null
                  ? (color ?? Colors.blue.shade600)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: onPressed != null
                    ? (color ?? Colors.blue.shade600)
                    : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;

    setState(() {
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
    });

    widget.onPagesReordered?.call(_pages);
    HapticFeedback.mediumImpact();
  }

  void _handlePageTap(int index) {
    if (_isSelectionMode) {
      _togglePageSelection(index);
    } else {
      widget.onPageSelected?.call(index);
    }
  }

  void _handleLongPress(int index) {
    if (!_isSelectionMode) {
      _toggleSelectionMode();
    }
    _togglePageSelection(index);
    HapticFeedback.mediumImpact();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'auto_arrange':
        _autoArrangePages();
        break;
      case 'reset_all':
        _resetAllPages();
        break;
    }
  }

  void _handleBulkAction(String action) {
    final selectedPages = _selectedIndices.toList();

    switch (action) {
      case 'duplicate':
        // Handle bulk duplication
        break;
      case 'reset':
        // Handle bulk reset
        break;
      case 'delete':
        _confirmDeletePages(selectedPages);
        break;
    }

    widget.onBulkAction?.call(selectedPages);
  }

  void _autoArrangePages() {
    setState(() {
      _pages.sort((a, b) {
        // Sort by type first (photos before PDFs), then by original index
        if (a.type != b.type) {
          return a.type == 'photo' ? -1 : 1;
        }
        return a.originalIndex.compareTo(b.originalIndex);
      });
    });

    widget.onPagesReordered?.call(_pages);
  }

  void _resetAllPages() {
    setState(() {
      _pages = _pages
          .map((page) => page.copyWith(transformations: {}))
          .toList();
    });
  }

  void _confirmDeletePage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Are you sure you want to delete page ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onPageDeleted?.call(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePages(List<int> indices) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pages'),
        content: Text(
          'Are you sure you want to delete ${indices.length} pages?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearSelection();
              // Handle bulk deletion
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
