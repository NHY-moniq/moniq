// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_detail_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TeamDetailState {
  String get teamId => throw _privateConstructorUsedError;
  TeamModel get team => throw _privateConstructorUsedError;
  List<TeamMemberWithUser> get members => throw _privateConstructorUsedError;
  List<ShiftTypeModel> get shiftTypes => throw _privateConstructorUsedError;
  List<ShiftRuleModel> get rules => throw _privateConstructorUsedError;
  bool get isAdmin => throw _privateConstructorUsedError;
  String get currentUserId => throw _privateConstructorUsedError;

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamDetailStateCopyWith<TeamDetailState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamDetailStateCopyWith<$Res> {
  factory $TeamDetailStateCopyWith(
    TeamDetailState value,
    $Res Function(TeamDetailState) then,
  ) = _$TeamDetailStateCopyWithImpl<$Res, TeamDetailState>;
  @useResult
  $Res call({
    String teamId,
    TeamModel team,
    List<TeamMemberWithUser> members,
    List<ShiftTypeModel> shiftTypes,
    List<ShiftRuleModel> rules,
    bool isAdmin,
    String currentUserId,
  });

  $TeamModelCopyWith<$Res> get team;
}

/// @nodoc
class _$TeamDetailStateCopyWithImpl<$Res, $Val extends TeamDetailState>
    implements $TeamDetailStateCopyWith<$Res> {
  _$TeamDetailStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? team = null,
    Object? members = null,
    Object? shiftTypes = null,
    Object? rules = null,
    Object? isAdmin = null,
    Object? currentUserId = null,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            team: null == team
                ? _value.team
                : team // ignore: cast_nullable_to_non_nullable
                      as TeamModel,
            members: null == members
                ? _value.members
                : members // ignore: cast_nullable_to_non_nullable
                      as List<TeamMemberWithUser>,
            shiftTypes: null == shiftTypes
                ? _value.shiftTypes
                : shiftTypes // ignore: cast_nullable_to_non_nullable
                      as List<ShiftTypeModel>,
            rules: null == rules
                ? _value.rules
                : rules // ignore: cast_nullable_to_non_nullable
                      as List<ShiftRuleModel>,
            isAdmin: null == isAdmin
                ? _value.isAdmin
                : isAdmin // ignore: cast_nullable_to_non_nullable
                      as bool,
            currentUserId: null == currentUserId
                ? _value.currentUserId
                : currentUserId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TeamModelCopyWith<$Res> get team {
    return $TeamModelCopyWith<$Res>(_value.team, (value) {
      return _then(_value.copyWith(team: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TeamDetailStateImplCopyWith<$Res>
    implements $TeamDetailStateCopyWith<$Res> {
  factory _$$TeamDetailStateImplCopyWith(
    _$TeamDetailStateImpl value,
    $Res Function(_$TeamDetailStateImpl) then,
  ) = __$$TeamDetailStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    TeamModel team,
    List<TeamMemberWithUser> members,
    List<ShiftTypeModel> shiftTypes,
    List<ShiftRuleModel> rules,
    bool isAdmin,
    String currentUserId,
  });

  @override
  $TeamModelCopyWith<$Res> get team;
}

/// @nodoc
class __$$TeamDetailStateImplCopyWithImpl<$Res>
    extends _$TeamDetailStateCopyWithImpl<$Res, _$TeamDetailStateImpl>
    implements _$$TeamDetailStateImplCopyWith<$Res> {
  __$$TeamDetailStateImplCopyWithImpl(
    _$TeamDetailStateImpl _value,
    $Res Function(_$TeamDetailStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? team = null,
    Object? members = null,
    Object? shiftTypes = null,
    Object? rules = null,
    Object? isAdmin = null,
    Object? currentUserId = null,
  }) {
    return _then(
      _$TeamDetailStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        team: null == team
            ? _value.team
            : team // ignore: cast_nullable_to_non_nullable
                  as TeamModel,
        members: null == members
            ? _value._members
            : members // ignore: cast_nullable_to_non_nullable
                  as List<TeamMemberWithUser>,
        shiftTypes: null == shiftTypes
            ? _value._shiftTypes
            : shiftTypes // ignore: cast_nullable_to_non_nullable
                  as List<ShiftTypeModel>,
        rules: null == rules
            ? _value._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as List<ShiftRuleModel>,
        isAdmin: null == isAdmin
            ? _value.isAdmin
            : isAdmin // ignore: cast_nullable_to_non_nullable
                  as bool,
        currentUserId: null == currentUserId
            ? _value.currentUserId
            : currentUserId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$TeamDetailStateImpl implements _TeamDetailState {
  const _$TeamDetailStateImpl({
    required this.teamId,
    required this.team,
    required final List<TeamMemberWithUser> members,
    required final List<ShiftTypeModel> shiftTypes,
    required final List<ShiftRuleModel> rules,
    required this.isAdmin,
    required this.currentUserId,
  }) : _members = members,
       _shiftTypes = shiftTypes,
       _rules = rules;

  @override
  final String teamId;
  @override
  final TeamModel team;
  final List<TeamMemberWithUser> _members;
  @override
  List<TeamMemberWithUser> get members {
    if (_members is EqualUnmodifiableListView) return _members;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_members);
  }

  final List<ShiftTypeModel> _shiftTypes;
  @override
  List<ShiftTypeModel> get shiftTypes {
    if (_shiftTypes is EqualUnmodifiableListView) return _shiftTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shiftTypes);
  }

  final List<ShiftRuleModel> _rules;
  @override
  List<ShiftRuleModel> get rules {
    if (_rules is EqualUnmodifiableListView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rules);
  }

  @override
  final bool isAdmin;
  @override
  final String currentUserId;

  @override
  String toString() {
    return 'TeamDetailState(teamId: $teamId, team: $team, members: $members, shiftTypes: $shiftTypes, rules: $rules, isAdmin: $isAdmin, currentUserId: $currentUserId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamDetailStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.team, team) || other.team == team) &&
            const DeepCollectionEquality().equals(other._members, _members) &&
            const DeepCollectionEquality().equals(
              other._shiftTypes,
              _shiftTypes,
            ) &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin) &&
            (identical(other.currentUserId, currentUserId) ||
                other.currentUserId == currentUserId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    team,
    const DeepCollectionEquality().hash(_members),
    const DeepCollectionEquality().hash(_shiftTypes),
    const DeepCollectionEquality().hash(_rules),
    isAdmin,
    currentUserId,
  );

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamDetailStateImplCopyWith<_$TeamDetailStateImpl> get copyWith =>
      __$$TeamDetailStateImplCopyWithImpl<_$TeamDetailStateImpl>(
        this,
        _$identity,
      );
}

abstract class _TeamDetailState implements TeamDetailState {
  const factory _TeamDetailState({
    required final String teamId,
    required final TeamModel team,
    required final List<TeamMemberWithUser> members,
    required final List<ShiftTypeModel> shiftTypes,
    required final List<ShiftRuleModel> rules,
    required final bool isAdmin,
    required final String currentUserId,
  }) = _$TeamDetailStateImpl;

  @override
  String get teamId;
  @override
  TeamModel get team;
  @override
  List<TeamMemberWithUser> get members;
  @override
  List<ShiftTypeModel> get shiftTypes;
  @override
  List<ShiftRuleModel> get rules;
  @override
  bool get isAdmin;
  @override
  String get currentUserId;

  /// Create a copy of TeamDetailState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamDetailStateImplCopyWith<_$TeamDetailStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
