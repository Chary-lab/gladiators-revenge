# Supabase — puesta en marcha

Proyecto: `ntmxmaxaprmqmvhsxtmd`  
URL REST: `https://ntmxmaxaprmqmvhsxtmd.supabase.co`

Estado actual: migración aplicada y `anon_key` configurada en `project.godot`.
La `service_role` está en `supabase/.env`, que está ignorado por git.

## 1. Crear el esquema

La migración ya está aplicada en este proyecto. Si creas otro proyecto o
necesitas recrearlo, abre el **SQL Editor** y pega
[`migrations/0001_coop.sql`](migrations/0001_coop.sql), o ejecútalo con `psql`:

```powershell
$env:SUPABASE_DB_URL="postgresql://postgres:TU_PASSWORD@db.ntmxmaxaprmqmvhsxtmd.supabase.co:5432/postgres"
psql $env:SUPABASE_DB_URL -f supabase/migrations/0001_coop.sql
```

La connection string es solo para administración/migraciones. **No la pongas en
el repo, en la web ni en el APK.**

## 2. Claves

En **Project Settings → API** copia:

- **anon public key** → `project.godot` → `[supabase] anon_key`. Es pública y
  puede ir en la build web; RLS limita la lectura.
- **service_role key** → solo como variable de entorno del servidor Godot:
  `SUPABASE_SERVICE_KEY`. Nunca en `project.godot`, en el cliente ni en git.

## 3. Servidor

El archivo `supabase/.env` (ignorado por git) contiene la `service_role` y una
URL pública vacía. Rellena `SERVER_PUBLIC_URL` con la URL `wss://` real y
arráncalo con:

```powershell
.\supabase\run-server.ps1
```

El script carga `.env` en el entorno y ejecuta el servidor headless. El servidor
hace un `upsert` en `servidores` cada 20 s con su URL, región y jugadores. Al
terminar la partida inserta una fila en `partidas` y marca el servidor como
inactivo.

Si prefieres no usar el script:

```powershell
$env:SUPABASE_SERVICE_KEY="..."
$env:SERVER_PUBLIC_URL="wss://tu-servidor.example.com"
godot --headless -- --servidor --puerto=9080
```

En Fly.io:

```powershell
fly secrets set SUPABASE_SERVICE_KEY="..." SERVER_PUBLIC_URL="wss://<app>.fly.dev"
fly deploy
```

En Render, define `SUPABASE_SERVICE_KEY` y `SERVER_PUBLIC_URL` como variables de
entorno del Web Service.

## 4. Clientes

- Web/APK leen `supabase/url` y `supabase/anon_key` de `project.godot` y muestran
  la lista de servidores activos en el menú.
- También se puede entrar directo con `?servidor=wss://…` (web) o
  `--cliente=wss://…` (escritorio).
- Un servidor se considera activo si `actualizado_en` tiene menos de 2 minutos.

## Seguridad

- RLS activo: lectura pública solo de servidores activos y partidas; escritura
  exclusiva de `service_role`.
- La `service_role` bypassa RLS. No la expongas en la build web/APK.
- El cliente nunca abre una conexión directa a PostgreSQL; usa PostgREST.
- Si sospechas que una clave se ha filtrado, rótala en Supabase.
