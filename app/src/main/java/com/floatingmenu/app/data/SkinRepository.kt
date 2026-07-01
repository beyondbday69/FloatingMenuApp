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
        "AR" to setOf("AKM", "M16A4", "SCAR", "M416", "GROZA", "AUG", "QBZ", "M762", "MK47", "G36C", "HoneyBadger", "ASM", "FAMAS", "ACE32"),
        "SMG" to setOf("UZI", "UMP", "Vector", "Thompson", "Bizon", "MP5K", "P90"),
        "SR" to setOf("Kar98", "M24", "AWM", "Mosin", "DSR", "AMR"),
        "DMR" to setOf("SKS", "VSS", "Mini14", "MK14", "SLR", "QBU", "MK12"),
        "Shotgun" to setOf("S12K", "DBS", "S1897", "S686"),
        "LMG" to setOf("M249", "DP28", "MG3"),
        "Melee" to setOf("Pan", "Machete", "Crowbar", "Sickle"),
        "Vehicles" to setOf("UAZ", "Dacia", "Buggy", "Motor", "CoupeRB"),
        "Cosmetics" to setOf("Suit", "Bag", "Helmet", "Parachute", "Pet", "Shirt", "Hat", "Mask", "Glasses", "Pants", "Shoes", "Armor")
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
        val builder = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            builder.append(line).append("\n")
        }
        process.waitFor()
        val exitCode = process.exitValue()
        
        val output = builder.toString()
        Log.d("SkinMod", "Shizuku exit code: $exitCode, Output length: ${output.length}")
        
        if (exitCode != 0 || output.trim().isEmpty()) {
            throw Exception("Failed to read file or file is empty (Exit code: $exitCode). Ensure file exists at $path")
        }
        return output
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
        var currentSkinName = ""

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
                if (line.startsWith("#")) {
                    val potentialName = line.substring(1).trim()
                    if (potentialName.isNotEmpty() && !potentialName.startsWith("=")) {
                        currentSkinName = potentialName
                    }
                } else if (line.contains("=")) {
                    val parts = line.split("=", limit = 2)
                    if (parts.size == 2 && currentSkinName.isNotEmpty()) {
                        val ids = parts[1].split(",").map { it.trim() }
                        skinListMap[currentSkinName] = ids
                        currentSkinName = "" 
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
            // Write to local cache dir first
            val tempFile = File(context.cacheDir, "SKINS.ini.tmp")
            tempFile.writeText(builder.toString())
            
            // Use Shizuku to copy over to the protected directory
            val cmd = "cp '${tempFile.absolutePath}' '$INI_PATH' && chmod 644 '$INI_PATH'"
            Log.d("SkinMod", "Shizuku executing write: $cmd")
            val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
            process.waitFor()
            val exitCode = process.exitValue()
            if (exitCode != 0) {
                throw Exception("Failed to write updated SKINS.ini via Shizuku (exit code: $exitCode)")
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
