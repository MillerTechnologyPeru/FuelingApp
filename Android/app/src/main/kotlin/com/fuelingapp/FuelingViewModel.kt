package com.fuelingapp

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fuelingapp.jni.FuelingSession
import com.fuelingapp.jni.LocationDetailScreen
import com.fuelingapp.jni.LocationsScreen
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.swift.swiftkit.core.ClosableSwiftArena
import org.swift.swiftkit.core.SwiftArena

/** One row in the Locations list, flattened from [LocationsScreen]'s index-based JNI getters. */
data class LocationRow(
    val index: Long,
    val id: Long,
    val name: String,
    val address: String,
    val distance: String,
)

/** A fuel product row on the Location Detail screen, e.g. "Diesel" / "$3.899". */
data class FuelProductRow(
    val name: String,
    val price: String,
)

/** Detail for one location, flattened from [LocationDetailScreen]'s JNI getters. */
data class LocationDetailUiState(
    val locationId: Long,
    val isLoading: Boolean = true,
    val error: String? = null,
    val name: String = "",
    val address: String = "",
    val distance: String = "",
    val fuelLanes: Long = 0,
    val showerCount: Long = 0,
    val truckParkingSpaces: Long = 0,
    val fuelOptions: List<String> = emptyList(),
    val fuelProducts: List<FuelProductRow> = emptyList(),
)

data class FuelingUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val searchText: String = "",
    val locations: List<LocationRow> = emptyList(),
    val selectedLocation: LocationDetailUiState? = null,
)

/**
 * Drives the shared Swift `Store` and `LocationsViewModel` through the
 * swift-java (JNI) bindings and exposes the result as a [StateFlow] for
 * Compose to collect.
 *
 * There is no push notification across the JNI boundary, so this polls the
 * view model on a fixed interval and republishes a new [FuelingUiState]
 * whenever the observed values change. All JNI calls run on the main thread
 * (`viewModelScope`'s default dispatcher), matching the wrapper's
 * `MainActor.assumeIsolated` contract.
 */
class FuelingViewModel : ViewModel() {

    private companion object {
        const val POLL_INTERVAL_MS = 300L
    }

    private val _uiState = MutableStateFlow(FuelingUiState())
    val uiState: StateFlow<FuelingUiState> = _uiState.asStateFlow()

    private var arena: ClosableSwiftArena? = null
    private var session: FuelingSession? = null
    private var screen: LocationsScreen? = null
    private var pollJob: Job? = null

    private var detailScreen: LocationDetailScreen? = null
    private var detailPollJob: Job? = null

    /** Idempotent: safe to call from `LaunchedEffect(Unit)` across recompositions. */
    fun start(documentsPath: String) {
        if (pollJob != null) return

        val arena = SwiftArena.ofConfined()
        this.arena = arena
        pollJob = viewModelScope.launch {
            try {
                val session = FuelingSession.init(documentsPath, arena)
                this@FuelingViewModel.session = session
                session.seedSampleLocations()
                val screen = session.makeLocationsScreen(arena)
                this@FuelingViewModel.screen = screen
                screen.reload()

                while (isActive) {
                    poll(screen)
                    delay(POLL_INTERVAL_MS)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.toString()) }
            }
        }
    }

    /** Re-reads every row from Swift; called on a timer. */
    private fun poll(screen: LocationsScreen) {
        val count = screen.locationCount()
        val locations = (0 until count).map { index ->
            LocationRow(
                index = index,
                id = screen.locationId(index),
                name = screen.locationName(index),
                address = screen.locationAddress(index),
                distance = screen.locationDistance(index),
            )
        }
        _uiState.update {
            it.copy(
                isLoading = screen.isLoading(),
                error = screen.errorMessage().ifEmpty { null },
                locations = locations,
            )
        }
    }

    /** Update the search text filter; the next poll picks up the filtered results. */
    fun setSearchText(text: String) {
        val screen = screen ?: return
        _uiState.update { it.copy(searchText = text) }
        screen.setSearchText(text)
    }

    /** Show the Location Detail screen for [locationId]. Idempotent while already showing that location. */
    fun selectLocation(locationId: Long) {
        val session = session ?: return
        val arena = arena ?: return
        if (detailScreen != null && _uiState.value.selectedLocation?.locationId == locationId) return

        detailPollJob?.cancel()
        _uiState.update { it.copy(selectedLocation = LocationDetailUiState(locationId = locationId)) }

        val screen = session.makeLocationDetailScreen(locationId, arena)
        detailScreen = screen
        screen.onAppear()
        detailPollJob = viewModelScope.launch {
            try {
                while (isActive) {
                    pollDetail(screen)
                    delay(POLL_INTERVAL_MS)
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(selectedLocation = it.selectedLocation?.copy(isLoading = false, error = e.toString()))
                }
            }
        }
    }

    /** Re-reads the selected location's detail from Swift; called on a timer. */
    private fun pollDetail(screen: LocationDetailScreen) {
        val fuelOptions = (0 until screen.fuelOptionCount()).map { screen.fuelOption(it) }
        val fuelProducts = (0 until screen.fuelProductCount()).map {
            FuelProductRow(name = screen.fuelProductName(it), price = screen.fuelProductPrice(it))
        }
        _uiState.update { state ->
            val locationId = state.selectedLocation?.locationId ?: return@update state
            state.copy(
                selectedLocation = LocationDetailUiState(
                    locationId = locationId,
                    isLoading = screen.isLoading(),
                    error = screen.errorMessage().ifEmpty { null },
                    name = screen.locationName(),
                    address = screen.locationAddress(),
                    distance = screen.distance(),
                    fuelLanes = screen.fuelLanes(),
                    showerCount = screen.showerCount(),
                    truckParkingSpaces = screen.truckParkingSpaces(),
                    fuelOptions = fuelOptions,
                    fuelProducts = fuelProducts,
                ),
            )
        }
    }

    /** Dismiss the Location Detail screen and return to the list. */
    fun deselectLocation() {
        detailPollJob?.cancel()
        detailPollJob = null
        detailScreen?.onDisappear()
        detailScreen = null
        _uiState.update { it.copy(selectedLocation = null) }
    }

    override fun onCleared() {
        super.onCleared()
        pollJob?.cancel()
        detailPollJob?.cancel()
        arena?.close()
    }
}
