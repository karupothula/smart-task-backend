class Task {
  final String? id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status; // 'pending', 'in_progress', 'completed'
  final String? assignedTo;
  final DateTime? dueDate;
  final List<String> suggestedActions;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.assignedTo,
    this.dueDate,
    this.suggestedActions = const [],
  });

  // --- FACTORY METHOD ---
  // Safely parses JSON from Supabase.
  // Handles potential nulls with default values ("general", "low", etc.)
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? "",
      category: json['category'] ?? "general",
      priority: json['priority'] ?? "low",
      status: json['status'] ?? "pending",
      assignedTo: json['assigned_to'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      suggestedActions: json['suggested_actions'] != null 
          ? List<String>.from(json['suggested_actions']) 
          : [],
    );
  }
}