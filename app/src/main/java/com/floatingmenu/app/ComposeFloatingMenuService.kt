package com.floatingmenu.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.Toast
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.*
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.floatingmenu.app.data.MatchedItem
import com.floatingmenu.app.ui.CounterViewModel
import com.floatingmenu.app.ui.SkinUiState
import com.floatingmenu.app.ui.SkinViewModel
import com.floatingmenu.app.ui.SukunaContent
import com.floatingmenu.app.ui.SukunaViewModel

class ComposeFloatingMenuService : Service(), LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private lateinit var windowManager: WindowManager
    private lateinit var composeView: ComposeView
    private lateinit var fovView: ComposeView
    private lateinit var counterView: ComposeView
    private lateinit var params: WindowManager.LayoutParams

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    private lateinit var viewModel: SkinViewModel
    private lateinit var sukunaViewModel: SukunaViewModel
    private lateinit var counterViewModel: CounterViewModel

    override fun onCreate() {
        super.onCreate()
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)

        val factory = ViewModelProvider.AndroidViewModelFactory.getInstance(application)
        viewModel = ViewModelProvider(this, factory)[SkinViewModel::class.java]
        sukunaViewModel = ViewModelProvider(this, factory)[SukunaViewModel::class.java]
        counterViewModel = ViewModelProvider(this, factory)[CounterViewModel::class.java]

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 50; y = 150
        }

        composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(this@ComposeFloatingMenuService)
            setViewTreeViewModelStoreOwner(this@ComposeFloatingMenuService)
            setViewTreeSavedStateRegistryOwner(this@ComposeFloatingMenuService)
            setContent {
                MaterialTheme(colorScheme = darkColorScheme()) {
                    FloatingApp(
                        viewModel = viewModel,
                        sukunaViewModel = sukunaViewModel,
                        onDrag = { dx, dy ->
                            params.x += dx.toInt()
                            params.y += dy.toInt()
                            windowManager.updateViewLayout(this, params)
                        },
                        onClose = { stopSelf() },
                        onToast = { msg -> Toast.makeText(this@ComposeFloatingMenuService, msg, Toast.LENGTH_SHORT).show() }
                    )
                }
            }
        }
        windowManager.addView(composeView, params)

        // FOV circle overlay
        val fovParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.CENTER }

        fovView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(this@ComposeFloatingMenuService)
            setViewTreeViewModelStoreOwner(this@ComposeFloatingMenuService)
            setViewTreeSavedStateRegistryOwner(this@ComposeFloatingMenuService)
            setContent {
                val state by sukunaViewModel.uiState.collectAsState()
                if (state.ESP_ON) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Box(modifier = Modifier.size(250.dp).border(2.dp, Color.Green, CircleShape))
                    }
                }
            }
        }
        windowManager.addView(fovView, fovParams)

        // Player/Bot Counter Overlay (Top Center)
        val counterParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply { 
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 80 // offset from top
        }

        counterView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(this@ComposeFloatingMenuService)
            setViewTreeViewModelStoreOwner(this@ComposeFloatingMenuService)
            setViewTreeSavedStateRegistryOwner(this@ComposeFloatingMenuService)
            setContent {
                val sukunaState by sukunaViewModel.uiState.collectAsState()
                if (sukunaState.ESP_ON) {
                    val counterState by counterViewModel.uiState.collectAsState()
                    MaterialTheme(colorScheme = darkColorScheme()) {
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.85f),
                            shape = RoundedCornerShape(16.dp),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
                            modifier = Modifier.padding(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("PLAYER", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                                    Text(
                                        "${counterState.playerCount}", 
                                        style = MaterialTheme.typography.titleLarge, 
                                        color = if (counterState.playerCount > 0) Color.Red else MaterialTheme.colorScheme.onSurface,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                Box(modifier = Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outlineVariant))
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text("BOT", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.secondary)
                                    Text(
                                        "${counterState.botCount}", 
                                        style = MaterialTheme.typography.titleLarge, 
                                        color = if (counterState.botCount > 0) Color(0xFFFFA500) else MaterialTheme.colorScheme.onSurface,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        windowManager.addView(counterView, counterParams)

        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        store.clear()
        if (::composeView.isInitialized) windowManager.removeView(composeView)
        if (::fovView.isInitialized) windowManager.removeView(fovView)
        if (::counterView.isInitialized) windowManager.removeView(counterView)
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = store
    override val savedStateRegistry: SavedStateRegistry get() = savedStateRegistryController.savedStateRegistry
}

// ───────────────────────────────────────────────────────────────────
// NAV TAB MODEL
// ───────────────────────────────────────────────────────────────────
data class NavTab(val label: String, val icon: ImageVector, val outlinedIcon: ImageVector)

val tabs = listOf(
    NavTab("ESP", Icons.Filled.Visibility, Icons.Outlined.Visibility),
    NavTab("LOOT", Icons.Filled.Backpack, Icons.Outlined.Backpack),
    NavTab("VISUALS", Icons.Filled.Palette, Icons.Outlined.Palette),
    NavTab("MISC", Icons.Filled.Tune, Icons.Outlined.Tune),
    NavTab("SKINS", Icons.Filled.Checkroom, Icons.Outlined.Checkroom),
)

// ───────────────────────────────────────────────────────────────────
// MAIN COMPOSABLE
// ───────────────────────────────────────────────────────────────────
@Composable
fun FloatingApp(
    viewModel: SkinViewModel,
    sukunaViewModel: SukunaViewModel,
    onDrag: (Float, Float) -> Unit,
    onClose: () -> Unit,
    onToast: (String) -> Unit
) {
    var isExpanded by remember { mutableStateOf(false) }
    var selectedTab by remember { mutableIntStateOf(0) }
    var showSheetForItem by remember { mutableStateOf<MatchedItem?>(null) }
    
    var windowWidth by remember { mutableStateOf(340.dp) }
    var windowHeight by remember { mutableStateOf(380.dp) }
    val density = androidx.compose.ui.platform.LocalDensity.current

    LaunchedEffect(Unit) {
        val (w, h) = viewModel.getWindowSize()
        windowWidth = w.dp
        windowHeight = h.dp
    }

    val cs = MaterialTheme.colorScheme

    Box(modifier = Modifier.wrapContentSize()) {
        if (!isExpanded) {
            // ─── FAB PILL ───
            FloatingActionButton(
                onClick = { isExpanded = true },
                containerColor = cs.primaryContainer,
                contentColor = cs.onPrimaryContainer,
                shape = CircleShape,
                modifier = Modifier
                    .size(52.dp)
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount.x, dragAmount.y)
                        }
                    }
            ) {
                Icon(Icons.Filled.Gamepad, contentDescription = "Open", modifier = Modifier.size(28.dp))
            }
        } else {
            // ─── MAIN WINDOW ───
            Card(
                modifier = Modifier.width(windowWidth).height(windowHeight),
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = cs.surfaceContainer),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Box(modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.fillMaxSize()) {
                    // ─── DRAG HEADER ───
                    Surface(
                        color = cs.surfaceContainerHigh,
                        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(44.dp)
                                .pointerInput(Unit) {
                                    detectDragGestures { change, dragAmount ->
                                        change.consume()
                                        onDrag(dragAmount.x, dragAmount.y)
                                    }
                                }
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Filled.DragIndicator, contentDescription = null, tint = cs.onSurfaceVariant, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("MOD V1", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = cs.onSurface)
                            Spacer(modifier = Modifier.weight(1f))
                            IconButton(onClick = { viewModel.loadData(); sukunaViewModel.loadData() }, modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Filled.Refresh, contentDescription = "Reload", tint = cs.onSurfaceVariant, modifier = Modifier.size(18.dp))
                            }
                            IconButton(onClick = { isExpanded = false }, modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Filled.Remove, contentDescription = "Minimize", tint = cs.onSurfaceVariant, modifier = Modifier.size(18.dp))
                            }
                            IconButton(onClick = { onClose() }, modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Filled.Close, contentDescription = "Close", tint = cs.onSurfaceVariant, modifier = Modifier.size(18.dp))
                            }
                        }
                    }

                    // ─── CONTENT AREA ───
                    Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        val currentTab = tabs[selectedTab]
                        when (currentTab.label) {
                            "ESP" -> SukunaContent(sukunaViewModel, "ESP")
                            "LOOT" -> SukunaContent(sukunaViewModel, "LOOT")
                            "VISUALS" -> SukunaContent(sukunaViewModel, "VISUALS")
                            "MISC" -> SukunaContent(sukunaViewModel, "MISC")
                            "SKINS" -> SkinsContent(viewModel, onToast) { showSheetForItem = it }
                        }
                    }

                    // ─── BOTTOM NAV (M3 NavigationBar) ───
                    NavigationBar(
                        containerColor = cs.surfaceContainerHigh,
                        tonalElevation = 0.dp,
                        modifier = Modifier.height(64.dp)
                    ) {
                        tabs.forEachIndexed { index, tab ->
                            NavigationBarItem(
                                selected = selectedTab == index,
                                onClick = { selectedTab = index },
                                icon = { Icon(if (selectedTab == index) tab.icon else tab.outlinedIcon, contentDescription = tab.label, modifier = Modifier.size(22.dp)) },
                                label = { Text(tab.label, fontSize = 10.sp, maxLines = 1) },
                                alwaysShowLabel = true
                            )
                        }
                    }
                }

                // ─── RESIZE HANDLE ───
                Icon(
                    imageVector = Icons.Filled.OpenInFull,
                    contentDescription = "Resize",
                    tint = cs.onSurfaceVariant.copy(alpha = 0.5f),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(bottom = 68.dp, end = 8.dp) // Offset above navigation bar
                        .size(20.dp)
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragEnd = {
                                    viewModel.saveWindowSize(windowWidth.value.toInt(), windowHeight.value.toInt())
                                }
                            ) { change, dragAmount ->
                                change.consume()
                                with(density) {
                                    val newW = (windowWidth.toPx() + dragAmount.x).toDp()
                                    val newH = (windowHeight.toPx() + dragAmount.y).toDp()
                                    windowWidth = newW.coerceIn(280.dp, 600.dp)
                                    windowHeight = newH.coerceIn(300.dp, 800.dp)
                                }
                            }
                        }
                )
            }
        }

        // ─── BOTTOM SHEET FOR SKIN PICKER ───
        if (showSheetForItem != null) {
            SkinPickerSheet(viewModel, showSheetForItem!!, onToast) { showSheetForItem = null }
        }
    }
}

// ───────────────────────────────────────────────────────────────────
// SKINS CONTENT — Accordion categories with dropdown pickers
// ───────────────────────────────────────────────────────────────────
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SkinsContent(viewModel: SkinViewModel, onToast: (String) -> Unit, onLongPress: (MatchedItem) -> Unit) {
    val uiState by viewModel.uiState.collectAsState()
    val cs = MaterialTheme.colorScheme

    when (uiState) {
        is SkinUiState.Loading -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = cs.primary)
            }
        }
        is SkinUiState.Error -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(16.dp)) {
                    Icon(Icons.Filled.ErrorOutline, contentDescription = null, tint = cs.error, modifier = Modifier.size(40.dp))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Shizuku not working", style = MaterialTheme.typography.bodyMedium, color = cs.error, textAlign = TextAlign.Center)
                    Spacer(modifier = Modifier.height(12.dp))
                    FilledTonalButton(onClick = { viewModel.loadData() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(6.dp))
                        Text("Retry")
                    }
                }
            }
        }
        is SkinUiState.Success -> {
            val state = uiState as SkinUiState.Success
            val expandedCats = remember { mutableStateMapOf<String, Boolean>() }

            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                state.itemsByCategory.forEach { (category, items) ->
                    // Category Header (Accordion)
                    item(key = "header_$category") {
                        val isExpanded = expandedCats[category] ?: true
                        Surface(
                            color = cs.surfaceContainerHighest,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth().clickable { expandedCats[category] = !isExpanded }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(category, style = MaterialTheme.typography.labelLarge, color = cs.primary, fontWeight = FontWeight.Bold)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("(${items.size})", style = MaterialTheme.typography.labelSmall, color = cs.onSurfaceVariant)
                                Spacer(modifier = Modifier.weight(1f))
                                Icon(
                                    if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                                    contentDescription = null,
                                    tint = cs.onSurfaceVariant,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    }

                    // Items under that category
                    val isExpanded = expandedCats[category] ?: true
                    if (isExpanded) {
                        items(items, key = { it.name }) { item ->
                            SkinItemRow(item, state.dumpMap, viewModel, onToast, onLongPress)
                        }
                    }
                }
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────
// SKIN ITEM ROW — Dropdown style
// ───────────────────────────────────────────────────────────────────
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SkinItemRow(
    item: MatchedItem,
    dumpMap: Map<String, String>,
    viewModel: SkinViewModel,
    onToast: (String) -> Unit,
    onLongPress: (MatchedItem) -> Unit
) {
    val cs = MaterialTheme.colorScheme
    val currentSkinId = item.skinIds.getOrNull(item.index) ?: ""
    val currentSkinName = dumpMap[currentSkinId] ?: currentSkinId
    var dropdownExpanded by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Item name
        Text(
            text = item.name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = cs.onSurface,
            modifier = Modifier.width(80.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Dropdown Selector
        Box(modifier = Modifier.weight(1f)) {
            Surface(
                color = cs.surfaceContainerHighest,
                shape = RoundedCornerShape(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(36.dp)
                    .clickable { dropdownExpanded = true }
            ) {
                Row(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = currentSkinName,
                        style = MaterialTheme.typography.bodySmall,
                        color = cs.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(Icons.Filled.UnfoldMore, contentDescription = null, tint = cs.onSurfaceVariant, modifier = Modifier.size(16.dp))
                }
            }

            DropdownMenu(
                expanded = dropdownExpanded,
                onDismissRequest = { dropdownExpanded = false },
                modifier = Modifier
                    .heightIn(max = 240.dp)
                    .widthIn(min = 180.dp)
            ) {
                item.skinIds.forEachIndexed { idx, skinId ->
                    val skinName = dumpMap[skinId] ?: skinId
                    val isSelected = idx == item.index
                    DropdownMenuItem(
                        text = {
                            Text(
                                skinName,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) cs.primary else cs.onSurface
                            )
                        },
                        onClick = {
                            viewModel.updateIndex(item, idx, onToast)
                            dropdownExpanded = false
                        },
                        leadingIcon = if (isSelected) {{ Icon(Icons.Filled.Check, contentDescription = null, tint = cs.primary, modifier = Modifier.size(16.dp)) }} else null
                    )
                }
            }
        }
    }
}

// ───────────────────────────────────────────────────────────────────
// SKIN PICKER BOTTOM SHEET (long-press)
// ───────────────────────────────────────────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SkinPickerSheet(
    viewModel: SkinViewModel,
    item: MatchedItem,
    onToast: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val cs = MaterialTheme.colorScheme
    val stateVal = viewModel.uiState.collectAsState().value
    if (stateVal !is SkinUiState.Success) { onDismiss(); return }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = cs.surfaceContainerLow
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            Text(item.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = cs.onSurface)
            Spacer(modifier = Modifier.height(4.dp))
            Text("${item.skinIds.size} skins available", style = MaterialTheme.typography.bodySmall, color = cs.onSurfaceVariant)
            Spacer(modifier = Modifier.height(12.dp))
        }
        LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
            items(item.skinIds.size) { idx ->
                val skinId = item.skinIds[idx]
                val skinName = stateVal.dumpMap[skinId] ?: skinId
                val isSelected = idx == item.index

                ListItem(
                    headlineContent = {
                        Text(
                            skinName,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            color = if (isSelected) cs.primary else cs.onSurface
                        )
                    },
                    leadingContent = if (isSelected) {{ Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = cs.primary) }} else null,
                    modifier = Modifier.clickable {
                        viewModel.updateIndex(item, idx, onToast)
                        onDismiss()
                    },
                    colors = ListItemDefaults.colors(containerColor = if (isSelected) cs.primaryContainer.copy(alpha = 0.3f) else Color.Transparent)
                )
            }
        }
        Spacer(modifier = Modifier.height(16.dp))
    }
}
