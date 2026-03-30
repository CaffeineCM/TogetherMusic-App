import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/music.dart';
import '../../../core/models/music_discovery.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/image_headers.dart';
import '../../../core/network/music_api.dart';
import '../providers/room_provider.dart';
import 'glass_panel.dart';

/// 点歌面板
/// 采用二级浏览结构：先浏览歌单/榜单，再进入详情页添加歌曲。
class PickPanel extends ConsumerStatefulWidget {
  final String selectedSource;

  const PickPanel({super.key, required this.selectedSource});

  @override
  ConsumerState<PickPanel> createState() => _PickPanelState();
}

class _PickPanelState extends ConsumerState<PickPanel> {
  final _searchController = TextEditingController();

  String? _boundHouseId;
  List<Music> _searchResults = [];
  bool _isSearching = false;

  MusicDiscoveryContext _discoveryContext = const MusicDiscoveryContext(
    canViewHostPlaylists: false,
    playlistSource: 'wy',
  );
  bool _isDiscoveryLoading = false;
  bool _isCollectionTracksLoading = false;
  List<MusicPlaylistSummary> _recommendedPlaylists = [];
  List<MusicPlaylistSummary> _hostPlaylists = [];
  List<MusicToplistSummary> _toplists = [];
  List<Music> _selectedTracks = [];
  _SelectedCollection? _selectedCollection;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PickPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSource != widget.selectedSource) {
      setState(() {
        _searchResults = [];
        _recommendedPlaylists = [];
        _hostPlaylists = [];
        _toplists = [];
        _selectedTracks = [];
        _selectedCollection = null;
      });
      final houseId = _boundHouseId;
      if (houseId != null) {
        _loadDiscovery(houseId);
      }
    }
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
      _selectedCollection = null;
    });
    _loadDiscovery(houseId);
  }

  Future<void> _loadDiscovery(String houseId) async {
    setState(() => _isDiscoveryLoading = true);

    try {
      final context = await MusicApi.getDiscoveryContext(
        houseId: houseId,
        source: widget.selectedSource,
      );
      final recommended = await MusicApi.getRecommendedPlaylists(
        houseId: houseId,
        source: widget.selectedSource,
      );
      final toplists = await MusicApi.getToplists(
        houseId: houseId,
        source: widget.selectedSource,
      );
      final hostPlaylists = context.canViewHostPlaylists
          ? await MusicApi.getHostPlaylists(
              houseId: houseId,
              source: widget.selectedSource,
            )
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
      ).showSnackBar(SnackBar(content: Text('加载点歌页失败: $e')));
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
        source: widget.selectedSource,
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

  Future<void> _openCollection({
    required String houseId,
    required _SelectedCollection collection,
  }) async {
    setState(() {
      _selectedCollection = collection;
      _selectedTracks = [];
      _isCollectionTracksLoading = true;
    });

    try {
      final tracks = await MusicApi.getPlaylistDetail(
        houseId: houseId,
        playlistId: collection.id,
        source: collection.source,
      );
      if (!mounted || _selectedCollection?.id != collection.id) {
        return;
      }
      setState(() => _selectedTracks = tracks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载歌单失败: $e')));
    } finally {
      if (mounted && _selectedCollection?.id == collection.id) {
        setState(() => _isCollectionTracksLoading = false);
      }
    }
  }

  void _closeCollection(_CollectionKind kind) {
    if (_selectedCollection?.kind != kind) {
      return;
    }
    setState(() {
      _selectedCollection = null;
      _selectedTracks = [];
      _isCollectionTracksLoading = false;
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

  Future<void> _pickCurrentCollection() async {
    final collection = _selectedCollection;
    if (collection == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('整单加入队列'),
          content: Text(
            '将 ${collection.title} 中的 ${_selectedTracks.length} 首歌曲加入当前播放队列。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认加入'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    ref
        .read(roomProvider.notifier)
        .pickPlaylist(playlistId: collection.id, source: collection.source);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('正在加入歌单: ${collection.title}')));
  }

  void _likeMusic(String musicId) {
    ref.read(roomProvider.notifier).likeMusic(musicId);
  }

  Future<void> _showQueueSheet(List<Music> pickList) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        final maxHeight = MediaQuery.of(bottomSheetContext).size.height * 0.72;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: maxHeight,
            child: _PickList(pickList: pickList, onLike: _likeMusic),
          ),
        );
      },
    );
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
      child: Stack(
        children: [
          Column(
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
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FilledButton.tonalIcon(
              onPressed: () => _showQueueSheet(roomState.pickList),
              icon: const Icon(Icons.queue_music_rounded),
              label: Text('播放列表 ${roomState.pickList.length}'),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 76),
      child: Column(
        children: [
          GlassPanel(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: Text(
                      _sourceName(widget.selectedSource),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '搜索歌曲、歌手或关键字...',
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
              emptyText: '输入关键词开始搜索，结果会完整展示在这里',
              onPick: _pickMusic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab(String houseId) {
    final selected = _selectedCollection;
    return Padding(
      padding: const EdgeInsets.only(bottom: 76),
      child: selected != null && selected.kind == _CollectionKind.playlist
          ? _CollectionDetailView(
              collection: selected,
              songs: _selectedTracks,
              loading: _isCollectionTracksLoading,
              onBack: () => _closeCollection(_CollectionKind.playlist),
              onPick: _pickMusic,
              onPickAll: _selectedTracks.isEmpty
                  ? null
                  : _pickCurrentCollection,
            )
          : _CollectionLibraryView(
              loading: _isDiscoveryLoading,
              emptyText: '暂无可浏览歌单',
              sections: [
                if (_discoveryContext.canViewHostPlaylists)
                  _CollectionSectionData(
                    title: '房主收藏',
                    items: _hostPlaylists
                        .map(
                          (playlist) => _CollectionCardData(
                            id: playlist.id,
                            title: playlist.name,
                            subtitle: playlist.creatorName,
                            meta: _playlistMeta(playlist),
                            description: playlist.description,
                            imageUrl: playlist.coverUrl,
                            source: playlist.source,
                            kind: _CollectionKind.playlist,
                          ),
                        )
                        .toList(),
                  ),
                _CollectionSectionData(
                  title: '推荐歌单',
                  items: _recommendedPlaylists
                      .map(
                        (playlist) => _CollectionCardData(
                          id: playlist.id,
                          title: playlist.name,
                          subtitle: playlist.creatorName,
                          meta: _playlistMeta(playlist),
                          description: playlist.description,
                          imageUrl: playlist.coverUrl,
                          source: playlist.source,
                          kind: _CollectionKind.playlist,
                        ),
                      )
                      .toList(),
                ),
              ],
              onOpen: (item) => _openCollection(
                houseId: houseId,
                collection: item.toSelection(),
              ),
            ),
    );
  }

  Widget _buildToplistsTab(String houseId) {
    final selected = _selectedCollection;
    return Padding(
      padding: const EdgeInsets.only(bottom: 76),
      child: selected != null && selected.kind == _CollectionKind.toplist
          ? _CollectionDetailView(
              collection: selected,
              songs: _selectedTracks,
              loading: _isCollectionTracksLoading,
              onBack: () => _closeCollection(_CollectionKind.toplist),
              onPick: _pickMusic,
              onPickAll: _selectedTracks.isEmpty
                  ? null
                  : _pickCurrentCollection,
            )
          : _CollectionLibraryView(
              loading: _isDiscoveryLoading,
              emptyText: '暂无排行榜',
              sections: [
                _CollectionSectionData(
                  title: '热门榜单',
                  items: _toplists
                      .map(
                        (toplist) => _CollectionCardData(
                          id: toplist.id,
                          title: toplist.name,
                          subtitle: toplist.updateFrequency,
                          meta: '榜单',
                          description: toplist.description,
                          imageUrl: toplist.coverUrl,
                          source: toplist.source,
                          kind: _CollectionKind.toplist,
                        ),
                      )
                      .toList(),
                ),
              ],
              onOpen: (item) => _openCollection(
                houseId: houseId,
                collection: item.toSelection(),
              ),
            ),
    );
  }
}

String _sourceName(String code) {
  for (final item in AppConstants.musicSources) {
    if (item['code'] == code) {
      return item['name'] ?? code;
    }
  }
  return code;
}

String _playlistMeta(MusicPlaylistSummary playlist) {
  final trackCount = playlist.trackCount;
  if (trackCount != null && trackCount > 0) {
    return '$trackCount 首';
  }
  return '歌单';
}

enum _CollectionKind { playlist, toplist }

class _SelectedCollection {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String source;
  final _CollectionKind kind;

  const _SelectedCollection({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    required this.source,
    required this.kind,
  });
}

class _CollectionSectionData {
  final String title;
  final List<_CollectionCardData> items;

  const _CollectionSectionData({required this.title, required this.items});
}

class _CollectionCardData {
  final String id;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? description;
  final String? imageUrl;
  final String source;
  final _CollectionKind kind;

  const _CollectionCardData({
    required this.id,
    required this.title,
    this.subtitle,
    this.meta,
    this.description,
    this.imageUrl,
    required this.source,
    required this.kind,
  });

  _SelectedCollection toSelection() {
    return _SelectedCollection(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      imageUrl: imageUrl,
      source: source,
      kind: kind,
    );
  }
}

class _CollectionLibraryView extends StatelessWidget {
  final bool loading;
  final String emptyText;
  final List<_CollectionSectionData> sections;
  final void Function(_CollectionCardData item) onOpen;

  const _CollectionLibraryView({
    required this.loading,
    required this.emptyText,
    required this.sections,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSections = sections
        .where((section) => section.items.isNotEmpty)
        .toList();

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : effectiveSections.isEmpty
          ? Center(child: Text(emptyText))
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width > 1180
                    ? 3
                    : width > 760
                    ? 2
                    : 1;
                const spacing = 12.0;
                final itemWidth =
                    (width - (crossAxisCount - 1) * spacing - 24) /
                    crossAxisCount;
                final itemHeight = itemWidth > 320 ? 148.0 : 132.0;

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final section in effectiveSections) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Text(
                          section.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: section.items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: itemHeight,
                        ),
                        itemBuilder: (context, index) {
                          final item = section.items[index];
                          return _CollectionCard(
                            item: item,
                            onTap: () => onOpen(item),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final _CollectionCardData item;
  final VoidCallback onTap;

  const _CollectionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: item.imageUrl == null
                    ? Container(
                        width: 88,
                        height: 88,
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.queue_music_rounded, size: 30),
                      )
                    : Image.network(
                        item.imageUrl!,
                        headers: musicImageHeaders,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 88,
                          height: 88,
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.35,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.queue_music_rounded,
                            size: 30,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if (item.meta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                            child: Text(
                              item.meta!,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionDetailView extends StatelessWidget {
  final _SelectedCollection collection;
  final List<Music> songs;
  final bool loading;
  final VoidCallback onBack;
  final void Function(Music music) onPick;
  final VoidCallback? onPickAll;

  const _CollectionDetailView({
    required this.collection,
    required this.songs,
    required this.loading,
    required this.onBack,
    required this.onPick,
    this.onPickAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                Expanded(
                  child: Text(
                    collection.kind == _CollectionKind.playlist
                        ? '歌单详情'
                        : '榜单详情',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: collection.imageUrl == null
                      ? Container(
                          width: 112,
                          height: 112,
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.32,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.album_rounded, size: 40),
                        )
                      : Image.network(
                          collection.imageUrl!,
                          headers: musicImageHeaders,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 112,
                                height: 112,
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.32),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.album_rounded,
                                  size: 40,
                                ),
                              ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (collection.subtitle != null &&
                          collection.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          collection.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
                      if (collection.description != null &&
                          collection.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          collection.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: onPickAll,
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: Text('全部加入 ${songs.length}'),
                          ),
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.library_music_outlined),
                            label: Text('${songs.length} 首歌曲'),
                          ),
                        ],
                      ),
                    ],
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
                      '当前歌单暂无歌曲',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemBuilder: (context, index) {
                      final music = songs[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: music.pictureUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  music.pictureUrl!,
                                  headers: musicImageHeaders,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.music_note_rounded),
                                ),
                              )
                            : const Icon(Icons.music_note_rounded, size: 32),
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
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => onPick(music),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('加入'),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    itemCount: songs.length,
                  ),
          ),
        ],
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: music.pictureUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  music.pictureUrl!,
                                  headers: musicImageHeaders,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.music_note),
                                ),
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
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => onPick(music),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('加入'),
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

class _PickList extends StatelessWidget {
  final List<Music> pickList;
  final void Function(String) onLike;

  const _PickList({required this.pickList, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPanel(
      margin: EdgeInsets.zero,
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        selected: isCurrent,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.24),
                        leading: Stack(
                          children: [
                            music.pictureUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      music.pictureUrl!,
                                      headers: musicImageHeaders,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.music_note),
                                    ),
                                  )
                                : const Icon(Icons.music_note, size: 40),
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
