import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'task_model.dart';

class TaskProvider with ChangeNotifier {
  late Dio _dio;
  
  // --- DEPENDENCY INJECTION ---
  // We pass the baseUrl (loaded from .env) here. 
  // This decouples the provider from the environment config.
  TaskProvider({required String baseUrl}) {
    _dio = Dio(BaseOptions(baseUrl: baseUrl));
    _startConnectivityListener();
  }

  // --- STATE VARIABLES ---
  int _pendingCount = 0;
  int _progressCount = 0;
  int _doneCount = 0;

  // Pagination Config
  final int _limit = 10;  
  bool _hasMore = true;   
  bool _isLoadingMore = false; 

  List<Task> _tasks = [];
  bool _isLoading = false;
  
  // Offline Handling
  bool _isOffline = false; 
  bool _showOnlineBanner = false;

  // Filter State
  String _searchQuery = "";
  String _filterCategory = "All"; 
  String _filterStatus = "All";

  // Getters
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isOffline => _isOffline;
  bool get showOnlineBanner => _showOnlineBanner; 
  String get currentFilter => _filterCategory;
  bool get isFilterActive => _filterCategory != "All" || _filterStatus != "All" || _searchQuery.isNotEmpty;
  int get pendingCount => _pendingCount;
  int get progressCount => _progressCount;
  int get doneCount => _doneCount;

  // --- CONNECTIVITY LISTENER ---
  // Automatically detects network loss. If network returns, it auto-refreshes data.
  void _startConnectivityListener() {
    Connectivity().checkConnectivity().then(_updateStatus);
    Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    bool currentlyOffline = results.contains(ConnectivityResult.none);
    if (currentlyOffline && !_isOffline) {
      _isOffline = true;
      _showOnlineBanner = false;
      notifyListeners();
    } else if (!currentlyOffline && _isOffline) {
      _isOffline = false;
      _showOnlineBanner = true;
      notifyListeners();
      refreshAll(); // Auto-sync when back online
      Timer(const Duration(seconds: 5), () {
        _showOnlineBanner = false;
        notifyListeners();
      });
    }
  }

  void refreshAll() {
    fetchTasks(refresh: true);
    fetchStats();
  }

  // --- FETCH STATS ---
  // Fetched separately from the task list. 
  // This allows us to update counters without reloading the whole list (performance).
  Future<void> fetchStats() async {
    if (_isOffline) return;
    try {
      Map<String, dynamic> params = {};
      if (_filterCategory != "All") {
        params["category"] = _filterCategory;
      }
      final response = await _dio.get('/stats', queryParameters: params);
      final data = response.data;
      
      _pendingCount = data['pending'] ?? 0;
      _progressCount = data['in_progress'] ?? 0;
      _doneCount = data['completed'] ?? 0;
      notifyListeners();
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  // --- FETCH TASKS (CORE LOGIC) ---
  // Implements Infinite Scroll and Smart Sorting.
  Future<void> fetchTasks({bool refresh = false}) async {
    if (_isOffline) return;

    if (refresh) {
      _hasMore = true;
      _isLoading = true;
      _tasks = [];
      notifyListeners();
      fetchStats(); 
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      int currentOffset = _tasks.length;
      Map<String, dynamic> params = {
        "limit": _limit,
        "offset": currentOffset
      };

      if (_filterCategory != "All") params["category"] = _filterCategory;
      if (_filterStatus != "All") params["status"] = _filterStatus;

      final response = await _dio.get('/tasks', queryParameters: params);
      List<dynamic> data = response.data;
      List<Task> newTasks = data.map((json) => Task.fromJson(json)).toList();

      if (refresh) {
        _tasks = newTasks;
      } else {
        _tasks.addAll(newTasks);
      }
      
      // --- CLIENT-SIDE SORT REFINEMENT ---
      // While the DB sorts broadly (Status -> Date), we refine it here for immediate UX.
      // Logic: 
      // 1. "Completed" tasks always go to bottom.
      // 2. High Priority tasks float to top of their section.
      _tasks.sort((a, b) {
        int statusA = a.status == 'completed' ? 1 : 0;
        int statusB = b.status == 'completed' ? 1 : 0;
        if (statusA != statusB) return statusA.compareTo(statusB);
        return _prioScore(a.priority).compareTo(_prioScore(b.priority));
      });

      if (newTasks.length < _limit) {
        _hasMore = false; // Stop fetching if we got fewer items than limit
      }

    } catch (e) {
      print("Fetch Error: $e");
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  int _prioScore(String p) {
    if (p.toLowerCase() == 'high') return 0;
    if (p.toLowerCase() == 'medium') return 1;
    return 2;
  }

  // --- FILTERS ---
  void setCategoryFilter(String filter) {
    _filterCategory = filter;
    refreshAll(); 
  }

  void setStatusFilter(String status) {
    if (_filterStatus == status) {
      _filterStatus = "All"; 
    } else {
      _filterStatus = status;
    }
    fetchTasks(refresh: true); 
  }

  void clearFilters() {
    _searchQuery = "";
    _filterCategory = "All";
    _filterStatus = "All";
    refreshAll();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Task> get filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // --- CRUD OPERATIONS ---

  // AI Preview
  Future<Map<String, dynamic>> previewTask(String title, String desc) async {
    if (_isOffline) throw Exception("Offline");
    final response = await _dio.post('/classify', data: {"title": title, "description": desc});
    return response.data;
  }

  Future<void> addTask(String title, String desc, String cat, String prio, String? assign, DateTime? date) async {
    if (_isOffline) return;
    await _dio.post('/tasks', data: {
      "title": title, "description": desc, "category": cat, "priority": prio,
      "assigned_to": assign, "due_date": date?.toIso8601String(), "status": "pending"
    });
    refreshAll();
  }

  Future<void> updateTask(String id, String title, String desc, String cat, String prio, String? assign, DateTime? date) async {
    if (_isOffline) return;
    await _dio.patch('/tasks/$id', data: {
      "title": title, "description": desc, "category": cat, "priority": prio,
      "assigned_to": assign, "due_date": date?.toIso8601String()
    });
    refreshAll();
  }

  // --- OPTIMISTIC UI UPDATE ---
  // When status changes, we update the UI *instantly* before the server responds.
  // This makes the app feel snappy.
  Future<void> updateStatus(String id, String newStatus) async {
    if (_isOffline) return;
    
    // 1. Send Request to Backend
    await _dio.patch('/tasks/$id', data: {"status": newStatus});

    // 2. Immediate Local Update
    int index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      // If current filter contradicts new status (e.g. moving Pending->Done while viewing "Pending" tab),
      // remove it from view instantly.
      if (_filterStatus != "All" && _filterStatus.toLowerCase() != newStatus.toLowerCase()) {
        _tasks.removeAt(index);
      } 
      else {
        _tasks[index] = _tasks[index].copyWith(status: newStatus); 
        
        // Re-sort locally so "Done" tasks jump to bottom immediately
        _tasks.sort((a, b) {
           int statusA = a.status == 'completed' ? 1 : 0;
           int statusB = b.status == 'completed' ? 1 : 0;
           if (statusA != statusB) return statusA.compareTo(statusB);
           return _prioScore(a.priority).compareTo(_prioScore(b.priority));
        });
      }
      notifyListeners();
    }
    
    // 3. Sync Stats in background
    fetchStats(); 
  }
  
  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
    refreshAll();
  }
}

extension TaskCopy on Task {
  Task copyWith({String? status}) {
    return Task(
      id: id, title: title, description: description, category: category, 
      priority: priority, assignedTo: assignedTo, dueDate: dueDate, 
      suggestedActions: suggestedActions, status: status ?? this.status
    );
  }
}