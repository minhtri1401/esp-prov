/// Bluetooth LE transport for `esp_prov_core`, built on `universal_ble`.
library;

export 'src/endpoint_discovery.dart'
    show
        EndpointMap,
        characteristicUuidFor,
        discoverEndpoints,
        endpointIdOf,
        fallbackEndpointNames;
