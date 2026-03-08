# hbot

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Edit and simulate in the cloud

This repository is configured to run in cloud dev environments and to publish a web preview.

Cloud options:

- GitHub Codespaces: open the repo on GitHub and create a Codespace. The `.devcontainer/devcontainer.json` will install Flutter and forward port 8080.
- Gitpod (one-click): open `https://gitpod.io/#https://github.com/<your-org-or-username>/<repo>` and it will start the workspace (uses `.gitpod.yml`).

GitHub Pages preview:

After pushing to `main`, the `deploy-pages` workflow will publish `build/web` to GitHub Pages using `peaceiris/actions-gh-pages`. The Pages site will be available at `https://<your-org-or-username>.github.io/<repo>/` (you may need to enable Pages in repository settings for a custom domain).

Run a web simulation (PowerShell examples):

```powershell
# inside Codespace or Gitpod terminal
flutter pub get
flutter devices
# interactive in Chrome
flutter run -d chrome
# or run a web-server (bind 0.0.0.0 so cloud port previews work)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Build locally for web release and preview the bundle:

```powershell
flutter build web
python -m http.server 8080 --directory build/web
```

CI and automatic deploys:

- A GitHub Actions workflow (`.github/workflows/flutter-ci.yml`) runs tests and builds `web` and `apk` on push/PR to `main`.
- A Pages deploy workflow (`.github/workflows/deploy-pages.yml`) builds and publishes `build/web` to GitHub Pages on push to `main`.

Secrets and environment variables:

- Use GitHub repository Secrets for service credentials (Supabase keys, etc.) and reference them in workflows.

Troubleshooting:

- If Codespaces fails to install dependencies, open a terminal and run `flutter pub get`.
- If you need a real Android device, use `flutter run` with a locally connected device; cloud containers typically cannot run emulators.

