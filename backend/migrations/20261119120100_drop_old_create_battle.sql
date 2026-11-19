-- Cleanup: drop the old single-argument create_battle overload left behind
-- when the function gained the p_mode parameter (default 'blocks'). The new
-- signature covers the same call, so old clients are unaffected.
DROP FUNCTION IF EXISTS public.create_battle(text);
