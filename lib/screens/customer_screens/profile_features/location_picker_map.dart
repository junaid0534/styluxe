import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerMap extends StatefulWidget {
  final LatLng initialPosition;

  const LocationPickerMap({super.key, required this.initialPosition});

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late GoogleMapController mapController;
  LatLng? selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          TextButton(
            onPressed: () {
              if (selectedLocation != null) {
                Navigator.pop(context, selectedLocation);
              }
            },
            child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialPosition,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          mapController = controller;
        },
        onTap: (LatLng position) {
          setState(() => selectedLocation = position);
        },
        markers: selectedLocation != null
            ? {
                Marker(
                  markerId: const MarkerId("selected"),
                  position: selectedLocation!,
                ),
              }
            : {},
      ),
    );
  }
}