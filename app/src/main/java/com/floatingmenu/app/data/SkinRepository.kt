package com.floatingmenu.app.data

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "skin_settings")

data class MatchedItem(val name: String, val index: Int, val skinIds: List<String>, val category: String)

class SkinRepository(private val context: Context) {

    private val INI_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini"
    private val DUMP_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/dump_full.txt"

    private val categorySets = mapOf(
        "Cosmetics" to setOf("Suit", "Bag", "Helmet", "Parachute", "Pet", "Hat", "Mask", "Pants", "Shoes", "Glasses", "Armor"),
        "AR" to setOf("M416", "AKM", "SCAR", "M762", "GROZA", "AUG", "ACE32", "QBZ", "G36C", "ASM", "HoneyBadger", "M16A4", "MK47", "FAMAS"),
        "SMG" to setOf("UMP", "Vector", "UZI", "Bizon", "P90", "MP5K", "Thompson"),
        "SR" to setOf("Kar98", "M24", "AWM", "AMR", "Mosin", "DSR"),
        "DMR" to setOf("MK14", "Mini14", "QBU", "MK12", "VSS", "SLR", "SKS"),
        "Shotgun" to setOf("S686", "S1897", "S12K", "NS2000", "DBS"),
        "LMG" to setOf("DP28", "M249", "MG3"),
        "Throwable" to setOf("Grenade"),
        "Melee" to setOf("Pan", "Machete", "Crowbar", "Sickle"),
        "Vehicles" to setOf("Motor", "Sidecar", "Dacia", "MiniBus", "Pickup", "PickupClosed", "Buggy", "UAZ", "UAZClosed", "UAZOpen", "PG117", "JetSki", "Mirado", "MiradoOpen", "Rony", "Scooter", "Snowmobile", "Tukshai", "MonsterTruck", "MotorGlider", "CoupeRB", "Tank", "MountainBike", "UTV", "Bike", "Horse", "Hovercraft")
    )

    private fun readWithShizuku(path: String): String {
        if (!rikka.shizuku.Shizuku.pingBinder()) throw Exception("Shizuku is not running")
        if (rikka.shizuku.Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            throw Exception("Shizuku permission not granted")
        }

        val cmd = "cat '$path'"
        Log.d("SkinMod", "Shizuku executing: $cmd")
        
        val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
        val reader = BufferedReader(InputStreamReader(process.inputStream))
        val errReader = BufferedReader(InputStreamReader(process.errorStream))
        
        val builder = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            builder.append(line).append("\n")
        }
        
        val errBuilder = StringBuilder()
        while (errReader.readLine().also { line = it } != null) {
            errBuilder.append(line).append(" ")
        }
        
        process.waitFor()
        val exitCode = process.exitValue()
        
        val output = builder.toString()
        Log.d("SkinMod", "Shizuku exit code: $exitCode, Output length: ${output.length}")
        
        if (exitCode != 0 || output.trim().isEmpty()) {
            throw Exception("Shizuku Read failed (Code: $exitCode, Err: ${errBuilder.toString()}). Path: $path")
        }
        return output
    }

    suspend fun saveWindowSize(width: Int, height: Int) {
        context.dataStore.edit { prefs ->
            prefs[intPreferencesKey("window_width")] = width
            prefs[intPreferencesKey("window_height")] = height
        }
    }

    suspend fun getWindowSize(): Pair<Int, Int> {
        return context.dataStore.data.map { prefs ->
            Pair(
                prefs[intPreferencesKey("window_width")] ?: 320,
                prefs[intPreferencesKey("window_height")] ?: 500
            )
        }.first()
    }

    suspend fun saveIndex(key: String, value: Int) {
        val prefKey = intPreferencesKey(key)
        context.dataStore.edit { prefs ->
            prefs[prefKey] = value
        }
    }

    suspend fun getIndex(key: String): Int {
        val prefKey = intPreferencesKey(key)
        return context.dataStore.data.map { prefs ->
            prefs[prefKey] ?: 0
        }.first()
    }

    suspend fun loadDump(): Map<String, String> = withContext(Dispatchers.IO) {
        val dumpMap = mutableMapOf<String, String>()
        try {
            val content = readWithShizuku(DUMP_PATH)
            val regex = Regex("^(\\d+)\\s*\\|\\s*[^|]+\\s*\\|\\s*(.+)$")
            content.lines().forEach { line ->
                val match = regex.find(line.trim())
                if (match != null) {
                    val (id, name) = match.destructured
                    dumpMap[id] = name.trim()
                }
            }
        } catch (e: Exception) {
            Log.e("SkinMod", "Failed to load dump_full.txt: ${e.message}")
        }
        dumpMap
    }

    suspend fun parseIni(): List<MatchedItem> = withContext(Dispatchers.IO) {
        val content = readWithShizuku(INI_PATH)
        
        val selectedMap = mutableMapOf<String, Int>()
        val skinListMap = mutableMapOf<String, List<String>>()
        
        var currentSection = ""

        content.lines().forEach { rawLine ->
            val line = rawLine.trim()
            if (line.startsWith("[") && line.endsWith("]")) {
                currentSection = line
            } else if (currentSection == "[SELECTED]") {
                if (line.contains("=")) {
                    val parts = line.split("=", limit = 2)
                    if (parts.size == 2) {
                        selectedMap[parts[0].trim()] = parts[1].trim().toIntOrNull() ?: 0
                    }
                }
            } else if (currentSection == "[SKIN_LIST]") {
                if (line.contains("=") && !line.startsWith("#")) {
                    val parts = line.split("=", limit = 2)
                    if (parts.size == 2) {
                        val skinName = parts[0].trim()
                        val ids = parts[1].split(",").map { it.trim() }
                        skinListMap[skinName] = ids
                    }
                }
            }
        }

        val results = mutableListOf<MatchedItem>()
        for ((name, ids) in skinListMap) {
            var idx = 0
            if (selectedMap.containsKey(name)) {
                idx = selectedMap[name] ?: 0
            } else {
                val fuzzyName = name.replace(" ", "").lowercase()
                val matchKey = selectedMap.keys.find { it.replace(" ", "").lowercase() == fuzzyName }
                if (matchKey != null) {
                    idx = selectedMap[matchKey] ?: 0
                }
            }
            results.add(MatchedItem(name, idx, ids, classify(name)))
        }
        results
    }

    suspend fun writeSelected(name: String, value: Int) = withContext(Dispatchers.IO) {
        val content = readWithShizuku(INI_PATH)
        val builder = java.lang.StringBuilder()
        
        var inSelected = false
        var written = false

        content.lines().forEachIndexed { index, rawLine ->
            // Skip the very last empty line split by .lines() if it's an artificial trailing newline
            if (index == content.lines().size - 1 && rawLine.isEmpty()) return@forEachIndexed

            val trimmed = rawLine.trim()
            if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                inSelected = (trimmed == "[SELECTED]")
                builder.append(rawLine).append("\n")
                return@forEachIndexed
            }

            if (inSelected && trimmed.contains("=")) {
                val parts = trimmed.split("=", limit = 2)
                val key = parts[0].trim()
                val fuzzyKey = key.replace(" ", "").lowercase()
                val fuzzyName = name.replace(" ", "").lowercase()
                if (fuzzyKey == fuzzyName) {
                    builder.append("$key=$value\n")
                    written = true
                    return@forEachIndexed
                }
            }
            builder.append(rawLine).append("\n")
        }
        
        if (written) {
            // Write to local cache dir first - MUST be external so Shizuku shell user can read it
            val tempFile = File(context.getExternalFilesDir(null), "SKINS.ini.tmp")
            tempFile.writeText(builder.toString())
            
            // Use Shizuku to copy over to the protected directory. Do not chmod, as ADB shell cannot chmod SELinux protected files.
            val cmd = "cp '${tempFile.absolutePath}' '$INI_PATH'"
            Log.d("SkinMod", "Shizuku executing write: $cmd")
            val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
            
            // Capture any error output to show in the Toast!
            val errReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
            val errBuilder = java.lang.StringBuilder()
            var errLine: String?
            while (errReader.readLine().also { errLine = it } != null) {
                errBuilder.append(errLine).append(" ")
            }
            
            process.waitFor()
            val exitCode = process.exitValue()
            if (exitCode != 0) {
                throw Exception("Shizuku Write failed (code: $exitCode, err: ${errBuilder.toString()})")
            }
        }
    }


    private fun classify(name: String): String {
        val lowerName = name.lowercase()
        if (lowerName.matches(Regex("^x[-_]?suit.*"))) return "XSuits"
        
        for ((cat, items) in categorySets) {
            for (item in items) {
                if (name.contains(item, ignoreCase = true)) {
                    return cat
                }
            }
        }
        return "Other"
    }
}
