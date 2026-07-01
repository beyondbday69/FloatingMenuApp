package com.floatingmenu.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
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
    var isExpanded by remember { mutableStateOf(false) }
    var showSheetForItem by remember { mutableStateOf<MatchedItem?>(null) }
    val sheetState = rememberModalBottomSheetState()

    Box(modifier = Modifier.wrapContentSize()) {
        if (!isExpanded) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .background(Color.DarkGray, CircleShape)
                    .pointerInput(Unit) {
                        detectDragGestures { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount.x, dragAmount.y)
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                IconButton(
                    onClick = { isExpanded = true },
                    modifier = Modifier.fillMaxSize()
                ) {
                    Text("M", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .width(320.dp)
                    .heightIn(max = 500.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF1E1E1E))
            ) {
                // Header
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF333333))
                        .pointerInput(Unit) {
                            detectDragGestures { change, dragAmount ->
                                change.consume()
                                onDrag(dragAmount.x, dragAmount.y)
                            }
                        }
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Skin Mod Menu", color = Color.White, fontWeight = FontWeight.Bold)
                    Row {
                        Button(onClick = { viewModel.loadData() }) {
                            Text("R")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(onClick = { isExpanded = false }) {
                            Text("X")
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(onClick = onClose) {
                            Text("Q")
                        }
                    }
                }

                val uiState by viewModel.uiState.collectAsState()

                when (uiState) {
                    is SkinUiState.Loading -> {
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    }
                    is SkinUiState.Error -> {
                        Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
                            Text((uiState as SkinUiState.Error).message, color = Color.Red)
                        }
                    }
                    is SkinUiState.Success -> {
                        val state = uiState as SkinUiState.Success
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            state.itemsByCategory.forEach { (category, items) ->
                                item {
                                    Text(
                                        text = category,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .background(Color(0xFF444444))
                                            .padding(8.dp),
                                        color = Color.White,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                                items(items) { item ->
                                    val currentSkinId = item.skinIds.getOrNull(item.index) ?: ""
                                    val currentSkinName = state.dumpMap[currentSkinId] ?: currentSkinId
                                    
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .combinedClickable(
                                                onClick = {},
                                                onLongClick = { showSheetForItem = item }
                                            )
                                            .padding(vertical = 12.dp, horizontal = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Button(onClick = {
                                            val newIdx = (item.index - 1 + item.skinIds.size) % item.skinIds.size
                                            viewModel.updateIndex(item, newIdx, onToast)
                                        }) { Text("<") }
                                        
                                        Column(
                                            horizontalAlignment = Alignment.CenterHorizontally,
                                            modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
                                        ) {
                                            Text(item.name, color = Color.White, fontWeight = FontWeight.Bold)
                                            Text(currentSkinName, color = Color.Gray, fontSize = 12.sp)
                                        }
                                        
                                        Button(onClick = {
                                            val newIdx = (item.index + 1) % item.skinIds.size
                                            viewModel.updateIndex(item, newIdx, onToast)
                                        }) { Text(">") }
                                    }
                                }
                            }
                        }
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
