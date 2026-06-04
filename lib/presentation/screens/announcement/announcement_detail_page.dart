part of 'announcement_screen.dart';

/// 공지사항 상세 페이지 (공용) — 첨부파일 + 댓글 지원
class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
    this.teamName,
    this.onDelete,
    this.onEdit,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onEdit;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  final _commentC = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentC.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      final repo = ref.read(announcementRepositoryProvider);
      await repo.addComment(
        announcementId: widget.announcement.id,
        teamId: widget.announcement.teamId,
        content: text,
      );
      _commentC.clear();
      ref.invalidate(announcementCommentsProvider(widget.announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await ref
          .read(announcementRepositoryProvider)
          .deleteComment(commentId);
      ref.invalidate(announcementCommentsProvider(widget.announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final commentsAsync =
        ref.watch(announcementCommentsProvider(a.id));
    final myUserId = ref.watch(currentUserProvider)?.id;

    final trailingActions = <Widget>[
      if (widget.onEdit != null)
        MoniqAppBarAction(
          icon: Icons.edit_outlined,
          onTap: () => widget.onEdit!(),
        ),
      if (widget.onDelete != null)
        MoniqAppBarAction(
          icon: Icons.delete_outline_rounded,
          tint: AppColors.error,
          onTap: () async {
            final ok = await showMoniqConfirmSheet(
              context: context,
              title: '공지를 삭제할까요?',
              message: '이 공지사항이 영구적으로 삭제돼요.',
              confirmLabel: '삭제',
              destructive: true,
            );
            if (ok) {
              await widget.onDelete!();
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
    ];

    return Scaffold(
      appBar: MoniqAppBar(
        title: widget.teamName ?? '공지사항',
        trailing: trailingActions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: trailingActions),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screenAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.teamName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Text(
                        widget.teamName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    a.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 작성자 + 작성 일시
                  _DetailAuthorLine(
                    announcement: a,
                    dateFormat: dateFormat,
                  ),
                  const Divider(height: AppSpacing.xxxl),
                  if (a.content != null && a.content!.isNotEmpty)
                    Text(
                      a.content!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),

                  // 첨부파일
                  if (a.attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text('첨부파일',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    // 이미지는 미리보기, 비이미지는 chip
                    Builder(
                      builder: (context) {
                        const imgExts = [
                          '.png',
                          '.jpg',
                          '.jpeg',
                          '.gif',
                          '.webp',
                          '.heic',
                          '.heif',
                          '.bmp',
                        ];
                        bool isImage(String url) {
                          final lower =
                              url.split('?').first.toLowerCase();
                          return imgExts.any((e) => lower.endsWith(e));
                        }

                        final images = a.attachmentUrls
                            .where(isImage)
                            .toList();
                        final files = a.attachmentUrls
                            .where((u) => !isImage(u))
                            .toList();

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (images.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: images.map((url) {
                                  return GestureDetector(
                                    onTap: () => _openImageViewer(
                                        context, url),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppRadius.md),
                                      child: Image.network(
                                        url,
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 140,
                                          height: 140,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                              Icons.broken_image_outlined),
                                        ),
                                        loadingBuilder:
                                            (ctx, child, progress) {
                                          if (progress == null) {
                                            return child;
                                          }
                                          return Container(
                                            width: 140,
                                            height: 140,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHigh,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (images.isNotEmpty && files.isNotEmpty)
                              const SizedBox(height: AppSpacing.sm),
                            if (files.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: files.map((url) {
                                  final filename = url.split('/').last;
                                  return ActionChip(
                                    avatar: const Icon(Icons.attach_file,
                                        size: 16),
                                    label: Text(filename,
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    onPressed: () async {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication);
                                      } else {
                                        await Clipboard.setData(
                                            ClipboardData(text: url));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '파일 링크가 클립보드에 복사되었습니다'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                          ],
                        );
                      },
                    ),
                  ],

                  // 댓글 섹션
                  const SizedBox(height: AppSpacing.xxl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  Text('댓글',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  commentsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('댓글을 불러올 수 없습니다',
                        style: TextStyle(color: AppColors.error)),
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Text('아직 댓글이 없습니다',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              )),
                        );
                      }
                      return Column(
                        children: comments.map((cw) {
                          final isMine = cw.comment.userId == myUserId;
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    cw.displayName.isNotEmpty
                                        ? cw.displayName[0]
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(cw.displayName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              )),
                                          const SizedBox(
                                              width: AppSpacing.xs),
                                          if (cw.comment.createdAt != null)
                                            Text(
                                              dateFormat.format(
                                                  cw.comment.createdAt!),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(cw.comment.content,
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (isMine)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _deleteComment(cw.comment.id),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // 댓글 입력
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentC,
                      decoration: const InputDecoration(
                        hintText: '댓글 입력',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _posting ? null : _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공지 상세 헤더의 작성자 + 작성 일시 한 줄.
class _DetailAuthorLine extends StatelessWidget {
  const _DetailAuthorLine({
    required this.announcement,
    required this.dateFormat,
  });

  final AnnouncementModel announcement;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author =
        AnnouncementAuthorInfo.fromAnnouncement(announcement);
    final createdAt = announcement.createdAt;

    return AnnouncementAuthor(
      name: author.displayName,
      avatarUrl: author.avatarUrl,
      avatarRadius: 10,
      trailing: createdAt == null
          ? null
          : Text(
              dateFormat.format(createdAt),
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
    );
  }
}
