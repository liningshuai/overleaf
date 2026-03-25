# Local Overleaf with Docker

This repository contains the Docker files and helper scripts for a local Overleaf deployment on Windows. It is safe to push this repo to GitHub because local secrets, cpolar binaries, logs, and Docker data are intentionally excluded from version control.

## 1. Prerequisites
- Docker Desktop installed on Windows
- Run all commands from this project directory
- Copy `.env.example` to `.env` before first use

```powershell
Copy-Item .env.example .env
```

Edit `.env` and set your own admin email, admin password, and site URL.

## 2. Start and bootstrap admin
If you have old data from a previous failed run and want a clean start:

```powershell
docker compose down -v
```

Then start and initialize:

```powershell
.\scripts\setup-overleaf.ps1
```

This setup builds a custom Overleaf image that preinstalls common TeX Live collections (`collection-latexrecommended`, `collection-fontsrecommended`, `collection-latexextra`) plus required NeurIPS-related packages, reducing repeated `*.sty not found` errors.

After setup:
- URL: value of `OVERLEAF_SITE_URL` in `.env`
- Admin email: value of `OVERLEAF_ADMIN_EMAIL` in `.env`
- Admin password: value of `OVERLEAF_ADMIN_PASSWORD` in `.env`

## 3. Create user accounts for colleagues
Create one user:

```powershell
.\scripts\create-user.ps1 -Email colleague@example.com
```

Create another admin:

```powershell
.\scripts\create-user.ps1 -Email admin2@example.com -Admin
```

Batch create users from an email list file:

```powershell
.\scripts\create-users-from-file.ps1 -FilePath .\emails.txt
```

Create your own local `emails.txt` file first, or copy the sample:

```powershell
Copy-Item .\emails.example.txt .\emails.txt
```

The script prints an activation link. Send that link to the user so they can set their own password.

## 4. Import your existing zip project
In the Overleaf UI:
1. Click `New Project`
2. Click `Upload Project`
3. Upload your zip file

## 5. LAN or public access
If teammates are in the same LAN, set this in `.env`:

```env
OVERLEAF_SITE_URL=http://<YOUR_LAN_IP>:8080
```

If you expose the service with cpolar, set:

```env
OVERLEAF_SITE_URL=https://<YOUR_CPOLAR_DOMAIN>
```

Then restart:

```powershell
docker compose down
docker compose up -d --build
```

If `OVERLEAF_SITE_URL` is left as `http://localhost:8080`, shared links will point to `localhost` and other people will not be able to open them.

## 6. Move to another computer
See the full migration and cpolar guide here:

- `docs/migrate-to-new-computer.md`

Use these helper scripts for Docker volume migration:

```powershell
.\scripts\backup-overleaf-data.ps1 -StopStack
.\scripts\restore-overleaf-data.ps1 -BackupDir .\backup
```

If the new computer cannot pull Docker images reliably, export the images from the old computer and import them offline on the new computer:

```powershell
.\scripts\export-overleaf-images.ps1
.\scripts\import-overleaf-images.ps1
```

## 7. Useful commands
```powershell
docker compose logs -f
docker compose down
docker compose up -d --build
```
