-- Phase 6.2: Supabase Schema Migrations
-- Run these in Supabase Dashboard > SQL Editor
-- Created: 2026-01-16

-- ============================================================================
-- TIMER TABLES
-- ============================================================================

-- Timer solves (individual solve records)
CREATE TABLE IF NOT EXISTS public.timer_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,          -- YYYY-MM-DD format
  timestamp TIMESTAMPTZ NOT NULL,
  time_ms INTEGER NOT NULL,
  penalty INTEGER,                   -- null=none, 2000=+2, -1=DNF
  scramble TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_timer_solves_user_session ON public.timer_solves(user_id, session_id DESC);
CREATE INDEX IF NOT EXISTS idx_timer_solves_timestamp ON public.timer_solves(user_id, timestamp DESC);

ALTER TABLE public.timer_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own solves" ON public.timer_solves;
CREATE POLICY "Users can manage their own solves" ON public.timer_solves FOR ALL USING (auth.uid() = user_id);

-- Timer sessions (daily aggregates)
CREATE TABLE IF NOT EXISTS public.timer_sessions (
  id TEXT NOT NULL,                  -- YYYY-MM-DD format
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  total_solves INTEGER DEFAULT 0,
  pb_single_ms INTEGER,
  ao5_ms INTEGER,
  ao12_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_timer_sessions_user_date ON public.timer_sessions(user_id, date DESC);
ALTER TABLE public.timer_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own sessions" ON public.timer_sessions;
CREATE POLICY "Users can manage their own sessions" ON public.timer_sessions FOR ALL USING (auth.uid() = user_id);

-- Timer stats snapshots (historical PBs)
CREATE TABLE IF NOT EXISTS public.timer_stats_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recorded_at TIMESTAMPTZ NOT NULL,
  total_solves INTEGER DEFAULT 0,
  pb_single_ms INTEGER,
  pb_ao5_ms INTEGER,
  pb_ao12_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_timer_stats_user_date ON public.timer_stats_snapshots(user_id, recorded_at DESC);
ALTER TABLE public.timer_stats_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own snapshots" ON public.timer_stats_snapshots;
CREATE POLICY "Users can manage their own snapshots" ON public.timer_stats_snapshots FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- DAILY CHALLENGE TABLES
-- ============================================================================

-- Daily challenges (global, not per-user)
CREATE TABLE IF NOT EXISTS public.daily_challenges (
  id TEXT PRIMARY KEY,               -- YYYY-MM-DD format
  scramble TEXT NOT NULL,
  algorithm_id TEXT,                 -- For daily algorithm challenge
  released_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily scramble submissions
CREATE TABLE IF NOT EXISTS public.daily_scramble_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT,
  challenge_date DATE NOT NULL,
  time_ms INTEGER NOT NULL,
  penalty INTEGER,
  scramble TEXT NOT NULL,
  notes TEXT,
  pairs_planned INTEGER,
  was_xcross BOOLEAN,
  was_zbll BOOLEAN,
  alg_used TEXT,
  completed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, challenge_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_scramble_user_date ON public.daily_scramble_solves(user_id, challenge_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_scramble_date ON public.daily_scramble_solves(challenge_date DESC);
ALTER TABLE public.daily_scramble_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own daily solves" ON public.daily_scramble_solves;
CREATE POLICY "Users can manage their own daily solves" ON public.daily_scramble_solves FOR ALL USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Everyone can view daily solves" ON public.daily_scramble_solves;
CREATE POLICY "Everyone can view daily solves" ON public.daily_scramble_solves FOR SELECT USING (true);

-- Daily algorithm submissions
CREATE TABLE IF NOT EXISTS public.daily_algorithm_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenge_date DATE NOT NULL,
  algorithm_id TEXT NOT NULL,
  time_ms INTEGER NOT NULL,
  success BOOLEAN DEFAULT true,
  completed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, challenge_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_alg_user_date ON public.daily_algorithm_solves(user_id, challenge_date DESC);
ALTER TABLE public.daily_algorithm_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own daily alg solves" ON public.daily_algorithm_solves;
CREATE POLICY "Users can manage their own daily alg solves" ON public.daily_algorithm_solves FOR ALL USING (auth.uid() = user_id);

-- Comments on solves
CREATE TABLE IF NOT EXISTS public.solve_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solve_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_solve ON public.solve_comments(solve_id);
ALTER TABLE public.solve_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own comments" ON public.solve_comments;
CREATE POLICY "Users can manage their own comments" ON public.solve_comments FOR ALL USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Everyone can view comments" ON public.solve_comments;
CREATE POLICY "Everyone can view comments" ON public.solve_comments FOR SELECT USING (true);

-- ============================================================================
-- LEADERBOARD TABLES
-- ============================================================================

-- Cross leaderboards (denormalized for fast queries)
CREATE TABLE IF NOT EXISTS public.cross_leaderboards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  level INTEGER NOT NULL,            -- 0-4 pairs
  avg_time_ms INTEGER NOT NULL,
  total_solves INTEGER NOT NULL,
  success_rate DECIMAL(5,2) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, level)
);

CREATE INDEX IF NOT EXISTS idx_cross_lb_level_time ON public.cross_leaderboards(level, avg_time_ms ASC);
ALTER TABLE public.cross_leaderboards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view cross leaderboards" ON public.cross_leaderboards;
CREATE POLICY "Everyone can view cross leaderboards" ON public.cross_leaderboards FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can update their own cross entries" ON public.cross_leaderboards;
CREATE POLICY "Users can update their own cross entries" ON public.cross_leaderboards FOR ALL USING (auth.uid() = user_id);

-- Algorithm leaderboards
CREATE TABLE IF NOT EXISTS public.algorithm_leaderboards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  set_type TEXT NOT NULL,            -- 'pll', 'oll', 'zbll'
  board_type TEXT NOT NULL,          -- 'avg_time', 'learned_count'
  value INTEGER NOT NULL,            -- time_ms or count
  total_solves INTEGER NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, set_type, board_type)
);

CREATE INDEX IF NOT EXISTS idx_alg_lb_set_type ON public.algorithm_leaderboards(set_type, board_type, value ASC);
ALTER TABLE public.algorithm_leaderboards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Everyone can view algorithm leaderboards" ON public.algorithm_leaderboards;
CREATE POLICY "Everyone can view algorithm leaderboards" ON public.algorithm_leaderboards FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can update their own alg entries" ON public.algorithm_leaderboards;
CREATE POLICY "Users can update their own alg entries" ON public.algorithm_leaderboards FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- CROSS TRAINER TABLES
-- ============================================================================

-- Cross sessions
CREATE TABLE IF NOT EXISTS public.cross_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  solve_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  avg_inspection_time_ms INTEGER,
  avg_execution_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cross_sessions_user ON public.cross_sessions(user_id, started_at DESC);
ALTER TABLE public.cross_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own cross sessions" ON public.cross_sessions;
CREATE POLICY "Users can manage their own cross sessions" ON public.cross_sessions FOR ALL USING (auth.uid() = user_id);

-- Cross solves
CREATE TABLE IF NOT EXISTS public.cross_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES public.cross_sessions(id) ON DELETE SET NULL,
  scramble TEXT NOT NULL,
  difficulty INTEGER NOT NULL,
  cross_color TEXT DEFAULT 'white',
  pairs_attempting INTEGER NOT NULL,
  pairs_planned INTEGER NOT NULL,
  cross_success BOOLEAN DEFAULT true,
  blindfolded BOOLEAN DEFAULT false,
  inspection_time_ms INTEGER NOT NULL,
  execution_time_ms INTEGER NOT NULL,
  used_unlimited_time BOOLEAN DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cross_solves_user ON public.cross_solves(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cross_solves_session ON public.cross_solves(session_id);
ALTER TABLE public.cross_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own cross solves" ON public.cross_solves;
CREATE POLICY "Users can manage their own cross solves" ON public.cross_solves FOR ALL USING (auth.uid() = user_id);

-- Cross SRS items
CREATE TABLE IF NOT EXISTS public.cross_srs_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scramble TEXT NOT NULL,
  difficulty INTEGER NOT NULL,
  cross_color TEXT DEFAULT 'white',
  pairs_attempting INTEGER NOT NULL,
  -- SRS State fields (flattened)
  ease_factor DECIMAL(4,2) DEFAULT 2.5,
  interval_days INTEGER DEFAULT 0,
  repetitions INTEGER DEFAULT 0,
  next_review_date TIMESTAMPTZ,
  stability DECIMAL(6,2) DEFAULT 0,
  srs_difficulty DECIMAL(4,2) DEFAULT 5.0,
  desired_retention DECIMAL(4,2) DEFAULT 0.9,
  card_state TEXT DEFAULT 'new',
  remaining_steps INTEGER,
  learning_due_at TIMESTAMPTZ,
  lapses INTEGER DEFAULT 0,
  last_reviewed_at TIMESTAMPTZ,
  total_reviews INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cross_srs_user_review ON public.cross_srs_items(user_id, next_review_date);
ALTER TABLE public.cross_srs_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own SRS items" ON public.cross_srs_items;
CREATE POLICY "Users can manage their own SRS items" ON public.cross_srs_items FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- ALGORITHM TRAINER TABLES
-- ============================================================================

-- User algorithm state (per-user settings for each algorithm)
CREATE TABLE IF NOT EXISTS public.user_algorithms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_id TEXT NOT NULL,
  enabled BOOLEAN DEFAULT false,
  custom_alg TEXT,
  is_learned BOOLEAN DEFAULT false,
  -- SRS State fields (flattened)
  ease_factor DECIMAL(4,2) DEFAULT 2.5,
  interval_days INTEGER DEFAULT 0,
  repetitions INTEGER DEFAULT 0,
  next_review_date TIMESTAMPTZ,
  stability DECIMAL(6,2) DEFAULT 0,
  srs_difficulty DECIMAL(4,2) DEFAULT 5.0,
  desired_retention DECIMAL(4,2) DEFAULT 0.9,
  card_state TEXT DEFAULT 'new',
  remaining_steps INTEGER,
  learning_due_at TIMESTAMPTZ,
  lapses INTEGER DEFAULT 0,
  last_reviewed_at TIMESTAMPTZ,
  total_reviews INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, algorithm_id)
);

CREATE INDEX IF NOT EXISTS idx_user_alg_user ON public.user_algorithms(user_id, is_learned);
CREATE INDEX IF NOT EXISTS idx_user_alg_review ON public.user_algorithms(user_id, next_review_date) WHERE is_learned = true;
ALTER TABLE public.user_algorithms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own algorithms" ON public.user_algorithms;
CREATE POLICY "Users can manage their own algorithms" ON public.user_algorithms FOR ALL USING (auth.uid() = user_id);

-- Algorithm solves
CREATE TABLE IF NOT EXISTS public.algorithm_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_id TEXT NOT NULL,
  time_ms INTEGER NOT NULL,
  success BOOLEAN DEFAULT true,
  scramble TEXT,
  notes TEXT,
  session_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alg_solves_user ON public.algorithm_solves(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alg_solves_alg ON public.algorithm_solves(user_id, algorithm_id);
ALTER TABLE public.algorithm_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own algorithm solves" ON public.algorithm_solves;
CREATE POLICY "Users can manage their own algorithm solves" ON public.algorithm_solves FOR ALL USING (auth.uid() = user_id);

-- Algorithm reviews (SRS history)
CREATE TABLE IF NOT EXISTS public.algorithm_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_id TEXT NOT NULL,
  rating TEXT NOT NULL,              -- 'again', 'hard', 'good', 'easy'
  interval_days INTEGER NOT NULL,
  ease_factor DECIMAL(4,2) NOT NULL,
  repetitions INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alg_reviews_user ON public.algorithm_reviews(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alg_reviews_alg ON public.algorithm_reviews(user_id, algorithm_id);
ALTER TABLE public.algorithm_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own reviews" ON public.algorithm_reviews;
CREATE POLICY "Users can manage their own reviews" ON public.algorithm_reviews FOR ALL USING (auth.uid() = user_id);

-- Training sessions
CREATE TABLE IF NOT EXISTS public.training_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_type TEXT NOT NULL,        -- 'recognition', 'execution', 'mixed'
  set_type TEXT,                     -- 'pll', 'oll', 'zbll'
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  total_time_ms INTEGER,
  total_cases INTEGER DEFAULT 0,
  correct_count INTEGER DEFAULT 0,
  accuracy_percent DECIMAL(5,2),
  avg_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_sessions_user ON public.training_sessions(user_id, created_at DESC);
ALTER TABLE public.training_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own training sessions" ON public.training_sessions;
CREATE POLICY "Users can manage their own training sessions" ON public.training_sessions FOR ALL USING (auth.uid() = user_id);

-- Training solves (within a session)
CREATE TABLE IF NOT EXISTS public.training_solves (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.training_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_id TEXT NOT NULL,
  recognition_time_ms INTEGER,
  execution_time_ms INTEGER,
  user_answer TEXT,
  correct_answer TEXT,
  is_correct BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_solves_session ON public.training_solves(session_id);
ALTER TABLE public.training_solves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own training solves" ON public.training_solves;
CREATE POLICY "Users can manage their own training solves" ON public.training_solves FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- USER SETTINGS TABLE (for UserRepository)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  username TEXT,
  theme_mode TEXT DEFAULT 'dark',
  timer_sound BOOLEAN DEFAULT true,
  haptic_feedback BOOLEAN DEFAULT true,
  default_pairs_planning INTEGER DEFAULT 2,
  favorited_alg_set TEXT,
  has_completed_onboarding BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_settings_user ON public.user_settings(user_id);
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own settings" ON public.user_settings;
CREATE POLICY "Users can manage their own settings" ON public.user_settings FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- CUBE SCAN TABLES
-- ============================================================================

-- Cube scan encounter history
CREATE TABLE IF NOT EXISTS public.cube_scan_encounters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  algorithm_id TEXT,                 -- matched algorithm from catalog
  phase TEXT NOT NULL,               -- 'oll', 'pll', 'solved', etc.
  case_name TEXT,                    -- e.g. 'OLL 27', 'T-Perm'
  confidence DECIMAL(4,3) NOT NULL,  -- 0.000 to 1.000
  srs_rating TEXT,                   -- 'again', 'hard', 'good', 'easy' if reviewed
  added_to_queue BOOLEAN DEFAULT false,
  scanned_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cube_scan_user ON public.cube_scan_encounters(user_id, scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_cube_scan_alg ON public.cube_scan_encounters(user_id, algorithm_id);
ALTER TABLE public.cube_scan_encounters ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own scan encounters" ON public.cube_scan_encounters;
CREATE POLICY "Users can manage their own scan encounters" ON public.cube_scan_encounters FOR ALL USING (auth.uid() = user_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables with updated_at
DROP TRIGGER IF EXISTS update_timer_solves_updated_at ON public.timer_solves;
CREATE TRIGGER update_timer_solves_updated_at BEFORE UPDATE ON public.timer_solves FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_timer_sessions_updated_at ON public.timer_sessions;
CREATE TRIGGER update_timer_sessions_updated_at BEFORE UPDATE ON public.timer_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cross_srs_items_updated_at ON public.cross_srs_items;
CREATE TRIGGER update_cross_srs_items_updated_at BEFORE UPDATE ON public.cross_srs_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_algorithms_updated_at ON public.user_algorithms;
CREATE TRIGGER update_user_algorithms_updated_at BEFORE UPDATE ON public.user_algorithms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_settings_updated_at ON public.user_settings;
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON public.user_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SEED DATA: Generate daily challenges for a range of dates
-- ============================================================================

-- This function generates a deterministic daily scramble based on the date
-- In production, you might want to pre-generate or use a different approach
CREATE OR REPLACE FUNCTION generate_daily_scramble(challenge_date DATE)
RETURNS TEXT AS $$
DECLARE
  moves TEXT[] := ARRAY['R', 'L', 'U', 'D', 'F', 'B'];
  modifiers TEXT[] := ARRAY['', '''', '2'];
  scramble TEXT := '';
  last_move TEXT := '';
  move TEXT;
  modifier TEXT;
  seed INTEGER;
  i INTEGER;
BEGIN
  -- Use date as seed for deterministic generation
  seed := EXTRACT(EPOCH FROM challenge_date)::INTEGER;

  FOR i IN 1..20 LOOP
    -- Simple deterministic selection based on seed and position
    move := moves[((seed + i * 7) % 6) + 1];

    -- Avoid same move twice in a row
    WHILE move = last_move LOOP
      seed := seed + 1;
      move := moves[((seed + i * 7) % 6) + 1];
    END LOOP;

    modifier := modifiers[((seed + i * 3) % 3) + 1];
    scramble := scramble || move || modifier || ' ';
    last_move := move;
  END LOOP;

  RETURN TRIM(scramble);
END;
$$ LANGUAGE plpgsql;

-- Insert daily challenges for the next 30 days (run once)
-- INSERT INTO public.daily_challenges (id, scramble, released_at)
-- SELECT
--   TO_CHAR(d::DATE, 'YYYY-MM-DD'),
--   generate_daily_scramble(d::DATE),
--   d::TIMESTAMPTZ
-- FROM generate_series(CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days', '1 day') d
-- ON CONFLICT (id) DO NOTHING;
