class TaskType {
  final String uid;
  final String name;
  final String label;
  final String category;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  TaskType({
    required this.uid,
    required this.name,
    required this.label,
    this.category = 'cleaning',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskType.fromJson(Map<String, dynamic> json) => TaskType(
    uid: json['uid'] ?? '',
    name: json['name'] ?? '',
    label: json['label'] ?? '',
    category: json['category'] ?? 'cleaning',
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] ?? '',
    updatedAt: json['updatedAt'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'label': label,
    'category': category,
    'isActive': isActive,
  };
}
