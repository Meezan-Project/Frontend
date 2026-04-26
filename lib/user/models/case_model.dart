import 'package:cloud_firestore/cloud_firestore.dart';

class CaseSession {
  final String id;
  final DateTime scheduledDate;
  final String? location;
  final String? notes;
  final String? result;
  final String status; // scheduled, completed, cancelled

  const CaseSession({
    required this.id,
    required this.scheduledDate,
    this.location,
    this.notes,
    this.result,
    this.status = 'scheduled',
  });

  factory CaseSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CaseSession(
      id: doc.id,
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      result: data['result'] as String?,
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  factory CaseSession.fromMap(Map<String, dynamic> data, String id) {
    return CaseSession(
      id: id,
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      result: data['result'] as String?,
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'location': location,
      'notes': notes,
      'result': result,
      'status': status,
    };
  }
}

class RequiredDocument {
  final String id;
  final String name;
  final String description;
  final bool isSubmitted;
  final DateTime? submittedDate;

  const RequiredDocument({
    required this.id,
    required this.name,
    required this.description,
    this.isSubmitted = false,
    this.submittedDate,
  });

  factory RequiredDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RequiredDocument(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isSubmitted: data['isSubmitted'] as bool? ?? false,
      submittedDate: (data['submittedDate'] as Timestamp?)?.toDate(),
    );
  }

  factory RequiredDocument.fromMap(Map<String, dynamic> data, String id) {
    return RequiredDocument(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      isSubmitted: data['isSubmitted'] as bool? ?? false,
      submittedDate: (data['submittedDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'isSubmitted': isSubmitted,
      'submittedDate': submittedDate != null ? Timestamp.fromDate(submittedDate!) : null,
    };
  }
}

class CaseUpdate {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final String type; // action, process, result, general

  const CaseUpdate({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    this.type = 'general',
  });

  factory CaseUpdate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CaseUpdate(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
    );
  }

  factory CaseUpdate.fromMap(Map<String, dynamic> data, String id) {
    return CaseUpdate(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'title': title,
      'description': description,
      'type': type,
    };
  }
}

class UserCase {
  final String id;
  final String caseNumber;
  final String title;
  final String description;
  final String lawyerId;
  final String lawyerName;
  final String? lawyerAvatar;
  final String status; // active, closed, pending, on_hold
  final String category;
  final DateTime createdDate;
  final DateTime? closedDate;
  final List<CaseSession> sessions;
  final List<RequiredDocument> requiredDocuments;
  final List<CaseUpdate> updates;
  final String? notes;

  const UserCase({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.description,
    required this.lawyerId,
    required this.lawyerName,
    this.lawyerAvatar,
    this.status = 'active',
    this.category = '',
    required this.createdDate,
    this.closedDate,
    this.sessions = const [],
    this.requiredDocuments = const [],
    this.updates = const [],
    this.notes,
  });

  factory UserCase.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final sessionsList = (data['sessions'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => CaseSession.fromMap(indexed.$2 as Map<String, dynamic>, 'session_${indexed.$1}'))
        .toList() ?? [];

    final documentsList = (data['requiredDocuments'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => RequiredDocument.fromMap(indexed.$2 as Map<String, dynamic>, 'doc_${indexed.$1}'))
        .toList() ?? [];

    final updatesList = (data['updates'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => CaseUpdate.fromMap(indexed.$2 as Map<String, dynamic>, 'update_${indexed.$1}'))
        .toList() ?? [];

    return UserCase(
      id: doc.id,
      caseNumber: data['caseNumber'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lawyerId: data['lawyerId'] as String? ?? '',
      lawyerName: data['lawyerName'] as String? ?? '',
      lawyerAvatar: data['lawyerAvatar'] as String?,
      status: data['status'] as String? ?? 'active',
      category: data['category'] as String? ?? '',
      createdDate: (data['createdDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedDate: (data['closedDate'] as Timestamp?)?.toDate(),
      sessions: sessionsList,
      requiredDocuments: documentsList,
      updates: updatesList,
      notes: data['notes'] as String?,
    );
  }

  factory UserCase.fromMap(Map<String, dynamic> data, String id) {
    final sessionsList = (data['sessions'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => CaseSession.fromMap(indexed.$2 as Map<String, dynamic>, 'session_${indexed.$1}'))
        .toList() ?? [];

    final documentsList = (data['requiredDocuments'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => RequiredDocument.fromMap(indexed.$2 as Map<String, dynamic>, 'doc_${indexed.$1}'))
        .toList() ?? [];

    final updatesList = (data['updates'] as List<dynamic>?)
        ?.indexed
        .map((indexed) => CaseUpdate.fromMap(indexed.$2 as Map<String, dynamic>, 'update_${indexed.$1}'))
        .toList() ?? [];

    return UserCase(
      id: id,
      caseNumber: data['caseNumber'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lawyerId: data['lawyerId'] as String? ?? '',
      lawyerName: data['lawyerName'] as String? ?? '',
      lawyerAvatar: data['lawyerAvatar'] as String?,
      status: data['status'] as String? ?? 'active',
      category: data['category'] as String? ?? '',
      createdDate: (data['createdDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      closedDate: (data['closedDate'] as Timestamp?)?.toDate(),
      sessions: sessionsList,
      requiredDocuments: documentsList,
      updates: updatesList,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caseNumber': caseNumber,
      'title': title,
      'description': description,
      'lawyerId': lawyerId,
      'lawyerName': lawyerName,
      'lawyerAvatar': lawyerAvatar,
      'status': status,
      'category': category,
      'createdDate': Timestamp.fromDate(createdDate),
      'closedDate': closedDate != null ? Timestamp.fromDate(closedDate!) : null,
      'sessions': sessions.map((s) => s.toMap()).toList(),
      'requiredDocuments': requiredDocuments.map((d) => d.toMap()).toList(),
      'updates': updates.map((u) => u.toMap()).toList(),
      'notes': notes,
    };
  }

  String getStatusColor(bool isDark) {
    switch (status.toLowerCase()) {
      case 'active':
        return isDark ? '#4CAF50' : '#2E7D32';
      case 'closed':
        return isDark ? '#1976D2' : '#0D47A1';
      case 'pending':
        return isDark ? '#FF9800' : '#E65100';
      case 'on_hold':
        return isDark ? '#F44336' : '#C62828';
      default:
        return isDark ? '#757575' : '#424242';
    }
  }

  int getCompletionPercentage() {
    if (requiredDocuments.isEmpty) return 0;
    final completed = requiredDocuments.where((d) => d.isSubmitted).length;
    return ((completed / requiredDocuments.length) * 100).toInt();
  }
}
