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
                    MaterialTheme(
                        colorScheme = darkColorScheme(
                            primary = cs2Primary,
                            surface = cs2Surface,
                            background = cs2Background,
                            onSurface = cs2Text,
                            onSurfaceVariant = Color.Gray,
                            surfaceContainer = cs2Background,
                            surfaceContainerHigh = cs2Surface,
                            outlineVariant = Color(0xFF3A3A3A)
                        )
                    ) {
                        Surface(
                            color = cs2Background.copy(alpha = 0.9f),
                            shape = RoundedCornerShape(2.dp),
                            border = BorderStroke(1.dp, Color(0xFF3A3A3A)),
                            modifier = Modifier.padding(4.dp)
                        ) {
                            Column {
                                // Header
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth(0.5f)
                                        .background(cs2TitleBar)
                                        .padding(horizontal = 4.dp, vertical = 2.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text("ESP INFO", style = MaterialTheme.typography.labelSmall, color = cs2Text, fontSize = 9.sp)
                                }
                                Row(
                                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text("PLAYER", style = MaterialTheme.typography.labelSmall, color = cs2Primary, fontSize = 10.sp)
                                        Text(
                                            "${counterState.playerCount}", 
                                            style = MaterialTheme.typography.titleMedium, 
                                            color = if (counterState.playerCount > 0) Color.Red else cs2Text,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
                                    Box(modifier = Modifier.width(1.dp).height(24.dp).background(Color(0xFF3A3A3A)))
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text("BOT", style = MaterialTheme.typography.labelSmall, color = Color(0xFFFFA500), fontSize = 10.sp)
                                        Text(
                                            "${counterState.botCount}", 
                                            style = MaterialTheme.typography.titleMedium, 
                                            color = if (counterState.botCount > 0) Color(0xFFFFA500) else cs2Text,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }
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
// CS2 IMGUI THEME COLORS
// ───────────────────────────────────────────────────────────────────
val cs2Background = Color(0xFF1E1E1E)
val cs2TitleBar = Color(0xFF2D2D2D)
val cs2Primary = Color(0xFF3E79BD)
val cs2Surface = Color(0xFF252526)
val cs2Text = Color(0xFFE0E0E0)

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
    
    var windowWidth by remember { mutableStateOf(380.dp) }
    var windowHeight by remember { mutableStateOf(420.dp) }
    val density = androidx.compose.ui.platform.LocalDensity.current

    LaunchedEffect(Unit) {
        val (w, h) = viewModel.getWindowSize()
        windowWidth = w.dp
        windowHeight = h.dp
    }

    Box(modifier = Modifier.wrapContentSize()) {
        if (!isExpanded) {
            // ─── FAB SQUARE ───
            Surface(
                onClick = { isExpanded = true },
                color = cs2Primary,
                contentColor = Color.White,
                shape = RoundedCornerShape(4.dp),
                modifier = Modifier
                    .size(48.dp)
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount.x, dragAmount.y)
                        }
                    }
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Menu, contentDescription = "Open", modifier = Modifier.size(24.dp))
                }
            }
        } else {
            // ─── MAIN CS2 IMGUI WINDOW ───
            Card(
                modifier = Modifier.width(windowWidth).height(windowHeight),
                shape = RoundedCornerShape(0.dp),
                colors = CardDefaults.cardColors(containerColor = cs2Background),
                border = BorderStroke(1.dp, Color(0xFF3A3A3A)),
                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
            ) {
                Box(modifier = Modifier.fillMaxSize()) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        // ─── TITLE BAR ───
                        Surface(
                            color = cs2TitleBar,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(32.dp)
                                    .pointerInput(Unit) {
                                        detectDragGestures { change, dragAmount ->
                                            change.consume()
                                            onDrag(dragAmount.x, dragAmount.y)
                                        }
                                    }
                                    .padding(horizontal = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("CS2 Cheat Menu", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = cs2Text)
                                Spacer(modifier = Modifier.weight(1f))
                                IconButton(onClick = { isExpanded = false }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Filled.Remove, contentDescription = "Minimize", tint = cs2Text, modifier = Modifier.size(16.dp))
                                }
                                Spacer(modifier = Modifier.width(4.dp))
                                IconButton(onClick = { onClose() }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = cs2Text, modifier = Modifier.size(16.dp))
                                }
                            }
                        }

                        // ─── TABS BAR ───
                        Surface(
                            color = cs2Background,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 4.dp, vertical = 4.dp)
                                    .background(cs2Surface, RoundedCornerShape(2.dp))
                            ) {
                                tabs.forEachIndexed { index, tab ->
                                    val isSelected = selectedTab == index
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clickable { selectedTab = index }
                                            .background(if (isSelected) cs2Primary else Color.Transparent, RoundedCornerShape(2.dp))
                                            .padding(vertical = 6.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            tab.label,
                                            fontSize = 11.sp,
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                            color = if (isSelected) Color.White else Color.Gray
                                        )
                                    }
                                }
                            }
                        }
                        Divider(color = Color(0xFF3A3A3A), thickness = 1.dp)

                        // ─── CONTENT AREA ───
                        Box(modifier = Modifier.weight(1f).fillMaxWidth().padding(4.dp)) {
                            // Provide our custom colors down the tree using CompositionLocal or just wrapping MaterialTheme
                            MaterialTheme(
                                colorScheme = darkColorScheme(
                                    primary = cs2Primary,
                                    surface = cs2Surface,
                                    background = cs2Background,
                                    onSurface = cs2Text,
                                    onSurfaceVariant = Color.Gray,
                                    surfaceContainer = cs2Background,
                                    surfaceContainerHigh = cs2Surface,
                                    surfaceContainerHighest = Color(0xFF303030),
                                    outlineVariant = Color(0xFF3A3A3A)
                                )
                            ) {
                                val currentTab = tabs[selectedTab]
                                when (currentTab.label) {
                                    "ESP" -> SukunaContent(sukunaViewModel, "ESP")
                                    "LOOT" -> SukunaContent(sukunaViewModel, "LOOT")
                                    "VISUALS" -> SukunaContent(sukunaViewModel, "VISUALS")
                                    "MISC" -> SukunaContent(sukunaViewModel, "MISC")
                                    "SKINS" -> SkinsContent(viewModel, onToast) { showSheetForItem = it }
                                }
                            }
                        }
                    }

                    // ─── RESIZE HANDLE ───
                    Icon(
                        imageVector = Icons.Filled.OpenInFull,
                        contentDescription = "Resize",
                        tint = Color.Gray.copy(alpha = 0.5f),
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(bottom = 8.dp, end = 8.dp)
                            .size(16.dp)
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
                    FilledTonalButton(onClick = { viewModel.loadData() }, shape = RoundedCornerShape(2.dp)) {
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
                modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                state.itemsByCategory.forEach { (category, items) ->
                    // Category Header (Accordion)
                    item(key = "header_$category") {
                        val isExpanded = expandedCats[category] ?: true
                        Surface(
                            color = cs.surfaceContainerHighest,
                            shape = RoundedCornerShape(2.dp),
                            modifier = Modifier.fillMaxWidth().clickable { expandedCats[category] = !isExpanded }
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(category, style = MaterialTheme.typography.labelMedium, color = cs.primary, fontWeight = FontWeight.SemiBold)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("(${items.size})", style = MaterialTheme.typography.labelSmall, color = cs.onSurfaceVariant)
                                Spacer(modifier = Modifier.weight(1f))
                                Icon(
                                    if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                                    contentDescription = null,
                                    tint = cs.onSurfaceVariant,
                                    modifier = Modifier.size(16.dp)
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
    var expanded by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Item name
        Text(
            text = item.name,
            style = MaterialTheme.typography.bodySmall,
            color = cs.onSurface,
            modifier = Modifier.width(90.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(modifier = Modifier.width(4.dp))

        // Lightweight Dropdown Selector
        Box(modifier = Modifier.weight(1f)) {
            Surface(
                color = cs.surfaceContainerHighest,
                shape = RoundedCornerShape(2.dp),
                border = BorderStroke(1.dp, cs.outlineVariant),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(28.dp)
                    .clickable { expanded = true }
            ) {
                Row(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 8.dp),
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
                    Icon(Icons.Filled.ArrowDropDown, contentDescription = null, tint = cs.onSurfaceVariant, modifier = Modifier.size(16.dp))
                }
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                modifier = Modifier
                    .background(cs.surfaceContainerHighest)
                    .border(1.dp, cs.outlineVariant, RoundedCornerShape(2.dp))
                    .heightIn(max = 200.dp)
            ) {
                item.skinIds.forEachIndexed { idx, skinId ->
                    val skinName = dumpMap[skinId] ?: skinId
                    val isSelected = idx == item.index
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = skinName,
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) cs.primary else cs.onSurface
                            )
                        },
                        onClick = {
                            viewModel.updateIndex(item, idx, onToast)
                            expanded = false
                        },
                        trailingIcon = if (isSelected) {
                            { Icon(Icons.Filled.Check, contentDescription = null, tint = cs.primary, modifier = Modifier.size(16.dp)) }
                        } else null
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
