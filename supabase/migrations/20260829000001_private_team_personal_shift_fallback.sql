-- =============================================================================
-- 친목(private) 팀 "겹치는 근무" 보기: 조직 팀이 없는 멤버는 개인 캘린더 근무 사용
--
-- 기존: get_personal_team_member_shifts가 항상 조직 팀의 발행 근무만 조회 →
--       조직 팀에 속하지 않은 멤버는 근무가 전부 비어 보였다.
-- 변경: 조직 팀 근무가 없는 멤버는 personal_events 중 근무로 표시된
--       (is_shift = true) 일정을 근무로 사용한다.
--
-- personal_events.is_shift: 개인 캘린더의 "근무 유형 칩"으로 만든 일정에만
-- true. 일반 일정(여행·약속 등)이 근무로 섞이지 않도록 구분하는 플래그다.
-- =============================================================================

ALTER TABLE public.personal_events
  ADD COLUMN IF NOT EXISTS is_shift BOOLEAN NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.get_personal_team_member_shifts(
  p_team_id UUID,
  p_year    INT,
  p_month   INT
)
RETURNS TABLE (
  user_id          UUID,
  display_name     TEXT,
  avatar_url       TEXT,
  shift_date       DATE,
  shift_type_code  TEXT,
  shift_type_color TEXT,
  shift_type_name  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_month_start DATE := make_date(p_year, p_month, 1);
  v_next_month  DATE := (make_date(p_year, p_month, 1) + INTERVAL '1 month')::DATE;
BEGIN
  RETURN QUERY
  WITH members AS (
    SELECT
      u.id           AS user_id,
      u.display_name AS display_name,
      u.avatar_url   AS avatar_url,
      tm_p.created_at AS joined_at
    FROM public.team_members tm_p
    JOIN public.users u
      ON u.id = tm_p.user_id
     AND u.is_deleted = false
    WHERE tm_p.team_id = p_team_id
      AND tm_p.is_deleted = false
  ),
  -- 멤버별 근무 소스 조직 팀: 즐겨찾기 → 그 달 발행 근무가 많은 팀 순.
  source_team AS (
    SELECT m.user_id, src.team_id
    FROM members m
    LEFT JOIN LATERAL (
      SELECT tm_org.team_id
      FROM public.team_members tm_org
      JOIN public.teams t_org
        ON t_org.id = tm_org.team_id
       AND t_org.is_deleted = false
       AND t_org.team_type <> 'personal'
      LEFT JOIN LATERAL (
        SELECT count(*)::INT AS published_shift_count
        FROM public.shifts s_count
        JOIN public.schedules sch_count
          ON sch_count.id = s_count.schedule_id
         AND sch_count.team_id = s_count.team_id
         AND sch_count.status = 'published'
         AND s_count.shift_date BETWEEN sch_count.period_start AND sch_count.period_end
        WHERE s_count.team_id = tm_org.team_id
          AND s_count.user_id = m.user_id
          AND s_count.shift_date >= v_month_start
          AND s_count.shift_date < v_next_month
          AND sch_count.version_no = (
            SELECT max(sch_latest.version_no)
            FROM public.schedules sch_latest
            WHERE sch_latest.team_id = s_count.team_id
              AND sch_latest.status = 'published'
              AND s_count.shift_date BETWEEN sch_latest.period_start AND sch_latest.period_end
          )
      ) score ON true
      WHERE tm_org.user_id = m.user_id
        AND tm_org.is_deleted = false
      ORDER BY
        COALESCE(tm_org.is_favorite, false) DESC,
        COALESCE(score.published_shift_count, 0) DESC,
        tm_org.created_at DESC
      LIMIT 1
    ) src ON true
  ),
  -- 1) 조직 팀의 최신 발행 근무
  team_shifts AS (
    SELECT
      m.user_id,
      s.shift_date,
      st.code  AS shift_type_code,
      st.color AS shift_type_color,
      st.name  AS shift_type_name
    FROM members m
    JOIN source_team src ON src.user_id = m.user_id
    JOIN public.shifts s
      ON s.team_id = src.team_id
     AND s.user_id = m.user_id
     AND s.shift_date >= v_month_start
     AND s.shift_date < v_next_month
    JOIN public.schedules sch
      ON sch.id = s.schedule_id
     AND sch.team_id = s.team_id
     AND sch.status = 'published'
     AND s.shift_date BETWEEN sch.period_start AND sch.period_end
    LEFT JOIN public.shift_types st
      ON st.id = s.shift_type_id
    WHERE sch.version_no = (
      SELECT max(sch_latest.version_no)
      FROM public.schedules sch_latest
      WHERE sch_latest.team_id = s.team_id
        AND sch_latest.status = 'published'
        AND s.shift_date BETWEEN sch_latest.period_start AND sch_latest.period_end
    )
  ),
  -- 2) 그 달에 조직 팀 근무가 하나도 없는 멤버 → 개인 캘린더 근무로 대체
  personal_shifts AS (
    SELECT
      m.user_id,
      pe.event_date AS shift_date,
      NULL::TEXT    AS shift_type_code,
      pe.color      AS shift_type_color,
      pe.title      AS shift_type_name
    FROM members m
    JOIN public.personal_events pe
      ON pe.user_id = m.user_id
     AND pe.is_shift = true
     AND pe.event_date >= v_month_start
     AND pe.event_date < v_next_month
    WHERE NOT EXISTS (
      SELECT 1 FROM team_shifts ts WHERE ts.user_id = m.user_id
    )
  )
  SELECT
    m.user_id,
    m.display_name,
    m.avatar_url,
    src.shift_date,
    src.shift_type_code,
    src.shift_type_color,
    src.shift_type_name
  FROM members m
  LEFT JOIN (
    SELECT * FROM team_shifts
    UNION ALL
    SELECT * FROM personal_shifts
  ) src ON src.user_id = m.user_id
  ORDER BY m.joined_at, src.shift_date;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_personal_team_member_shifts(UUID, INT, INT)
TO authenticated;
