# M-link SEBN

Base Flutter/Firebase pour la gestion preventive et corrective des machines de test SEBN.MA.

## Architecture du projet

```text
M-LINK/
  assets/
    maps/
      plant 1.jpg
      plant 2.jpg
      satellite 1.jpg
      satellite 2.jpg
      satellite 3.jpg
  docs/
    firebase_schema.json
  lib/
    core/
      constants/
        app_constants.dart
      theme/
        app_theme.dart
    data/
      models/
        app_user.dart
        intervention.dart
        machine.dart
      repositories/
        mock_maintenance_repository.dart
      mock_data.dart
    features/
      admin/
        admin_screen.dart
      auth/
        login_screen.dart
      dashboard/
        dashboard_screen.dart
      interventions/
        anomaly_report_screen.dart
      machines/
        machine_detail_screen.dart
      map/
        map_screen.dart
    app.dart
    main.dart
  pubspec.yaml
```

## Methode de localisation XY sur les cartes

Chaque machine est stockee avec deux coordonnees normalisees:

- `mapX` entre `0.0` et `1.0`
- `mapY` entre `0.0` et `1.0`

Exemple:

```json
{ "mapX": 0.72, "mapY": 0.60 }
```

Conversion au rendu (dans `MapScreen`):

- `pixelX = mapX * largeurCarte`
- `pixelY = mapY * hauteurCarte`

Avantages:

- Independant de la resolution des images
- Fonctionne avec zoom (`InteractiveViewer`)
- Simple a maintenir dans Firestore

Pour calibrer une machine sur la carte:

1. Ouvrir le plan du site.
2. Cliquer la zone de la machine.
3. Convertir la position cliquee en ratio:
   - `mapX = xClique / largeurImage`
   - `mapY = yClique / hauteurImage`
4. Enregistrer `mapX`, `mapY` dans la collection `Machines`.

## Demarrage

```bash
flutter pub get
flutter run
```

Admin demo:

- Matricule: `19879`
- Mot de passe: `041125`
