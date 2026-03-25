# Move This Overleaf Setup To A New Computer

## What GitHub does and does not save
Pushing this repository to GitHub saves:

- `docker-compose.yml`
- `Dockerfile.sharelatex`
- PowerShell helper scripts
- documentation

It does **not** save your live Overleaf data. The actual projects, users, MongoDB data, and Redis data live inside Docker volumes:

- `overleaf20_overleaf_data`
- `overleaf20_overleaf_logs`
- `overleaf20_mongo_data`
- `overleaf20_redis_data`

If you want the new computer to contain the same projects and users, back up those volumes and restore them on the new machine.

## On the current computer
1. Push this repo to GitHub.
2. Create a Docker data backup:

```powershell
.\scripts\backup-overleaf-data.ps1 -StopStack
```

3. If the new computer cannot access Docker Hub reliably, also export the Docker images:

```powershell
.\scripts\export-overleaf-images.ps1
```

4. Copy the generated `backup/` folder to the new computer with a USB drive, LAN share, or cloud disk.

## On the new computer
Install these first:

- Git
- Docker Desktop
- cpolar (only if you want public access)

Clone the repo:

```powershell
git clone https://github.com/liningshuai/overleaf.git
cd overleaf
```

Create your local config if needed:

```powershell
Copy-Item .env.example .env
```

If you copied the `backup/` folder from the old machine, restore the Docker data:

```powershell
.\scripts\restore-overleaf-data.ps1 -BackupDir .\backup
```

If the new computer cannot pull images from Docker Hub, import the offline image archive first:

```powershell
.\scripts\import-overleaf-images.ps1 -InputFile .\backup\overleaf-images.tar
```

Then start without rebuilding:

```powershell
docker compose up -d
```

If you are starting from scratch instead of restoring old data, bootstrap the stack with:

```powershell
.\scripts\setup-overleaf.ps1
```

## cpolar setup on the new computer
1. Install cpolar and make sure `cpolar.exe` is available.
2. Log in cpolar on that computer with your own auth token:

```powershell
cpolar authtoken <your-cpolar-authtoken>
```

3. Expose the local Overleaf service:

```powershell
cpolar http 8080
```

4. Copy the HTTPS public URL printed by cpolar.
5. Update `.env` so Overleaf generates correct links:

```env
OVERLEAF_SITE_URL=https://your-public-domain.cpolar.cn
```

6. Restart the stack:

```powershell
docker compose down
docker compose up -d --build
```

## Important cpolar note
If you are using a free cpolar domain, the public URL can change after restart. When that happens:

1. Run `cpolar http 8080` again.
2. Update `OVERLEAF_SITE_URL` in `.env`.
3. Restart Docker Compose.

Otherwise users may receive links pointing to the old address.
