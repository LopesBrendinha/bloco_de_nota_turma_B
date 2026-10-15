class Note {
  final int? id;
  final String uid;
  final String title;
  final String content;
  final String date;

  Note({
    this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.date,
  });

  Map<String, dynamic> toMap(){
    return{
      'id': id,
      'uid' : uid,
      'title' : title,
      'content' : content,
      'date' : date,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map){
    return Note(
      id: map['id'],
      uid: map['uid'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
    );
  }


}
