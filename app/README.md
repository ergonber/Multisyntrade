# SynTrade MVP

Plataforma de señales de trading - MVP funcional

## Requisitos Previos

### 1. Instalar Flutter SDK

```bash
# Linux (snap)
sudo snap install flutter --classic

# O manualmente desde:
# https://docs.flutter.dev/get-started/install/linux

# Verificar instalación
flutter --version
```

### 2. Instalar Android Studio

```bash
# Descargar desde:
# https://developer.android.com/studio

# O usar el emulador de línea de comandos:
sudo apt install android-sdk
```

### 3. Configurar Supabase

1. Crear cuenta en [supabase.com](https://supabase.com)
2. Crear nuevo proyecto
3. Ir a SQL Editor y ejecutar el contenido de `syntrade/supabase/schema.sql`
4. Copiar la URL y anon key del proyecto

## Configurar el Proyecto

### 1. Configurar variables de entorno

Editar el archivo `syntrade/app/android/app/build.gradle` y agregar:

```gradle
android {
    defaultConfig {
        // Agregar estas líneas
        resValue "string", "SUPABASE_URL", "https://TU-PROYECTO.supabase.co"
        resValue "string", "SUPABASE_ANON_KEY", "TU-ANON-KEY-AQUI"
    }
}
```

### 2. Instalar dependencias

```bash
cd syntrade/app
flutter pub get
```

### 3. Ejecutar la app

```bash
# Con emulador Android ejecutándose
flutter run

# O generar APK
flutter build apk
```

## Estructura del Proyecto

```
syntrade/
├── app/
│   ├── lib/
│   │   ├── main.dart           # Punto de entrada
│   │   ├── screens/
│   │   │   ├── login_screen.dart      # Login
│   │   │   ├── register_screen.dart   # Registro
│   │   │   ├── home_screen.dart       # Dashboard principal
│   │   │   ├── signals_screen.dart    # Señales de trading
│   │   │   └── profile_screen.dart    # Perfil + logout
│   │   ├── services/                  # Servicios
│   │   ├── models/                    # Modelos de datos
│   │   ├── config/                    # Configuración
│   │   └── widgets/                   # Widgets reutilizables
│   ├── pubspec.yaml             # Dependencias
│   └── android/                 # Configuración Android
├── supabase/
│   └── schema.sql               # Esquema de BD
└── document/                    # Documentación
```

## Funcionalidades MVP

### ✅ Implementadas

1. **Login** - Autenticación con email/contraseña via Supabase
2. **Registro** - Crear cuenta con nombre, email y contraseña
3. **Dashboard** - Vista principal con:
   - Capital total estimado
   - Ganancia y win rate
   - Señales activas en tiempo real
   - Historial reciente
4. **Señales** - Pestañas con:
   - Señales activas
   - Señales programadas
   - Historial de señales
5. **Perfil** - Información del usuario con:
   - Estadísticas personales
   - Menú de opciones
   - **Cerrar sesión** con confirmación

### 🔜 Próximas versiones

- [ ] Conexión con Deriv (OAuth)
- [ ] Auto-copy de operaciones
- [ ] Push notifications
- [ ] Simulador de trading
- [ ] Objetivos financieros
- [ ] Panel de administración

## Solución de Problemas

### Error: "Flutter not found"

```bash
export PATH="$PATH:$HOME/snap/flutter/common/flutter/bin"
```

### Error: "Supabase not initialized"

Verificar que las credenciales estén configuradas correctamente en `main.dart`.

### Error: "No connected devices"

1. Abrir Android Studio
2. Ir a Tools > Device Manager
3. Crear o iniciar un emulador

## Soporte

Para problemas o dudas, contactar al equipo de desarrollo.
