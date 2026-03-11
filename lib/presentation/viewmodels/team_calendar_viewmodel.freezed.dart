// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_calendar_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$TeamCalendarState {
  String get teamId => throw _privateConstructorUsedError;
  String get teamName => throw _privateConstructorUsedError;
  DateTime get focusedMonth => throw _privateConstructorUsedError;
  DateTime get selectedDate => throw _privateConstructorUsedError;
  CalendarViewMode get viewMode => throw _privateConstructorUsedError;
  Map<DateTime, List<ShiftWithType>> get monthlyShifts =>
      throw _privateConstructorUsedError;
  List<RosterEntry> get selectedDateRoster =>
      throw _privateConstructorUsedError;
  List<ShiftTypeModel> get shiftTypes => throw _privateConstructorUsedError;

  /// Create a copy of TeamCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeamCalendarStateCopyWith<TeamCalendarState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeamCalendarStateCopyWith<$Res> {
  factory $TeamCalendarStateCopyWith(
    TeamCalendarState value,
    $Res Function(TeamCalendarState) then,
  ) = _$TeamCalendarStateCopyWithImpl<$Res, TeamCalendarState>;
  @useResult
  $Res call({
    String teamId,
    String teamName,
    DateTime focusedMonth,
    DateTime selectedDate,
    CalendarViewMode viewMode,
    Map<DateTime, List<ShiftWithType>> monthlyShifts,
    List<RosterEntry> selectedDateRoster,
    List<ShiftTypeModel> shiftTypes,
  });
}

/// @nodoc
class _$TeamCalendarStateCopyWithImpl<$Res, $Val extends TeamCalendarState>
    implements $TeamCalendarStateCopyWith<$Res> {
  _$TeamCalendarStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TeamCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? teamName = null,
    Object? focusedMonth = null,
    Object? selectedDate = null,
    Object? viewMode = null,
    Object? monthlyShifts = null,
    Object? selectedDateRoster = null,
    Object? shiftTypes = null,
  }) {
    return _then(
      _value.copyWith(
            teamId: null == teamId
                ? _value.teamId
                : teamId // ignore: cast_nullable_to_non_nullable
                      as String,
            teamName: null == teamName
                ? _value.teamName
                : teamName // ignore: cast_nullable_to_non_nullable
                      as String,
            focusedMonth: null == focusedMonth
                ? _value.focusedMonth
                : focusedMonth // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            selectedDate: null == selectedDate
                ? _value.selectedDate
                : selectedDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            viewMode: null == viewMode
                ? _value.viewMode
                : viewMode // ignore: cast_nullable_to_non_nullable
                      as CalendarViewMode,
            monthlyShifts: null == monthlyShifts
                ? _value.monthlyShifts
                : monthlyShifts // ignore: cast_nullable_to_non_nullable
                      as Map<DateTime, List<ShiftWithType>>,
            selectedDateRoster: null == selectedDateRoster
                ? _value.selectedDateRoster
                : selectedDateRoster // ignore: cast_nullable_to_non_nullable
                      as List<RosterEntry>,
            shiftTypes: null == shiftTypes
                ? _value.shiftTypes
                : shiftTypes // ignore: cast_nullable_to_non_nullable
                      as List<ShiftTypeModel>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TeamCalendarStateImplCopyWith<$Res>
    implements $TeamCalendarStateCopyWith<$Res> {
  factory _$$TeamCalendarStateImplCopyWith(
    _$TeamCalendarStateImpl value,
    $Res Function(_$TeamCalendarStateImpl) then,
  ) = __$$TeamCalendarStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String teamId,
    String teamName,
    DateTime focusedMonth,
    DateTime selectedDate,
    CalendarViewMode viewMode,
    Map<DateTime, List<ShiftWithType>> monthlyShifts,
    List<RosterEntry> selectedDateRoster,
    List<ShiftTypeModel> shiftTypes,
  });
}

/// @nodoc
class __$$TeamCalendarStateImplCopyWithImpl<$Res>
    extends _$TeamCalendarStateCopyWithImpl<$Res, _$TeamCalendarStateImpl>
    implements _$$TeamCalendarStateImplCopyWith<$Res> {
  __$$TeamCalendarStateImplCopyWithImpl(
    _$TeamCalendarStateImpl _value,
    $Res Function(_$TeamCalendarStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TeamCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? teamId = null,
    Object? teamName = null,
    Object? focusedMonth = null,
    Object? selectedDate = null,
    Object? viewMode = null,
    Object? monthlyShifts = null,
    Object? selectedDateRoster = null,
    Object? shiftTypes = null,
  }) {
    return _then(
      _$TeamCalendarStateImpl(
        teamId: null == teamId
            ? _value.teamId
            : teamId // ignore: cast_nullable_to_non_nullable
                  as String,
        teamName: null == teamName
            ? _value.teamName
            : teamName // ignore: cast_nullable_to_non_nullable
                  as String,
        focusedMonth: null == focusedMonth
            ? _value.focusedMonth
            : focusedMonth // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        selectedDate: null == selectedDate
            ? _value.selectedDate
            : selectedDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        viewMode: null == viewMode
            ? _value.viewMode
            : viewMode // ignore: cast_nullable_to_non_nullable
                  as CalendarViewMode,
        monthlyShifts: null == monthlyShifts
            ? _value._monthlyShifts
            : monthlyShifts // ignore: cast_nullable_to_non_nullable
                  as Map<DateTime, List<ShiftWithType>>,
        selectedDateRoster: null == selectedDateRoster
            ? _value._selectedDateRoster
            : selectedDateRoster // ignore: cast_nullable_to_non_nullable
                  as List<RosterEntry>,
        shiftTypes: null == shiftTypes
            ? _value._shiftTypes
            : shiftTypes // ignore: cast_nullable_to_non_nullable
                  as List<ShiftTypeModel>,
      ),
    );
  }
}

/// @nodoc

class _$TeamCalendarStateImpl implements _TeamCalendarState {
  const _$TeamCalendarStateImpl({
    required this.teamId,
    required this.teamName,
    required this.focusedMonth,
    required this.selectedDate,
    this.viewMode = CalendarViewMode.month,
    final Map<DateTime, List<ShiftWithType>> monthlyShifts = const {},
    final List<RosterEntry> selectedDateRoster = const [],
    final List<ShiftTypeModel> shiftTypes = const [],
  }) : _monthlyShifts = monthlyShifts,
       _selectedDateRoster = selectedDateRoster,
       _shiftTypes = shiftTypes;

  @override
  final String teamId;
  @override
  final String teamName;
  @override
  final DateTime focusedMonth;
  @override
  final DateTime selectedDate;
  @override
  @JsonKey()
  final CalendarViewMode viewMode;
  final Map<DateTime, List<ShiftWithType>> _monthlyShifts;
  @override
  @JsonKey()
  Map<DateTime, List<ShiftWithType>> get monthlyShifts {
    if (_monthlyShifts is EqualUnmodifiableMapView) return _monthlyShifts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_monthlyShifts);
  }

  final List<RosterEntry> _selectedDateRoster;
  @override
  @JsonKey()
  List<RosterEntry> get selectedDateRoster {
    if (_selectedDateRoster is EqualUnmodifiableListView)
      return _selectedDateRoster;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedDateRoster);
  }

  final List<ShiftTypeModel> _shiftTypes;
  @override
  @JsonKey()
  List<ShiftTypeModel> get shiftTypes {
    if (_shiftTypes is EqualUnmodifiableListView) return _shiftTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shiftTypes);
  }

  @override
  String toString() {
    return 'TeamCalendarState(teamId: $teamId, teamName: $teamName, focusedMonth: $focusedMonth, selectedDate: $selectedDate, viewMode: $viewMode, monthlyShifts: $monthlyShifts, selectedDateRoster: $selectedDateRoster, shiftTypes: $shiftTypes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeamCalendarStateImpl &&
            (identical(other.teamId, teamId) || other.teamId == teamId) &&
            (identical(other.teamName, teamName) ||
                other.teamName == teamName) &&
            (identical(other.focusedMonth, focusedMonth) ||
                other.focusedMonth == focusedMonth) &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            (identical(other.viewMode, viewMode) ||
                other.viewMode == viewMode) &&
            const DeepCollectionEquality().equals(
              other._monthlyShifts,
              _monthlyShifts,
            ) &&
            const DeepCollectionEquality().equals(
              other._selectedDateRoster,
              _selectedDateRoster,
            ) &&
            const DeepCollectionEquality().equals(
              other._shiftTypes,
              _shiftTypes,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    teamId,
    teamName,
    focusedMonth,
    selectedDate,
    viewMode,
    const DeepCollectionEquality().hash(_monthlyShifts),
    const DeepCollectionEquality().hash(_selectedDateRoster),
    const DeepCollectionEquality().hash(_shiftTypes),
  );

  /// Create a copy of TeamCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeamCalendarStateImplCopyWith<_$TeamCalendarStateImpl> get copyWith =>
      __$$TeamCalendarStateImplCopyWithImpl<_$TeamCalendarStateImpl>(
        this,
        _$identity,
      );
}

abstract class _TeamCalendarState implements TeamCalendarState {
  const factory _TeamCalendarState({
    required final String teamId,
    required final String teamName,
    required final DateTime focusedMonth,
    required final DateTime selectedDate,
    final CalendarViewMode viewMode,
    final Map<DateTime, List<ShiftWithType>> monthlyShifts,
    final List<RosterEntry> selectedDateRoster,
    final List<ShiftTypeModel> shiftTypes,
  }) = _$TeamCalendarStateImpl;

  @override
  String get teamId;
  @override
  String get teamName;
  @override
  DateTime get focusedMonth;
  @override
  DateTime get selectedDate;
  @override
  CalendarViewMode get viewMode;
  @override
  Map<DateTime, List<ShiftWithType>> get monthlyShifts;
  @override
  List<RosterEntry> get selectedDateRoster;
  @override
  List<ShiftTypeModel> get shiftTypes;

  /// Create a copy of TeamCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeamCalendarStateImplCopyWith<_$TeamCalendarStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
