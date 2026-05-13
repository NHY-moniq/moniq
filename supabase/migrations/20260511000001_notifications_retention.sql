-- notifications 30일 이상 자동 정리 (pg_cron)
-- 클라이언트에서도 30일 cutoff로 fetch 하지만 DB 크기 관리를 위해 매일 정리.

create extension if not exists pg_cron;

-- 기존 동명 job이 있으면 제거 (재실행 안전)
do $$
begin
  perform cron.unschedule('moniq_notifications_retention');
exception when others then null;
end$$;

select cron.schedule(
  'moniq_notifications_retention',
  '15 3 * * *', -- 매일 03:15 UTC
  $$
    delete from public.notifications
    where created_at < now() - interval '30 days';
  $$
);
