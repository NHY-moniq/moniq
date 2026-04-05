-- skill_level_num 컬럼 제거
-- skill_level (TEXT: 'junior'/'mid'/'senior') 이 동일한 역할을 하므로 불필요
ALTER TABLE public.team_members
  DROP COLUMN IF EXISTS skill_level_num;
