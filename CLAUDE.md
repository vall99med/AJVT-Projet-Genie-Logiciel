# AJVT — Association des Jeunes / شبكة الشباب

## Identité de l'association
- Nom arabe   : رابطة شباب قرية التاكلالت
- Nom français : Association des Jeunes du Village de Taguilalett
- Sigle : AJVT
- Logo : assets/images/AJVT-logo.jpeg
- Village : Taguilalett, Mauritanie

## Description
Application mobile (Flutter + Django REST API) de gestion d'une association
de jeunesse en Mauritanie. Bilingue Arabe/Français.

## Stack technique
- Backend  : Django 4.x + Django REST Framework
- Mobile   : Flutter 3.x + Riverpod 2.x + GoRouter
- BDD      : PostgreSQL 16 (prod) / SQLite (dev)
- Cache    : Redis 7
- Auth     : PIN 4 chiffres (bcrypt) + OTP SMS via Twilio
- HTTP     : Dio (Flutter) + djangorestframework-simplejwt
- Docker   : docker-compose (django + postgres + redis + media_data)

## Structure du projet
```
AJVT/
├── backend/
│   ├── config/
│   │   ├── settings/base.py
│   │   ├── settings/development.py
│   │   └── urls.py
│   ├── apps/
│   │   ├── users/        → Auth, PIN, OTP, JWT
│   │   ├── members/      → Profils, validation, annuaire, recherche full-text
│   │   ├── payments/     → Cotisations, reçus mobiles, carte membre, export
│   │   ├── posts/        → Fil d'actualité + Événements (BF-06/07)
│   │   └── dashboard/    → Statistiques, export Excel
│   ├── media/            → Fichiers uploadés (reçus, photos profil, images posts)
│   ├── test_api.py       → 68 tests automatisés (8 sections)
│   ├── tests_manual.http → Tests REST Client VS Code
│   └── docker-compose.yml
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── app_colors.dart
│   │   │   │   ├── app_strings.dart
│   │   │   │   └── api_constants.dart
│   │   │   ├── network/dio_client.dart
│   │   │   ├── storage/secure_storage.dart
│   │   │   └── router/app_router.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── data/auth_repository.dart
│   │   │   │   ├── domain/auth_state.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── phone_screen.dart
│   │   │   │       ├── otp_screen.dart
│   │   │   │       ├── pin_screen.dart
│   │   │   │       └── login_screen.dart
│   │   │   ├── member/
│   │   │   │   ├── data/
│   │   │   │   │   ├── member_repository.dart
│   │   │   │   │   └── directory_repository.dart   ← BF-10/13
│   │   │   │   ├── domain/member_state.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── register_screen.dart
│   │   │   │       ├── profile_screen.dart        (MainNavBar index=3)
│   │   │   │       ├── member_card_screen.dart
│   │   │   │       ├── members_list_screen.dart
│   │   │   │       ├── directory_screen.dart       ← BF-10/13 (MainNavBar index=2)
│   │   │   │       └── member_profile_screen.dart  ← BF-13
│   │   │   ├── payment/
│   │   │   │   └── presentation/
│   │   │   │       ├── submit_payment_screen.dart
│   │   │   │       ├── payment_history_screen.dart
│   │   │   │       ├── review_payments_screen.dart
│   │   │   │       └── receipt_viewer_screen.dart
│   │   │   ├── posts/
│   │   │   │   ├── data/
│   │   │   │   │   ├── post_repository.dart
│   │   │   │   │   └── event_repository.dart
│   │   │   │   ├── domain/post_state.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── feed_screen.dart            (MainNavBar index=0)
│   │   │   │       ├── post_detail_screen.dart
│   │   │   │       ├── create_post_screen.dart
│   │   │   │       ├── events_screen.dart          (MainNavBar index=1)
│   │   │   │       ├── event_detail_screen.dart
│   │   │   │       ├── create_event_screen.dart
│   │   │   │       └── event_attendance_screen.dart
│   │   │   └── dashboard/
│   │   │       └── presentation/dashboard_screen.dart (Admin MainNavBar index=2)
│   │   └── shared/
│   │       ├── widgets/
│   │       │   ├── ajvt_button.dart
│   │       │   ├── ajvt_text_field.dart
│   │       │   ├── loading_overlay.dart
│   │       │   ├── language_toggle.dart
│   │       │   └── main_nav_bar.dart
│   │       └── theme/app_theme.dart
│   └── pubspec.yaml
└── CLAUDE.md
```

## Modèles Django

### User (apps/users/models.py)
phone       : CharField(unique=True) — identifiant principal
pin_hash    : CharField             — PIN hashé bcrypt
role        : visitor | member | moderator | admin
status      : pending | active | rejected
is_verified : bool — OTP validé au moins une fois
created_at  : DateTimeField(auto_now_add)
Méthodes : `set_pin(raw)`, `check_pin(raw)`

### Profile (apps/members/models.py)
user          : OneToOneField(User)
full_name     : CharField
situation     : student | employed | unemployed
specialty     : CharField (si étudiant)
study_level   : CharField (si étudiant)
job_title     : CharField (si employé)
neighborhood  : CharField — région/ville du membre
photo         : ImageField (compressée auto < 200 Ko)
rejection_reason : TextField
validated_by  : ForeignKey(User)
validated_at  : DateTimeField
Signal : profil vide créé automatiquement à chaque nouveau User

### Payment (apps/payments/models.py)
user             : ForeignKey(User)
year             : IntegerField
amount           : DecimalField
status           : pending | submitted | paid | rejected
payment_mode     : cash | bankily | masrivi | sedad | bimbank | clique | amanty | transfer
receipt_image    : ImageField(upload_to='receipts/') — capture d'écran du reçu
transaction_ref  : CharField — numéro de transaction mobile (optionnel)
submitted_at     : DateTimeField — quand le membre a soumis le reçu
reviewed_by      : ForeignKey(User) — admin ayant traité le reçu
reviewed_at      : DateTimeField
rejection_reason : TextField — motif si rejeté
paid_at          : DateTimeField
validated_by     : ForeignKey(User) — pour paiements cash directs
notes            : TextField
Méthode : `compress_receipt()` — redimensionne si > 500 Ko
Pas de unique_together — un reçu rejeté peut être re-soumis

### Post (apps/posts/models.py)
author     : ForeignKey(User)
title      : CharField
body       : TextField
image      : ImageField (compressée auto < 300 Ko)
status     : draft | published
created_at : DateTimeField
published_at : DateTimeField

### Event (apps/posts/models.py)
organizer       : ForeignKey(User)
title           : CharField
description     : TextField
location        : CharField
image           : ImageField
starts_at       : DateTimeField
ends_at         : DateTimeField
max_participants : IntegerField (optionnel)
created_at      : DateTimeField

### EventParticipant (apps/posts/models.py)
event    : ForeignKey(Event)
user     : ForeignKey(User)
attended : BooleanField
joined_at : DateTimeField

### AuditLog (apps/dashboard/models.py)
action       : CharField
performed_by : ForeignKey(User)
target_user  : ForeignKey(User)
details      : JSONField
created_at   : DateTimeField
Classmethod : `AuditLog.log(action, performed_by, target_user, details)`

## Endpoints API (tous opérationnels)

### Auth — /api/auth/
POST /request-otp/        → envoie OTP SMS (Redis TTL 5 min)
POST /verify-otp/         → vérifie OTP (3 essais max, blocage 15 min)
POST /set-pin/            → crée PIN après vérification OTP
POST /login/              → numéro + PIN → JWT access + refresh
POST /reset-pin/request/  → OTP pour reset PIN
POST /reset-pin/confirm/  → nouveau PIN après OTP

### Members — /api/members/
POST  /register/            → inscription (AllowAny)
GET   /                     → liste membres actifs + recherche full-text (IsActiveMember)
                              params: ?search=… &situation=student|employed|unemployed &page=N
GET   /{id}/                → profil public d'un membre actif (IsActiveMember)
GET   /pending/             → demandes en attente (IsAdmin)
GET   /me/                  → profil connecté (IsActiveMember)
PATCH /me/                  → modifier profil (IsActiveMember)
PATCH /{id}/validate/       → approuver/rejeter membre (IsAdmin)
                              body: {"action": "approve"} | {"action": "reject", "rejection_reason": "..."}

MemberListSerializer retourne : id, full_name, situation, specialty, job_title,
  neighborhood, photo, phone, status, role, cotisation_status, member_since (année)

### Payments — /api/payments/
GET   /card/            → carte membre digitale (IsActiveMember)
                          retourne : cotisation_status (pending|submitted|paid|rejected),
                          rejection_reason, member_id, detail, etc.
GET   /me/              → historique cotisations du membre (IsActiveMember)
POST  /submit/          → soumettre reçu mobile (IsActiveMember, multipart/form-data)
                          fields: year, amount, payment_mode, transaction_ref, receipt_image
GET   /submitted/       → liste reçus en attente de vérification (IsAdmin)
PATCH /{id}/review/     → approuver/rejeter un reçu (IsAdmin)
                          body: {"action": "approve"} | {"action": "reject", "rejection_reason": "..."}
POST  /                 → enregistrer cotisation cash directement (IsAdmin)
GET   /all/             → toutes les cotisations avec filtres year/status (IsAdmin)

### Dashboard — /api/dashboard/
GET /stats/   → statistiques globales (IsAdmin)
GET /export/  → export Excel membres (IsAdmin)

### Posts & Événements — /api/
GET    /posts/                   → liste articles publiés (IsAuthenticatedOrReadOnly, 3 max si non-membre)
POST   /posts/create/            → créer article brouillon (IsAdminOrModerator, multipart ou JSON)
GET    /posts/{id}/              → détail article publié (AllowAny)
PATCH  /posts/{id}/publish/      → publier un brouillon (IsAdminOrModerator)
DELETE /posts/{id}/delete/       → supprimer article (IsAdminOrModerator)
GET    /events/                  → liste événements avec nb participants (IsActiveMember)
POST   /events/create/           → créer événement (IsAdminOrModerator)
GET    /events/{id}/             → détail événement (IsActiveMember)
POST   /events/{id}/join/        → s'inscrire à un événement (IsActiveMember)
DELETE /events/{id}/leave/       → se désinscrire (IsActiveMember)
GET    /events/{id}/participants/ → liste des participants (IsAdminOrModerator)
PATCH  /events/{id}/attendance/  → marquer présence body: {"user_id": X, "attended": bool} (IsAdminOrModerator)

## Flux de paiement mobile
1. Membre effectue un virement (Bankily, Masrivi, etc.)
2. Membre soumet capture d'écran via POST /payments/submit/ (multipart)
3. Payment créé avec status=SUBMITTED
4. Admin voit les reçus via GET /payments/submitted/
5. Admin approuve → status=PAID  |  Admin rejette → status=REJECTED + motif
6. Si rejeté, le membre peut re-soumettre (nouvelle entrée Payment)

## Format réponse API standard
```json
{
  "success": true,
  "data": {},
  "message": "..."
}
```
Exception : endpoints paginés → `{count, next, previous, results: [...]}`

## Permissions
AllowAny           → endpoints auth + inscription
IsActiveMember     → user.status == "active"
IsAdmin            → user.role == "admin"
IsAdminOrModerator → role in ["admin", "moderator"]

## Auth — Flux complet
1ère inscription :
numéro → OTP SMS → verify → créer PIN 4 chiffres → JWT
Connexions suivantes :
numéro + PIN → JWT (fonctionne hors ligne après 1ère connexion)
PIN oublié :
numéro → OTP SMS → nouveau PIN

## Sécurité
- PIN jamais en clair — bcrypt uniquement
- OTP Redis TTL 5 min, 3 tentatives max, blocage 15 min
- JWT access 1 jour, refresh 30 jours, rotation activée
- HTTPS obligatoire en production
- Variables d'environnement pour tous les secrets (.env)

## Numéros de téléphone
- Format E.164 international obligatoire : +[indicatif][numéro]
- Exemples : +22212345678 (MR), +33612345678 (FR), +12125551234 (US)
- Validation dans apps/users/utils.py → validate_international_phone()
- Membres résidant à l'étranger bienvenus

## Flutter — Packages utilisés
```yaml
flutter_riverpod: ^2.4.9        # State management
go_router: ^13.2.0              # Navigation
dio: ^5.4.0                     # HTTP client
flutter_secure_storage: ^9.0.0  # Stocker JWT
shared_preferences: ^2.2.2      # Cache local
pinput: ^3.0.0                  # Saisie PIN/OTP
cached_network_image: ^3.3.1    # Images réseau avec cache
intl: ^0.20.0                   # Internationalisation
flutter_dotenv: ^5.1.0          # Variables d'environnement
flutter_svg: ^2.0.9             # Icons SVG
image_picker: ^1.0.7            # Sélection photos (reçus)
url_launcher: ^6.2.5            # Ouvrir WhatsApp, appels, URLs
```

## Flutter — URLs API
```dart
// Émulateur Android  : http://10.0.2.2:8000/api
// Appareil physique  : http://192.168.X.X:8000/api
// Production         : https://api.ajvt.mr/api
```

## Flutter — Navigation (MainNavBar)
```
Membres  : Accueil(0,/feed) | Événements(1,/events) | Annuaire(2,/directory) | Profil(3,/profile)
Admins   : Accueil(0,/feed) | Événements(1,/events) | Admin(2,/dashboard) | Reçus(3,/payment/review)
```
Redirect après login : admin → /dashboard, membre → /profile

## Flutter — Routes GoRouter (app_router.dart)
```
/phone, /login, /otp, /pin, /register
/profile, /card, /members, /dashboard
/payment/submit, /payment/history, /payment/review, /payment/receipt
/feed, /post/create, /post/:id
/events, /event/create, /event/:id, /event/:id/attendance
/directory, /member/:id                ← BF-10/13
```

## Flutter — i18n
- Fichiers : assets/translations/fr.json + ar.json
- Pattern : `t.translate('key')` ou `AppLocalizations.tr(context, 'key')`
- Zéro chaîne codée en dur dans les widgets
- Clé "neighborhood" traduit "Région" (fr) / "المنطقة" (ar)

## Règles de développement
- Tous les commentaires en français
- Variables d'environnement pour TOUS les secrets
- PIN jamais en clair — toujours bcrypt
- OTP stocké dans Redis avec TTL 5 minutes
- API REST uniquement — zéro template Django
- Pagination sur tous les endpoints list (20 par page)
- Toute la logique métier dans services.py — jamais dans les vues
- Chaque vue Django : maximum 15 lignes
- select_related sur tous les querysets avec FK
- flutter analyze doit retourner 0 erreurs avant tout commit
- Images uploadées : compress_photo() < 200 Ko (profil), compress_receipt() < 500 Ko (reçu)

## État d'avancement

### Backend ✅ TERMINÉ
- 35 endpoints fonctionnels
- 68 tests automatisés (8 sections) → python test_api.py
- Docker opérationnel : docker-compose up (depuis AJVT/)
- Médias servis via /media/ en développement (DEBUG=True)

### Flutter — Auth & Profil ✅
- [x] core/ : DioClient, SecureStorage, AppRouter, AppColors
- [x] auth : phone_screen, otp_screen, pin_screen, login_screen
- [x] member : register_screen, profile_screen, member_card_screen, members_list_screen
- [x] dashboard_screen — stats admin + validation membres

### Flutter — Paiements ✅
- [x] submit_payment_screen — image_picker + upload multipart
- [x] payment_history_screen — historique cotisations membre
- [x] review_payments_screen — liste reçus soumis (admin) + approve/reject
- [x] receipt_viewer_screen — visualisation reçu plein écran

### Flutter — Fil d'actualité & Événements ✅ (BF-06/07)
- [x] feed_screen — liste articles publiés
- [x] post_detail_screen — détail article
- [x] create_post_screen — création + publication (admin/modérateur)
- [x] events_screen — onglets À venir / En cours / Passés
- [x] event_detail_screen — détail + s'inscrire/se désinscrire
- [x] create_event_screen — création événement (admin/modérateur)
- [x] event_attendance_screen — marquage présence (admin/modérateur)

### Flutter — Annuaire avancé ✅ (BF-10 à BF-13)
- [x] directory_repository.dart — searchMembers() paginé + getMemberDetail()
- [x] directory_screen — recherche debounce 500ms, chips filtre, scroll infini, WhatsApp
- [x] member_profile_screen — profil public, avatar, badge rôle, bouton WhatsApp
- [x] Backend : GET /members/?search=…&situation=… (Q filter full-text)
- [x] Backend : GET /members/{id}/ (détail membre public)
- [x] MemberListSerializer : champ member_since ajouté

### Prochaines tâches
- [ ] BF-08 : Notifications push (Firebase FCM backend + Flutter)
- [ ] BF-18 : Notifications de masse (admin → tous les membres)
- [ ] Redirect post-login → /feed (optionnel, actuellement /profile et /dashboard)

## Compte admin de test
Phone  : +22200000000
PIN    : 1234
Role   : admin
Status : active

## Membres de test (approuvés, PIN: 1234)
+22241234567 — Mohamed Vall Bah      — Étudiant, Master 1, Nouakchott
+22241234568 — Ibrahim Diallo        — Étudiant, Licence 3, Rosso
+22241234569 — Fatima Wane           — Employée, Ingénieure civile, Nouadhibou
+22241234570 — Aminata Sy            — Étudiante, BTS, Kaédi
+22241234571 — Oumar Soumaré         — Sans emploi, Kiffa
