class Assignment {
  final String id;
  final String title;
  final String status;

  Assignment({
    required this.id, 
    required this.title, 
    required this.status
  });

}

final List<Assignment> dummyAssignments = [
  Assignment(id: 'a1', title: 'Week 1 Quiz', status: 'Submitted'),
  Assignment(id: 'a2', title: 'Project Proposal', status: 'Pending'),
  Assignment(id: 'a3', title: 'Week 3 Assignment', status: 'Pending'),
  Assignment(id: 'a4', title: 'Final Project', status: 'Submitted'),
  Assignment(id: 'a5', title: 'project chater', status: 'Submitted'),
];