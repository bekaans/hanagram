// Hanagram — Push bildirim gönderme Edge Function
// OneSignal API ile bildirim gönderir (ücretsiz)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") ?? "";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") ?? "";

serve(async (req: Request) => {
  try {
    const { target_user_id, target, title, body, data } = await req.json();

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "title and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    let notificationPayload: Record<string, unknown>;

    if (target === "all") {
      // Tüm kullanıcılara gönder
      notificationPayload = {
        app_id: ONESIGNAL_APP_ID,
        contents: { tr: body, en: body },
        headings: { tr: title, en: title },
        data: data || {},
      };
    } else if (target_user_id) {
      // Belirli bir kullanıcıya gönder (supabase_id alias ile)
      notificationPayload = {
        app_id: ONESIGNAL_APP_ID,
        contents: { tr: body, en: body },
        headings: { tr: title, en: title },
        data: data || {},
        filters: [
          {
            field: "tag",
            key: "supabase_id",
            relation: "=",
            value: target_user_id,
          },
        ],
      };
    } else {
      return new Response(
        JSON.stringify({ error: "target or target_user_id required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // OneSignal API'ye gönder
    const response = await fetch(
      "https://onesignal.com/api/v1/notifications",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify(notificationPayload),
      }
    );

    const result = await response.json();

    if (!response.ok) {
      console.error("OneSignal error:", result);
      return new Response(
        JSON.stringify({ error: "Notification failed", details: result }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, id: result.id }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
