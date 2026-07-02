package com.floatingmenu.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.floatingmenu.app.data.CounterRepository
import com.floatingmenu.app.data.CounterState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CounterViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = CounterRepository(application)
    
    private val _uiState = MutableStateFlow(CounterState(0, 0))
    val uiState: StateFlow<CounterState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.getCountersFlow().collect { state ->
                _uiState.value = state
            }
        }
    }
}
