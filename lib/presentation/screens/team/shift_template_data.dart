import 'package:flutter/material.dart';

/// 기본 근무 유형 템플릿
class ShiftTemplate {
  const ShiftTemplate({
    required this.name,
    required this.code,
    required this.color,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.icon,
  });

  final String name;
  final String code;
  final String color;
  final String startTime;
  final String endTime;
  final String description;
  final IconData icon;
}

const defaultShiftTemplates = [
  ShiftTemplate(
    name: '데이',
    code: 'D',
    color: '#F0C040',
    startTime: '07:00:00',
    endTime: '15:00:00',
    description: '오전 7시 ~ 오후 3시',
    icon: Icons.wb_sunny_rounded,
  ),
  ShiftTemplate(
    name: '이브닝',
    code: 'E',
    color: '#E8923A',
    startTime: '14:00:00',
    endTime: '22:00:00',
    description: '오후 2시 ~ 밤 10시',
    icon: Icons.wb_twilight_rounded,
  ),
  ShiftTemplate(
    name: '나이트',
    code: 'N',
    color: '#5A8BB5',
    startTime: '21:00:00',
    endTime: '08:00:00',
    description: '밤 9시 ~ 오전 8시',
    icon: Icons.nightlight_round,
  ),
  ShiftTemplate(
    name: '교육',
    code: 'ED',
    color: '#9F7AEA',
    startTime: '09:00:00',
    endTime: '18:00:00',
    description: '오전 9시 ~ 오후 6시',
    icon: Icons.school_rounded,
  ),
];

const presetColors = [
  '#F0C040',
  '#E8923A',
  '#5A8BB5',
  '#A0AEC0',
  '#48BB78',
  '#ED64A6',
  '#9F7AEA',
  '#ED8936',
];
