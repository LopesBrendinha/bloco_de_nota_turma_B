class ChecklistItem {
  final String text;
  final bool completed;

  const ChecklistItem({required this.text, this.completed = false});

  Map<String, dynamic> toMap() {
    return {'text': text, 'completed': completed};
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      text: map['text'] as String,
      completed: map['completed'] as bool? ?? false,
    );
  }
}
