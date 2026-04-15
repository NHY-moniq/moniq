import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

class AnnouncementScreen extends HookConsumerWidget {
  const AnnouncementScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync =
        ref.watch(teamAnnouncementsProvider(teamId));

    return Scaffold(
      appBar: AppBar(title: const Text('팀 공지사항')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
      body: announcementsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '공지사항을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamAnnouncementsProvider(teamId)),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return const MoniqEmptyState(
              icon: Icons.campaign_outlined,
              message: '등록된 공지사항이 없습니다',
              description: '팀원들에게 전달할 공지를 작성해보세요',
            );
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(teamAnnouncementsProvider(teamId)),
            child: ListView.separated(
              padding: AppSpacing.screenAll,
              itemCount: announcements.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final a = announcements[index];
                return AnnouncementListTile(
                  title: a.title,
                  content: a.content,
                  createdAt: a.createdAt,
                  isPinned: a.isPinned,
                  onTap: () => _showDetail(context, ref, a),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _AnnouncementCreateSheet(teamId: teamId),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, AnnouncementModel a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailPage(
          announcement: a,
          onDelete: () async {
            final repo = ref.read(announcementRepositoryProvider);
            await repo.delete(a.id);
            ref.invalidate(teamAnnouncementsProvider(teamId));
            ref.invalidate(myAnnouncementsProvider);
          },
        ),
      ),
    );
  }
}

class _AnnouncementCreateSheet extends ConsumerStatefulWidget {
  const _AnnouncementCreateSheet({required this.teamId});
  final String teamId;

  @override
  ConsumerState<_AnnouncementCreateSheet> createState() =>
      _AnnouncementCreateSheetState();
}

class _AnnouncementCreateSheetState
    extends ConsumerState<_AnnouncementCreateSheet> {
  final _titleC = TextEditingController();
  final _contentC = TextEditingController();
  final List<_PendingAttachment> _pending = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진 라이브러리에서 선택'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('파일 선택'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'photo') {
      final picker = ImagePicker();
      // 업로드 시간 단축: 리사이즈 + 품질 85
      final picked = await picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;
      setState(() {
        for (final x in picked) {
          _pending.add(_PendingAttachment(name: x.name, path: x.path));
        }
      });
    } else if (choice == 'camera') {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      setState(() {
        _pending.add(_PendingAttachment(name: x.name, path: x.path));
      });
    } else if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      setState(() {
        for (final f in result.files) {
          if (f.path != null) {
            _pending.add(_PendingAttachment(name: f.name, path: f.path!));
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(announcementRepositoryProvider);
      // 첨부 업로드 — 병렬
      final urls = await Future.wait(_pending.map((p) => repo.uploadAttachment(
            teamId: widget.teamId,
            file: File(p.path),
            filename: p.name,
          )));
      await repo.create(
        teamId: widget.teamId,
        title: title,
        content: _contentC.text.trim().isNotEmpty ? _contentC.text.trim() : null,
        attachmentUrls: urls,
      );
      ref.invalidate(teamAnnouncementsProvider(widget.teamId));
      ref.invalidate(myAnnouncementsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지사항이 등록되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('공지사항 작성',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(
              hintText: '제목',
              prefixIcon: Icon(Icons.title),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _contentC,
            decoration: const InputDecoration(
              hintText: '내용 (선택)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 6,
            maxLength: 2000,
          ),
          const SizedBox(height: AppSpacing.md),
          // 첨부파일 영역
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _pickAttachment,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('첨부파일 추가'),
            ),
          ),
          if (_pending.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _pending
                  .asMap()
                  .entries
                  .map((e) => Chip(
                        label: Text(e.value.name,
                            style: const TextStyle(fontSize: 11)),
                        onDeleted: _saving
                            ? null
                            : () => setState(() => _pending.removeAt(e.key)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('등록'),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachment {
  _PendingAttachment({required this.name, required this.path});
  final String name;
  final String path;
}

// ══════════════════════════════════════════════
// 공용 위젯들 (팀 관리 + 홈탭 공유)
// ══════════════════════════════════════════════

/// 공지사항 리스트 타일 (공용)
class AnnouncementListTile extends StatelessWidget {
  const AnnouncementListTile({
    super.key,
    this.teamName,
    required this.title,
    this.content,
    this.createdAt,
    this.isPinned = false,
    required this.onTap,
  });

  final String? teamName;
  final String title;
  final String? content;
  final DateTime? createdAt;
  final bool isPinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 팀 이름 (있는 경우)
                    if (teamName != null) ...[
                      Text(
                        teamName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    // 제목
                    Row(
                      children: [
                        if (isPinned) ...[
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppColors.brandOrange,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style:
                                theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // 내용 미리보기
                    if (content != null &&
                        content!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        content!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (createdAt != null)
                Text(
                  dateFormat.format(createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공지사항 상세 페이지 (공용) — 첨부파일 + 댓글 지원
class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
    this.teamName,
    this.onDelete,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final Future<void> Function()? onDelete;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName ?? '공지사항'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('공지 삭제'),
                    content:
                        const Text('이 공지사항을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        child: Text(
                          '삭제',
                          style: TextStyle(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.onDelete!();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (a.createdAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dateFormat.format(a.createdAt!),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
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
