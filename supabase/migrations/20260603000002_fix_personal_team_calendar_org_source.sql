-- Personal team calendar should read each member's organizational schedule.
-- If the current favorite team is a private team, fall back to an
-- organizational team that has published shifts in the requested month.

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
  SELECT
    u.id         AS user_id,
    u.display_name,
    u.avatar_url,
    s.shift_date,
    st.code      AS shift_type_code,
    st.color     AS shift_type_color,
    st.name      AS shift_type_name
  FROM public.team_members tm_p
  JOIN public.users u
    ON u.id = tm_p.user_id
   AND u.is_deleted = false
  LEFT JOIN LATERAL (
    SELECT
      tm_org.team_id
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
        AND s_count.user_id = tm_p.user_id
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
    WHERE tm_org.user_id = tm_p.user_id
      AND tm_org.is_deleted = false
    ORDER BY
      COALESCE(tm_org.is_favorite, false) DESC,
      COALESCE(score.published_shift_count, 0) DESC,
      tm_org.created_at DESC
    LIMIT 1
  ) source_team ON true
  LEFT JOIN LATERAL (
    SELECT s_inner.*
    FROM public.shifts s_inner
    JOIN public.schedules sch
      ON sch.id = s_inner.schedule_id
     AND sch.team_id = s_inner.team_id
     AND sch.status = 'published'
     AND s_inner.shift_date BETWEEN sch.period_start AND sch.period_end
    WHERE s_inner.team_id = source_team.team_id
      AND s_inner.user_id = tm_p.user_id
      AND s_inner.shift_date >= v_month_start
      AND s_inner.shift_date < v_next_month
      AND sch.version_no = (
        SELECT max(sch_latest.version_no)
        FROM public.schedules sch_latest
        WHERE sch_latest.team_id = s_inner.team_id
          AND sch_latest.status = 'published'
          AND s_inner.shift_date BETWEEN sch_latest.period_start AND sch_latest.period_end
      )
  ) s ON true
  LEFT JOIN public.shift_types st
    ON st.id = s.shift_type_id
  WHERE tm_p.team_id = p_team_id
    AND tm_p.is_deleted = false
  ORDER BY tm_p.created_at, s.shift_date;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_personal_team_member_shifts(UUID, INT, INT)
TO authenticated;
