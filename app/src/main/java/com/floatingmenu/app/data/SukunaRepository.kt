package com.floatingmenu.app.data

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

data class SukunaState(
    val ESP_ON: Boolean = true,
    val Color: Int = 1,
    val Distance: Boolean = true,
    val HP: Boolean = true,
    val EspBom: Boolean = true,
    val EspBomItem: Boolean = true,
    val EspBomActive: Boolean = true,
    val WhiteBody: Boolean = false,
    val WbOffset: Int = 2,
    val WbPower: Int = 5,
    val WbShadow: Int = 100,
    val MagicBullet: Int = 5,
    val ESPWeapon: Boolean = true,
    val WpnSize: Int = 100,
    val WpnAR: Boolean = true,
    val WpnSMG: Boolean = true,
    val WpnSR: Boolean = true,
    val WpnSG: Boolean = true,
    val WpnLMG: Boolean = true,
    val WpnPistol: Boolean = true,
    val WpnMelee: Boolean = true,
    val WpnSP: Boolean = true,
    val WpnLV3: Boolean = true,
    val WpnSCP: Boolean = true,
    val WpnMED: Boolean = true
)

class SukunaRepository(private val context: Context) {

    private val CFG_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS/sukuna_settings.cfg"
    private val CFG_DIR = "/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS"

    private fun readWithShizuku(path: String): String {
        if (!rikka.shizuku.Shizuku.pingBinder()) throw Exception("Shizuku is not running")
        if (rikka.shizuku.Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            throw Exception("Shizuku permission not granted")
        }

        val cmd = "cat '$path'"
        val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val builder = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            builder.append(line).append("\n")
        }
        process.waitFor()
        val exitCode = process.exitValue()
        
        if (exitCode != 0) {
            // File might not exist yet, return empty
            return ""
        }
        return builder.toString()
    }

    suspend fun loadConfig(): SukunaState = withContext(Dispatchers.IO) {
        var state = SukunaState()
        try {
            val content = readWithShizuku(CFG_PATH)
            if (content.isNotEmpty()) {
                val map = mutableMapOf<String, String>()
                content.lines().forEach { line ->
                    val parts = line.split("=", limit = 2)
                    if (parts.size == 2) {
                        map[parts[0].trim()] = parts[1].trim()
                    }
                }
                
                state = state.copy(
                    ESP_ON = map["ESP_ON"]?.toBooleanStrictOrNull() ?: state.ESP_ON,
                    Color = map["Color"]?.toIntOrNull() ?: state.Color,
                    Distance = map["Distance"]?.toBooleanStrictOrNull() ?: state.Distance,
                    HP = map["HP"]?.toBooleanStrictOrNull() ?: state.HP,
                    EspBom = map["EspBom"]?.toBooleanStrictOrNull() ?: state.EspBom,
                    EspBomItem = map["EspBomItem"]?.toBooleanStrictOrNull() ?: state.EspBomItem,
                    EspBomActive = map["EspBomActive"]?.toBooleanStrictOrNull() ?: state.EspBomActive,
                    WhiteBody = map["WhiteBody"]?.toBooleanStrictOrNull() ?: state.WhiteBody,
                    WbOffset = map["WbOffset"]?.toIntOrNull() ?: state.WbOffset,
                    WbPower = map["WbPower"]?.toIntOrNull() ?: state.WbPower,
                    WbShadow = map["WbShadow"]?.toIntOrNull() ?: state.WbShadow,
                    MagicBullet = map["MagicBullet"]?.toIntOrNull() ?: state.MagicBullet,
                    ESPWeapon = map["ESPWeapon"]?.toBooleanStrictOrNull() ?: state.ESPWeapon,
                    WpnSize = map["WpnSize"]?.toIntOrNull() ?: state.WpnSize,
                    WpnAR = map["WpnAR"]?.toBooleanStrictOrNull() ?: state.WpnAR,
                    WpnSMG = map["WpnSMG"]?.toBooleanStrictOrNull() ?: state.WpnSMG,
                    WpnSR = map["WpnSR"]?.toBooleanStrictOrNull() ?: state.WpnSR,
                    WpnSG = map["WpnSG"]?.toBooleanStrictOrNull() ?: state.WpnSG,
                    WpnLMG = map["WpnLMG"]?.toBooleanStrictOrNull() ?: state.WpnLMG,
                    WpnPistol = map["WpnPistol"]?.toBooleanStrictOrNull() ?: state.WpnPistol,
                    WpnMelee = map["WpnMelee"]?.toBooleanStrictOrNull() ?: state.WpnMelee,
                    WpnSP = map["WpnSP"]?.toBooleanStrictOrNull() ?: state.WpnSP,
                    WpnLV3 = map["WpnLV3"]?.toBooleanStrictOrNull() ?: state.WpnLV3,
                    WpnSCP = map["WpnSCP"]?.toBooleanStrictOrNull() ?: state.WpnSCP,
                    WpnMED = map["WpnMED"]?.toBooleanStrictOrNull() ?: state.WpnMED
                )
            }
        } catch (e: Exception) {
            Log.e("SukunaMod", "Failed to load config", e)
        }
        state
    }

    suspend fun saveConfig(state: SukunaState) = withContext(Dispatchers.IO) {
        val builder = java.lang.StringBuilder()
        builder.append("ESP_ON=${state.ESP_ON}\n")
        builder.append("Color=${state.Color}\n")
        builder.append("Distance=${state.Distance}\n")
        builder.append("HP=${state.HP}\n")
        builder.append("EspBom=${state.EspBom}\n")
        builder.append("EspBomItem=${state.EspBomItem}\n")
        builder.append("EspBomActive=${state.EspBomActive}\n")
        builder.append("WhiteBody=${state.WhiteBody}\n")
        builder.append("WbOffset=${state.WbOffset}\n")
        builder.append("WbPower=${state.WbPower}\n")
        builder.append("WbShadow=${state.WbShadow}\n")
        builder.append("MagicBullet=${state.MagicBullet}\n")
        builder.append("ESPWeapon=${state.ESPWeapon}\n")
        builder.append("WpnSize=${state.WpnSize}\n")
        builder.append("WpnAR=${state.WpnAR}\n")
        builder.append("WpnSMG=${state.WpnSMG}\n")
        builder.append("WpnSR=${state.WpnSR}\n")
        builder.append("WpnSG=${state.WpnSG}\n")
        builder.append("WpnLMG=${state.WpnLMG}\n")
        builder.append("WpnPistol=${state.WpnPistol}\n")
        builder.append("WpnMelee=${state.WpnMelee}\n")
        builder.append("WpnSP=${state.WpnSP}\n")
        builder.append("WpnLV3=${state.WpnLV3}\n")
        builder.append("WpnSCP=${state.WpnSCP}\n")
        builder.append("WpnMED=${state.WpnMED}\n")

        val tempFile = File(context.getExternalFilesDir(null), "sukuna_settings.cfg.tmp")
        tempFile.writeText(builder.toString())

        // Ensure directory exists then copy
        val cmd = "mkdir -p '$CFG_DIR' && cp '${tempFile.absolutePath}' '$CFG_PATH'"
        val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
        
        val errReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
        val errBuilder = java.lang.StringBuilder()
        var errLine: String?
        while (errReader.readLine().also { errLine = it } != null) {
            errBuilder.append(errLine).append(" ")
        }
        
        process.waitFor()
        val exitCode = process.exitValue()
        if (exitCode != 0) {
            throw Exception("Shizuku Config Write failed (code: $exitCode, err: ${errBuilder.toString()})")
        }
    }
}
