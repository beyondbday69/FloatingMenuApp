package com.floatingmenu.app.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.io.File

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
        val file = File(DUMP_PATH)
        if (file.exists()) {
            val regex = Regex("^(\\d+)\\s*\\|\\s*[^|]+\\s*\\|\\s*(.+)$")
            file.forEachLine { line ->
                val match = regex.find(line)
                if (match != null) {
                    val (id, name) = match.destructured
                    dumpMap[id] = name.trim()
                }
            }
        }
        dumpMap
    }

    suspend fun parseIni(): List<MatchedItem> = withContext(Dispatchers.IO) {
        val file = File(INI_PATH)
        if (!file.exists()) return@withContext emptyList()

        val selectedMap = mutableMapOf<String, Int>()
        val skinListMap = mutableMapOf<String, List<String>>()
        
        var currentSection = ""
        var currentSkinName = ""

        file.forEachLine { rawLine ->
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
                        // reset so we don't apply same comment to next key if comment is missing
                        currentSkinName = "" 
                    }
                }
            }
        }

        val results = mutableListOf<MatchedItem>()
        // Match them up
        for ((name, ids) in skinListMap) {
            // Find current index
            var idx = 0
            // Exact match
            if (selectedMap.containsKey(name)) {
                idx = selectedMap[name] ?: 0
            } else {
                // Fuzzy match
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
        val file = File(INI_PATH)
        if (!file.exists()) throw Exception("SKINS.ini not found")

        val lines = file.readLines()
        val tempFile = File(file.parent, "SKINS.ini.tmp")
        
        var inSelected = false
        var written = false

        tempFile.bufferedWriter().use { writer ->
            for (line in lines) {
                val trimmed = line.trim()
                if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
                    inSelected = (trimmed == "[SELECTED]")
                    writer.write(line + "\n")
                    continue
                }

                if (inSelected && trimmed.contains("=")) {
                    val parts = trimmed.split("=", limit = 2)
                    val key = parts[0].trim()
                    // Fuzzy match key to name
                    val fuzzyKey = key.replace(" ", "").lowercase()
                    val fuzzyName = name.replace(" ", "").lowercase()
                    if (fuzzyKey == fuzzyName) {
                        writer.write("$key=$value\n")
                        written = true
                        continue
                    }
                }
                writer.write(line + "\n")
            }
            // If it wasn't found in [SELECTED] but we need to add it, we should theoretically add it,
            // but the instructions imply replacing. Let's assume it always exists in [SELECTED].
        }
        
        if (written) {
            tempFile.renameTo(file)
        } else {
            tempFile.delete()
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
