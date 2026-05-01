/// Injects the rendered state board text into the message list,
/// inserting it after the first system message.
class StateInjector {
  const StateInjector();

  List<Map<String, dynamic>> inject(
    List<Map<String, dynamic>> messages,
    String stateText,
  ) {
    if (stateText.trim().isEmpty) return messages;

    final result = List<Map<String, dynamic>>.from(messages);
    var insertIdx = 0;
    for (var i = 0; i < result.length; i++) {
      if (result[i]['role'] == 'system') {
        insertIdx = i + 1;
        break;
      }
    }
    result.insert(insertIdx, {'role': 'system', 'content': stateText});
    return result;
  }
}
