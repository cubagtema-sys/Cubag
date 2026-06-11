// dart:io removed — not needed on web; file handling uses PlatformFile.bytes instead
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/shimmer_loader.dart';
import '../services/api_service.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tasks = [];
  
  // Modal State
  Map<String, dynamic>? _selectedTask;
  final TextEditingController _noteController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  bool _submitDone = false;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  @override
  void dispose() {
    _noteController.dispose(); // BUG-F14 fix
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    if (!_isLoading) setState(() { _isLoading = true; _error = null; });
    await ApiService().fetchDataWithCache('/tasks', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() {
          _tasks = ApiService.ensureList(data);
          _isLoading = false;
        });
      }
    });
  }

  void _openSubmitModal(Map<String, dynamic> task) {
    setState(() {
      _selectedTask = task;
      _noteController.clear();
      _selectedFile = null;
      _submitDone = false;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSubmitModal(),
    );
  }

  Future<void> _pickFile(StateSetter setModalState) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null) {
      setModalState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _handleSubmit(StateSetter setModalState) async {
    setModalState(() => _isSubmitting = true);
    setState(() => _isSubmitting = true);
    try {
      final apiService = ApiService();
      final formData = FormData.fromMap({
        'task_id': _selectedTask?['id'],
        'notes': _noteController.text,
        if (_selectedFile != null)
          'file': kIsWeb || _selectedFile!.bytes != null
              ? MultipartFile.fromBytes(_selectedFile!.bytes!, filename: _selectedFile!.name)
              : await MultipartFile.fromFile(_selectedFile!.path!, filename: _selectedFile!.name),
      });
      final response = await apiService.post('/tasks/submit', data: formData);
      if (!mounted) return;
      // BUG-F13 fix: only mark done on success, show error on failure
      if (response.statusCode == 200 || response.statusCode == 201) {
        setModalState(() { _submitDone = true; });
        setState(() { _submitDone = true; });
        _fetchTasks();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
      } else {
        final msg = (response.data is Map ? response.data['message'] : null) ?? 'Submission failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setModalState(() => _isSubmitting = false);
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSubmitModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(32),
            child: _submitDone
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const _PulsingRing(color: Color(0xFF10b981)),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10b981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Evidence Submitted!',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF08060d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your evidence has been sent for admin review.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6b6375),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Submit Evidence',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF08060d),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTask?['title'] ?? 'Task Requirement',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF6b6375),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                              padding: const EdgeInsets.all(8),
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Completion Notes',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF08060d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 4,
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Describe what you did to complete this task...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748b)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2.0,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1f2028)
                              : Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Attachments (images, PDF, Word, video)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF08060d),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomPaint(
                        painter: DashedBorderPainter(
                          color: _selectedFile != null
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).dividerColor,
                          borderRadius: 12,
                        ),
                        child: InkWell(
                          onTap: () => _pickFile(setModalState),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _selectedFile != null
                                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                        : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _selectedFile != null
                                        ? Icons.file_present_rounded
                                        : Icons.cloud_upload_outlined,
                                    size: 32,
                                    color: _selectedFile != null
                                        ? Theme.of(context).primaryColor
                                        : const Color(0xFF64748b),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedFile != null ? _selectedFile!.name : 'Click to attach files',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: _selectedFile != null
                                        ? Theme.of(context).primaryColor
                                        : const Color(0xFF64748b),
                                    fontWeight: _selectedFile != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSubmitting ? null : () {
                            _handleSubmit(setModalState);
                          },
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Submit for Admin Review',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    int pendingCount = _tasks.where((t) => t['done'] != true).length;
    int verifiedCount = _tasks.where((t) => t['admin_verified'] == true).length;

    return AppLayout(
      title: 'Tasks & Compliance',
      child: RefreshIndicator(
        onRefresh: _fetchTasks,
        color: Theme.of(context).primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? [const Color(0xFF1f2028), const Color(0xFF16171d)]
                              : [const Color(0xFFf08232), const Color(0xFFe66c19)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2e303a)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon with pulsing circle
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!_isLoading && pendingCount > 0)
                                _PulsingRing(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                                ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isLoading
                                      ? Icons.sync
                                      : (pendingCount > 0
                                          ? Icons.assignment_late_rounded
                                          : Icons.verified_user_rounded),
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compliance Status',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (!_isLoading && pendingCount > 0) ...[
                                      const _BlinkingDot(color: Colors.redAccent, size: 8),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      _isLoading
                                          ? 'Checking records...'
                                          : '$pendingCount Action Required · $verifiedCount Verified',
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF9ca3af)
                                            : Colors.white.withValues(alpha: 0.95),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
                      child: Text(
                        'Compliance Requirements',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF08060d),
                        ),
                      ),
                    ),

                    if (_isLoading && _tasks.isEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 4,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                        itemBuilder: (ctx, i) => const ShimmerListTile(),
                      )
                    else if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                        decoration: BoxDecoration(
                          color: const Color(0xFFef4444).withValues(alpha: 0.05),
                          border: Border.all(color: const Color(0xFFef4444).withValues(alpha: 0.2), width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFef4444).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFef4444), size: 32),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Connection Failed',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF08060d),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please check your internet connection and try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: const Color(0xFF6b6375), fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 140,
                              height: 44,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFef4444),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _fetchTasks,
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    else if (_tasks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2e303a)
                                : const Color(0xFFe5e4e7),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 36),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'All caught up!',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF08060d),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No pending compliance tasks at this time.',
                              style: GoogleFonts.inter(color: const Color(0xFF6b6375), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          final bool submitted = task['submission_id'] != null;
                          final bool verified = task['admin_verified'] == true;
                          final bool urgent = task['urgent'] == true;

                          // Status determination
                          Color badgeBgColor;
                          Color badgeTextColor;
                          String statusText;
                          IconData statusIcon;
                          bool isPulsing = false;

                          if (verified) {
                            badgeBgColor = const Color(0xFF10b981).withValues(alpha: 0.1);
                            badgeTextColor = const Color(0xFF10b981);
                            statusText = 'Verified';
                            statusIcon = Icons.verified_rounded;
                          } else if (submitted) {
                            badgeBgColor = const Color(0xFF3b82f6).withValues(alpha: 0.1);
                            badgeTextColor = const Color(0xFF3b82f6);
                            statusText = 'Reviewing';
                            statusIcon = Icons.hourglass_empty_rounded;
                          } else if (urgent) {
                            badgeBgColor = const Color(0xFFef4444).withValues(alpha: 0.1);
                            badgeTextColor = const Color(0xFFef4444);
                            statusText = 'Urgent';
                            statusIcon = Icons.warning_amber_rounded;
                            isPulsing = true;
                          } else {
                            badgeBgColor = Theme.of(context).primaryColor.withValues(alpha: 0.1);
                            badgeTextColor = Theme.of(context).primaryColor;
                            statusText = 'Pending';
                            statusIcon = Icons.assignment_outlined;
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2e303a)
                                    : const Color(0xFFe5e4e7),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: !submitted ? () => _openSubmitModal(task) : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Leading icon representation
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: badgeBgColor.withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            statusIcon,
                                            color: badgeTextColor,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Info section
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task['title'] ?? 'Unknown Task',
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : const Color(0xFF08060d),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                // Status Chip
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: badgeBgColor,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (isPulsing) ...[
                                                        const _BlinkingDot(
                                                            color: Color(0xFFef4444), size: 6),
                                                        const SizedBox(width: 6),
                                                      ],
                                                      Text(
                                                        statusText,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: badgeTextColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Due Date tag
                                                if (!verified && !submitted && task['due_date'] != null)
                                                  Text(
                                                    'Due: ${task['due_date']}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: urgent
                                                          ? const Color(0xFFef4444)
                                                          : const Color(0xFF6b6375),
                                                      fontWeight: urgent
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action element on the right
                                      if (!submitted) ...[
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context).primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 12),
                                          ),
                                          onPressed: () => _openSubmitModal(task),
                                          child: Text(
                                            'Submit',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Color(0xFF10b981),
                                          size: 24,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
}

// Stateful widgets and Custom Painters for premium visual indicators

class _BlinkingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _BlinkingDot({
    required this.color,
    this.size = 8.0,
  });

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 52 + (24 * _controller.value),
          height: 52 + (24 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 1.0 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    double distance = 0.0;

    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final len = dashLength;
        final nextDistance = distance + len;
        if (nextDistance < pathMetric.length) {
          dashPath.addPath(
            pathMetric.extractPath(distance, nextDistance),
            Offset.zero,
          );
        } else {
          dashPath.addPath(
            pathMetric.extractPath(distance, pathMetric.length),
            Offset.zero,
          );
        }
        distance = nextDistance + gap;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
