package com.floatingmenu.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {

    private const val CHANNEL_SKIN = "skin_channel"
    private const val CHANNEL_ESP = "esp_channel"
    private const val SKIN_NOTIF_ID = 2001
    private const val ESP_NOTIF_ID = 2002

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val skinChannel = NotificationChannel(
                CHANNEL_SKIN,
                "Skin Changes",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when skins are applied"
                enableVibration(true)
            }

            val espChannel = NotificationChannel(
                CHANNEL_ESP,
                "ESP Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alert when more than 5 real players detected"
                enableVibration(true)
            }

            nm.createNotificationChannel(skinChannel)
            nm.createNotificationChannel(espChannel)
        }
    }

    fun notifySkinApplied(context: Context, weaponName: String, skinName: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_SKIN)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentTitle("Skin Applied ✓")
            .setContentText("$weaponName → $skinName")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(SKIN_NOTIF_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted, silently ignore
        }
    }

    fun notifyPlayerAlert(context: Context, playerCount: Int) {
        val notification = NotificationCompat.Builder(context, CHANNEL_ESP)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠ Player Alert!")
            .setContentText("$playerCount real players nearby!")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(ESP_NOTIF_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS not granted, silently ignore
        }
    }
}
