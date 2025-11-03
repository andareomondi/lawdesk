import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { create } from "https://deno.land/x/djwt@v2.8/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!;

interface Event {
  id: string;
  date: string;
  agenda?: string;
  profile: string;
}

interface Profile {
  id: string;
  fcm_token: string;
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const payload = {
    iss: FIREBASE_CLIENT_EMAIL,
    sub: FIREBASE_CLIENT_EMAIL,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  // Import the private key
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(FIREBASE_PRIVATE_KEY),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const jwt = await create({ alg: "RS256", typ: "JWT" }, payload, privateKey);

  // Exchange JWT for access token
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await response.json();
  return data.access_token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function sendFCMNotification(
  token: string,
  title: string,
  body: string,
  eventId: string,
  eventDate: string,
  notificationType: string
): Promise<{ success: boolean; message: string }> {
  try {
    const accessToken = await getAccessToken();

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              eventId: eventId,
              eventDate: eventDate,
              notificationType: notificationType,
            },
          },
        }),
      }
    );

    if (!fcmResponse.ok) {
      const errorData = await fcmResponse.json();
      return {
        success: false,
        message: `FCM error: ${JSON.stringify(errorData)}`,
      };
    }

    return {
      success: true,
      message: "Notification sent successfully",
    };
  } catch (error) {
    return {
      success: false,
      message: `FCM request failed: ${error.message}`,
    };
  }
}

serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get current timestamp
    const now = new Date();
    const twentyFourHoursLater = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const seventyTwoHoursLater = new Date(now.getTime() + 72 * 60 * 60 * 1000);

    // Fetch events happening in the next 72 hours
    const { data: events, error: eventsError } = await supabase
      .from("events")
      .select("id, date, agenda, profile")
      .gte("date", now.toISOString())
      .lte("date", seventyTwoHoursLater.toISOString());

    if (eventsError) {
      throw new Error(`Error fetching events: ${eventsError.message}`);
    }

    if (!events || events.length === 0) {
      return new Response(null, { status: 204 });
    }

    const notifications: Array<{ success: boolean; eventId: string; message: string }> = [];

    // Process each event
    for (const event of events as Event[]) {
      const eventDate = new Date(event.date);
      const hoursUntilEvent = (eventDate.getTime() - now.getTime()) / (1000 * 60 * 60);

      // Determine notification type
      let notificationType: "24h" | "72h" | null = null;
      let title = "";
      let body = "";

      if (hoursUntilEvent <= 24 && hoursUntilEvent > 0) {
        notificationType = "24h";
        title = "Event Tomorrow!";
        body = `Reminder: "${event.agenda || 'Your event'}" is happening in less than 24 hours!`;
      } else if (hoursUntilEvent <= 72 && hoursUntilEvent > 24) {
        notificationType = "72h";
        title = "Event in 3 Days";
        body = `Upcoming: "${event.agenda || 'Your event'}" is happening in less than 3 days`;
      }

      if (!notificationType) continue;

      // Fetch user's FCM token from profile table
      const { data: profile, error: profileError } = await supabase
        .from("profile")
        .select("fcm_token")
        .eq("id", event.profile)
        .single();

      if (profileError || !profile?.fcm_token) {
        notifications.push({
          success: false,
          eventId: event.id,
          message: `No FCM token found for profile ${event.profile}`,
        });
        continue;
      }

      // Send FCM notification
      const result = await sendFCMNotification(
        profile.fcm_token,
        title,
        body,
        event.id,
        event.date,
        notificationType
      );

      notifications.push({
        success: result.success,
        eventId: event.id,
        message: result.message,
      });
    }

    return new Response(
      JSON.stringify({
        message: "Notification processing complete",
        processedEvents: events.length,
        notifications,
      }),
      { headers: { "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { "Content-Type": "application/json" }, status: 500 }
    );
  }
});
