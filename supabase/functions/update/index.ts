import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

interface Event {
  id: string
  date: string
  agenda?: string
  profile: string
}

interface Profile {
  fcm_token: string
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string
  privateKey: string
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    jwtClient.authorize((err, tokens) => {
      if (err) {
        reject(err)
        return
      }
      resolve(tokens!.access_token!)
    })
  })
}

const sendFCMNotification = async (
  fcmToken: string,
  title: string,
  body: string,
  eventId: string,
  eventDate: string,
  notificationType: string
) => {
  const accessToken = await getAccessToken({
    clientEmail: Deno.env.get('FIREBASE_CLIENT_EMAIL')!,
    privateKey: Deno.env.get('FIREBASE_PRIVATE_KEY')!,
  })

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${Deno.env.get('FIREBASE_PROJECT_ID')}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
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
  )

  const resData = await res.json()

  if (res.status < 200 || res.status > 299) {
    throw resData
  }

  return resData
}

Deno.serve(async (req) => {
  try {
    // Get current timestamp
    const now = new Date()
    const twentyFourHoursLater = new Date(now.getTime() + 24 * 60 * 60 * 1000)
    const seventyTwoHoursLater = new Date(now.getTime() + 72 * 60 * 60 * 1000)

    // Fetch events happening in the next 72 hours
    const { data: events, error: eventsError } = await supabase
      .from('events')
      .select('id, date, agenda, profile')
      .gte('date', now.toISOString())
      .lte('date', seventyTwoHoursLater.toISOString())

    if (eventsError) {
      throw new Error(`Error fetching events: ${eventsError.message}`)
    }

    if (!events || events.length === 0) {
      return new Response(null, { status: 204 })
    }

    const notifications: Array<{
      success: boolean
      eventId: string
      message: string
    }> = []

    // Process each event
    for (const event of events as Event[]) {
      const eventDate = new Date(event.date)
      const hoursUntilEvent = (eventDate.getTime() - now.getTime()) / (1000 * 60 * 60)

      // Determine notification type
      let notificationType: '24h' | '72h' | null = null
      let title = ''
      let body = ''

      if (hoursUntilEvent <= 24 && hoursUntilEvent > 0) {
        notificationType = '24h'
        title = 'Event Tomorrow!'
        body = `Reminder: "${event.agenda || 'Your event'}" is happening in less than 24 hours!`
      } else if (hoursUntilEvent <= 72 && hoursUntilEvent > 24) {
        notificationType = '72h'
        title = 'Event in 3 Days'
        body = `Upcoming: "${event.agenda || 'Your event'}" is happening in less than 3 days`
      }

      if (!notificationType) continue

      // Fetch user's FCM token from profile table
      const { data: profile, error: profileError } = await supabase
        .from('profile')
        .select('fcm_token')
        .eq('id', event.profile)
        .single()

      if (profileError || !profile?.fcm_token) {
        notifications.push({
          success: false,
          eventId: event.id,
          message: `No FCM token found for profile ${event.profile}`,
        })
        continue
      }

      // Send FCM notification
      try {
        await sendFCMNotification(
          profile.fcm_token,
          title,
          body,
          event.id,
          event.date,
          notificationType
        )

        notifications.push({
          success: true,
          eventId: event.id,
          message: 'Notification sent successfully',
        })
      } catch (error) {
        notifications.push({
          success: false,
          eventId: event.id,
          message: `FCM error: ${JSON.stringify(error)}`,
        })
      }
    }

    return new Response(
      JSON.stringify({
        message: 'Notification processing complete',
        processedEvents: events.length,
        notifications,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
