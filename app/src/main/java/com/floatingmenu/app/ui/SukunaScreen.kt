package com.floatingmenu.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.floatingmenu.app.data.SukunaState

@Composable
fun SukunaScreen(viewModel: SukunaViewModel) {
    val state by viewModel.uiState.collectAsState()
    
    val tabs = listOf("Main ESP", "Loot", "Visuals", "Misc")
    var selectedTab by remember { mutableStateOf(0) }
    
    val accentPurple = Color(0xFFBB86FC)
    val bgDark = Color(0xFF121212)
    
    Column(modifier = Modifier.fillMaxSize().background(bgDark)) {
        ScrollableTabRow(
            selectedTabIndex = selectedTab,
            containerColor = bgDark,
            contentColor = Color.White,
            edgePadding = 12.dp,
            modifier = Modifier.height(40.dp),
            indicator = { tabPositions ->
                if (selectedTab < tabPositions.size) {
                    TabRowDefaults.Indicator(
                        modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                        color = accentPurple,
                        height = 2.dp
                    )
                }
            },
            divider = {}
        ) {
            tabs.forEachIndexed { index, title ->
                Tab(
                    selected = selectedTab == index,
                    onClick = { selectedTab = index },
                    text = { Text(title, color = if (selectedTab == index) Color.White else Color.Gray, fontSize = 13.sp) }
                )
            }
        }
        
        Divider(color = Color(0xFF333333), thickness = 1.dp)
        
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            when (selectedTab) {
                0 -> { // Main ESP
                    item { ToggleRow("ESP Master Switch", state.ESP_ON) { viewModel.updateState { it.copy(ESP_ON = it.ESP_ON.not()) } } }
                    item {
                        Column {
                            Text("ESP Color", color = Color.White, fontSize = 14.sp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                val colors = listOf(Color.Red, Color.Green, Color.Blue, Color.Yellow, Color.White)
                                colors.forEachIndexed { index, color ->
                                    val id = index + 1
                                    Box(
                                        modifier = Modifier
                                            .size(32.dp)
                                            .background(color, CircleShape)
                                            .clickable { viewModel.updateState { it.copy(Color = id) } }
                                            .padding(4.dp)
                                    ) {
                                        if (state.Color == id) {
                                            Box(modifier = Modifier.fillMaxSize().background(Color.White, CircleShape).padding(2.dp).background(color, CircleShape))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    item { ToggleRow("Show Player HP", state.HP) { viewModel.updateState { it.copy(HP = it.HP.not()) } } }
                    item { ToggleRow("Show Distance", state.Distance) { viewModel.updateState { it.copy(Distance = it.Distance.not()) } } }
                    
                    item { Divider(color = Color(0xFF333333)) }
                    
                    item { ToggleRow("Grenade ESP Master", state.EspBom) { viewModel.updateState { it.copy(EspBom = it.EspBom.not()) } } }
                    item { ToggleRow("↳ Ground Items", state.EspBomItem, modifier = Modifier.padding(start = 16.dp)) { viewModel.updateState { it.copy(EspBomItem = it.EspBomItem.not()) } } }
                    item { ToggleRow("↳ Active Thrown", state.EspBomActive, modifier = Modifier.padding(start = 16.dp)) { viewModel.updateState { it.copy(EspBomActive = it.EspBomActive.not()) } } }
                }
                1 -> { // Loot Filter
                    item { ToggleRow("Weapon ESP Master", state.ESPWeapon) { viewModel.updateState { it.copy(ESPWeapon = it.ESPWeapon.not()) } } }
                    item { SliderRow("Loot Text Size", state.WpnSize.toFloat(), 50f, 200f) { v -> viewModel.updateState { it.copy(WpnSize = v.toInt()) } } }
                    item { Divider(color = Color(0xFF333333)) }
                    item { ToggleRow("AR (Assault Rifles)", state.WpnAR) { viewModel.updateState { it.copy(WpnAR = it.WpnAR.not()) } } }
                    item { ToggleRow("SMG", state.WpnSMG) { viewModel.updateState { it.copy(WpnSMG = it.WpnSMG.not()) } } }
                    item { ToggleRow("Sniper / DMR", state.WpnSR) { viewModel.updateState { it.copy(WpnSR = it.WpnSR.not()) } } }
                    item { ToggleRow("Shotgun", state.WpnSG) { viewModel.updateState { it.copy(WpnSG = it.WpnSG.not()) } } }
                    item { ToggleRow("LMG", state.WpnLMG) { viewModel.updateState { it.copy(WpnLMG = it.WpnLMG.not()) } } }
                    item { ToggleRow("Pistol", state.WpnPistol) { viewModel.updateState { it.copy(WpnPistol = it.WpnPistol.not()) } } }
                    item { ToggleRow("Melee / Special", state.WpnMelee) { viewModel.updateState { it.copy(WpnMelee = it.WpnMelee.not()) } } }
                    item { ToggleRow("Special Items", state.WpnSP) { viewModel.updateState { it.copy(WpnSP = it.WpnSP.not()) } } }
                    item { ToggleRow("Lv3 Gear", state.WpnLV3) { viewModel.updateState { it.copy(WpnLV3 = it.WpnLV3.not()) } } }
                    item { ToggleRow("Scopes", state.WpnSCP) { viewModel.updateState { it.copy(WpnSCP = it.WpnSCP.not()) } } }
                    item { ToggleRow("Meds", state.WpnMED) { viewModel.updateState { it.copy(WpnMED = it.WpnMED.not()) } } }
                }
                2 -> { // Visuals
                    item { ToggleRow("White Body (iPad View)", state.WhiteBody) { viewModel.updateState { it.copy(WhiteBody = it.WhiteBody.not()) } } }
                    item { SliderRow("WB Offset", state.WbOffset.toFloat(), 0f, 20f) { v -> viewModel.updateState { it.copy(WbOffset = v.toInt()) } } }
                    item { SliderRow("WB Power", state.WbPower.toFloat(), 0f, 50f) { v -> viewModel.updateState { it.copy(WbPower = v.toInt()) } } }
                    item { SliderRow("WB Shadow", state.WbShadow.toFloat(), 0f, 200f) { v -> viewModel.updateState { it.copy(WbShadow = v.toInt()) } } }
                }
                3 -> { // Misc
                    item { SliderRow("Magic Bullet (%)", state.MagicBullet.toFloat(), 0f, 100f) { v -> viewModel.updateState { it.copy(MagicBullet = v.toInt()) } } }
                }
            }
        }
    }
}

@Composable
fun ToggleRow(title: String, checked: Boolean, modifier: Modifier = Modifier, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = modifier.fillMaxWidth().clickable { onCheckedChange(!checked) },
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, color = Color.White, fontSize = 14.sp)
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedThumbColor = Color(0xFFBB86FC), checkedTrackColor = Color(0xFFBB86FC).copy(alpha = 0.5f))
        )
    }
}

@Composable
fun SliderRow(title: String, value: Float, min: Float, max: Float, onValueChange: (Float) -> Unit) {
    Column {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, color = Color.White, fontSize = 14.sp)
            Text("${value.toInt()}", color = Color.Gray, fontSize = 14.sp)
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = min..max,
            colors = SliderDefaults.colors(thumbColor = Color(0xFFBB86FC), activeTrackColor = Color(0xFFBB86FC))
        )
    }
}
