package com.floatingmenu.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.floatingmenu.app.data.SukunaState

val ModRed = Color(0xFFFF2A2A)
val ModText = Color(0xFFEEEEEE)
val ModMuted = Color(0xFF888888)

@Composable
fun SukunaContent(viewModel: SukunaViewModel, tab: String) {
    val state by viewModel.uiState.collectAsState()
    
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        when (tab) {
            "ESP" -> {
                item { ModToggle("ESP Master", state.ESP_ON) { viewModel.updateState { it.copy(ESP_ON = it.ESP_ON.not()) } } }
                
                item {
                    Column {
                        Text("ESP Color", color = ModMuted, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.height(4.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            val colors = listOf(Color.Red, Color.Green, Color.Blue, Color.Yellow, Color.White)
                            colors.forEachIndexed { index, color ->
                                val id = index + 1
                                Box(
                                    modifier = Modifier
                                        .size(20.dp)
                                        .background(if (state.Color == id) color else Color.Transparent)
                                        .border(1.dp, color)
                                        .clickable { viewModel.updateState { it.copy(Color = id) } }
                                )
                            }
                        }
                    }
                }
                
                item { ModToggle("Show HP", state.HP) { viewModel.updateState { it.copy(HP = it.HP.not()) } } }
                item { ModToggle("Show Distance", state.Distance) { viewModel.updateState { it.copy(Distance = it.Distance.not()) } } }
                
                item { Spacer(modifier = Modifier.height(4.dp)) }
                item { ModToggle("Grenade ESP", state.EspBom) { viewModel.updateState { it.copy(EspBom = it.EspBom.not()) } } }
                item { ModToggle("- Ground Items", state.EspBomItem) { viewModel.updateState { it.copy(EspBomItem = it.EspBomItem.not()) } } }
                item { ModToggle("- Active Thrown", state.EspBomActive) { viewModel.updateState { it.copy(EspBomActive = it.EspBomActive.not()) } } }
            }
            "LOOT" -> {
                item { ModToggle("Weapon ESP", state.ESPWeapon) { viewModel.updateState { it.copy(ESPWeapon = it.ESPWeapon.not()) } } }
                item { ModSlider("Loot Text Size", state.WpnSize.toFloat(), 50f, 200f) { v -> viewModel.updateState { it.copy(WpnSize = v.toInt()) } } }
                item { Spacer(modifier = Modifier.height(4.dp)) }
                
                item { ModToggle("ARs", state.WpnAR) { viewModel.updateState { it.copy(WpnAR = it.WpnAR.not()) } } }
                item { ModToggle("SMGs", state.WpnSMG) { viewModel.updateState { it.copy(WpnSMG = it.WpnSMG.not()) } } }
                item { ModToggle("Snipers", state.WpnSR) { viewModel.updateState { it.copy(WpnSR = it.WpnSR.not()) } } }
                item { ModToggle("Shotguns", state.WpnSG) { viewModel.updateState { it.copy(WpnSG = it.WpnSG.not()) } } }
                item { ModToggle("LMGs", state.WpnLMG) { viewModel.updateState { it.copy(WpnLMG = it.WpnLMG.not()) } } }
                item { ModToggle("Pistols", state.WpnPistol) { viewModel.updateState { it.copy(WpnPistol = it.WpnPistol.not()) } } }
                item { ModToggle("Melee", state.WpnMelee) { viewModel.updateState { it.copy(WpnMelee = it.WpnMelee.not()) } } }
                item { ModToggle("Special", state.WpnSP) { viewModel.updateState { it.copy(WpnSP = it.WpnSP.not()) } } }
                item { ModToggle("Lv3 Gear", state.WpnLV3) { viewModel.updateState { it.copy(WpnLV3 = it.WpnLV3.not()) } } }
                item { ModToggle("Scopes", state.WpnSCP) { viewModel.updateState { it.copy(WpnSCP = it.WpnSCP.not()) } } }
                item { ModToggle("Meds", state.WpnMED) { viewModel.updateState { it.copy(WpnMED = it.WpnMED.not()) } } }
            }
            "VISUALS" -> {
                item { ModToggle("White Body (iPad)", state.WhiteBody) { viewModel.updateState { it.copy(WhiteBody = it.WhiteBody.not()) } } }
                item { ModSlider("Offset", state.WbOffset.toFloat(), 0f, 20f) { v -> viewModel.updateState { it.copy(WbOffset = v.toInt()) } } }
                item { ModSlider("Power", state.WbPower.toFloat(), 0f, 50f) { v -> viewModel.updateState { it.copy(WbPower = v.toInt()) } } }
                item { ModSlider("Shadow", state.WbShadow.toFloat(), 0f, 200f) { v -> viewModel.updateState { it.copy(WbShadow = v.toInt()) } } }
            }
            "MISC" -> {
                item { ModSlider("Magic Bullet (%)", state.MagicBullet.toFloat(), 0f, 100f) { v -> viewModel.updateState { it.copy(MagicBullet = v.toInt()) } } }
            }
        }
    }
}

@Composable
fun ModToggle(title: String, checked: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable { onClick() }.padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, color = ModText, fontSize = 12.sp)
        Box(
            modifier = Modifier
                .width(28.dp)
                .height(14.dp)
                .border(1.dp, if (checked) ModRed else ModMuted)
                .background(if (checked) ModRed.copy(alpha = 0.8f) else Color.Transparent),
            contentAlignment = Alignment.Center
        ) {
            if (checked) {
                Text("ON", color = Color.White, fontSize = 8.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun ModSlider(title: String, value: Float, min: Float, max: Float, onValueChange: (Float) -> Unit) {
    Column {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, color = ModText, fontSize = 12.sp)
            Text("${value.toInt()}", color = ModRed, fontSize = 12.sp)
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = min..max,
            colors = SliderDefaults.colors(
                thumbColor = ModRed, 
                activeTrackColor = ModRed,
                inactiveTrackColor = Color(0xFF333333)
            )
        )
    }
}
