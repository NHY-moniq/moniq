// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_viewmodel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$HomeCalendarState {
  DateTime get focusedMonth => throw _privateConstructorUsedError;
  DateTime get selectedDate => throw _privateConstructorUsedError;
  Map<DateTime, List<ShiftWithType>> get monthlyShifts =>
      throw _privateConstructorUsedError;
  List<ShiftWithType>? get selectedDateShifts =>
      throw _privateConstructorUsedError;
  CalendarViewMode get viewMode => throw _privateConstructorUsedError;

  /// 즐겨찾기 팀의 published 스케줄이 커버하는 날짜들.
  /// 본인 근무가 없어도 이 set에 포함되면 OFF로 표시한다.
  Set<DateTime> get teamScheduledDates => throw _privateConstructorUsedError;

  /// Create a copy of HomeCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HomeCalendarStateCopyWith<HomeCalendarState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HomeCalendarStateCopyWith<$Res> {
  factory $HomeCalendarStateCopyWith(
    HomeCalendarState value,
    $Res Function(HomeCalendarState) then,
  ) = _$HomeCalendarStateCopyWithImpl<$Res, HomeCalendarState>;
  @useResult
  $Res call({
    DateTime focusedMonth,
    DateTime selectedDate,
    Map<DateTime, List<ShiftWithType>> monthlyShifts,
    List<ShiftWithType>? selectedDateShifts,
    CalendarViewMode viewMode,
    Set<DateTime> teamScheduledDates,
  });
}

/// @nodoc
class _$HomeCalendarStateCopyWithImpl<$Res, $Val extends HomeCalendarState>
    implements $HomeCalendarStateCopyWith<$Res> {
  _$HomeCalendarStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HomeCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? focusedMonth = null,
    Object? selectedDate = null,
    Object? monthlyShifts = null,
    Object? selectedDateShifts = freezed,
    Object? viewMode = null,
    Object? teamScheduledDates = null,
  }) {
    return _then(
      _value.copyWith(
            focusedMonth: null == focusedMonth
                ? _value.focusedMonth
                : focusedMonth // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            selectedDate: null == selectedDate
                ? _value.selectedDate
                : selectedDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            monthlyShifts: null == monthlyShifts
                ? _value.monthlyShifts
                : monthlyShifts // ignore: cast_nullable_to_non_nullable
                      as Map<DateTime, List<ShiftWithType>>,
            selectedDateShifts: freezed == selectedDateShifts
                ? _value.selectedDateShifts
                : selectedDateShifts // ignore: cast_nullable_to_non_nullable
                      as List<ShiftWithType>?,
            viewMode: null == viewMode
                ? _value.viewMode
                : viewMode // ignore: cast_nullable_to_non_nullable
                      as CalendarViewMode,
            teamScheduledDates: null == teamScheduledDates
                ? _value.teamScheduledDates
                : teamScheduledDates // ignore: cast_nullable_to_non_nullable
                      as Set<DateTime>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HomeCalendarStateImplCopyWith<$Res>
    implements $HomeCalendarStateCopyWith<$Res> {
  factory _$$HomeCalendarStateImplCopyWith(
    _$HomeCalendarStateImpl value,
    $Res Function(_$HomeCalendarStateImpl) then,
  ) = __$$HomeCalendarStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime focusedMonth,
    DateTime selectedDate,
    Map<DateTime, List<ShiftWithType>> monthlyShifts,
    List<ShiftWithType>? selectedDateShifts,
    CalendarViewMode viewMode,
    Set<DateTime> teamScheduledDates,
  });
}

/// @nodoc
class __$$HomeCalendarStateImplCopyWithImpl<$Res>
    extends _$HomeCalendarStateCopyWithImpl<$Res, _$HomeCalendarStateImpl>
    implements _$$HomeCalendarStateImplCopyWith<$Res> {
  __$$HomeCalendarStateImplCopyWithImpl(
    _$HomeCalendarStateImpl _value,
    $Res Function(_$HomeCalendarStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HomeCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? focusedMonth = null,
    Object? selectedDate = null,
    Object? monthlyShifts = null,
    Object? selectedDateShifts = freezed,
    Object? viewMode = null,
    Object? teamScheduledDates = null,
  }) {
    return _then(
      _$HomeCalendarStateImpl(
        focusedMonth: null == focusedMonth
            ? _value.focusedMonth
            : focusedMonth // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        selectedDate: null == selectedDate
            ? _value.selectedDate
            : selectedDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        monthlyShifts: null == monthlyShifts
            ? _value._monthlyShifts
            : monthlyShifts // ignore: cast_nullable_to_non_nullable
                  as Map<DateTime, List<ShiftWithType>>,
        selectedDateShifts: freezed == selectedDateShifts
            ? _value._selectedDateShifts
            : selectedDateShifts // ignore: cast_nullable_to_non_nullable
                  as List<ShiftWithType>?,
        viewMode: null == viewMode
            ? _value.viewMode
            : viewMode // ignore: cast_nullable_to_non_nullable
                  as CalendarViewMode,
        teamScheduledDates: null == teamScheduledDates
            ? _value._teamScheduledDates
            : teamScheduledDates // ignore: cast_nullable_to_non_nullable
                  as Set<DateTime>,
      ),
    );
  }
}

/// @nodoc

class _$HomeCalendarStateImpl implements _HomeCalendarState {
  const _$HomeCalendarStateImpl({
    required this.focusedMonth,
    required this.selectedDate,
    final Map<DateTime, List<ShiftWithType>> monthlyShifts = const {},
    final List<ShiftWithType>? selectedDateShifts = null,
    this.viewMode = CalendarViewMode.month,
    final Set<DateTime> teamScheduledDates = const {},
  }) : _monthlyShifts = monthlyShifts,
       _selectedDateShifts = selectedDateShifts,
       _teamScheduledDates = teamScheduledDates;

  @override
  final DateTime focusedMonth;
  @override
  final DateTime selectedDate;
  final Map<DateTime, List<ShiftWithType>> _monthlyShifts;
  @override
  @JsonKey()
  Map<DateTime, List<ShiftWithType>> get monthlyShifts {
    if (_monthlyShifts is EqualUnmodifiableMapView) return _monthlyShifts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_monthlyShifts);
  }

  final List<ShiftWithType>? _selectedDateShifts;
  @override
  @JsonKey()
  List<ShiftWithType>? get selectedDateShifts {
    final value = _selectedDateShifts;
    if (value == null) return null;
    if (_selectedDateShifts is EqualUnmodifiableListView)
      return _selectedDateShifts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final CalendarViewMode viewMode;

  /// 즐겨찾기 팀의 published 스케줄이 커버하는 날짜들.
  /// 본인 근무가 없어도 이 set에 포함되면 OFF로 표시한다.
  final Set<DateTime> _teamScheduledDates;

  /// 즐겨찾기 팀의 published 스케줄이 커버하는 날짜들.
  /// 본인 근무가 없어도 이 set에 포함되면 OFF로 표시한다.
  @override
  @JsonKey()
  Set<DateTime> get teamScheduledDates {
    if (_teamScheduledDates is EqualUnmodifiableSetView)
      return _teamScheduledDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_teamScheduledDates);
  }

  @override
  String toString() {
    return 'HomeCalendarState(focusedMonth: $focusedMonth, selectedDate: $selectedDate, monthlyShifts: $monthlyShifts, selectedDateShifts: $selectedDateShifts, viewMode: $viewMode, teamScheduledDates: $teamScheduledDates)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HomeCalendarStateImpl &&
            (identical(other.focusedMonth, focusedMonth) ||
                other.focusedMonth == focusedMonth) &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality().equals(
              other._monthlyShifts,
              _monthlyShifts,
            ) &&
            const DeepCollectionEquality().equals(
              other._selectedDateShifts,
              _selectedDateShifts,
            ) &&
            (identical(other.viewMode, viewMode) ||
                other.viewMode == viewMode) &&
            const DeepCollectionEquality().equals(
              other._teamScheduledDates,
              _teamScheduledDates,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    focusedMonth,
    selectedDate,
    const DeepCollectionEquality().hash(_monthlyShifts),
    const DeepCollectionEquality().hash(_selectedDateShifts),
    viewMode,
    const DeepCollectionEquality().hash(_teamScheduledDates),
  );

  /// Create a copy of HomeCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HomeCalendarStateImplCopyWith<_$HomeCalendarStateImpl> get copyWith =>
      __$$HomeCalendarStateImplCopyWithImpl<_$HomeCalendarStateImpl>(
        this,
        _$identity,
      );
}

abstract class _HomeCalendarState implements HomeCalendarState {
  const factory _HomeCalendarState({
    required final DateTime focusedMonth,
    required final DateTime selectedDate,
    final Map<DateTime, List<ShiftWithType>> monthlyShifts,
    final List<ShiftWithType>? selectedDateShifts,
    final CalendarViewMode viewMode,
    final Set<DateTime> teamScheduledDates,
  }) = _$HomeCalendarStateImpl;

  @override
  DateTime get focusedMonth;
  @override
  DateTime get selectedDate;
  @override
  Map<DateTime, List<ShiftWithType>> get monthlyShifts;
  @override
  List<ShiftWithType>? get selectedDateShifts;
  @override
  CalendarViewMode get viewMode;

  /// 즐겨찾기 팀의 published 스케줄이 커버하는 날짜들.
  /// 본인 근무가 없어도 이 set에 포함되면 OFF로 표시한다.
  @override
  Set<DateTime> get teamScheduledDates;

  /// Create a copy of HomeCalendarState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HomeCalendarStateImplCopyWith<_$HomeCalendarStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
