import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'task_provider.dart';
import 'task_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- SECURITY INITIALIZATION ---
  // Load environment variables from assets. 
  // This prevents hardcoding the backend URL in the compiled binary.
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    throw Exception("CRITICAL ERROR: .env file not found. Ensure it is in the assets folder.");
  }

  final String? envUrl = dotenv.env['API_URL'];
  if (envUrl == null || envUrl.isEmpty) {
    throw Exception("CRITICAL ERROR: 'API_URL' variable is missing in .env file.");
  }
  
  runApp(
    MultiProvider(
      providers: [
        // Dependency Injection: Pass the secure URL to the Provider
        ChangeNotifierProvider(create: (_) => TaskProvider(baseUrl: envUrl))
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DashboardScreen(),
      ),
    ),
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController(); 

  @override
  void initState() {
    super.initState();
    // --- INFINITE SCROLL LISTENER ---
    // Triggers data fetch when user scrolls near the bottom of the list.
    _scrollController.addListener(_onScroll);

    // Initial fetch after UI build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskProvider>(context, listen: false).fetchTasks(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Threshold: Fetch more when 200px from bottom
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      Provider.of<TaskProvider>(context, listen: false).fetchTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final List<String> filters = ["All", "High", "Medium", "Low", "Scheduling", "Finance", "Technical", "Safety", "General"];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Smart Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- OFFLINE INDICATOR ---
          // Shows red banner if connection drops, green when restored.
          if (provider.isOffline || provider.showOnlineBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: provider.isOffline ? Colors.red : Colors.green,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(provider.isOffline ? Icons.wifi_off : Icons.wifi, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    provider.isOffline ? "You are Offline" : "You are Online",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),

          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search tasks...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchCtrl.clear();
                      provider.setSearchQuery("");
                    }) 
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) => provider.setSearchQuery(val),
            ),
          ),

          // STATUS CARDS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _StatusCard("Pending", provider.pendingCount, Colors.orange, "pending", provider),
                const SizedBox(width: 8),
                _StatusCard("In Progress", provider.progressCount, Colors.blue, "in_progress", provider),
                const SizedBox(width: 8),
                _StatusCard("Done", provider.doneCount, Colors.green, "completed", provider),
              ],
            ),
          ),

          // FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
            child: Row(
              children: filters.map((filter) {
                bool isActive = provider.currentFilter == filter; 
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    selectedColor: Colors.indigo.shade100,
                    checkmarkColor: Colors.indigo,
                    onSelected: (_) => provider.setCategoryFilter(filter),
                    backgroundColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),

          // CLEAR FILTERS BUTTON
          if (provider.isFilterActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filters Active", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                  TextButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      provider.clearFilters(); 
                    }, 
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text("Clear All Filters"),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  )
                ],
              ),
            ),

          // TASK LIST VIEW
          Expanded(
            child: provider.isLoading && provider.tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => provider.fetchTasks(refresh: true),
                    child: provider.filteredTasks.isEmpty 
                      ? const Center(child: Text("No tasks found", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: _scrollController,
                          // +1 allows rendering the "Loading..." spinner at the very bottom
                          itemCount: provider.filteredTasks.length + 1,
                          itemBuilder: (ctx, index) {
                            if (index == provider.filteredTasks.length) {
                              if (provider.isLoadingMore) {
                                return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                              }
                              if (!provider.hasMore && provider.filteredTasks.isNotEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(20), 
                                  child: Center(child: Text("All records fetched", style: TextStyle(color: Colors.grey)))
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            return TaskTile(task: provider.filteredTasks[index]);
                          },
                        ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _searchCtrl.clear();
          provider.clearFilters(); 
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const TaskFormSheet(),
          );
        },
        label: const Text("New Task"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
    );
  }
}

// --- WIDGETS ---

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String statusKey;
  final TaskProvider provider;

  const _StatusCard(this.label, this.count, this.color, this.statusKey, this.provider);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => provider.setStatusFilter(statusKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(count.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  const TaskTile({super.key, required this.task});

  Color _getPrioColor(String p) {
    if (p.toLowerCase() == 'high') return Colors.red.shade100;
    if (p.toLowerCase() == 'medium') return Colors.orange.shade100;
    return Colors.green.shade100;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    bool isDone = task.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDone ? Colors.grey[100] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => TaskFormSheet(taskToEdit: task),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(task.category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _getPrioColor(task.priority), borderRadius: BorderRadius.circular(6)),
                        child: Text(task.priority.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: task.status,
                    underline: const SizedBox(),
                    icon: Icon(Icons.circle, size: 12, color: isDone ? Colors.green : Colors.orange),
                    items: const [
                      DropdownMenuItem(value: "pending", child: Text("Pending")),
                      DropdownMenuItem(value: "in_progress", child: Text("In Progress")),
                      DropdownMenuItem(value: "completed", child: Text("Done")),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.updateStatus(task.id!, val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (task.dueDate != null) ...[
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(DateFormat('MMM dd').format(task.dueDate!), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 12),
                  ],
                  if (task.assignedTo != null && task.assignedTo!.isNotEmpty) ...[
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(task.assignedTo!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class TaskFormSheet extends StatefulWidget {
  final Task? taskToEdit; 
  const TaskFormSheet({super.key, this.taskToEdit});

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _assignCtrl;
  DateTime? _selectedDate;
  
  bool _isAnalyzing = false;
  bool _showPreview = false;
  String _predCat = "general";
  String _predPrio = "low";
  List<String> _suggestedActions = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.taskToEdit?.title ?? "");
    _descCtrl = TextEditingController(text: widget.taskToEdit?.description ?? "");
    _assignCtrl = TextEditingController(text: widget.taskToEdit?.assignedTo ?? "");
    _selectedDate = widget.taskToEdit?.dueDate;
    
    if (widget.taskToEdit != null) {
      _predCat = widget.taskToEdit!.category;
      _predPrio = widget.taskToEdit!.priority;
      _suggestedActions = List<String>.from(widget.taskToEdit!.suggestedActions);
      _showPreview = true;
    }
  }

  void _analyze() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Description are required!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isAnalyzing = true);
    
    try {
      final data = await Provider.of<TaskProvider>(context, listen: false)
          .previewTask(_titleCtrl.text, _descCtrl.text);
          
      setState(() {
        _predCat = data['category'];
        _predPrio = data['priority'];
        _suggestedActions = List<String>.from(data['suggested_actions']);
        
        List<dynamic> people = data['extracted_entities']['people'];
        if (people.isNotEmpty && _assignCtrl.text.isEmpty) {
          _assignCtrl.text = people.first;
        }

        _isAnalyzing = false;
        _showPreview = true;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showPreview = true; 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not connect to AI. Please enter manually.")));
    }
  }

  void _save() {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title is required!")));
      return;
    }
    if (_descCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Description is required!")));
      return;
    }

    final provider = Provider.of<TaskProvider>(context, listen: false);

    if (widget.taskToEdit == null) {
      provider.addTask(_titleCtrl.text, _descCtrl.text, _predCat, _predPrio, _assignCtrl.text.isEmpty ? null : _assignCtrl.text, _selectedDate);
    } else {
      provider.updateTask(widget.taskToEdit!.id!, _titleCtrl.text, _descCtrl.text, _predCat, _predPrio, _assignCtrl.text.isEmpty ? null : _assignCtrl.text, _selectedDate);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isOffline = Provider.of<TaskProvider>(context).isOffline;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.taskToEdit == null ? "New Task" : "Edit Task", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (isOffline)
                  const Chip(
                    label: Text("OFFLINE", style: TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                  )
              ],
            ),
            
            if (isOffline)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "You are offline. Connect to the internet to save.",
                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Title (Required)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Description (Required)", border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(child: TextField(controller: _assignCtrl, decoration: const InputDecoration(labelText: "Assigned To", prefixIcon: Icon(Icons.person)))),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null ? "Due Date" : DateFormat('MMM dd').format(_selectedDate!)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _selectedDate = d);
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_isAnalyzing) const Center(child: CircularProgressIndicator()),
            
            if (!_showPreview && !_isAnalyzing)
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: isOffline ? null : _analyze, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo, 
                    padding: const EdgeInsets.all(16),
                    disabledBackgroundColor: Colors.grey[300]
                  ),
                  child: const Text("Next: Analyze & Classify", style: TextStyle(color: Colors.white)),
                )
              ),

            if (_showPreview) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.indigo.withOpacity(0.2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AI Configuration", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _predCat,
                            decoration: const InputDecoration(labelText: "Category", isDense: true),
                            items: ["scheduling", "finance", "technical", "safety", "general"].map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                            onChanged: (v) => setState(() => _predCat = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _predPrio,
                            decoration: const InputDecoration(labelText: "Priority", isDense: true),
                            items: ["high", "medium", "low"].map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                            onChanged: (v) => setState(() => _predPrio = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_suggestedActions.isNotEmpty) ...[
                      const Text("Suggested Actions:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: _suggestedActions.map((action) => Chip(
                          label: Text(action, style: const TextStyle(fontSize: 10)),
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList(),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: isOffline ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, 
                    padding: const EdgeInsets.all(16),
                    disabledBackgroundColor: Colors.grey[300]
                  ),
                  child: Text(widget.taskToEdit == null ? "Save Task" : "Update Task", style: const TextStyle(color: Colors.white)),
                )
              ),
            ]
          ],
        ),
      ),
    );
  }
}