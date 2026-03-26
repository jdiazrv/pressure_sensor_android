# WaterMaker — Pressure Sensor Remote

Flutter app (Android / iOS / macOS) para monitorización en tiempo real del sistema de presión del WaterMaker basado en ESP32 + ADS1115.

## Funcionalidad

- **Telemetría en tiempo real** por UDP broadcast (presión, voltaje)
- **Fallback HTTP** automático cuando no llega paquete UDP (`/api/state` cada 1 s mientras no haya telemetría UDP)
- **Dos sensores de presión**:
  - Presión de entrada (0–4 bar) con zonas WARNING / NORMAL / ALARM
  - Presión principal (0–70 bar) con zonas WARNING / NORMAL / ALARM
- **Voltaje por sensor** mostrado en cada tarjeta de presión
- **Historial min/max por minuto** con ventana rodante de 5 minutos (marcas en la barra de progreso)
- **Última lectura** calculada por el teléfono al recibir dato válido
- **Runtime del ESP** (uptime) y runtime total acumulado en la hero card
- **SignalK** integración con indicador de estado en la top bar
- **Diagnósticos** nativos, monitor SignalK en vivo y configuración de sensores
- **mDNS / subnet scan** para descubrimiento automático del dispositivo
- **Pantalla siempre encendida** (wakelock)
- **Android multicast lock** para mejorar la recepción de UDP broadcast con la app en primer plano

## Arquitectura

```
ESP32 (firmware independiente)
  ├── /api/state         → DeviceState  (HTTP polling)
  ├── /api/diagnostics   → DeviceDiagnostics
  ├── /api/settings      → DeviceSettings (lectura / escritura)
  └── UDP broadcast      → _UdpTelemetryPacket (presión + voltaje)

Flutter app
  ├── DeviceService      → HTTP client + descubrimiento
  ├── _PressureHomeState → estado principal, listener UDP, historial
  ├── PressureCard       → tarjeta de presión con barra de zonas
  ├── _HeroCard          → estado del sistema y runtimes
  └── _InfoStrip         → hora de última lectura
```

## Requisitos

- Flutter ≥ 3.x
- Android 6+ / iOS 14+ / macOS 12+
- ESP32 con firmware WaterMaker accesible en la misma red

## Build y despliegue

```bash
# Android
flutter build apk --release
flutter install -d <device-id>

# iOS
flutter build ios --release
```

## Dependencias principales

| Paquete | Uso |
|---|---|
| `http` | Comunicación HTTP con el ESP32 |
| `multicast_dns` | Descubrimiento mDNS |
| `shared_preferences` | Persistencia de host y preferencias |
| `wakelock_plus` | Pantalla siempre encendida |
| `url_launcher` | Abrir páginas web del ESP32 |
