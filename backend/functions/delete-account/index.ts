import { AuthError, corsHeaders, createAdminClient, requireAuth } from "../_shared/auth.ts";

/**
 * Permanently deletes the signed-in user's account.
 * 1. Removes their avatar files.
 * 2. Cancels waiting invitations, fixes results of active battles, and
 *    detaches their identity from battle history (opponents keep scores).
 * 3. Deletes the auth user; profile, stats, towers, streak days and
 *    workouts are removed by cascade.
 * The user id always comes from the verified token, never the request body.
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  try {
    const user = await requireAuth(req);
    const admin = createAdminClient();
    const folder = user.id.toLowerCase();

    // 1. Avatar files
    const { data: files, error: listError } = await admin.storage.from("avatars").list(folder, { limit: 1000 });
    if (listError) throw listError;
    if (files && files.length > 0) {
      const { error: removeError } = await admin.storage
        .from("avatars")
        .remove(files.map((f) => `${folder}/${f.name}`));
      if (removeError) throw removeError;
    }

    // 2. Battles: cancel invites, finalize active ones, anonymise history
    const { error: battleError } = await admin.rpc("prepare_account_deletion", { p_user: user.id });
    if (battleError) throw battleError;

    // 3. Auth user (cascades personal data)
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError && !/not.?found/i.test(deleteError.message)) throw deleteError;

    console.log(`[delete-account] Deleted user ${user.id}`);
    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) {
      return json({ error: "Unauthorized" }, 401);
    }
    console.error("[delete-account] Failed:", err instanceof Error ? err.message : err);
    return json({ error: "Internal server error" }, 500);
  }
});
