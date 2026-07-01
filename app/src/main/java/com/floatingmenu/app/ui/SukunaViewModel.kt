package com.floatingmenu.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatingmenu.app.data.SukunaRepository
import com.floatingmenu.app.data.SukunaState
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SukunaViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = SukunaRepository(application)
    
    private val _uiState = MutableStateFlow(SukunaState())
    val uiState: StateFlow<SukunaState> = _uiState.asStateFlow()
    
    private var debounceJob: Job? = null

    init {
        loadData()
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = repository.loadConfig()
        }
    }

    fun updateState(modifier: (SukunaState) -> SukunaState) {
        val newState = modifier(_uiState.value)
        _uiState.value = newState
        
        debounceJob?.cancel()
        debounceJob = viewModelScope.launch {
            delay(200) // Debounce rapid toggles
            try {
                repository.saveConfig(newState)
            } catch (e: Exception) {
                // In a real app we might show a toast, but for now silently fail/log
            }
        }
    }
}
