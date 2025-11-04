import { createClient } from 'npm:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

interface Event {
  id: string
  date: string
  agenda?: string
  profile: string
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

Deno.serve(async (req) => {
  const now = new Date()
  const seventyTwoHoursLater = new Date(now.getTime() + 72 * 60 * 60 * 1000)

  const { data: events, error: eventsError } = await supabase
    .from('events')
    .select('id, date, agenda, profile')
    .gte('date', now.toISOString())
    .lte('date', seventyTwoHoursLater.toISOString())

  if (eventsError) throw eventsError
  if (!events || events.length === 0) return new Response(null, { status: 204 })

  const accessToken = await getAccessToken({
    clientEmail: Deno.env.get('client_email')!,
    privateKey: Deno.env.get('FIREBASE_PRIVATE_KEY')!,
  })

  const notifications = []

  for (const event of events as Event[]) {
    const eventDate = new Date(event.date)
    const hoursUntilEvent = (eventDate.getTime() - now.getTime()) / (1000 * 60 * 60)

    let title = ''
    let body = ''
    let notificationType = ''

    if (hoursUntilEvent <= 24 && hoursUntilEvent > 0) {
      notificationType = '24h'
      title = 'Event Tomorrow!'
      body = `Reminder: "${event.agenda || 'Your event'}" is happening in less than 24 hours!`
    } else if (hoursUntilEvent <= 72 && hoursUntilEvent > 24) {
      notificationType = '72h'
      title = 'Event in 3 Days'
      body = `Upcoming: "${event.agenda || 'Your event'}" is happening in less than 3 days`
    } else {
      continue
    }

    const { data: profile } = await supabase
      .from('profile')
      .select('fcm_token')
      .eq('id', event.profile)
      .single()

    if (!profile?.fcm_token) continue

    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${Deno.env.get('PROJECT_ID')}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: { title, body },
            data: {
              eventId: event.id,
              eventDate: event.date,
              notificationType,
            },
          },
        }),
      }
    )

    const resData = await res.json()
    if (res.status < 200 || res.status > 299) throw resData

    notifications.push({ eventId: event.id, status: 'sent' })
  }

  return new Response(JSON.stringify({ notifications }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
