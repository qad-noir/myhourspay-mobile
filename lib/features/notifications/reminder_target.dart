class ReminderTarget {
  const ReminderTarget(this.workspaceId, this.date);
  final int workspaceId;
  final DateTime date;
  static ReminderTarget? parse(Map<String, dynamic> data, int accountId) {
    if (data['type'] != 'missing_entry' ||
        int.tryParse('${data['user_id']}') != accountId) {
      return null;
    }
    final workspace = int.tryParse('${data['workspace_id']}');
    final raw = data['work_date'];
    if (workspace == null ||
        workspace <= 0 ||
        raw is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return null;
    }
    final date = DateTime.tryParse(raw);
    if (date == null ||
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' !=
            raw) {
      return null;
    }
    return ReminderTarget(workspace, date);
  }
}
