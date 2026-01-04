package com.example.lawdesk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device booted - notifications will be rescheduled by the app")
            // Notifications are automatically rescheduled by flutter_local_notifications
            // when the device reboots, as long as allowWhileIdle is set
        }
    }
}
