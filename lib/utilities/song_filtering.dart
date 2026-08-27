List<dynamic> filterSongsByQuery(List<dynamic> songsList, String searchQuery) {
  if (searchQuery.isEmpty) return songsList;

  final q = searchQuery.toLowerCase();
  return songsList.where((s) {
    final title = (s['title'] ?? '').toString().toLowerCase();
    final artist = (s['artist'] ?? '').toString().toLowerCase();
    return title.contains(q) || artist.contains(q);
  }).toList();
}
