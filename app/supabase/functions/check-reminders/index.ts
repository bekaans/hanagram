// Hanagram — Hatırlatma kontrol Edge Function
// Supabase pg_cron ile düzenli çalıştırılır
// Zamanlanmış hatırlatmaları kontrol edip SMS gönderir

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (_req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Gönderilmemiş ve zamanı gelmiş hatırlatmaları çek
    const now = new Date().toISOString();
    const { data: reminders, error } = await supabase
      .from("scheduled_reminders")
      .select("*")
      .eq("status", "pending")
      .lte("scheduled_for", now)
      .limit(50);

    if (error) throw error;
    if (!reminders || reminders.length === 0) {
      return new Response(
        JSON.stringify({ success: true, sent: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    let sentCount = 0;

    for (const reminder of reminders) {
      try {
        // send-sms Edge Function'ını çağır
        const smsResponse = await fetch(
          `${SUPABASE_URL}/functions/v1/send-sms`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              to: reminder.recipient_phone,
              message: reminder.message,
            }),
          }
        );

        if (smsResponse.ok) {
          // Başarılı → durumu güncelle
          await supabase
            .from("scheduled_reminders")
            .update({
              status: "sent",
              sent_at: new Date().toISOString(),
            })
            .eq("id", reminder.id);

          sentCount++;
        } else {
          // Başarısız → failed olarak işaretle
          await supabase
            .from("scheduled_reminders")
            .update({ status: "failed" })
            .eq("id", reminder.id);
        }
      } catch (e) {
        console.error("Reminder send failed:", e);
        await supabase
          .from("scheduled_reminders")
          .update({ status: "failed" })
          .eq("id", reminder.id);
      }
    }

    return new Response(
      JSON.stringify({ success: true, sent: sentCount, total: reminders.length }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
