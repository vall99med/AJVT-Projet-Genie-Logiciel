# AJVT — Plateforme Numérique de Gestion
## رابطة شباب قرية التاكلالت
### Association des Jeunes du Village de Taguilalett

![CI](https://github.com/vall99med/AJVT-Projet-Genie-Logiciel/actions/workflows/ci.yml/badge.svg)

Application mobile de gestion d'association de jeunesse — Mauritanie.
Bilingue Arabe / Français · Fonctionne sur 3G · Android & iOS.

---

## Stack Technique

| Couche | Technologie |
|---|---|
| Backend | Django REST Framework + PostgreSQL + Redis |
| Mobile | Flutter 3.x + Riverpod |
| Auth | PIN 4 chiffres + OTP SMS (Twilio) |
| Infrastructure | Docker + docker-compose |

## Fonctionnalités

- Adhésion & carte membre digitale
- Annuaire avec recherche par compétence
- Paiements mobiles mauritaniens (Bankily, Masrivi, Sedad...)
- Fil d'actualité & événements
- Dashboard admin + export Excel

## Tests

**68/68 tests automatisés passent en CI/CD.**

## Lancer le projet

```bash
# Backend
docker-compose up
docker-compose exec django python manage.py migrate

# Mobile
cd mobile
flutter run
```

## Structure

```
AJVT/
├── backend/          # API Django REST
├── mobile/           # App Flutter
└── .github/workflows # CI/CD GitHub Actions
```

## Cours

Projet académique — Génie Logiciel 2025-2026