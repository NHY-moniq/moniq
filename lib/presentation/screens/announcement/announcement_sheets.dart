part of 'announcement_screen.dart';

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

/// 공지 수정 바텀시트를 띄운다. 저장 성공 시 true, 취소/변경 없음은 null/false.
Future<bool?> showAnnouncementEditSheet(
  BuildContext context,
  AnnouncementModel announcement,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _AnnouncementEditSheet(announcement: announcement),
  );
}

class _AnnouncementEditSheet extends ConsumerStatefulWidget {
  const _AnnouncementEditSheet({required this.announcement});
  final AnnouncementModel announcement;

  @override
  ConsumerState<_AnnouncementEditSheet> createState() =>
      _AnnouncementEditSheetState();
}

class _AnnouncementEditSheetState
    extends ConsumerState<_AnnouncementEditSheet> {
  late final TextEditingController _titleC;
  late final TextEditingController _contentC;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.announcement.title);
    _contentC = TextEditingController(text: widget.announcement.content ?? '');
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) return;

    final content = _contentC.text.trim();
    final originalContent = widget.announcement.content ?? '';

    final titleChanged = title != widget.announcement.title;
    final contentChanged = content != originalContent;
    if (!titleChanged && !contentChanged) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(announcementRepositoryProvider).update(
            widget.announcement.id,
            title: titleChanged ? title : null,
            content: contentChanged ? content : null,
          );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지사항이 수정되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
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
          Text('공지사항 수정',
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
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}

