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
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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
import com.floatingmenu.app.ui.ModRed
import com.floatingmenu.app.ui.ModText
import com.floatingmenu.app.ui.SkinUiState
import com.floatingmenu.app.ui.SkinViewModel
import com.floatingmenu.app.ui.SukunaContent
import com.floatingmenu.app.ui.SukunaViewModel
import kotlinx.coroutines.launch

class ComposeFloatingMenuService : Service(), LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private lateinit var windowManager: WindowManager
    private lateinit var composeView: ComposeView
    private lateinit var params: WindowManager.LayoutParams

    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateRegistryController = SavedStateRegistryController.create(this)
    private lateinit var viewModel: SkinViewModel
    private lateinit var sukunaViewModel: SukunaViewModel

    override fun onCreate() {
        super.onCreate()
        
        savedStateRegistryController.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
        
        val factory = ViewModelProvider.AndroidViewModelFactory.getInstance(application)
        viewModel = ViewModelProvider(this, factory)[SkinViewModel::class.java]
        sukunaViewModel = ViewModelProvider(this, factory)[SukunaViewModel::class.java]

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
                        sukunaViewModel = sukunaViewModel,
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
fun FloatingApp(viewModel: SkinViewModel, sukunaViewModel: SukunaViewModel, onDrag: (Float, Float) -> Unit, onClose: () -> Unit, onToast: (String) -> Unit) {
    var isExpanded by remember { mutableStateOf(false) } // Start minimized
    var currentTab by remember { mutableStateOf("ESP") }
    var showSheetForItem by remember { mutableStateOf<MatchedItem?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    
    val configuration = LocalConfiguration.current
    
    Box(modifier = Modifier.wrapContentSize()) {
        if (!isExpanded) {
            // Floating Icon (Classic Mod Menu style)
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(Color(0xFF111111), CircleShape)
                    .border(2.dp, ModRed, CircleShape)
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount.x, dragAmount.y)
                        }
                    }
                    .clickable { isExpanded = true },
                contentAlignment = Alignment.Center
            ) {
                Text("💀", fontSize = 24.sp)
            }
        } else {
            // Main Mod Menu Frame
            Column(
                modifier = Modifier
                    .width(320.dp)
                    .height(300.dp)
                    .background(Color(0xEE111111))
                    .border(1.dp, ModRed)
            ) {
                // Header
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(35.dp)
                        .background(Color(0xFF000000))
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                onDrag(dragAmount.x, dragAmount.y)
                            }
                        },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("  SUKUNA MOD v1", color = ModRed, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Spacer(modifier = Modifier.weight(1f))
                    Text("[HIDE]", color = Color.White, fontSize = 12.sp, modifier = Modifier.clickable { isExpanded = false }.padding(horizontal = 8.dp))
                    Text("[X]", color = Color.Gray, fontSize = 12.sp, modifier = Modifier.clickable { onClose() }.padding(end = 8.dp))
                }
                
                // Body Sidebar + Content
                Row(modifier = Modifier.fillMaxSize()) {
                    // Sidebar
                    Column(modifier = Modifier.width(90.dp).fillMaxHeight().background(Color(0xFF1A1A1A))) {
                        val tabs = listOf("ESP", "LOOT", "VISUALS", "MISC", "SKINS")
                        tabs.forEach { tab ->
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(40.dp)
                                    .background(if (currentTab == tab) Color(0xFF331111) else Color.Transparent)
                                    .clickable { currentTab = tab },
                                contentAlignment = Alignment.CenterStart
                            ) {
                                Text("  " + tab, color = if (currentTab == tab) ModRed else Color.Gray, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                    
                    // Vertical divider
                    Box(modifier = Modifier.width(1.dp).fillMaxHeight().background(Color(0xFF333333)))
                    
                    // Content
                    Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
                        when (currentTab) {
                            "ESP" -> SukunaContent(sukunaViewModel, "ESP")
                            "LOOT" -> SukunaContent(sukunaViewModel, "LOOT")
                            "VISUALS" -> SukunaContent(sukunaViewModel, "VISUALS")
                            "MISC" -> SukunaContent(sukunaViewModel, "MISC")
                            "SKINS" -> {
                                val uiState by viewModel.uiState.collectAsState()
                                when (uiState) {
                                    is SkinUiState.Loading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = ModRed)
                                    is SkinUiState.Error -> Text("Error loading skins", color = ModRed, modifier = Modifier.align(Alignment.Center))
                                    is SkinUiState.Success -> {
                                        val state = uiState as SkinUiState.Success
                                        val allItems = state.itemsByCategory.values.flatten()
                                        LazyColumn(modifier = Modifier.fillMaxSize().padding(8.dp)) {
                                            itemsIndexed(allItems) { _, item ->
                                                val currentSkinId = item.skinIds.getOrNull(item.index) ?: ""
                                                val currentSkinName = state.dumpMap[currentSkinId] ?: currentSkinId
                                                
                                                Row(
                                                    modifier = Modifier
                                                        .fillMaxWidth()
                                                        .height(40.dp),
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Text(
                                                        text = "<",
                                                        color = ModRed,
                                                        fontWeight = FontWeight.Bold,
                                                        modifier = Modifier.clickable {
                                                            val newIdx = (item.index - 1 + item.skinIds.size) % item.skinIds.size
                                                            viewModel.updateIndex(item, newIdx, onToast)
                                                        }.padding(4.dp)
                                                    )
                                                    
                                                    Column(
                                                        modifier = Modifier.weight(1f).combinedClickable(
                                                            onClick = {},
                                                            onLongClick = { showSheetForItem = item }
                                                        ),
                                                        horizontalAlignment = Alignment.CenterHorizontally
                                                    ) {
                                                        Text(item.name, color = ModText, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                                        Text(currentSkinName, color = Color.Gray, fontSize = 9.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                                    }
                                                    
                                                    Text(
                                                        text = ">",
                                                        color = ModRed,
                                                        fontWeight = FontWeight.Bold,
                                                        modifier = Modifier.clickable {
                                                            val newIdx = (item.index + 1) % item.skinIds.size
                                                            viewModel.updateIndex(item, newIdx, onToast)
                                                        }.padding(4.dp)
                                                    )
                                                }
                                                Divider(color = Color(0xFF222222), thickness = 1.dp)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Skin List Bottom Sheet (kept purely for long-press skin selection)
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
                                    .background(if (isSelected) Color(0xFF331111) else Color.Transparent)
                                    .clickable {
                                        viewModel.updateIndex(item, idx, onToast)
                                        showSheetForItem = null
                                    }
                                    .padding(16.dp)
                            ) {
                                Text(
                                    text = skinName,
                                    color = if (isSelected) ModRed else Color.Black,
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
