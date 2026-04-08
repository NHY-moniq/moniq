-- Announcement Comments + Attachments
-- 팀 공지사항에 댓글 기능과 첨부파일 기능 추가

-- 1. team_announcements에 attachment_urls 컬럼 추가
ALTER TABLE public.team_announcements
  ADD COLUMN IF NOT EXISTS attachment_urls TEXT[] DEFAULT '{}';

-- 2. announcement_comments 테이블
CREATE TABLE IF NOT EXISTS public.announcement_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES public.team_announcements(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_announcement_comments_announcement
  ON public.announcement_comments(announcement_id, created_at);

ALTER TABLE public.announcement_comments ENABLE ROW LEVEL SECURITY;

-- 팀 멤버 조회 가능
CREATE POLICY "Team members can view announcement comments"
  ON public.announcement_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = announcement_comments.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

-- 본인 댓글 작성
CREATE POLICY "Members can insert own announcement comments"
  ON public.announcement_comments FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = announcement_comments.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.is_deleted = false
    )
  );

-- 본인 댓글 삭제
CREATE POLICY "Members can delete own announcement comments"
  ON public.announcement_comments FOR DELETE
  USING (user_id = auth.uid());

-- 팀 관리자는 모든 댓글 삭제 가능
CREATE POLICY "Team admins can delete any announcement comments"
  ON public.announcement_comments FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members
      WHERE team_members.team_id = announcement_comments.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role = 'admin'
        AND team_members.is_deleted = false
    )
  );

-- 3. Storage bucket: 'announcements'
INSERT INTO storage.buckets (id, name, public)
VALUES ('announcements', 'announcements', true)
ON CONFLICT (id) DO NOTHING;

-- 인증된 사용자는 업로드 가능
CREATE POLICY "Authenticated users can upload announcement attachments"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'announcements'
    AND auth.role() = 'authenticated'
  );

-- 누구나 읽을 수 있음 (public bucket)
CREATE POLICY "Anyone can read announcement attachments"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'announcements');

-- 본인이 업로드한 파일 삭제
CREATE POLICY "Users can delete own announcement attachments"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'announcements'
    AND auth.uid() = owner
  );
