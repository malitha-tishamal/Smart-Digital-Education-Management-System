import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ClassDetailScreen extends StatelessWidget {
  final Map<String, dynamic> teacher;

  const ClassDetailScreen({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Class - ${teacher['name']}'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher profile card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Teacher avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        teacher['profileImageUrl'] ??
                            'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png',
                      ),
                      backgroundColor: Colors.grey.shade200,
                      child: teacher['profileImageUrl'] == null ||
                              teacher['profileImageUrl'].isEmpty
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Teacher name
                    Text(
                      teacher['name'] ?? 'Teacher',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Teacher email
                    Text(
                      teacher['email'] ?? 'No email',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stream label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Stream: ${teacher['stream'] ?? 'Not set'}',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Subjects section
                    const Text(
                      'Subjects',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (teacher['subjects'] as List<String>? ?? []).map((subject) {
                        return Chip(
                          label: Text(subject),
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(color: Colors.grey.shade800),
                          avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        );
                      }).toList(),
                    ),
                    if ((teacher['subjects'] as List<String>? ?? []).isEmpty)
                      const Text(
                        'No subjects assigned',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Class activities section (placeholder)
            const Text(
              'Class Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 12),

            // Upcoming assignments
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const ListTile(
                leading: Icon(Icons.event_note, color: AppColors.primaryPurple),
                title: Text('Upcoming Assignments'),
                subtitle: Text('No assignments yet'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(height: 8),

            // Class schedule
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const ListTile(
                leading: Icon(Icons.calendar_today, color: AppColors.primaryPurple),
                title: Text('Class Schedule'),
                subtitle: Text('No schedule yet'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primaryPurple),
              ),
            ),
            const SizedBox(height: 8),

            // Classmates
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const ListTile(
                leading: Icon(Icons.people, color: AppColors.primaryPurple),
                title: Text('Classmates'),
                subtitle: Text('No students yet'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primaryPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}