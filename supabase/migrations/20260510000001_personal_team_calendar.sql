-- Personal team calendar: get each member's shifts from their favorited org team
CREATE OR REPLACE FUNCTION get_personal_team_member_shifts(
  p_team_id UUID,
  p_year    INT,
  p_month   INT
)
RETURNS TABLE (
  user_id         UUID,
  display_name    TEXT,
  avatar_url      TEXT,
  shift_date      DATE,
  shift_type_code TEXT,
  shift_type_color TEXT,
  shift_type_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id                AS user_id,
    u.display_name      AS display_name,
    u.avatar_url        AS avatar_url,
    s.shift_date        AS shift_date,
    st.code             AS shift_type_code,
    st.color            AS shift_type_color,
    st.name             AS shift_type_name
  FROM   team_members tm_p
  JOIN   users        u       ON  u.id            = tm_p.user_id
  LEFT   JOIN team_members tm_fav
                              ON  tm_fav.user_id   = tm_p.user_id
                              AND tm_fav.is_favorite = true
                              AND tm_fav.is_deleted  = false
  LEFT   JOIN shifts   s      ON  s.team_id        = tm_fav.team_id
                              AND s.user_id         = tm_p.user_id
                              AND EXTRACT(YEAR  FROM s.shift_date) = p_year
                              AND EXTRACT(MONTH FROM s.shift_date) = p_month
  LEFT   JOIN shift_types st  ON  st.id            = s.shift_type_id
  WHERE  tm_p.team_id   = p_team_id
    AND  tm_p.is_deleted = false
  ORDER  BY tm_p.created_at, s.shift_date;
END;
$$;
