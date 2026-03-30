import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/music.dart';
import '../../../core/network/image_headers.dart';
import '../providers/player_provider.dart';
import 'glass_panel.dart';

/// 播放器组件
/// 展示当前歌曲封面、歌词、名称、艺术家、进度条、音量滑块
class PlayerWidget extends ConsumerStatefulWidget {
  const PlayerWidget({super.key});

  @override
  ConsumerState<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends ConsumerState<PlayerWidget> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_currentPage == page) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final music = playerState.currentMusic;
    final hasLyric = music?.lyric?.trim().isNotEmpty ?? false;

    if (!hasLyric && _currentPage != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageController.jumpToPage(0);
        setState(() => _currentPage = 0);
      });
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.transparent,
      child: GlassPanel(
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 540;
            final spacing = compact ? 10.0 : 16.0;

            return Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                children: [
                  Expanded(
                    child: _PlayerDisplay(
                      music: music,
                      compact: compact,
                      currentPosition: playerState.currentPosition,
                      hasLyric: hasLyric,
                      currentPage: _currentPage,
                      pageController: _pageController,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                      },
                      onSelectPage: _goToPage,
                    ),
                  ),
                  SizedBox(height: spacing),
                  _ProgressBar(playerState: playerState, compact: compact),
                  SizedBox(height: compact ? 4 : 8),
                  _PlaybackControls(playerState: playerState, compact: compact),
                  SizedBox(height: compact ? 4 : 8),
                  _VolumeControl(playerState: playerState, compact: compact),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerDisplay extends StatelessWidget {
  final Music? music;
  final bool compact;
  final int currentPosition;
  final bool hasLyric;
  final int currentPage;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSelectPage;

  const _PlayerDisplay({
    required this.music,
    required this.compact,
    required this.currentPosition,
    required this.hasLyric,
    required this.currentPage,
    required this.pageController,
    required this.onPageChanged,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _PosterPage(music: music, compact: compact),
      if (hasLyric)
        _LyricPage(
          music: music,
          compact: compact,
          currentPosition: currentPosition,
        ),
    ];

    return Column(
      children: [
        if (hasLyric)
          _DisplaySwitcher(
            currentPage: currentPage,
            onSelectPage: onSelectPage,
          ),
        if (hasLyric) SizedBox(height: compact ? 8 : 12),
        Expanded(
          child: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: pages,
          ),
        ),
      ],
    );
  }
}

class _DisplaySwitcher extends StatelessWidget {
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  const _DisplaySwitcher({
    required this.currentPage,
    required this.onSelectPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildTab(int page, IconData icon, String label) {
      final selected = currentPage == page;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelectPage(page),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: selected ? 0.98 : 0.55,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: selected ? 0.98 : 0.6,
                    ),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          buildTab(0, Icons.album_rounded, '海报'),
          buildTab(1, Icons.lyrics_rounded, '歌词'),
        ],
      ),
    );
  }
}

class _PosterPage extends StatelessWidget {
  final Music? music;
  final bool compact;

  const _PosterPage({required this.music, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AlbumArt(music: music, compact: compact),
            SizedBox(height: compact ? 10 : 16),
            _SongInfo(music: music, compact: compact),
          ],
        ),
      ),
    );
  }
}

class _LyricPage extends StatelessWidget {
  final Music? music;
  final bool compact;
  final int currentPosition;

  const _LyricPage({
    required this.music,
    required this.compact,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          music?.name ?? '暂无歌曲',
          style:
              (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          music?.artist ?? '未知艺术家',
          style:
              (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: compact ? 10 : 14),
        Expanded(
          child: _LyricPanel(
            lyric: music?.lyric ?? '',
            currentPosition: currentPosition,
          ),
        ),
      ],
    );
  }
}

/// 专辑封面
class _AlbumArt extends StatelessWidget {
  final Music? music;
  final bool compact;

  const _AlbumArt({this.music, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: compact ? 148 : 200,
      height: compact ? 148 : 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        image: music?.pictureUrl != null
            ? DecorationImage(
                image: NetworkImage(
                  music!.pictureUrl!,
                  headers: musicImageHeaders,
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: music?.pictureUrl == null
          ? Icon(
              Icons.music_note,
              size: compact ? 56 : 80,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}

/// 歌曲信息
class _SongInfo extends StatelessWidget {
  final Music? music;
  final bool compact;

  const _SongInfo({this.music, required this.compact});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (music == null) {
      return Text(
        '暂无歌曲',
        style:
            (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                ?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
      );
    }

    return Column(
      children: [
        Text(
          music!.name,
          style:
              (compact
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          music!.artist ?? '未知艺术家',
          style:
              (compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
                  ?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (music!.source.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SourceBadge(source: music!.source),
          ),
      ],
    );
  }
}

/// 音乐来源标签
class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  String get _sourceName {
    switch (source.toLowerCase()) {
      case 'wy':
      case 'netease':
        return '网易云';
      case 'qq':
        return 'QQ音乐';
      case 'kg':
      case 'kugou':
        return '酷狗';
      case 'upload':
        return '上传';
      default:
        return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _sourceName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// 进度条
class _ProgressBar extends ConsumerWidget {
  final PlayerState playerState;
  final bool compact;

  const _ProgressBar({required this.playerState, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Slider(
          value: playerState.progress.clamp(0.0, 1.0),
          onChanged: (value) {
            ref.read(playerProvider.notifier).seekTo(value);
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                playerState.currentPositionText,
                style: theme.textTheme.bodySmall,
              ),
              Text(
                playerState.durationText ?? '00:00',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 播放控制按钮
class _PlaybackControls extends ConsumerWidget {
  final PlayerState playerState;
  final bool compact;

  const _PlaybackControls({required this.playerState, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMusic = playerState.hasMusic;
    final isPlaying = playerState.playbackState == PlaybackState.playing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: hasMusic
              ? () => ref.read(playerProvider.notifier).togglePlayPause()
              : null,
          visualDensity: VisualDensity.compact,
          iconSize: compact ? 40 : 48,
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          ),
        ),
      ],
    );
  }
}

/// 音量控制
class _VolumeControl extends ConsumerWidget {
  final PlayerState playerState;
  final bool compact;

  const _VolumeControl({required this.playerState, required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final volume = playerState.isMuted ? 0 : playerState.volume;

    return Row(
      children: [
        IconButton(
          onPressed: () => ref.read(playerProvider.notifier).toggleMute(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            playerState.isMuted || playerState.volume == 0
                ? Icons.volume_off
                : playerState.volume < 50
                ? Icons.volume_down
                : Icons.volume_up,
          ),
        ),
        Expanded(
          child: Slider(
            value: volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$volume',
            onChanged: (value) {
              ref.read(playerProvider.notifier).setVolume(value.toInt());
            },
          ),
        ),
        SizedBox(
          width: compact ? 32 : 40,
          child: Text(
            '$volume',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _LyricPanel extends StatefulWidget {
  final String lyric;
  final int currentPosition;

  const _LyricPanel({required this.lyric, required this.currentPosition});

  @override
  State<_LyricPanel> createState() => _LyricPanelState();
}

class _LyricPanelState extends State<_LyricPanel> {
  static const double _lineExtent = 34;
  final ScrollController _scrollController = ScrollController();
  int _lastAutoIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = _parseLyric(widget.lyric);
    final activeIndex = _findActiveIndex(lines, widget.currentPosition);
    _scheduleAutoScroll(activeIndex, lines.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: lines.isEmpty
          ? Center(
              child: Text(
                '暂无歌词',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 42),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final isActive = index == activeIndex;
                return SizedBox(
                  height: _lineExtent,
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style:
                        (isActive
                                ? theme.textTheme.bodyMedium
                                : theme.textTheme.bodySmall)
                            ?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isActive ? 0.98 : 0.58,
                              ),
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                  ),
                );
              },
            ),
    );
  }

  void _scheduleAutoScroll(int activeIndex, bool hasLines) {
    if (!hasLines || activeIndex < 0 || activeIndex == _lastAutoIndex) {
      return;
    }
    _lastAutoIndex = activeIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final viewport = _scrollController.position.viewportDimension;
      final targetOffset =
          activeIndex * _lineExtent - (viewport / 2 - _lineExtent / 2);
      final clampedOffset = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  static List<_LyricLine> _parseLyric(String lyric) {
    final regExp = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final result = <_LyricLine>[];

    for (final rawLine in lyric.split('\n')) {
      final matches = regExp.allMatches(rawLine).toList();
      final text = rawLine.replaceAll(regExp, '').trim();
      if (matches.isEmpty || text.isEmpty) {
        continue;
      }

      for (final match in matches) {
        final minute = int.parse(match.group(1)!);
        final second = int.parse(match.group(2)!);
        final millis = int.tryParse(match.group(3) ?? '0') ?? 0;
        final timestamp =
            minute * 60 * 1000 +
            second * 1000 +
            (match.group(3) == null
                ? 0
                : match.group(3)!.length == 2
                ? millis * 10
                : match.group(3)!.length == 1
                ? millis * 100
                : millis);
        result.add(_LyricLine(timestamp: timestamp, text: text));
      }
    }

    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  static int _findActiveIndex(List<_LyricLine> lines, int currentPosition) {
    if (lines.isEmpty) return -1;
    var activeIndex = 0;
    for (var i = 0; i < lines.length; i++) {
      if (currentPosition >= lines[i].timestamp) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }
}

class _LyricLine {
  final int timestamp;
  final String text;

  const _LyricLine({required this.timestamp, required this.text});
}
