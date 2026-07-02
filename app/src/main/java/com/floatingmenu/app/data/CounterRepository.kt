package com.floatingmenu.app.data

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.io.BufferedReader
import java.io.InputStreamReader

data class CounterState(val botCount: Int, val playerCount: Int)

class CounterRepository(private val context: Context) {
    private val COUNTER_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/esp_counters.txt"

    fun getCountersFlow(): Flow<CounterState> = flow {
        var lastBotCount = 0
        var lastPlayerCount = 0

        while (true) {
            try {
                if (!rikka.shizuku.Shizuku.pingBinder()) {
                    delay(1000)
                    continue
                }

                val cmd = "cat '$COUNTER_PATH'"
                val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                
                var content = ""
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    content += line
                }
                process.waitFor()

                if (content.isNotEmpty()) {
                    // Expected format: "BOT : X     PLAYER : Y"
                    val parts = content.split("PLAYER :")
                    if (parts.size == 2) {
                        val botStr = parts[0].replace("BOT :", "").trim()
                        val playerStr = parts[1].trim()
                        
                        val botCount = botStr.toIntOrNull() ?: 0
                        val playerCount = playerStr.toIntOrNull() ?: 0
                        
                        if (botCount != lastBotCount || playerCount != lastPlayerCount) {
                            lastBotCount = botCount
                            lastPlayerCount = playerCount
                            emit(CounterState(botCount, playerCount))
                        }
                    }
                }
            } catch (e: Exception) {
                // Log.e("SkinMod", "Counter Error", e)
            }
            delay(1000) // Poll every 1 second
        }
    }.flowOn(Dispatchers.IO)
}
