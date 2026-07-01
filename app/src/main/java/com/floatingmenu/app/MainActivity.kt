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
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        checkAndStartService()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            MainScreen(
                hasPermissions = checkPermissions(),
                onRequestPermissions = { requestPermissions() },
                onStartService = { startFloatingService() },
                onStopService = { stopFloatingService() },
                onTestShizuku = { testShizukuAccess() }
            )
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
                MainScreen(
                    hasPermissions = true,
                    onRequestPermissions = { requestPermissions() },
                    onStartService = { startFloatingService() },
                    onStopService = { stopFloatingService() },
                    onTestShizuku = { testShizukuAccess() }
                )
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
            Toast.makeText(this, "Shizuku works! It can see inside com.pubg.imobile folder.", Toast.LENGTH_LONG).show()
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
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("Floating Mod Menu", style = androidx.compose.material3.MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(32.dp))

        if (!hasPermissions) {
            Text("We need Overlay and Storage permissions to function.")
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onRequestPermissions) {
                Text("Grant Permissions")
            }
        } else {
            Button(onClick = onStartService, modifier = Modifier.fillMaxWidth(0.7f)) {
                Text("Start Floating Menu")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onStopService, modifier = Modifier.fillMaxWidth(0.7f)) {
                Text("Stop Floating Menu")
            }
            Spacer(modifier = Modifier.height(32.dp))
            Button(onClick = onTestShizuku, modifier = Modifier.fillMaxWidth(0.7f)) {
                Text("Test Shizuku Access")
            }
        }
    }
}
