-- =============================================================================
-- 친목 팀 폴백이 근무 코드를 함께 반환하도록 수정
--
-- 20260829000001의 폴백은 shift_type_code를 NULL로 돌려줬는데, 겹침 그리드는
-- 코드가 비면 그 칸을 무조건 오프로 그린다(weekly_member_grid). 그래서 개인
-- 근무가 있어도 전부 'O'로 보였다.
--
-- personal_events에는 코드가 없으므로 제목과 같은 이름의 shift_types에서
-- 코드를 찾아 채운다. 못 찾으면 제목 첫 글자를 대문자로 쓴다.
-- =============================================================================

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
      u.id            AS user_id,
      u.display_name  AS display_name,
      u.avatar_url    AS avatar_url,
      tm_p.created_at AS joined_at
    FROM public.team_members tm_p
    JOIN public.users u
      ON u.id = tm_p.user_id
     AND u.is_deleted = false
    WHERE tm_p.team_id = p_team_id
      AND tm_p.is_deleted = false
  ),
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
  personal_shifts AS (
    SELECT
      m.user_id,
      pe.event_date AS shift_date,
      -- 코드가 비면 그리드가 오프로 그리므로 반드시 채운다.
      COALESCE(
        (SELECT st2.code FROM public.shift_types st2
          WHERE st2.name = pe.title LIMIT 1),
        upper(left(pe.title, 1))
      )             AS shift_type_code,
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
