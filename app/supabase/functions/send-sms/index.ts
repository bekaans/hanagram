// Hanagram — SMS gönderme Edge Function
// Supabase Dashboard → Edge Functions → send-sms olarak deploy edin
// Twilio veya benzeri SMS servisini entegre edin

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const TWILIO_ACCOUNT_SID = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
const TWILIO_AUTH_TOKEN = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
const TWILIO_PHONE_NUMBER = Deno.env.get("TWILIO_PHONE_NUMBER") ?? "";

serve(async (req: Request) => {
  try {
    const { to, message } = await req.json();

    if (!to || !message) {
      return new Response(
        JSON.stringify({ error: "to and message are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Twilio API ile SMS gönder
    const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`;
    const credentials = btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`);

    const formData = new URLSearchParams();
    formData.append("To", to);
    formData.append("From", TWILIO_PHONE_NUMBER);
    formData.append("Body", message);

    const response = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: formData.toString(),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("Twilio error:", result);
      return new Response(
        JSON.stringify({ error: "SMS failed", details: result }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, sid: result.sid }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
