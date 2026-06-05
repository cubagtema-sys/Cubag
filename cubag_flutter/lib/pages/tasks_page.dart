import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../components/app_layout.dart';
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

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiService = ApiService();
      final response = await apiService.get('/tasks');
      if (response.statusCode == 200) {
        setState(() {
          _tasks = response.data;
        });
      } else {
        setState(() => _error = 'Failed to fetch tasks');
      }
    } catch (e) {
      setState(() => _error = 'Connection failed. Please check your network.');
    } finally {
      setState(() => _isLoading = false);
    }
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

  Future<void> _handleSubmit() async {
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
      
      await apiService.post('/tasks/submit', data: formData);
      
      setState(() {
        _submitDone = true;
      });
      
      _fetchTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSubmitting = false);
      
      if (_submitDone) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Close modal
          }
        });
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
                      const Icon(Icons.check_circle, color: Color(0xFF10b981), size: 64),
                      const SizedBox(height: 16),
                      Text('Submitted!', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Your evidence has been sent for admin review.', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Submit Task Evidence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      Text(_selectedTask?['title'] ?? '', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      const Text('Completion Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe what you did to complete this task...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Attachments (images, PDF, Word, video)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickFile(setModalState),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid), // Should be dashed, simplified for now
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).cardColor,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFile != null ? Icons.file_present : Icons.cloud_upload, 
                                size: 48, 
                                color: _selectedFile != null ? Theme.of(context).primaryColor : Colors.grey
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFile != null ? _selectedFile!.name : 'Click to attach files', 
                                style: TextStyle(color: _selectedFile != null ? Theme.of(context).primaryColor : Colors.grey)
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                          onPressed: _isSubmitting ? null : () {
                            setModalState(() => _isSubmitting = true);
                            _handleSubmit();
                          },
                          child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit for Admin Review', style: TextStyle(color: Colors.white)),
                        ),
                      )
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFf08232), Color(0xFFe66c19)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLoading ? Icons.sync : (pendingCount > 0 ? Icons.assignment_late : Icons.verified_user),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compliance Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        _isLoading ? 'Checking records...' : '$pendingCount pending · $verifiedCount verified',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444).withValues(alpha: 0.05),
                border: Border.all(color: const Color(0xFFef4444)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, color: Color(0xFFef4444), size: 48),
                  const SizedBox(height: 16),
                  const Text('Connection Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
                    onPressed: _fetchTasks,
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            )
          else if (_tasks.isEmpty)
             Container(
              width: double.infinity,
              padding: const EdgeInsets.all(60),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inventory_2, color: Colors.grey, size: 48),
                  SizedBox(height: 16),
                  Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('No pending compliance tasks at this time.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Compliance Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tasks.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final bool submitted = task['submission_id'] != null;
                      final bool verified = task['admin_verified'] == true;
                      final bool urgent = task['urgent'] == true;
                      
                      Color iconBgColor = verified ? const Color(0x1910b981) : submitted ? const Color(0x193b82f6) : const Color(0x19f08232);
                      Color iconColor = verified ? const Color(0xFF10b981) : submitted ? const Color(0xFF3b82f6) : Theme.of(context).primaryColor;
                      IconData icon = verified ? Icons.verified : submitted ? Icons.hourglass_top : Icons.description;

                      final isSmall = MediaQuery.of(context).size.width < 360;
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task['title'] ?? 'Unknown Task', 
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmall ? 13 : 15),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    verified ? '✅ Verified' : submitted ? '⏳ Reviewing' : task['due_date'] != null ? 'Due: ${task['due_date']}' : 'No due date',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: verified ? const Color(0xFF10b981) : submitted ? const Color(0xFF3b82f6) : urgent ? const Color(0xFFef4444) : Colors.grey
                                    ),
                                  )
                                ],
                              ),
                            ),
                            if (!submitted)
                              const SizedBox(width: 8),
                            if (!submitted)
                              SizedBox(
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _openSubmitModal(task),
                                  child: const Text('Submit'),
                                ),
                              )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
