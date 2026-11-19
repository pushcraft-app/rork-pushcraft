-- Raw push-ups battle mode: a battle can be played with blocks (default,
-- today's behavior) or "raw" (no block smashing; winner is still the higher
-- rep count, which battle scoring already uses).

ALTER TABLE public.battles ADD COLUMN IF NOT EXISTS mode text NOT NULL DEFAULT 'blocks';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'battles_mode_check') THEN
    ALTER TABLE public.battles ADD CONSTRAINT battles_mode_check CHECK (mode IN ('blocks', 'raw'));
  END IF;
END $$;

-- create_battle: accept the mode (defaults to 'blocks' so older clients and
-- existing calls keep working). A re-created invitation also updates the mode.
CREATE OR REPLACE FUNCTION public.create_battle(p_exercise text, p_mode text DEFAULT 'blocks')
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
  v_rules int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_exercise NOT IN ('push_ups', 'sit_ups') THEN
    RAISE EXCEPTION 'invalid_exercise' USING ERRCODE = '22023';
  END IF;
  IF p_mode NOT IN ('blocks', 'raw') THEN
    RAISE EXCEPTION 'invalid_exercise' USING ERRCODE = '22023';
  END IF;
  PERFORM public.bootstrap_user(v_uid);

  FOR v_id IN SELECT id FROM public.battles WHERE host_id = v_uid AND status = 'waiting' LOOP
    PERFORM public.finalize_battle(v_id);
  END LOOP;

  SELECT id INTO v_id FROM public.battles WHERE host_id = v_uid AND status = 'waiting' FOR UPDATE;
  IF FOUND THEN
    UPDATE public.battles SET exercise = p_exercise, mode = p_mode WHERE id = v_id;
    RETURN public.battle_view(v_id, v_uid);
  END IF;

  SELECT version INTO v_rules FROM public.reward_rules WHERE is_current;
  INSERT INTO public.battles (code, host_id, exercise, mode, status, rules_version)
  VALUES (public.new_battle_code(), v_uid, p_exercise, p_mode, 'waiting', v_rules)
  RETURNING id INTO v_id;
  INSERT INTO public.battle_participants (battle_id, slot, user_id) VALUES (v_id, 'host', v_uid);
  RETURN public.battle_view(v_id, v_uid);
END;
$function$;

-- battle_view: expose the mode so both clients render the same format.
CREATE OR REPLACE FUNCTION public.battle_view(p_battle_id uuid, p_uid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_b public.battles%ROWTYPE;
  v_me public.battle_participants%ROWTYPE;
  v_them public.battle_participants%ROWTYPE;
  v_has_them boolean;
  v_name text;
  v_avatar text;
  v_final boolean;
BEGIN
  SELECT * INTO v_b FROM public.battles WHERE id = p_battle_id;
  SELECT * INTO v_me FROM public.battle_participants WHERE battle_id = p_battle_id AND user_id = p_uid;
  IF v_b.id IS NULL OR v_me.battle_id IS NULL THEN
    RETURN NULL;
  END IF;
  SELECT * INTO v_them FROM public.battle_participants WHERE battle_id = p_battle_id AND slot <> v_me.slot;
  v_has_them := FOUND;
  IF v_has_them AND v_them.user_id IS NOT NULL THEN
    SELECT display_name, avatar_path INTO v_name, v_avatar FROM public.profiles WHERE id = v_them.user_id;
  END IF;
  v_final := v_b.status IN ('completed', 'expired');

  RETURN jsonb_build_object(
    'id', v_b.id,
    'code', v_b.code,
    'exercise', v_b.exercise,
    'mode', v_b.mode,
    'status', v_b.status,
    'is_host', v_me.slot = 'host',
    'created_at', v_b.created_at,
    'invite_expires_at', v_b.invite_expires_at,
    'joined_at', v_b.joined_at,
    'deadline_at', v_b.deadline_at,
    'completed_at', v_b.completed_at,
    'duration_seconds', v_b.duration_seconds,
    'outcome', CASE
      WHEN NOT v_final THEN NULL
      WHEN v_b.result = 'draw' THEN 'draw'
      WHEN v_b.result = v_me.slot THEN 'victory'
      WHEN v_b.result IN ('host', 'guest') THEN 'defeat'
      ELSE 'none' END,
    'my_run_started', v_me.session_id IS NOT NULL,
    'my_submitted', v_me.submitted_at IS NOT NULL,
    'my_score', v_me.score,
    'my_session_id', v_me.session_id,
    'opponent', CASE WHEN NOT v_has_them THEN NULL ELSE jsonb_build_object(
      'user_id', v_them.user_id,
      'display_name', CASE WHEN v_them.user_id IS NULL THEN 'Deleted player' ELSE coalesce(v_name, 'Builder') END,
      'avatar_path', CASE WHEN v_them.user_id IS NULL THEN NULL ELSE v_avatar END,
      'submitted', v_them.submitted_at IS NOT NULL,
      'score', CASE WHEN v_final THEN v_them.score ELSE NULL END
    ) END
  );
END;
$function$;

-- complete_workout_session: raw battles earn coins from the same block
-- ladder, converted from the full rep count (a raw run has no blocks to
-- smash, so the ladder is walked without the device-reported block cap).
-- Battle scoring itself already uses the rep count, so winners are unchanged.
CREATE OR REPLACE FUNCTION public.complete_workout_session(p_session_id uuid, p_reps integer, p_blocks integer, p_end_reason text DEFAULT 'finished'::text, p_client_ended_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_s public.workout_sessions%ROWTYPE;
  v_rules public.reward_rules%ROWTYPE;
  v_now timestamptz := now();
  v_elapsed numeric;
  v_cap int;
  v_reps int;
  v_blocks int;
  v_coins int;
  v_completed boolean;
  v_xp int;
  v_remaining int;
  v_prog public.user_tower_progress%ROWTYPE;
  v_need int;
  v_take int;
  v_total_stages int;
  v_stage_name text;
  v_tower_name text;
  v_next_target int;
  v_next_tower text;
  v_credits jsonb := '[]'::jsonb;
  v_towers_done jsonb := '[]'::jsonb;
  v_towers_done_count int := 0;
  v_overflow int := 0;
  v_streak_awarded boolean := false;
  v_current int;
  v_longest int;
  v_last date;
  v_battle public.battles%ROWTYPE;
  v_part public.battle_participants%ROWTYPE;
  v_other public.battle_participants%ROWTYPE;
  v_submission text;
  v_end_reason text;
  v_outcome jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  -- 1. Lock the session row. Retries and concurrent calls serialize here.
  SELECT * INTO v_s FROM public.workout_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR v_s.user_id <> v_uid THEN
    RAISE EXCEPTION 'session_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Already accepted: return the stored outcome, no matter how old.
  IF v_s.status = 'accepted' THEN
    RETURN v_s.outcome;
  END IF;

  -- 3. Age limit applies only to sessions never accepted.
  SELECT * INTO v_rules FROM public.reward_rules WHERE version = v_s.rules_version;
  IF v_now > v_s.started_at + make_interval(days => v_rules.recovery_days) THEN
    RAISE EXCEPTION 'session_expired' USING ERRCODE = 'P0001';
  END IF;

  v_end_reason := CASE WHEN p_end_reason IN ('finished', 'interrupted', 'timer') THEN p_end_reason ELSE 'finished' END;

  -- 4. Plausibility: cap reps by server-observed elapsed time (battle runs cap at the timer).
  v_elapsed := extract(epoch FROM (v_now - v_s.started_at));
  IF v_s.source = 'battle' THEN
    v_elapsed := least(v_elapsed, (60 + v_rules.battle_grace_seconds)::numeric);
  END IF;
  v_cap := floor(v_elapsed * v_rules.max_reps_per_second)::int + 1;
  v_reps := least(greatest(coalesce(p_reps, 0), 0), v_cap, 100000);

  -- 5. Coins recomputed from the block ladder; never trusted from the device.
  -- Raw battles walk the same ladder from the full rep count, so rewards
  -- match a block battle of equal reps.
  IF v_s.source = 'battle' AND v_s.battle_id IS NOT NULL
     AND (SELECT mode FROM public.battles WHERE id = v_s.battle_id) = 'raw' THEN
    SELECT bl.blocks, bl.coins INTO v_blocks, v_coins FROM public.block_ladder(v_reps, 100000) bl;
  ELSE
    SELECT bl.blocks, bl.coins INTO v_blocks, v_coins FROM public.block_ladder(v_reps, p_blocks) bl;
  END IF;
  v_completed := v_reps >= v_rules.completion_reps;
  v_xp := CASE WHEN v_completed THEN v_rules.xp_per_completed ELSE 0 END;

  -- 6. Lock the user's stats: all of this user's saves apply one at a time.
  PERFORM public.bootstrap_user(v_uid);
  PERFORM 1 FROM public.user_stats WHERE user_id = v_uid FOR UPDATE;

  -- 7. Construction: reps flow through stages and into the next tower.
  v_remaining := v_reps;
  WHILE v_remaining > 0 LOOP
    SELECT * INTO v_prog FROM public.user_tower_progress
    WHERE user_id = v_uid AND status = 'in_progress' FOR UPDATE;
    IF NOT FOUND THEN
      v_overflow := v_remaining;
      v_remaining := 0;
      EXIT;
    END IF;

    SELECT name INTO v_tower_name FROM public.tower_definitions WHERE id = v_prog.tower_id;
    SELECT max(stage_number) INTO v_total_stages FROM public.tower_stage_definitions WHERE tower_id = v_prog.tower_id;
    SELECT name INTO v_stage_name FROM public.tower_stage_definitions
    WHERE tower_id = v_prog.tower_id AND stage_number = v_prog.current_stage;

    v_need := greatest(v_prog.stage_target - v_prog.reps_into_stage, 0);
    v_take := least(v_remaining, v_need);
    v_remaining := v_remaining - v_take;

    IF v_take < v_need THEN
      UPDATE public.user_tower_progress SET reps_into_stage = reps_into_stage + v_take
      WHERE user_id = v_uid AND tower_id = v_prog.tower_id;
      v_credits := v_credits || jsonb_build_array(jsonb_build_object(
        'tower_id', v_prog.tower_id, 'tower_name', v_tower_name,
        'stage_number', v_prog.current_stage, 'stage_name', v_stage_name,
        'reps', v_take, 'stage_target', v_prog.stage_target, 'stage_completed', false
      ));
    ELSE
      v_credits := v_credits || jsonb_build_array(jsonb_build_object(
        'tower_id', v_prog.tower_id, 'tower_name', v_tower_name,
        'stage_number', v_prog.current_stage, 'stage_name', v_stage_name,
        'reps', v_take, 'stage_target', v_prog.stage_target, 'stage_completed', true
      ));
      IF v_prog.current_stage < v_total_stages THEN
        SELECT reps_required INTO v_next_target FROM public.tower_stage_definitions
        WHERE tower_id = v_prog.tower_id AND stage_number = v_prog.current_stage + 1;
        UPDATE public.user_tower_progress SET current_stage = current_stage + 1, reps_into_stage = 0, stage_target = v_next_target
        WHERE user_id = v_uid AND tower_id = v_prog.tower_id;
      ELSE
        UPDATE public.user_tower_progress SET status = 'completed', reps_into_stage = stage_target, completed_at = v_now
        WHERE user_id = v_uid AND tower_id = v_prog.tower_id;
        v_towers_done_count := v_towers_done_count + 1;
        v_towers_done := v_towers_done || jsonb_build_array(jsonb_build_object('tower_id', v_prog.tower_id, 'tower_name', v_tower_name));

        SELECT t.id, s.reps_required INTO v_next_tower, v_next_target
        FROM public.tower_definitions t
        JOIN public.tower_stage_definitions s ON s.tower_id = t.id AND s.stage_number = 1
        WHERE t.is_active
          AND NOT EXISTS (SELECT 1 FROM public.user_tower_progress p WHERE p.user_id = v_uid AND p.tower_id = t.id)
        ORDER BY t.sort_order
        LIMIT 1;
        IF v_next_tower IS NOT NULL THEN
          INSERT INTO public.user_tower_progress (user_id, tower_id, status, current_stage, reps_into_stage, stage_target, started_at)
          VALUES (v_uid, v_next_tower, 'in_progress', 1, 0, v_next_target, v_now);
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- 8. Streak: one qualifying day per local date; recomputed from all days.
  IF v_completed THEN
    INSERT INTO public.streak_days (user_id, local_date, first_session_id)
    VALUES (v_uid, v_s.local_date, v_s.id)
    ON CONFLICT DO NOTHING;
    v_streak_awarded := FOUND;
  END IF;
  IF v_streak_awarded THEN
    WITH d AS (
      SELECT local_date, local_date - (row_number() OVER (ORDER BY local_date))::int AS grp
      FROM public.streak_days WHERE user_id = v_uid
    ), runs AS (
      SELECT grp, count(*)::int AS len, max(local_date) AS last_day FROM d GROUP BY grp
    )
    SELECT (SELECT max(len) FROM runs),
           (SELECT len FROM runs ORDER BY last_day DESC LIMIT 1),
           (SELECT max(last_day) FROM runs)
    INTO v_longest, v_current, v_last;
  END IF;

  -- 9. Battle score is the accepted rep count, attached in this same transaction.
  IF v_s.source = 'battle' THEN
    v_submission := 'too_late';
    IF v_s.battle_id IS NOT NULL THEN
      PERFORM public.finalize_battle(v_s.battle_id);
      SELECT * INTO v_battle FROM public.battles WHERE id = v_s.battle_id FOR UPDATE;
      SELECT * INTO v_part FROM public.battle_participants
      WHERE battle_id = v_s.battle_id AND session_id = v_s.id FOR UPDATE;
      IF FOUND AND v_battle.status = 'active' AND v_now < v_battle.deadline_at AND v_part.submitted_at IS NULL THEN
        UPDATE public.battle_participants SET score = v_reps, submitted_at = v_now
        WHERE battle_id = v_s.battle_id AND slot = v_part.slot;
        v_submission := 'scored';
        SELECT * INTO v_other FROM public.battle_participants
        WHERE battle_id = v_s.battle_id AND slot <> v_part.slot;
        IF FOUND AND v_other.submitted_at IS NOT NULL THEN
          UPDATE public.battles SET
            status = 'completed',
            completed_at = v_now,
            result = CASE
              WHEN v_reps > coalesce(v_other.score, 0) THEN v_part.slot
              WHEN v_reps < coalesce(v_other.score, 0) THEN v_other.slot
              ELSE 'draw' END
          WHERE id = v_s.battle_id;
        END IF;
      END IF;
    END IF;
  END IF;

  -- 10. Cumulative stats cache.
  UPDATE public.user_stats SET
    total_reps = total_reps + v_reps,
    push_up_reps = push_up_reps + CASE WHEN v_s.exercise = 'push_ups' THEN v_reps ELSE 0 END,
    sit_up_reps = sit_up_reps + CASE WHEN v_s.exercise = 'sit_ups' THEN v_reps ELSE 0 END,
    total_sessions = total_sessions + 1,
    completed_workouts = completed_workouts + CASE WHEN v_completed THEN 1 END,
    completed_towers = completed_towers + v_towers_done_count,
    coins_balance = coins_balance + v_coins,
    xp_total = xp_total + v_xp,
    overflow_reps = overflow_reps + v_overflow,
    current_streak = CASE WHEN v_streak_awarded THEN v_current ELSE current_streak END,
    longest_streak = CASE WHEN v_streak_awarded THEN v_longest ELSE longest_streak END,
    last_streak_date = CASE WHEN v_streak_awarded THEN v_last ELSE last_streak_date END,
    updated_at = v_now
  WHERE user_id = v_uid;

  -- 11. Store the exact outcome so history never changes.
  v_outcome := jsonb_build_object(
    'session_id', v_s.id,
    'exercise', v_s.exercise,
    'source', v_s.source,
    'battle_id', v_s.battle_id,
    'end_reason', v_end_reason,
    'reps', v_reps,
    'reps_reported', coalesce(p_reps, 0),
    'blocks_smashed', v_blocks,
    'coins_awarded', v_coins,
    'xp_awarded', v_xp,
    'is_completed', v_completed,
    'completion_reps', v_rules.completion_reps,
    'streak_day_awarded', v_streak_awarded,
    'local_date', v_s.local_date,
    'credits', v_credits,
    'towers_completed', v_towers_done,
    'overflow_reps', v_overflow,
    'battle_submission', v_submission,
    'rules_version', v_s.rules_version,
    'accepted_at', v_now
  );

  UPDATE public.workout_sessions SET
    status = 'accepted',
    end_reason = v_end_reason,
    client_ended_at = p_client_ended_at,
    reps_reported = coalesce(p_reps, 0),
    blocks_reported = coalesce(p_blocks, 0),
    reps = v_reps,
    blocks_smashed = v_blocks,
    coins_awarded = v_coins,
    xp_awarded = v_xp,
    is_completed = v_completed,
    battle_submission = v_submission,
    outcome = v_outcome,
    accepted_at = v_now
  WHERE id = v_s.id;

  RETURN v_outcome;
END;
$function$;
