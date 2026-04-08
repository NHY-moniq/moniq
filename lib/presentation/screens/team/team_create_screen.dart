import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/core/utils/team_icon_utils.dart';
import 'package:moniq/data/models/team_model.dart';
import 'package:moniq/data/providers/supabase_providers.dart';
import 'package:moniq/data/providers/team_providers.dart';
import 'package:moniq/presentation/screens/team/team_create_widgets.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_calendar_viewmodel.dart';
import 'package:moniq/presentation/viewmodels/team_viewmodel.dart';

class TeamCreateScreen extends HookConsumerWidget {
  const TeamCreateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final descController = useTextEditingController();
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final createdTeam = useState<TeamModel?>(null);

    final selectedEmoji = useState(defaultEmoji);
    final selectedColor = useState(teamColors[0]);
    final selectedTeamType = useState('organizational');
    final pickedImageBytes = useState<Uint8List?>(null);
    final pickedImageUrl = useState<String?>(null);

    Future<void> handleCreate() async {
      if (!formKey.currentState!.validate()) return;
      errorMessage.value = null;
      isLoading.value = true;
      try {
        // 이미지 업로드
        String? iconEncoded;
        if (pickedImageBytes.value != null) {
          final client = ref.read(supabaseClientProvider);
          final userId = client.auth.currentUser?.id ?? '';
          final path =
              'team-icons/$userId-${DateTime.now().millisecondsSinceEpoch}.png';
          await client.storage
              .from('avatars')
              .uploadBinary(path, pickedImageBytes.value!);
          final url = client.storage
              .from('avatars')
              .getPublicUrl(path);
          iconEncoded = TeamIconData(
            color: selectedColor.value,
            imageUrl: url,
          ).encode();
        } else {
          iconEncoded = TeamIconData(
            emoji: selectedEmoji.value,
            color: selectedColor.value,
          ).encode();
        }

        final team = await ref
            .read(teamViewModelProvider.notifier)
            .createTeam(
              name: nameController.text.trim(),
              icon: iconEncoded,
              description:
                  descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : null,
              teamType: selectedTeamType.value,
            );

        // 즐겨찾기 팀이 없으면 자동 설정
        final teamRepo = ref.read(teamRepositoryProvider);
        final favorite = await teamRepo.getFavoriteTeam();
        if (favorite == null) {
          await teamRepo.setFavoriteTeam(team.id);
          ref.invalidate(favoriteTeamProvider);
        }

        createdTeam.value = team;
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    // 성공 화면
    if (createdTeam.value != null) {
      return TeamCreateSuccessView(team: createdTeam.value!);
    }

    // 생성 폼
    return Scaffold(
      appBar: AppBar(title: const Text('팀 만들기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenAll,
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 에러 메시지
                if (errorMessage.value != null) ...[
                  SelectableText.rich(
                    TextSpan(
                      text: errorMessage.value,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 프로필 미리보기 + 이모지 변경
                TeamCreateProfilePreview(
                  emoji: selectedEmoji.value,
                  color: selectedColor.value,
                  imageBytes: pickedImageBytes.value,
                  imageUrl: pickedImageUrl.value,
                  onEmojiChanged: (e) =>
                      selectedEmoji.value = e,
                  onPickImage: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 80,
                    );
                    if (file == null) return;
                    final bytes = await file.readAsBytes();
                    pickedImageBytes.value = bytes;
                    pickedImageUrl.value = null;
                  },
                  onClearImage: () {
                    pickedImageBytes.value = null;
                    pickedImageUrl.value = null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // 배경 색상
                Text(
                  '배경 색상',
                  style:
                      Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: teamColors.map((color) {
                    final isSelected =
                        color == selectedColor.value;
                    return GestureDetector(
                      onTap: () =>
                          selectedColor.value = color,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: parseHexColor(color),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  width: 2.5,
                                )
                              : null,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // 팀 타입
                Text(
                  '팀 유형',
                  style:
                      Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'organizational',
                      label: Text('조직'),
                      icon: Icon(Icons.business),
                    ),
                    ButtonSegment(
                      value: 'personal',
                      label: Text('개인'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: {selectedTeamType.value},
                  onSelectionChanged: (v) =>
                      selectedTeamType.value = v.first,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  selectedTeamType.value == 'organizational'
                      ? '병동, 부서 등 공유 근무표를 관리하는 팀'
                      : '개인 일정 관리용 (근무표 생성 불가)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // 팀 이름
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '팀 이름',
                    hintText: '예: 내과 3병동',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return '팀 이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // 설명
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택)',
                    hintText: '팀에 대한 간단한 설명',
                    prefixIcon:
                        Icon(Icons.description_outlined),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // 만들기 버튼
                ElevatedButton(
                  onPressed:
                      isLoading.value ? null : handleCreate,
                  child: isLoading.value
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary,
                          ),
                        )
                      : const Text('팀 만들기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
