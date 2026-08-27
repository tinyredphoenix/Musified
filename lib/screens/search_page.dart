import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/artist_bar.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_bar.dart';
import 'package:musified/widgets/section_header.dart';
import 'package:musified/widgets/song_tile.dart';

final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  bool _isSearching = false;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSearchRequest = 0;

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
    }
    _debounce?.cancel();
    _suggestionsList = [];
    _inputNode.unfocus();
    await _performSearch();
  }

  Future<void> _performSearch() async {
    final query = _searchBar.text.trim();
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      setState(() {
        _songsSearchResult = [];
        _artistsSearchResult = [];
        _playlistsSearchResult = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final searchHistory = List.from(searchHistoryNotifier.value);
      if (!searchHistory.contains(query)) {
        searchHistory.insert(0, query);
        if (searchHistory.length > 20) searchHistory.removeLast();
        searchHistoryNotifier.value = searchHistory;
        unawaited(addOrUpdateData<List>('user', 'searchHistory', searchHistory));
      }

      final songResults = await fetchSongsList(query);
      if (requestId != _latestSearchRequest || !mounted) return;

      final artistResults = await searchArtists(query);
      if (requestId != _latestSearchRequest || !mounted) return;

      final playlistResults = await getPlaylists(query: query);
      if (requestId != _latestSearchRequest || !mounted) return;

      setState(() {
        _songsSearchResult = songResults;
        _artistsSearchResult = artistResults;
        _playlistsSearchResult = playlistResults;
        _isSearching = false;
      });
    } catch (e) {
      logger.log('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestionsList = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final suggestions = await getSearchSuggestions(query);
      if (mounted && _searchBar.text == query) {
        setState(() {
          _suggestionsList = List<String>.from(suggestions);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);
    final hasResults = _songsSearchResult.isNotEmpty ||
        _artistsSearchResult.isNotEmpty ||
        _playlistsSearchResult.isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Search',
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: navBarColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
                width: 0.5,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: CupertinoSearchTextField(
                controller: _searchBar,
                focusNode: _inputNode,
                placeholder: 'Artists, songs, or playlists',
                onChanged: _onQueryChanged,
                onSubmitted: _submitSearch,
                style: TextStyle(
                  fontFamily: MusifiedStyle.uiFont,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                ),
              ),
            ),
          ),
          if (_isSearching)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CupertinoActivityIndicator(radius: 12)),
              ),
            )
          else if (_suggestionsList.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final suggestion = _suggestionsList[index];
                  return CupertinoListTile(
                    leading: const Icon(CupertinoIcons.search, size: 18, color: CupertinoColors.systemGrey),
                    title: Text(
                      suggestion,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        color: isDark ? CupertinoColors.white : CupertinoColors.black,
                      ),
                    ),
                    onTap: () => _submitSearch(suggestion),
                  );
                },
                childCount: _suggestionsList.length,
              ),
            )
          else if (!hasResults && _searchBar.text.isEmpty)
            _buildSearchHistory(isDark)
          else if (hasResults)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_songsSearchResult.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: SectionHeader(title: 'Songs', icon: CupertinoIcons.music_note_list),
                      ),
                      ..._songsSearchResult.map(
                        (s) => SongTile(
                          song: s is Map ? s : {},
                          onTap: () {
                            HapticFeedback.selectionClick();
                            audioHandler.playSong(s is Map ? s : {});
                          },
                        ),
                      ),
                    ],
                    if (_artistsSearchResult.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: SectionHeader(title: 'Artists', icon: CupertinoIcons.person_2_fill),
                      ),
                      ..._artistsSearchResult.map(
                        (a) => ArtistBar(
                          artist: a,
                          onTap: () {
                            if (a['ytid'] != null) {
                              context.push(
                                NavigationManager.artistPath(context, a['ytid'].toString()),
                                extra: a,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                    if (_playlistsSearchResult.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: SectionHeader(title: 'Playlists', icon: CupertinoIcons.music_albums_fill),
                      ),
                      ..._playlistsSearchResult.map(
                        (p) => PlaylistBar(
                          p['title']?.toString() ?? 'Playlist',
                          playlistData: p,
                        ),
                      ),
                    ],
                    const MiniPlayerBottomSpace(),
                  ],
                ),
              ),
            )
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'No results found',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontFamily: MusifiedStyle.displayFont,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        searchHistoryNotifier.value = [];
                        unawaited(deleteData('user', 'searchHistory'));
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF2D55),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: history.map<Widget>((query) {
                    return GestureDetector(
                      onTap: () => _submitSearch(query.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.clock, size: 14, color: CupertinoColors.systemGrey),
                            const SizedBox(width: 6),
                            Text(
                              query.toString(),
                              style: TextStyle(
                                fontFamily: MusifiedStyle.uiFont,
                                fontSize: 14,
                                color: isDark ? CupertinoColors.white : CupertinoColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
        );
      },
    );
  }
}
