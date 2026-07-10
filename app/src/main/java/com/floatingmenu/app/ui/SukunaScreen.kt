package com.floatingmenu.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun SukunaContent(viewModel: SukunaViewModel, tab: String) {
    val state by viewModel.uiState.collectAsState()
    val cs = MaterialTheme.colorScheme

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        when (tab) {
            "ESP" -> {
                item { SectionHeader("Player ESP") }
                item { M3Toggle("ESP Master", state.ESP_ON) { viewModel.updateState { it.copy(ESP_ON = !it.ESP_ON) } } }
                item {
                    Column(modifier = Modifier.padding(vertical = 4.dp)) {
                        Text("ESP Color", style = MaterialTheme.typography.labelMedium, color = cs.onSurfaceVariant)
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            val colors = listOf(Color.Red, Color.Green, Color.Blue, Color.Yellow, Color.White)
                            colors.forEachIndexed { index, color ->
                                val id = index + 1
                                val isSelected = state.Color == id
                                Box(
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(CircleShape)
                                        .background(color)
                                        .then(if (isSelected) Modifier.border(3.dp, cs.primary, CircleShape) else Modifier.border(1.dp, cs.outlineVariant, CircleShape))
                                        .clickable { viewModel.updateState { it.copy(Color = id) } }
                                )
                            }
                        }
                    }
                }
                item { M3Toggle("Show HP", state.HP) { viewModel.updateState { it.copy(HP = !it.HP) } } }
                item { M3Toggle("Show Distance", state.Distance) { viewModel.updateState { it.copy(Distance = !it.Distance) } } }
                item { HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp)) }
                item { SectionHeader("Grenade ESP") }
                item { M3Toggle("Grenade Master", state.EspBom) { viewModel.updateState { it.copy(EspBom = !it.EspBom) } } }
                item { M3Toggle("Ground Items", state.EspBomItem) { viewModel.updateState { it.copy(EspBomItem = !it.EspBomItem) } } }
                item { M3Toggle("Active Thrown", state.EspBomActive) { viewModel.updateState { it.copy(EspBomActive = !it.EspBomActive) } } }
            }
            "LOOT" -> {
                item { SectionHeader("Weapon Loot ESP") }
                item { M3Toggle("Weapon ESP", state.ESPWeapon) { viewModel.updateState { it.copy(ESPWeapon = !it.ESPWeapon) } } }
                item { M3Slider("Text Size", state.WpnSize.toFloat(), 50f, 200f) { v -> viewModel.updateState { it.copy(WpnSize = v.toInt()) } } }
                item { HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp)) }
                item { SectionHeader("Weapon Filters") }
                item { M3Toggle("ARs", state.WpnAR) { viewModel.updateState { it.copy(WpnAR = !it.WpnAR) } } }
                item { M3Toggle("SMGs", state.WpnSMG) { viewModel.updateState { it.copy(WpnSMG = !it.WpnSMG) } } }
                item { M3Toggle("Snipers", state.WpnSR) { viewModel.updateState { it.copy(WpnSR = !it.WpnSR) } } }
                item { M3Toggle("Shotguns", state.WpnSG) { viewModel.updateState { it.copy(WpnSG = !it.WpnSG) } } }
                item { M3Toggle("LMGs", state.WpnLMG) { viewModel.updateState { it.copy(WpnLMG = !it.WpnLMG) } } }
                item { M3Toggle("Pistols", state.WpnPistol) { viewModel.updateState { it.copy(WpnPistol = !it.WpnPistol) } } }
                item { M3Toggle("Melee", state.WpnMelee) { viewModel.updateState { it.copy(WpnMelee = !it.WpnMelee) } } }
                item { M3Toggle("Special", state.WpnSP) { viewModel.updateState { it.copy(WpnSP = !it.WpnSP) } } }
                item { M3Toggle("Lv3 Gear", state.WpnLV3) { viewModel.updateState { it.copy(WpnLV3 = !it.WpnLV3) } } }
                item { M3Toggle("Scopes", state.WpnSCP) { viewModel.updateState { it.copy(WpnSCP = !it.WpnSCP) } } }
                item { M3Toggle("Meds", state.WpnMED) { viewModel.updateState { it.copy(WpnMED = !it.WpnMED) } } }
            }
            "VISUALS" -> {
                item { SectionHeader("White Body") }
                item { M3Toggle("White Body (iPad)", state.WhiteBody) { viewModel.updateState { it.copy(WhiteBody = !it.WhiteBody) } } }
                item { M3Slider("Offset", state.WbOffset.toFloat(), 0f, 20f) { v -> viewModel.updateState { it.copy(WbOffset = v.toInt()) } } }
                item { M3Slider("Power", state.WbPower.toFloat(), 0f, 50f) { v -> viewModel.updateState { it.copy(WbPower = v.toInt()) } } }
                item { M3Slider("Shadow", state.WbShadow.toFloat(), 0f, 200f) { v -> viewModel.updateState { it.copy(WbShadow = v.toInt()) } } }
            }
            "MISC" -> {
                item { SectionHeader("Combat") }
                item { M3Slider("Magic Bullet %", state.MagicBullet.toFloat(), 0f, 100f) { v -> viewModel.updateState { it.copy(MagicBullet = v.toInt()) } } }
            }
        }
    }
}

@Composable
fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(vertical = 4.dp, horizontal = 2.dp)
    )
}

@Composable
fun M3Toggle(title: String, checked: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() }
            .padding(vertical = 4.dp, horizontal = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface)
        // ImGui Style Checkbox
        Box(
            modifier = Modifier
                .size(16.dp)
                .background(if (checked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest, RoundedCornerShape(2.dp))
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(2.dp)),
            contentAlignment = Alignment.Center
        ) {
            if (checked) {
                Icon(Icons.Filled.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(12.dp))
            }
        }
    }
}

@Composable
fun M3Slider(title: String, value: Float, min: Float, max: Float, onValueChange: (Float) -> Unit) {
    // Keep a precise local float state so dragging doesn't glitch due to integer rounding from caller
    var internalValue by remember(value) { mutableFloatStateOf(value) }
    
    Column(modifier = Modifier.padding(vertical = 4.dp, horizontal = 2.dp)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface)
            Text("${internalValue.toInt()}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
        }
        Spacer(modifier = Modifier.height(4.dp))
        var width by remember { mutableStateOf(1f) }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(14.dp)
                .background(MaterialTheme.colorScheme.surfaceContainerHighest, RoundedCornerShape(2.dp))
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(2.dp))
                .onSizeChanged { width = it.width.toFloat().coerceAtLeast(1f) }
                .pointerInput(Unit) {
                    detectDragGestures { change, dragAmount ->
                        change.consume()
                        internalValue = (internalValue + (dragAmount.x / width) * (max - min)).coerceIn(min, max)
                        onValueChange(internalValue)
                    }
                }
                .pointerInput(Unit) {
                    detectTapGestures { offset ->
                        internalValue = (min + (offset.x / width) * (max - min)).coerceIn(min, max)
                        onValueChange(internalValue)
                    }
                },
            contentAlignment = Alignment.CenterStart
        ) {
            val fraction = ((internalValue - min) / (max - min)).coerceIn(0f, 1f)
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .fillMaxWidth(fraction)
                    .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(2.dp))
            )
        }
    }
}
