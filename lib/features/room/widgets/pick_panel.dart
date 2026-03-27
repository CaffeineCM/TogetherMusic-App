import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/music.dart';
import '../../../core/models/music_discovery.dart';
import '../../../core/network/music_api.dart';
import '../providers/room_provider.dart';
import 'glass_panel.dart';

/// 点歌面板
/// 支持搜索、歌单、排行榜三个入口，并保留当前房间播放列表
class PickPanel extends ConsumerStatefulWidget {
  const PickPanel({super.key});

  @override
  ConsumerState<PickPanel> createState() => _PickPanelState();
}

class _PickPanelState extends ConsumerState<PickPanel> {
  final _searchController = TextEditingController();

  String? _boundHouseId;
  String _selectedSource = 'wy';
  List<Music> _searchResults = [];
  bool _isSearching = false;

  MusicDiscoveryContext _discoveryContext = const MusicDiscoveryContext(
    canViewHostPlaylists: false,
    playlistSource: 'wy',
  );
  bool _isDiscoveryLoading = false;
  bool _isPlaylistTracksLoading = false;
  List<MusicPlaylistSummary> _recommendedPlaylists = [];
  List<MusicPlaylistSummary> _hostPlaylists = [];
  List<MusicToplistSummary> _toplists = [];
  List<Music> _selectedTracks = [];
  String? _selectedCollectionId;
  String? _selectedCollectionTitle;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _bindHouse(String? houseId) {
    if (houseId == null || houseId == _boundHouseId) {
      return;
    }
    setState(() {
      _boundHouseId = houseId;
      _searchResults = [];
      _recommendedPlaylists = [];
      _hostPlaylists = [];
      _toplists = [];
      _selectedTracks = [];
      _selectedCollectionId = null;
      _selectedCollectionTitle = null;
    });
    _loadDiscovery(houseId);
  }

  Future<void> _loadDiscovery(String houseId) async {
    setState(() => _isDiscoveryLoading = true);

    try {
      final context = await MusicApi.getDiscoveryContext(houseId: houseId);
      final recommended = await MusicApi.getRecommendedPlaylists(
        houseId: houseId,
      );
      final toplists = await MusicApi.getToplists(houseId: houseId);
      final hostPlaylists = context.canViewHostPlaylists
          ? await MusicApi.getHostPlaylists(houseId: houseId)
          : <MusicPlaylistSummary>[];

      if (!mounted || _boundHouseId != houseId) {
        return;
      }

      setState(() {
        _discoveryContext = context;
        _recommendedPlaylists = recommended;
        _toplists = toplists;
        _hostPlaylists = hostPlaylists;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载歌单页失败: $e')));
    } finally {
      if (mounted && _boundHouseId == houseId) {
        setState(() => _isDiscoveryLoading = false);
      }
    }
  }

  Future<void> _search(String houseId) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await MusicApi.search(
        houseId: houseId,
        keyword: keyword,
        source: _selectedSource,
      );
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _loadPlaylistTracks({
    required String houseId,
    required String playlistId,
    required String title,
  }) async {
    setState(() {
      _isPlaylistTracksLoading = true;
      _selectedCollectionId = playlistId;
      _selectedCollectionTitle = title;
      _selectedTracks = [];
    });

    try {
      final tracks = await MusicApi.getPlaylistDetail(
        houseId: houseId,
        playlistId: playlistId,
      );
      if (!mounted || _selectedCollectionId != playlistId) {
        return;
      }
      setState(() => _selectedTracks = tracks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载歌单失败: $e')));
    } finally {
      if (mounted && _selectedCollectionId == playlistId) {
        setState(() => _isPlaylistTracksLoading = false);
      }
    }
  }

  void _clearSelectedCollection() {
    setState(() {
      _selectedCollectionId = null;
      _selectedCollectionTitle = null;
      _selectedTracks = [];
      _isPlaylistTracksLoading = false;
    });
  }

  void _pickMusic(Music music) {
    ref
        .read(roomProvider.notifier)
        .pickMusic(
          musicId: music.id,
          keyword: music.name,
          source: music.source,
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已点歌: ${music.name}')));
  }

  void _likeMusic(String musicId) {
    ref.read(roomProvider.notifier).likeMusic(musicId);
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final houseId = roomState.currentHouseId;

    if (houseId != null && houseId != _boundHouseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _bindHouse(houseId);
        }
      });
    }

    if (houseId == null) {
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 420;
          final pickListHeight = compact
              ? (constraints.maxHeight * 0.34).clamp(112.0, 168.0)
              : (constraints.maxHeight * 0.28).clamp(160.0, 220.0);
          return Column(
            children: [
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildSearchTab(houseId),
                    _buildPlaylistsTab(houseId),
                    _buildToplistsTab(houseId),
                  ],
                ),
              ),
              SizedBox(
                height: pickListHeight,
                child: _PickList(
                  pickList: roomState.pickList,
                  onLike: _likeMusic,
                  compact: compact,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: const TabBar(
        tabs: [
          Tab(text: '搜索'),
          Tab(text: '歌单'),
          Tab(text: '排行榜'),
        ],
      ),
    );
  }

  Widget _buildSearchTab(String houseId) {
    return Column(
      children: [
        GlassPanel(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedSource,
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'wy', child: Text('网易云')),
                    DropdownMenuItem(value: 'qq', child: Text('QQ音乐')),
                    DropdownMenuItem(value: 'kg', child: Text('酷狗')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedSource = value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索歌曲...',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(houseId),
                  ),
                ),
                _isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _search(houseId),
                      ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _SongBrowserPanel(
            title: '搜索结果',
            songs: _searchResults,
            loading: _isSearching,
            emptyText: '输入关键词开始搜索',
            onPick: _pickMusic,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(String houseId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 260) {
          if (_selectedCollectionId != null) {
            return _CompactSongBrowser(
              title: _selectedCollectionTitle ?? '歌单歌曲',
              songs: _selectedTracks,
              loading: _isPlaylistTracksLoading,
              emptyText: '点击上方歌单查看曲目',
              onPick: _pickMusic,
              onBack: _clearSelectedCollection,
            );
          }
          return GlassPanel(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _isDiscoveryLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_discoveryContext.canViewHostPlaylists)
                        _PlaylistSection(
                          title: '房主收藏',
                          playlists: _hostPlaylists,
                          selectedId: _selectedCollectionId,
                          onTap: (playlist) => _loadPlaylistTracks(
                            houseId: houseId,
                            playlistId: playlist.id,
                            title: playlist.name,
                          ),
                        ),
                      _PlaylistSection(
                        title: '网易云歌单',
                        playlists: _recommendedPlaylists,
                        selectedId: _selectedCollectionId,
                        onTap: (playlist) => _loadPlaylistTracks(
                          houseId: houseId,
                          playlistId: playlist.id,
                          title: playlist.name,
                        ),
                      ),
                    ],
                  ),
          );
        }

        final topHeight = (constraints.maxHeight * 0.42).clamp(108.0, 180.0);
        return Column(
          children: [
            SizedBox(
              height: topHeight,
              child: GlassPanel(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: _isDiscoveryLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_discoveryContext.canViewHostPlaylists)
                            _PlaylistSection(
                              title: '房主收藏',
                              playlists: _hostPlaylists,
                              selectedId: _selectedCollectionId,
                              onTap: (playlist) => _loadPlaylistTracks(
                                houseId: houseId,
                                playlistId: playlist.id,
                                title: playlist.name,
                              ),
                            ),
                          _PlaylistSection(
                            title: '网易云歌单',
                            playlists: _recommendedPlaylists,
                            selectedId: _selectedCollectionId,
                            onTap: (playlist) => _loadPlaylistTracks(
                              houseId: houseId,
                              playlistId: playlist.id,
                              title: playlist.name,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Expanded(
              child: _SongBrowserPanel(
                title: _selectedCollectionTitle ?? '歌单歌曲',
                songs: _selectedTracks,
                loading: _isPlaylistTracksLoading,
                emptyText: '点击上方歌单查看曲目',
                onPick: _pickMusic,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToplistsTab(String houseId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 260) {
          if (_selectedCollectionId != null) {
            return _CompactSongBrowser(
              title: _selectedCollectionTitle ?? '榜单歌曲',
              songs: _selectedTracks,
              loading: _isPlaylistTracksLoading,
              emptyText: '点击上方榜单查看曲目',
              onPick: _pickMusic,
              onBack: _clearSelectedCollection,
            );
          }
          return GlassPanel(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: _isDiscoveryLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _toplists.length,
                    itemBuilder: (context, index) {
                      final toplist = _toplists[index];
                      final selected = toplist.id == _selectedCollectionId;
                      return _CollectionTile(
                        title: toplist.name,
                        subtitle:
                            toplist.updateFrequency ?? toplist.description,
                        imageUrl: toplist.coverUrl,
                        selected: selected,
                        trailing: const Text('榜单'),
                        onTap: () => _loadPlaylistTracks(
                          houseId: houseId,
                          playlistId: toplist.id,
                          title: toplist.name,
                        ),
                      );
                    },
                  ),
          );
        }

        final topHeight = (constraints.maxHeight * 0.42).clamp(108.0, 180.0);
        return Column(
          children: [
            SizedBox(
              height: topHeight,
              child: GlassPanel(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: _isDiscoveryLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _toplists.length,
                        itemBuilder: (context, index) {
                          final toplist = _toplists[index];
                          final selected = toplist.id == _selectedCollectionId;
                          return _CollectionTile(
                            title: toplist.name,
                            subtitle:
                                toplist.updateFrequency ?? toplist.description,
                            imageUrl: toplist.coverUrl,
                            selected: selected,
                            trailing: const Text('榜单'),
                            onTap: () => _loadPlaylistTracks(
                              houseId: houseId,
                              playlistId: toplist.id,
                              title: toplist.name,
                            ),
                          );
                        },
                      ),
              ),
            ),
            Expanded(
              child: _SongBrowserPanel(
                title: _selectedCollectionTitle ?? '榜单歌曲',
                songs: _selectedTracks,
                loading: _isPlaylistTracksLoading,
                emptyText: '点击上方榜单查看曲目',
                onPick: _pickMusic,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistSection extends StatelessWidget {
  final String title;
  final List<MusicPlaylistSummary> playlists;
  final String? selectedId;
  final void Function(MusicPlaylistSummary) onTap;

  const _PlaylistSection({
    required this.title,
    required this.playlists,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...playlists.map(
            (playlist) => _CollectionTile(
              title: playlist.name,
              subtitle: playlist.creatorName,
              imageUrl: playlist.coverUrl,
              selected: playlist.id == selectedId,
              trailing: Text('${playlist.trackCount ?? 0} 首'),
              onTap: () => onTap(playlist),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.selected,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.24)
            : Colors.white.withValues(alpha: 0.03),
      ),
      child: ListTile(
        leading: imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.queue_music),
                ),
              )
            : const Icon(Icons.queue_music),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null || subtitle!.isEmpty
            ? null
            : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _SongBrowserPanel extends StatelessWidget {
  final String title;
  final List<Music> songs;
  final bool loading;
  final String emptyText;
  final void Function(Music) onPick;

  const _SongBrowserPanel({
    required this.title,
    required this.songs,
    required this.loading,
    required this.emptyText,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : songs.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final music = songs[index];
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: music.pictureUrl != null
                            ? Image.network(
                                music.pictureUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.music_note),
                              )
                            : const Icon(Icons.music_note),
                        title: Text(
                          music.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          music.artist ?? '未知艺术家',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onPick(music),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompactSongBrowser extends StatelessWidget {
  final String title;
  final List<Music> songs;
  final bool loading;
  final String emptyText;
  final VoidCallback onBack;
  final void Function(Music) onPick;

  const _CompactSongBrowser({
    required this.title,
    required this.songs,
    required this.loading,
    required this.emptyText,
    required this.onBack,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : songs.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final music = songs[index];
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: music.pictureUrl != null
                            ? Image.network(
                                music.pictureUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.music_note),
                              )
                            : const Icon(Icons.music_note),
                        title: Text(
                          music.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          music.artist ?? '未知艺术家',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => onPick(music),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// PickList 展示
class _PickList extends StatelessWidget {
  final List<Music> pickList;
  final void Function(String) onLike;
  final bool compact;

  const _PickList({
    required this.pickList,
    required this.onLike,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '播放列表',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('${pickList.length} 首', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: pickList.isEmpty
                ? Center(
                    child: Text(
                      '暂无歌曲，快来点歌吧！',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: pickList.length,
                    itemBuilder: (context, index) {
                      final music = pickList[index];
                      final isCurrent = index == 0;

                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity(
                          vertical: compact ? -3 : -1,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: compact ? 0 : 2,
                        ),
                        minLeadingWidth: 24,
                        selected: isCurrent,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.24),
                        leading: Stack(
                          children: [
                            music.pictureUrl != null
                                ? Image.network(
                                    music.pictureUrl!,
                                    width: compact ? 34 : 40,
                                    height: compact ? 34 : 40,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.music_note),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    size: compact ? 34 : 40,
                                  ),
                            if (isCurrent)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 12,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          music.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isCurrent
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
                        subtitle: Text(
                          music.artist ?? '未知艺术家',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (music.likedUserIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${music.likedUserIds.length}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.thumb_up_outlined),
                              iconSize: 20,
                              onPressed: () => onLike(music.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
