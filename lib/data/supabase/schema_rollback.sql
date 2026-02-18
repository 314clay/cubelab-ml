-- Phase 6.2: Rollback Script
-- Run this in Supabase Dashboard > SQL Editor to remove all Phase 6.2 tables
-- WARNING: This will DELETE ALL DATA in these tables!

-- Drop triggers first
DROP TRIGGER IF EXISTS update_timer_solves_updated_at ON public.timer_solves;
DROP TRIGGER IF EXISTS update_timer_sessions_updated_at ON public.timer_sessions;
DROP TRIGGER IF EXISTS update_cross_srs_items_updated_at ON public.cross_srs_items;
DROP TRIGGER IF EXISTS update_user_algorithms_updated_at ON public.user_algorithms;
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON public.user_settings;

-- Drop function
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP FUNCTION IF EXISTS generate_daily_scramble(DATE);

-- Drop tables in reverse dependency order
-- (child tables first, then parent tables)

-- Training solves (depends on training_sessions)
DROP TABLE IF EXISTS public.training_solves CASCADE;

-- Training sessions
DROP TABLE IF EXISTS public.training_sessions CASCADE;

-- Algorithm reviews
DROP TABLE IF EXISTS public.algorithm_reviews CASCADE;

-- Algorithm solves
DROP TABLE IF EXISTS public.algorithm_solves CASCADE;

-- User algorithms
DROP TABLE IF EXISTS public.user_algorithms CASCADE;

-- Cross SRS items
DROP TABLE IF EXISTS public.cross_srs_items CASCADE;

-- Cross solves (depends on cross_sessions)
DROP TABLE IF EXISTS public.cross_solves CASCADE;

-- Cross sessions
DROP TABLE IF EXISTS public.cross_sessions CASCADE;

-- Algorithm leaderboards
DROP TABLE IF EXISTS public.algorithm_leaderboards CASCADE;

-- Cross leaderboards
DROP TABLE IF EXISTS public.cross_leaderboards CASCADE;

-- Solve comments
DROP TABLE IF EXISTS public.solve_comments CASCADE;

-- Daily algorithm solves
DROP TABLE IF EXISTS public.daily_algorithm_solves CASCADE;

-- Daily scramble solves
DROP TABLE IF EXISTS public.daily_scramble_solves CASCADE;

-- Daily challenges
DROP TABLE IF EXISTS public.daily_challenges CASCADE;

-- Timer stats snapshots
DROP TABLE IF EXISTS public.timer_stats_snapshots CASCADE;

-- Timer sessions
DROP TABLE IF EXISTS public.timer_sessions CASCADE;

-- Timer solves
DROP TABLE IF EXISTS public.timer_solves CASCADE;

-- User settings
DROP TABLE IF EXISTS public.user_settings CASCADE;

-- Verify cleanup
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'timer_solves', 'timer_sessions', 'timer_stats_snapshots',
    'daily_challenges', 'daily_scramble_solves', 'daily_algorithm_solves',
    'solve_comments', 'cross_leaderboards', 'algorithm_leaderboards',
    'cross_sessions', 'cross_solves', 'cross_srs_items',
    'user_algorithms', 'algorithm_solves', 'algorithm_reviews',
    'training_sessions', 'training_solves', 'user_settings'
  );
-- Should return 0 rows if rollback was successful
