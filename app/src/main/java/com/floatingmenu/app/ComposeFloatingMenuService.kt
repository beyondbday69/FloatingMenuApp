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
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.*
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.floatingmenu.app.data.MatchedItem
import com.floatingmenu.app.ui.SkinUiState
import com.floatingmenu.app.ui.SkinViewModel
import kotlinx.coroutines.launch

class ComposeFloatingMenuService : Service(), LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private lateinit var windowManager: WindowManager
    private lateinit var composeView: ComposeView
    private lateinit var params: WindowManager.LayoutParams

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    private lateinit var viewModel: SkinViewModel

    override fun onCreate() {
        super.onCreate()
        
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        
        viewModel = ViewModelProvider(this, ViewModelProvider.AndroidViewModelFactory.getInstance(application))[SkinViewModel::class.java]

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
            x = 0
            y = 100
        }

        composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(this@ComposeFloatingMenuService)
            setViewTreeViewModelStoreOwner(this@ComposeFloatingMenuService)
            setViewTreeSavedStateRegistryOwner(this@ComposeFloatingMenuService)
            
            setContent {
                MaterialTheme {
                    FloatingApp(
                        viewModel = viewModel,
                        onDrag = { dx, dy ->
                            params.x += dx.toInt()
                            params.y += dy.toInt()
                            windowManager.updateViewLayout(this, params)
                        },
                        onClose = {
                            stopSelf()
                        },
                        onToast = { msg ->
                            Toast.makeText(this@ComposeFloatingMenuService, msg, Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }
        }

        windowManager.addView(composeView, params)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        store.clear()
        if (::composeView.isInitialized) {
            windowManager.removeView(composeView)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = store
    override val savedStateRegistry: SavedStateRegistry get() = savedStateRegistryController.savedStateRegistry
}

@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun FloatingApp(viewModel: SkinViewModel, onDrag: (Float, Float) -> Unit, onClose: () -> Unit, onToast: (String) -> Unit) {
    var isExpanded by remember { mutableStateOf(true) }
    var showSheetForItem by remember { mutableStateOf<MatchedItem?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    
    // Window Open/Close Animation States
    var isVisible by remember { mutableStateOf(false) }
    var isClosing by remember { mutableStateOf(false) }
    
    LaunchedEffect(Unit) {
        isVisible = true
    }

    val windowScale by animateFloatAsState(
        targetValue = if (isClosing) 0.9f else if (isVisible) 1f else 0.9f,
        animationSpec = tween(durationMillis = if (isClosing) 150 else 200, easing = FastOutSlowInEasing),
        finishedListener = { if (isClosing) onClose() }
    )
    val windowAlpha by animateFloatAsState(
        targetValue = if (isClosing) 0f else if (isVisible) 1f else 0f,
        animationSpec = tween(durationMillis = if (isClosing) 150 else 200, easing = FastOutSlowInEasing)
    )

    // Resize Animation States
    var dragWidth by remember { mutableStateOf(320.dp) }
    var dragHeight by remember { mutableStateOf(450.dp) }
    var isResizing by remember { mutableStateOf(false) }
    
    // Load persisted window size
    LaunchedEffect(Unit) {
        val (w, h) = viewModel.getWindowSize()
        dragWidth = w.dp
        dragHeight = h.dp
    }

    val configuration = LocalConfiguration.current
    val maxW = (configuration.screenWidthDp * 0.9f).dp
    val maxH = (configuration.screenHeightDp * 0.85f).dp
    val minW = 240.dp
    val minH = 200.dp

    val animatedWidth by animateDpAsState(
        targetValue = if (isResizing) dragWidth else dragWidth.coerceIn(minW, maxW),
        animationSpec = if (isResizing) snap() else spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow)
    )
    
    val animatedHeight by animateDpAsState(
        targetValue = if (isResizing) dragHeight else dragHeight.coerceIn(minH, maxH),
        animationSpec = if (isResizing) snap() else spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessLow)
    )

    val accentPurple = Color(0xFFBB86FC)
    val bgDark = Color(0xFF121212)
    val headerDark = Color(0xFF1E1E1E)

    Box(
        modifier = Modifier
            .wrapContentSize()
            .graphicsLayer(alpha = windowAlpha, scaleX = windowScale, scaleY = windowScale)
            .animateContentSize(animationSpec = tween(250, easing = FastOutSlowInEasing))
    ) {
        AnimatedContent(
            targetState = isExpanded,
            transitionSpec = {
                fadeIn(tween(250)) togetherWith fadeOut(tween(250))
            }
        ) { expanded ->
            if (!expanded) {
                // Pill State
                Row(
                    modifier = Modifier
                        .width(100.dp)
                        .height(44.dp)
                        .background(headerDark, CircleShape)
                        .padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "⋮⋮",
                        color = Color.White,
                        modifier = Modifier.pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                onDrag(dragAmount.x, dragAmount.y)
                            }
                        }
                    )
                    Text("🔫", fontSize = 16.sp)
                    IconButton(onClick = { isExpanded = true }, modifier = Modifier.size(24.dp)) {
                        Text("[+]", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    }
                }
            } else {
                // Main Window
                Column(
                    modifier = Modifier
                        .width(animatedWidth)
                        .height(animatedHeight)
                        .clip(RoundedCornerShape(16.dp))
                        .background(bgDark)
                ) {
                    // Header
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp)
                            .background(headerDark)
                            .padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "⋮⋮",
                            color = Color.Gray,
                            modifier = Modifier
                                .padding(end = 12.dp)
                                .pointerInput(Unit) {
                                    detectDragGestures { change, dragAmount ->
                                        change.consume()
                                        onDrag(dragAmount.x, dragAmount.y)
                                    }
                                }
                        )
                        Text("Skin Menu", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                        
                        Row {
                            IconButton(onClick = { viewModel.loadData() }, modifier = Modifier.size(32.dp)) {
                                Text("⟳", color = Color.White, fontSize = 18.sp)
                            }
                            IconButton(onClick = { isExpanded = false }, modifier = Modifier.size(32.dp)) {
                                Text("–", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                            }
                            IconButton(onClick = { isClosing = true }, modifier = Modifier.size(32.dp)) {
                                Text("✕", color = Color.White, fontSize = 14.sp)
                            }
                        }
                    }

                    // Chips
                    val categories = listOf("All", "AR", "SMG", "Vehicles", "Cosmetics")
                    val moreCategories = listOf("X-Suits", "SR", "DMR", "Shotgun", "LMG", "Throwable", "Melee", "Other")
                    var activeChip by remember { mutableStateOf("All") }
                    var moreExpanded by remember { mutableStateOf(false) }

                    val isMoreActive = moreCategories.contains(activeChip)
                    val moreLabel = if (isMoreActive) activeChip else "More ▾"
                    
                    val allTabs = categories + moreLabel
                    val selectedTabIndex = if (isMoreActive) categories.size else categories.indexOf(activeChip).takeIf { it >= 0 } ?: 0

                    ScrollableTabRow(
                        selectedTabIndex = selectedTabIndex,
                        containerColor = bgDark,
                        contentColor = Color.White,
                        edgePadding = 12.dp,
                        modifier = Modifier.height(40.dp),
                        indicator = { tabPositions ->
                            if (selectedTabIndex < tabPositions.size) {
                                TabRowDefaults.Indicator(
                                    modifier = Modifier.tabIndicatorOffset(tabPositions[selectedTabIndex]),
                                    color = accentPurple,
                                    height = 2.dp
                                )
                            }
                        },
                        divider = {}
                    ) {
                        categories.forEachIndexed { index, cat ->
                            Tab(
                                selected = selectedTabIndex == index,
                                onClick = { activeChip = cat },
                                text = { Text(cat, color = if (selectedTabIndex == index) Color.White else Color.Gray, fontSize = 13.sp) }
                            )
                        }
                        
                        // "More" Dropdown Tab
                        Box {
                            Tab(
                                selected = selectedTabIndex == categories.size,
                                onClick = { moreExpanded = true },
                                text = { Text(moreLabel, color = if (selectedTabIndex == categories.size) Color.White else Color.Gray, fontSize = 13.sp) }
                            )
                            DropdownMenu(expanded = moreExpanded, onDismissRequest = { moreExpanded = false }) {
                                moreCategories.forEach { cat ->
                                    DropdownMenuItem(
                                        text = { Text(cat) },
                                        onClick = {
                                            activeChip = cat
                                            moreExpanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    Divider(color = Color(0xFF333333), thickness = 1.dp)

                    // List Area
                    val uiState by viewModel.uiState.collectAsState()
                    Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        when (uiState) {
                            is SkinUiState.Loading -> {
                                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = accentPurple)
                            }
                            is SkinUiState.Error -> {
                                Column(
                                    modifier = Modifier.align(Alignment.Center).padding(16.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text("⚠️", fontSize = 32.sp)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text("Couldn't load skins — check Shizuku access", color = Color.LightGray, fontSize = 14.sp)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    TextButton(onClick = { viewModel.loadData() }) {
                                        Text("Retry", color = accentPurple)
                                    }
                                }
                            }
                            is SkinUiState.Success -> {
                                val state = uiState as SkinUiState.Success
                                val allItems = state.itemsByCategory.values.flatten()
                                val displayItems = if (activeChip == "All") allItems else state.itemsByCategory[activeChip] ?: emptyList()

                                AnimatedContent(
                                    targetState = displayItems,
                                    transitionSpec = {
                                        fadeIn(tween(150)) togetherWith fadeOut(tween(150))
                                    }
                                ) { items ->
                                    if (items.isEmpty()) {
                                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                            Text("No items in this category", color = Color.Gray)
                                        }
                                    } else {
                                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                                            itemsIndexed(items) { index, item ->
                                                val currentSkinId = item.skinIds.getOrNull(item.index) ?: ""
                                                val currentSkinName = state.dumpMap[currentSkinId] ?: currentSkinId
                                                
                                                Row(
                                                    modifier = Modifier
                                                        .fillMaxWidth()
                                                        .height(52.dp)
                                                        .padding(horizontal = 8.dp),
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    IconButton(
                                                        onClick = {
                                                            val newIdx = (item.index - 1 + item.skinIds.size) % item.skinIds.size
                                                            viewModel.updateIndex(item, newIdx, onToast)
                                                        },
                                                        modifier = Modifier.size(44.dp)
                                                    ) {
                                                        Text("◀", color = Color.White)
                                                    }
                                                    
                                                    Row(
                                                        modifier = Modifier
                                                            .weight(1f)
                                                            .combinedClickable(
                                                                onClick = {},
                                                                onLongClick = { showSheetForItem = item }
                                                            )
                                                            .padding(horizontal = 4.dp),
                                                        horizontalArrangement = Arrangement.Center,
                                                        verticalAlignment = Alignment.CenterVertically
                                                    ) {
                                                        Text(item.name, color = Color.White, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                                        Text(" — ", color = Color.Gray)
                                                        AnimatedContent(
                                                            targetState = currentSkinName,
                                                            transitionSpec = {
                                                                fadeIn(tween(150)) togetherWith fadeOut(tween(150))
                                                            }
                                                        ) { name ->
                                                            Text(name, color = Color.Gray, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                                        }
                                                    }
                                                    
                                                    IconButton(
                                                        onClick = {
                                                            val newIdx = (item.index + 1) % item.skinIds.size
                                                            viewModel.updateIndex(item, newIdx, onToast)
                                                        },
                                                        modifier = Modifier.size(44.dp)
                                                    ) {
                                                        Text("▶", color = Color.White)
                                                    }
                                                }
                                                
                                                if (index < items.size - 1) {
                                                    Divider(color = Color(0xFF222222), thickness = 1.dp, modifier = Modifier.padding(horizontal = 16.dp))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Resize handle overlay
                        Text(
                            text = "⇲",
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 18.sp,
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .size(24.dp)
                                .pointerInput(Unit) {
                                    detectDragGestures(
                                        onDragStart = { isResizing = true },
                                        onDragEnd = {
                                            isResizing = false
                                            dragWidth = dragWidth.coerceIn(minW, maxW)
                                            dragHeight = dragHeight.coerceIn(minH, maxH)
                                            viewModel.saveWindowSize(dragWidth.value.toInt(), dragHeight.value.toInt())
                                        }
                                    ) { change, dragAmount ->
                                        change.consume()
                                        val density = configuration.densityDpi / 160f
                                        dragWidth += (dragAmount.x / density).dp
                                        dragHeight += (dragAmount.y / density).dp
                                    }
                                }
                                .padding(end = 4.dp, bottom = 4.dp)
                        )
                    }
                }
            }
        }

        // Bottom Sheet handling
        if (showSheetForItem != null) {
            val item = showSheetForItem!!
            val stateVal = viewModel.uiState.collectAsState().value
            if (stateVal is SkinUiState.Success) {
                ModalBottomSheet(
                    onDismissRequest = { showSheetForItem = null },
                    sheetState = sheetState
                ) {
                    LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp)) {
                        items(item.skinIds.size) { idx ->
                            val skinId = item.skinIds[idx]
                            val skinName = stateVal.dumpMap[skinId] ?: skinId
                            val isSelected = idx == item.index
                            
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(if (isSelected) Color(0xFFE0E0FF) else Color.Transparent)
                                    .clickable {
                                        viewModel.updateIndex(item, idx, onToast)
                                        showSheetForItem = null
                                    }
                                    .padding(16.dp)
                            ) {
                                Text(
                                    text = skinName,
                                    color = if (isSelected) Color(0xFF0000AA) else Color.Black,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
