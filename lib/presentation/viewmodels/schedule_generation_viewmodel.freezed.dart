// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_generation_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ScheduleGenerationState {
  String get teamId => throw _privateConstructorUsedError;
  List<ShiftTypeModel> get shiftTypes => throw _privateConstructorUsedError;
  List<TeamMemberWithUser> get members => throw _privateConstructorUsedError;
  List<ShiftRuleModel> get rules => throw _privateConstructorUsedError;
  List<CustomRuleModel> get customRules => throw _privateConstructorUsedError;
  DateTime? get periodStart => throw _privateConstructorUsedError;
  DateTime? get periodEnd => throw _privateConstructorUsedError;
  List<WantedEntryModel> get wantedEntries =>
      throw _privateConstructorUsedError;
  List<String> get excludedMemberIds => throw _privateConstructorUsedError;
  bool get isGenerating => throw _privateConstructorUsedError;
  bool get isPublishing => throw _privateConstructorUsedError;
  ScheduleModel? get generatedSchedule => throw _privateConstructorUsedError;
  List<ShiftModel>? get previewShifts => throw _privateConstructorUsedError;
  List<String>? get validationWarnings => throw _privateConstructorUsedError;
  int get understaffedCount => throw _privateConstructorUsedError;
  int get wantedTotal => throw _privateConstructorUsedError;
  int get wantedSatisfied => throw _privateConstructorUsedError;
  Map<String, List<String>> get softViolations =>
      throw _privateConstructorUsedError; // {'NOD':['홍길동 05-03',...], ...}
  List<String> get wantedUnsatisfied =>
      throw _privateConstructorUsedError; // ['홍길동 05-10 (휴무 요청)', ...]
  List<String> get customRuleViolations => throw _privateConstructorUsedError;
  bool get isAnalyzing => throw _privateConstructorUsedError;
  String? get aiAnalysis => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScheduleGenerationStateCopyWith<ScheduleGenerationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduleGenerationStateCopyWith<$Res> {
  factory $ScheduleGenerationStateCopyWith(
    ScheduleGenerationState value,
    $Res Function(ScheduleGenerationState) then,
  ) = _$ScheduleGenerationStateCopyWithImpl<$Res, ScheduleGenerationState>;
  @useResult
  $Res call({
    String teamId,
    List<ShiftTypeModel> shiftTypes,
    List<TeamMemberWithUser> members,
    List<ShiftRuleModel> rules,
    List<CustomRuleModel> customRules,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<WantedEntryModel> wantedEntries,
    List<String> excludedMemberIds,
    bool isGenerating,
    bool isPublishing,
    ScheduleModel? generatedSchedule,
    List<ShiftModel>? previewShifts,
    List<String>? validationWarnings,
    int understaffedCount,
    int wantedTotal,
    int wantedSatisfied,
    Map<String, List<String>> softViolations,
    List<String> wantedUnsatisfied,
    List<String> customRuleViolations,
    bool isAnalyzing,
    String? aiAnalysis,
    String? error,
  });

  $ScheduleModelCopyWith<$Res>? get generatedSchedule;
}

/// @nodoc
class _$ScheduleGenerationStateCopyWithImpl<
  $Res,
  $Val extends ScheduleGenerationState
>
    implements $ScheduleGenerationStateCopyWith<$Res> {
  _$ScheduleGenerationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? shiftTypes = null,
    Object? members = null,
    Object? rules = null,
    Object? customRules = null,
    Object? periodStart = freezed,
    Object? periodEnd = freezed,
    Object? wantedEntries = null,
    Object? excludedMemberIds = null,
    Object? isGenerating = null,
    Object? isPublishing = null,
    Object? generatedSchedule = freezed,
    Object? previewShifts = freezed,
    Object? validationWarnings = freezed,
    Object? understaffedCount = null,
    Object? wantedTotal = null,
    Object? wantedSatisfied = null,
    Object? softViolations = null,
    Object? wantedUnsatisfied = null,
    Object? customRuleViolations = null,
    Object? isAnalyzing = null,
    Object? aiAnalysis = freezed,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            shiftTypes: null == shiftTypes
                ? _value.shiftTypes
                : shiftTypes // ignore: cast_nullable_to_non_nullable
                      as List<ShiftTypeModel>,
            members: null == members
                ? _value.members
                : members // ignore: cast_nullable_to_non_nullable
                      as List<TeamMemberWithUser>,
            rules: null == rules
                ? _value.rules
                : rules // ignore: cast_nullable_to_non_nullable
                      as List<ShiftRuleModel>,
            customRules: null == customRules
                ? _value.customRules
                : customRules // ignore: cast_nullable_to_non_nullable
                      as List<CustomRuleModel>,
            periodStart: freezed == periodStart
                ? _value.periodStart
                : periodStart // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            periodEnd: freezed == periodEnd
                ? _value.periodEnd
                : periodEnd // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            wantedEntries: null == wantedEntries
                ? _value.wantedEntries
                : wantedEntries // ignore: cast_nullable_to_non_nullable
                      as List<WantedEntryModel>,
            excludedMemberIds: null == excludedMemberIds
                ? _value.excludedMemberIds
                : excludedMemberIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isGenerating: null == isGenerating
                ? _value.isGenerating
                : isGenerating // ignore: cast_nullable_to_non_nullable
                      as bool,
            isPublishing: null == isPublishing
                ? _value.isPublishing
                : isPublishing // ignore: cast_nullable_to_non_nullable
                      as bool,
            generatedSchedule: freezed == generatedSchedule
                ? _value.generatedSchedule
                : generatedSchedule // ignore: cast_nullable_to_non_nullable
                      as ScheduleModel?,
            previewShifts: freezed == previewShifts
                ? _value.previewShifts
                : previewShifts // ignore: cast_nullable_to_non_nullable
                      as List<ShiftModel>?,
            validationWarnings: freezed == validationWarnings
                ? _value.validationWarnings
                : validationWarnings // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            understaffedCount: null == understaffedCount
                ? _value.understaffedCount
                : understaffedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            wantedTotal: null == wantedTotal
                ? _value.wantedTotal
                : wantedTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            wantedSatisfied: null == wantedSatisfied
                ? _value.wantedSatisfied
                : wantedSatisfied // ignore: cast_nullable_to_non_nullable
                      as int,
            softViolations: null == softViolations
                ? _value.softViolations
                : softViolations // ignore: cast_nullable_to_non_nullable
                      as Map<String, List<String>>,
            wantedUnsatisfied: null == wantedUnsatisfied
                ? _value.wantedUnsatisfied
                : wantedUnsatisfied // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            customRuleViolations: null == customRuleViolations
                ? _value.customRuleViolations
                : customRuleViolations // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isAnalyzing: null == isAnalyzing
                ? _value.isAnalyzing
                : isAnalyzing // ignore: cast_nullable_to_non_nullable
                      as bool,
            aiAnalysis: freezed == aiAnalysis
                ? _value.aiAnalysis
                : aiAnalysis // ignore: cast_nullable_to_non_nullable
                      as String?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ScheduleModelCopyWith<$Res>? get generatedSchedule {
    if (_value.generatedSchedule == null) {
      return null;
    }

    return $ScheduleModelCopyWith<$Res>(_value.generatedSchedule!, (value) {
      return _then(_value.copyWith(generatedSchedule: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ScheduleGenerationStateImplCopyWith<$Res>
    implements $ScheduleGenerationStateCopyWith<$Res> {
  factory _$$ScheduleGenerationStateImplCopyWith(
    _$ScheduleGenerationStateImpl value,
    $Res Function(_$ScheduleGenerationStateImpl) then,
  ) = __$$ScheduleGenerationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    List<ShiftTypeModel> shiftTypes,
    List<TeamMemberWithUser> members,
    List<ShiftRuleModel> rules,
    List<CustomRuleModel> customRules,
    DateTime? periodStart,
    DateTime? periodEnd,
    List<WantedEntryModel> wantedEntries,
    List<String> excludedMemberIds,
    bool isGenerating,
    bool isPublishing,
    ScheduleModel? generatedSchedule,
    List<ShiftModel>? previewShifts,
    List<String>? validationWarnings,
    int understaffedCount,
    int wantedTotal,
    int wantedSatisfied,
    Map<String, List<String>> softViolations,
    List<String> wantedUnsatisfied,
    List<String> customRuleViolations,
    bool isAnalyzing,
    String? aiAnalysis,
    String? error,
  });

  @override
  $ScheduleModelCopyWith<$Res>? get generatedSchedule;
}

/// @nodoc
class __$$ScheduleGenerationStateImplCopyWithImpl<$Res>
    extends
        _$ScheduleGenerationStateCopyWithImpl<
          $Res,
          _$ScheduleGenerationStateImpl
        >
    implements _$$ScheduleGenerationStateImplCopyWith<$Res> {
  __$$ScheduleGenerationStateImplCopyWithImpl(
    _$ScheduleGenerationStateImpl _value,
    $Res Function(_$ScheduleGenerationStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? shiftTypes = null,
    Object? members = null,
    Object? rules = null,
    Object? customRules = null,
    Object? periodStart = freezed,
    Object? periodEnd = freezed,
    Object? wantedEntries = null,
    Object? excludedMemberIds = null,
    Object? isGenerating = null,
    Object? isPublishing = null,
    Object? generatedSchedule = freezed,
    Object? previewShifts = freezed,
    Object? validationWarnings = freezed,
    Object? understaffedCount = null,
    Object? wantedTotal = null,
    Object? wantedSatisfied = null,
    Object? softViolations = null,
    Object? wantedUnsatisfied = null,
    Object? customRuleViolations = null,
    Object? isAnalyzing = null,
    Object? aiAnalysis = freezed,
    Object? error = freezed,
  }) {
    return _then(
      _$ScheduleGenerationStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        shiftTypes: null == shiftTypes
            ? _value._shiftTypes
            : shiftTypes // ignore: cast_nullable_to_non_nullable
                  as List<ShiftTypeModel>,
        members: null == members
            ? _value._members
            : members // ignore: cast_nullable_to_non_nullable
                  as List<TeamMemberWithUser>,
        rules: null == rules
            ? _value._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<ShiftRuleModel>,
        customRules: null == customRules
            ? _value._customRules
            : customRules // ignore: cast_nullable_to_non_nullable
                  as List<CustomRuleModel>,
        periodStart: freezed == periodStart
            ? _value.periodStart
            : periodStart // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        periodEnd: freezed == periodEnd
            ? _value.periodEnd
            : periodEnd // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        wantedEntries: null == wantedEntries
            ? _value._wantedEntries
            : wantedEntries // ignore: cast_nullable_to_non_nullable
                  as List<WantedEntryModel>,
        excludedMemberIds: null == excludedMemberIds
            ? _value._excludedMemberIds
            : excludedMemberIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isGenerating: null == isGenerating
            ? _value.isGenerating
            : isGenerating // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPublishing: null == isPublishing
            ? _value.isPublishing
            : isPublishing // ignore: cast_nullable_to_non_nullable
                  as bool,
        generatedSchedule: freezed == generatedSchedule
            ? _value.generatedSchedule
            : generatedSchedule // ignore: cast_nullable_to_non_nullable
                  as ScheduleModel?,
        previewShifts: freezed == previewShifts
            ? _value._previewShifts
            : previewShifts // ignore: cast_nullable_to_non_nullable
                  as List<ShiftModel>?,
        validationWarnings: freezed == validationWarnings
            ? _value._validationWarnings
            : validationWarnings // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        understaffedCount: null == understaffedCount
            ? _value.understaffedCount
            : understaffedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        wantedTotal: null == wantedTotal
            ? _value.wantedTotal
            : wantedTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        wantedSatisfied: null == wantedSatisfied
            ? _value.wantedSatisfied
            : wantedSatisfied // ignore: cast_nullable_to_non_nullable
                  as int,
        softViolations: null == softViolations
            ? _value._softViolations
            : softViolations // ignore: cast_nullable_to_non_nullable
                  as Map<String, List<String>>,
        wantedUnsatisfied: null == wantedUnsatisfied
            ? _value._wantedUnsatisfied
            : wantedUnsatisfied // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        customRuleViolations: null == customRuleViolations
            ? _value._customRuleViolations
            : customRuleViolations // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isAnalyzing: null == isAnalyzing
            ? _value.isAnalyzing
            : isAnalyzing // ignore: cast_nullable_to_non_nullable
                  as bool,
        aiAnalysis: freezed == aiAnalysis
            ? _value.aiAnalysis
            : aiAnalysis // ignore: cast_nullable_to_non_nullable
                  as String?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$ScheduleGenerationStateImpl implements _ScheduleGenerationState {
  const _$ScheduleGenerationStateImpl({
    required this.teamId,
    required final List<ShiftTypeModel> shiftTypes,
    required final List<TeamMemberWithUser> members,
    required final List<ShiftRuleModel> rules,
    final List<CustomRuleModel> customRules = const [],
    this.periodStart,
    this.periodEnd,
    final List<WantedEntryModel> wantedEntries = const [],
    final List<String> excludedMemberIds = const [],
    this.isGenerating = false,
    this.isPublishing = false,
    this.generatedSchedule,
    final List<ShiftModel>? previewShifts,
    final List<String>? validationWarnings,
    this.understaffedCount = 0,
    this.wantedTotal = 0,
    this.wantedSatisfied = 0,
    final Map<String, List<String>> softViolations = const {},
    final List<String> wantedUnsatisfied = const [],
    final List<String> customRuleViolations = const [],
    this.isAnalyzing = false,
    this.aiAnalysis,
    this.error,
  }) : _shiftTypes = shiftTypes,
       _members = members,
       _rules = rules,
       _customRules = customRules,
       _wantedEntries = wantedEntries,
       _excludedMemberIds = excludedMemberIds,
       _previewShifts = previewShifts,
       _validationWarnings = validationWarnings,
       _softViolations = softViolations,
       _wantedUnsatisfied = wantedUnsatisfied,
       _customRuleViolations = customRuleViolations;

  @override
  final String teamId;
  final List<ShiftTypeModel> _shiftTypes;
  @override
  List<ShiftTypeModel> get shiftTypes {
    if (_shiftTypes is EqualUnmodifiableListView) return _shiftTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shiftTypes);
  }

  final List<TeamMemberWithUser> _members;
  @override
  List<TeamMemberWithUser> get members {
    if (_members is EqualUnmodifiableListView) return _members;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_members);
  }

  final List<ShiftRuleModel> _rules;
  @override
  List<ShiftRuleModel> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  final List<CustomRuleModel> _customRules;
  @override
  @JsonKey()
  List<CustomRuleModel> get customRules {
    if (_customRules is EqualUnmodifiableListView) return _customRules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customRules);
  }

  @override
  final DateTime? periodStart;
  @override
  final DateTime? periodEnd;
  final List<WantedEntryModel> _wantedEntries;
  @override
  @JsonKey()
  List<WantedEntryModel> get wantedEntries {
    if (_wantedEntries is EqualUnmodifiableListView) return _wantedEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_wantedEntries);
  }

  final List<String> _excludedMemberIds;
  @override
  @JsonKey()
  List<String> get excludedMemberIds {
    if (_excludedMemberIds is EqualUnmodifiableListView)
      return _excludedMemberIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_excludedMemberIds);
  }

  @override
  @JsonKey()
  final bool isGenerating;
  @override
  @JsonKey()
  final bool isPublishing;
  @override
  final ScheduleModel? generatedSchedule;
  final List<ShiftModel>? _previewShifts;
  @override
  List<ShiftModel>? get previewShifts {
    final value = _previewShifts;
    if (value == null) return null;
    if (_previewShifts is EqualUnmodifiableListView) return _previewShifts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _validationWarnings;
  @override
  List<String>? get validationWarnings {
    final value = _validationWarnings;
    if (value == null) return null;
    if (_validationWarnings is EqualUnmodifiableListView)
      return _validationWarnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final int understaffedCount;
  @override
  @JsonKey()
  final int wantedTotal;
  @override
  @JsonKey()
  final int wantedSatisfied;
  final Map<String, List<String>> _softViolations;
  @override
  @JsonKey()
  Map<String, List<String>> get softViolations {
    if (_softViolations is EqualUnmodifiableMapView) return _softViolations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_softViolations);
  }

  // {'NOD':['홍길동 05-03',...], ...}
  final List<String> _wantedUnsatisfied;
  // {'NOD':['홍길동 05-03',...], ...}
  @override
  @JsonKey()
  List<String> get wantedUnsatisfied {
    if (_wantedUnsatisfied is EqualUnmodifiableListView)
      return _wantedUnsatisfied;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_wantedUnsatisfied);
  }

  // ['홍길동 05-10 (휴무 요청)', ...]
  final List<String> _customRuleViolations;
  // ['홍길동 05-10 (휴무 요청)', ...]
  @override
  @JsonKey()
  List<String> get customRuleViolations {
    if (_customRuleViolations is EqualUnmodifiableListView)
      return _customRuleViolations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customRuleViolations);
  }

  @override
  @JsonKey()
  final bool isAnalyzing;
  @override
  final String? aiAnalysis;
  @override
  final String? error;

  @override
  String toString() {
    return 'ScheduleGenerationState(teamId: $teamId, shiftTypes: $shiftTypes, members: $members, rules: $rules, customRules: $customRules, periodStart: $periodStart, periodEnd: $periodEnd, wantedEntries: $wantedEntries, excludedMemberIds: $excludedMemberIds, isGenerating: $isGenerating, isPublishing: $isPublishing, generatedSchedule: $generatedSchedule, previewShifts: $previewShifts, validationWarnings: $validationWarnings, understaffedCount: $understaffedCount, wantedTotal: $wantedTotal, wantedSatisfied: $wantedSatisfied, softViolations: $softViolations, wantedUnsatisfied: $wantedUnsatisfied, customRuleViolations: $customRuleViolations, isAnalyzing: $isAnalyzing, aiAnalysis: $aiAnalysis, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduleGenerationStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            const DeepCollectionEquality().equals(
              other._shiftTypes,
              _shiftTypes,
            ) &&
            const DeepCollectionEquality().equals(other._members, _members) &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            const DeepCollectionEquality().equals(
              other._customRules,
              _customRules,
            ) &&
            (identical(other.periodStart, periodStart) ||
                other.periodStart == periodStart) &&
            (identical(other.periodEnd, periodEnd) ||
                other.periodEnd == periodEnd) &&
            const DeepCollectionEquality().equals(
              other._wantedEntries,
              _wantedEntries,
            ) &&
            const DeepCollectionEquality().equals(
              other._excludedMemberIds,
              _excludedMemberIds,
            ) &&
            (identical(other.isGenerating, isGenerating) ||
                other.isGenerating == isGenerating) &&
            (identical(other.isPublishing, isPublishing) ||
                other.isPublishing == isPublishing) &&
            (identical(other.generatedSchedule, generatedSchedule) ||
                other.generatedSchedule == generatedSchedule) &&
            const DeepCollectionEquality().equals(
              other._previewShifts,
              _previewShifts,
            ) &&
            const DeepCollectionEquality().equals(
              other._validationWarnings,
              _validationWarnings,
            ) &&
            (identical(other.understaffedCount, understaffedCount) ||
                other.understaffedCount == understaffedCount) &&
            (identical(other.wantedTotal, wantedTotal) ||
                other.wantedTotal == wantedTotal) &&
            (identical(other.wantedSatisfied, wantedSatisfied) ||
                other.wantedSatisfied == wantedSatisfied) &&
            const DeepCollectionEquality().equals(
              other._softViolations,
              _softViolations,
            ) &&
            const DeepCollectionEquality().equals(
              other._wantedUnsatisfied,
              _wantedUnsatisfied,
            ) &&
            const DeepCollectionEquality().equals(
              other._customRuleViolations,
              _customRuleViolations,
            ) &&
            (identical(other.isAnalyzing, isAnalyzing) ||
                other.isAnalyzing == isAnalyzing) &&
            (identical(other.aiAnalysis, aiAnalysis) ||
                other.aiAnalysis == aiAnalysis) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    teamId,
    const DeepCollectionEquality().hash(_shiftTypes),
    const DeepCollectionEquality().hash(_members),
    const DeepCollectionEquality().hash(_rules),
    const DeepCollectionEquality().hash(_customRules),
    periodStart,
    periodEnd,
    const DeepCollectionEquality().hash(_wantedEntries),
    const DeepCollectionEquality().hash(_excludedMemberIds),
    isGenerating,
    isPublishing,
    generatedSchedule,
    const DeepCollectionEquality().hash(_previewShifts),
    const DeepCollectionEquality().hash(_validationWarnings),
    understaffedCount,
    wantedTotal,
    wantedSatisfied,
    const DeepCollectionEquality().hash(_softViolations),
    const DeepCollectionEquality().hash(_wantedUnsatisfied),
    const DeepCollectionEquality().hash(_customRuleViolations),
    isAnalyzing,
    aiAnalysis,
    error,
  ]);

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduleGenerationStateImplCopyWith<_$ScheduleGenerationStateImpl>
  get copyWith =>
      __$$ScheduleGenerationStateImplCopyWithImpl<
        _$ScheduleGenerationStateImpl
      >(this, _$identity);
}

abstract class _ScheduleGenerationState implements ScheduleGenerationState {
  const factory _ScheduleGenerationState({
    required final String teamId,
    required final List<ShiftTypeModel> shiftTypes,
    required final List<TeamMemberWithUser> members,
    required final List<ShiftRuleModel> rules,
    final List<CustomRuleModel> customRules,
    final DateTime? periodStart,
    final DateTime? periodEnd,
    final List<WantedEntryModel> wantedEntries,
    final List<String> excludedMemberIds,
    final bool isGenerating,
    final bool isPublishing,
    final ScheduleModel? generatedSchedule,
    final List<ShiftModel>? previewShifts,
    final List<String>? validationWarnings,
    final int understaffedCount,
    final int wantedTotal,
    final int wantedSatisfied,
    final Map<String, List<String>> softViolations,
    final List<String> wantedUnsatisfied,
    final List<String> customRuleViolations,
    final bool isAnalyzing,
    final String? aiAnalysis,
    final String? error,
  }) = _$ScheduleGenerationStateImpl;

  @override
  String get teamId;
  @override
  List<ShiftTypeModel> get shiftTypes;
  @override
  List<TeamMemberWithUser> get members;
  @override
  List<ShiftRuleModel> get rules;
  @override
  List<CustomRuleModel> get customRules;
  @override
  DateTime? get periodStart;
  @override
  DateTime? get periodEnd;
  @override
  List<WantedEntryModel> get wantedEntries;
  @override
  List<String> get excludedMemberIds;
  @override
  bool get isGenerating;
  @override
  bool get isPublishing;
  @override
  ScheduleModel? get generatedSchedule;
  @override
  List<ShiftModel>? get previewShifts;
  @override
  List<String>? get validationWarnings;
  @override
  int get understaffedCount;
  @override
  int get wantedTotal;
  @override
  int get wantedSatisfied;
  @override
  Map<String, List<String>> get softViolations; // {'NOD':['홍길동 05-03',...], ...}
  @override
  List<String> get wantedUnsatisfied; // ['홍길동 05-10 (휴무 요청)', ...]
  @override
  List<String> get customRuleViolations;
  @override
  bool get isAnalyzing;
  @override
  String? get aiAnalysis;
  @override
  String? get error;

  /// Create a copy of ScheduleGenerationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScheduleGenerationStateImplCopyWith<_$ScheduleGenerationStateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
