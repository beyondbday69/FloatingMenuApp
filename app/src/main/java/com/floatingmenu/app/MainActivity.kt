package com.floatingmenu.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        checkAndStartService()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                MainScreen(
                    hasPermissions = checkPermissions(),
                    onRequestPermissions = { requestPermissions() },
                    onStartService = { startFloatingService() },
                    onStopService = { stopFloatingService() },
                    onTestShizuku = { testShizukuAccess() }
                )
            }
        }
    }

    private fun checkPermissions(): Boolean {
        val hasOverlay = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
        val hasStorage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
        return hasOverlay && hasStorage
    }

    private fun requestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            permissionLauncher.launch(intent)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                permissionLauncher.launch(intent)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                permissionLauncher.launch(intent)
            }
            return
        }
    }

    private fun checkAndStartService() {
        if (checkPermissions()) {
            setContent {
                MaterialTheme(colorScheme = darkColorScheme()) {
                    MainScreen(
                        hasPermissions = true,
                        onRequestPermissions = { requestPermissions() },
                        onStartService = { startFloatingService() },
                        onStopService = { stopFloatingService() },
                        onTestShizuku = { testShizukuAccess() }
                    )
                }
            }
        } else {
            Toast.makeText(this, "Permissions not fully granted", Toast.LENGTH_SHORT).show()
        }
    }

    private fun startFloatingService() {
        startService(Intent(this, ComposeFloatingMenuService::class.java))
    }

    private fun stopFloatingService() {
        stopService(Intent(this, ComposeFloatingMenuService::class.java))
    }

    private val SHIZUKU_CODE = 102
    private fun testShizukuAccess() {
        if (!rikka.shizuku.Shizuku.pingBinder()) {
            Toast.makeText(this, "Shizuku is not running!", Toast.LENGTH_SHORT).show()
            return
        }
        if (rikka.shizuku.Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) {
            rikka.shizuku.Shizuku.requestPermission(SHIZUKU_CODE)
            return
        }
        try {
            val process = rikka.shizuku.Shizuku.newProcess(arrayOf("sh", "-c", "ls -l /sdcard/Android/data/com.pubg.imobile"), null, null)
            process.waitFor()
            Toast.makeText(this, "Shizuku works!", Toast.LENGTH_LONG).show()
        } catch (e: Exception) {
            Toast.makeText(this, "Shizuku failed: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }
}

@Composable
fun MainScreen(
    hasPermissions: Boolean,
    onRequestPermissions: () -> Unit,
    onStartService: () -> Unit,
    onStopService: () -> Unit,
    onTestShizuku: () -> Unit
) {
    val cs = MaterialTheme.colorScheme
    Scaffold(containerColor = cs.surface) { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(Icons.Filled.Gamepad, contentDescription = null, modifier = Modifier.size(64.dp), tint = cs.primary)
            Spacer(modifier = Modifier.height(16.dp))
            Text("MOD V1", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Text("Game Overlay Menu", style = MaterialTheme.typography.bodyLarge, color = cs.onSurfaceVariant)
            Spacer(modifier = Modifier.height(40.dp))

            if (!hasPermissions) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = cs.errorContainer)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Permissions Required", style = MaterialTheme.typography.titleMedium, color = cs.onErrorContainer)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Overlay and Storage permissions are needed.", style = MaterialTheme.typography.bodyMedium, color = cs.onErrorContainer)
                        Spacer(modifier = Modifier.height(12.dp))
                        FilledTonalButton(onClick = onRequestPermissions, modifier = Modifier.fillMaxWidth()) {
                            Icon(Icons.Filled.Security, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Grant Permissions")
                        }
                    }
                }
            } else {
                FilledTonalButton(onClick = onStartService, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Start Overlay", style = MaterialTheme.typography.titleMedium)
                }
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(onClick = onStopService, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                    Icon(Icons.Filled.Stop, contentDescription = null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Stop Overlay", style = MaterialTheme.typography.titleMedium)
                }
                Spacer(modifier = Modifier.height(24.dp))
                TextButton(onClick = onTestShizuku) {
                    Icon(Icons.Filled.BugReport, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Test Shizuku")
                }
            }
        }
    }
}
