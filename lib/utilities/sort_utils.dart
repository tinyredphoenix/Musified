/// Sorts a list of songs by a given key (title or artist)
void sortSongsByKey(List<dynamic> songs, String sortKey) {
  songs.sort((a, b) {
    final valueA = (a[sortKey] ?? '').toString().toLowerCase();
    final valueB = (b[sortKey] ?? '').toString().toLowerCase();
    return valueA.compareTo(valueB);
  });
}
