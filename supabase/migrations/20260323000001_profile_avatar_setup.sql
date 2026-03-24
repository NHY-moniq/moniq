-- Profile & Avatar Setup
-- 1. Sync auth.users metadata → public.users on profile update
-- 2. RPC for nickname duplicate check (bypasses RLS)
-- 3. Avatars storage bucket + policies

-- =============================================================================
-- Trigger: sync auth.users metadata changes to public.users
-- =============================================================================
CREATE OR REPLACE FUNCTION handle_user_profile_update()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.users
  SET
    display_name = COALESCE(NEW.raw_user_meta_data->>'display_name', display_name),
    avatar_url = COALESCE(NEW.raw_user_meta_data->>'avatar_url', avatar_url)
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_user_profile_update();

-- =============================================================================
-- RPC: check_nickname_duplicate
-- Returns true if the nickname is already taken by another user
-- =============================================================================
CREATE OR REPLACE FUNCTION check_nickname_duplicate(p_nickname TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE display_name = p_nickname
      AND id != auth.uid()
      AND NOT is_deleted
  ) INTO v_exists;
  RETURN v_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- Storage: avatars bucket
-- =============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Users can upload to their own folder
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can update their own avatar
CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Users can delete their own avatar
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Anyone can view avatars (public bucket)
CREATE POLICY "Anyone can view avatars"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');
