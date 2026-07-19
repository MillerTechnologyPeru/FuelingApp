package com.fuelingapp

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

/**
 * Fueling Android entry point.
 *
 * Renders [FuelingViewModel]'s [FuelingUiState] — sourced from the shared
 * Swift `Store`/`LocationsViewModel` over the swift-java JNI bindings — as a
 * Compose list, one row per location.
 */
class MainActivity : ComponentActivity() {

    private val viewModel: FuelingViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    // Content draws edge-to-edge by default on API 35+ (and can't opt
                    // out via the manifest anymore) — without this padding, the title
                    // and back button drew underneath the status bar's clock/icons.
                    Box(modifier = Modifier.windowInsetsPadding(WindowInsets.safeDrawing)) {
                        FuelingScreen(viewModel, documentsPath = filesDir.absolutePath)
                    }
                }
            }
        }
    }
}

@Composable
fun FuelingScreen(viewModel: FuelingViewModel, documentsPath: String) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.start(documentsPath)
    }

    val selectedLocation = state.selectedLocation
    if (selectedLocation != null) {
        BackHandler(onBack = viewModel::deselectLocation)
        LocationDetailScreenView(state = selectedLocation, onBack = viewModel::deselectLocation)
        return
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Fueling — Swift model over JNI", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = state.searchText,
                onValueChange = viewModel::setSearchText,
                label = { Text("Search") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            state.error?.let { error ->
                Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
        }

        if (state.isLoading && state.locations.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else {
            LocationsList(locations = state.locations, onSelectLocation = viewModel::selectLocation)
        }
    }
}

@Composable
fun LocationsList(locations: List<LocationRow>, onSelectLocation: (Long) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(vertical = 8.dp)) {
        items(locations, key = { it.id }) { location ->
            LocationRowView(location = location, onClick = { onSelectLocation(location.id) })
            HorizontalDivider()
        }
    }
}

@Composable
fun LocationRowView(location: LocationRow, onClick: () -> Unit = {}) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Text(location.name, style = MaterialTheme.typography.titleMedium)
        Text(location.address, style = MaterialTheme.typography.bodyMedium)
        if (location.distance.isNotEmpty()) {
            Text(location.distance, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun LocationDetailScreenView(state: LocationDetailUiState, onBack: () -> Unit) {
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = onBack) {
                Text("← Back")
            }
        }

        if (state.isLoading && state.name.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            Text(state.name, style = MaterialTheme.typography.headlineSmall)
            Text(state.address, style = MaterialTheme.typography.bodyMedium)
            if (state.distance.isNotEmpty()) {
                Text(state.distance, style = MaterialTheme.typography.bodySmall)
            }
            state.error?.let { error ->
                Text(error, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Text("Fuel lanes: ${state.fuelLanes}", style = MaterialTheme.typography.bodyMedium)
            Text("Showers: ${state.showerCount}", style = MaterialTheme.typography.bodyMedium)
            Text("Truck parking spaces: ${state.truckParkingSpaces}", style = MaterialTheme.typography.bodyMedium)

            if (state.fuelProducts.isNotEmpty()) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                Text("Fuel Prices", style = MaterialTheme.typography.titleMedium)
                state.fuelProducts.forEach { product ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(product.name, style = MaterialTheme.typography.bodyMedium)
                        Text(product.price, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            if (state.fuelOptions.isNotEmpty()) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                Text("Fueling Options", style = MaterialTheme.typography.titleMedium)
                state.fuelOptions.forEach { option ->
                    Text("• $option", style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun LocationRowPreview() {
    MaterialTheme {
        LocationRowView(
            location = LocationRow(
                index = 0,
                id = 15,
                name = "Seville Travel Center",
                address = "8834 Lake Road, Seville, Ohio 44273",
                distance = "12 mi",
            ),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun LocationDetailScreenPreview() {
    MaterialTheme {
        LocationDetailScreenView(
            state = LocationDetailUiState(
                locationId = 15,
                isLoading = false,
                name = "Seville Travel Center",
                address = "8834 Lake Road\nSeville, Ohio 44273",
                distance = "12 mi",
                fuelLanes = 9,
                showerCount = 10,
                truckParkingSpaces = 237,
                fuelProducts = listOf(FuelProductRow("Diesel", "$3.899")),
                fuelOptions = listOf("Diesel", "Auto Diesel", "DEF Island Fueling"),
            ),
            onBack = {},
        )
    }
}
