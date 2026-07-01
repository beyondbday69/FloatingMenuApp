package com.floatingmenu.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatingmenu.app.data.MatchedItem
import com.floatingmenu.app.data.SkinRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed class SkinUiState {
    object Loading : SkinUiState()
    data class Success(
        val itemsByCategory: Map<String, List<MatchedItem>>,
        val dumpMap: Map<String, String>
    ) : SkinUiState()
    data class Error(val message: String) : SkinUiState()
}

class SkinViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SkinRepository(application)
    
    private val _uiState = MutableStateFlow<SkinUiState>(SkinUiState.Loading)
    val uiState: StateFlow<SkinUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = SkinUiState.Loading
            try {
                val dumpMap = repository.loadDump()
                val parsedItems = repository.parseIni()
                
                if (parsedItems.isEmpty()) {
                    _uiState.value = SkinUiState.Error("SKINS.ini not found or empty.")
                    return@launch
                }

                // Restore indices from DataStore
                val updatedItems = parsedItems.map { item ->
                    val savedIndex = repository.getIndex(item.name)
                    if (savedIndex != 0) item.copy(index = savedIndex) else item
                }.filter { it.skinIds.size > 1 }
                
                val grouped = updatedItems.groupBy { it.category }
                
                _uiState.value = SkinUiState.Success(grouped, dumpMap)
            } catch (e: Exception) {
                _uiState.value = SkinUiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun updateIndex(item: MatchedItem, newIndex: Int, onComplete: (String) -> Unit) {
        viewModelScope.launch {
            try {
                repository.writeSelected(item.name, newIndex)
                repository.saveIndex(item.name, newIndex)
                
                val currentState = _uiState.value
                if (currentState is SkinUiState.Success) {
                    val skinId = item.skinIds.getOrNull(newIndex) ?: ""
                    val skinName = currentState.dumpMap[skinId] ?: "Unknown Skin"
                    onComplete(skinName)
                    
                    // Update state to reflect new index
                    val newGrouped = currentState.itemsByCategory.mapValues { entry ->
                        entry.value.map { if (it.name == item.name) it.copy(index = newIndex) else it }
                    }
                    _uiState.value = currentState.copy(itemsByCategory = newGrouped)
                }
            } catch (e: Exception) {
                onComplete("Error: ${e.message}")
            }
        }
    }
}
