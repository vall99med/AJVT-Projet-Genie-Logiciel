"""
Script de test automatique de l'API AJVT.
Lance avec : docker-compose exec django python test_api.py
"""
import sys
import os
import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:8000/api"
ADMIN_PHONE = "+22200000000"
MEMBER_PHONE = "+22299887766"
PIN = "1234"

# Couleurs terminal
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"
BOLD = "\033[1m"

passed = 0
failed = 0


def test(name, response, expected_status, check_key=None):
    """Vérifie une réponse API et affiche le résultat."""
    global passed, failed
    ok = response.status_code == expected_status
    if ok and check_key:
        try:
            ok = check_key in str(response.json())
        except Exception:
            ok = False

    if ok:
        passed += 1
        print(f"  {GREEN}✓{RESET} {name} → {response.status_code}")
    else:
        failed += 1
        print(f"  {RED}✗{RESET} {name} → {response.status_code} (attendu {expected_status})")
        try:
            print(f"    {YELLOW}{json.dumps(response.json(), ensure_ascii=False, indent=2)[:300]}{RESET}")
        except Exception:
            print(f"    {YELLOW}{response.text[:300]}{RESET}")
    return response


def header(title):
    print(f"\n{BOLD}{'─' * 55}{RESET}")
    print(f"{BOLD}  {title}{RESET}")
    print(f"{BOLD}{'─' * 55}{RESET}")


def post(path, data, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.post(f"{BASE_URL}{path}", json=data, headers=headers)


def get(path, token=None, params=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.get(f"{BASE_URL}{path}", headers=headers, params=params)


def patch(path, data, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.patch(f"{BASE_URL}{path}", json=data, headers=headers)


# ════════════════════════════════════════════════════════
# SETUP Django — doit tourner dans le conteneur /app
# ════════════════════════════════════════════════════════
header("SETUP — Préparation de la base de données")

sys.path.insert(0, "/app")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

import django
django.setup()

from apps.users.models import User
from django.core.cache import cache

# Crée ou met à jour le compte admin
admin_user, created = User.objects.get_or_create(phone=ADMIN_PHONE)
admin_user.set_pin(PIN)
admin_user.role = User.Role.ADMIN
admin_user.status = User.Status.ACTIVE
admin_user.is_verified = True
admin_user.save()
print(f"  {GREEN}✓{RESET} Compte admin prêt : {ADMIN_PHONE} / PIN: {PIN} ({'créé' if created else 'mis à jour'})")

# Nettoyage du compte membre de test pour pouvoir relancer le script
User.objects.filter(phone=MEMBER_PHONE).delete()
cache.delete(f"otp:{MEMBER_PHONE}")
cache.delete(f"otp_attempts:{MEMBER_PHONE}")
cache.delete(f"otp_blocked:{MEMBER_PHONE}")
print(f"  {GREEN}✓{RESET} Nettoyage compte membre test : {MEMBER_PHONE}")


# ════════════════════════════════════════════════════════
# 1. AUTHENTIFICATION
# ════════════════════════════════════════════════════════
header("1. AUTHENTIFICATION")

# 1.1 Request OTP
r = post("/auth/request-otp/", {"phone": MEMBER_PHONE})
test("Request OTP (nouveau membre)", r, 200)

# Récupère l'OTP directement depuis Redis (mode DEBUG)
otp_code = cache.get(f"otp:{MEMBER_PHONE}")
if not otp_code:
    print(f"  {RED}✗ OTP introuvable dans Redis — serveur démarré ?{RESET}")
    sys.exit(1)
print(f"  {YELLOW}  → OTP récupéré depuis Redis : {otp_code}{RESET}")

# 1.2 OTP invalide → 400
r = post("/auth/verify-otp/", {"phone": MEMBER_PHONE, "code": "000000"})
test("OTP invalide → 400", r, 400)

# 1.3 Verify OTP (code correct)
r = post("/auth/verify-otp/", {"phone": MEMBER_PHONE, "code": otp_code})
test("Verify OTP (code correct)", r, 200)

# 1.4 Set PIN
r = post("/auth/set-pin/", {"phone": MEMBER_PHONE, "pin": PIN, "pin_confirm": PIN})
test("Set PIN", r, 201, "access")

# 1.5 Login membre
r = post("/auth/login/", {"phone": MEMBER_PHONE, "pin": PIN})
test("Login membre", r, 200, "access")
member_token = r.json()["data"]["tokens"]["access"]

# 1.6 Login admin
r = post("/auth/login/", {"phone": ADMIN_PHONE, "pin": PIN})
test("Login admin", r, 200, "access")
admin_token = r.json()["data"]["tokens"]["access"]

# 1.7 Numéro sans indicatif → 400
r = post("/auth/request-otp/", {"phone": "12345678"})
test("OTP numéro sans indicatif → 400", r, 400)

# 1.8 PIN non numérique → 400
r = post("/auth/set-pin/", {"phone": MEMBER_PHONE, "pin": "abcd", "pin_confirm": "abcd"})
test("PIN non numérique → 400", r, 400)

# 1.9 PIN non concordants → 400
r = post("/auth/set-pin/", {"phone": MEMBER_PHONE, "pin": "1234", "pin_confirm": "5678"})
test("PIN non concordants → 400", r, 400)

# 1.10 PIN incorrect → 400
r = post("/auth/login/", {"phone": MEMBER_PHONE, "pin": "9999"})
test("Login PIN incorrect → 400", r, 400)

# 1.11 Reset PIN — demande
r = post("/auth/reset-pin/request/", {"phone": MEMBER_PHONE})
test("Reset PIN — demande OTP", r, 200)
new_otp = cache.get(f"otp:{MEMBER_PHONE}")
print(f"  {YELLOW}  → Nouvel OTP : {new_otp}{RESET}")

# 1.12 Reset PIN — confirmation
r = post("/auth/reset-pin/confirm/", {
    "phone": MEMBER_PHONE, "code": new_otp, "pin": PIN, "pin_confirm": PIN
})
test("Reset PIN — confirmation", r, 200)


# ════════════════════════════════════════════════════════
# 2. MEMBRES — INSCRIPTION
# ════════════════════════════════════════════════════════
header("2. MEMBRES — INSCRIPTION")

# 2.1 Inscription membre
r = post("/members/register/", {
    "phone": MEMBER_PHONE,
    "full_name": "Fatima Mint Ahmed",
    "situation": "student",
    "specialty": "Médecine",
    "study_level": "4ème année",
    "neighborhood": "Tevragh Zeina",
})
test("Inscription membre", r, 201)

# 2.2 Inscription doublon → 400
r = post("/members/register/", {
    "phone": MEMBER_PHONE,
    "full_name": "Fatima Mint Ahmed",
    "situation": "student",
})
test("Inscription doublon → 400", r, 400)

# 2.3 Inscription sans OTP préalable → 400
r = post("/members/register/", {
    "phone": "+22211111111",
    "full_name": "Inconnu Test",
    "situation": "unemployed",
})
test("Inscription sans OTP préalable → 400", r, 400)


# ════════════════════════════════════════════════════════
# 3. MEMBRES — VALIDATION ADMIN
# ════════════════════════════════════════════════════════
header("3. MEMBRES — VALIDATION ADMIN")

# 3.1 Liste membres en attente (admin)
r = get("/members/pending/", token=admin_token)
test("Liste membres en attente (admin)", r, 200)

# Récupère l'ID utilisateur du membre de test depuis la liste
pending_data = r.json()
results = pending_data.get("results", [])
member_id = None
for m in results:
    if m.get("phone") == MEMBER_PHONE:
        member_id = m.get("id")
        break

if member_id:
    print(f"  {YELLOW}  → Membre trouvé, user_id={member_id}{RESET}")
else:
    print(f"  {RED}  → Membre non trouvé dans la liste en attente{RESET}")

# 3.2 Liste sans token → 401
r = get("/members/pending/")
test("Liste pending sans token → 401", r, 401)

# 3.3 Liste avec token membre (non admin) → 403
r = get("/members/pending/", token=member_token)
test("Liste pending avec token membre → 403", r, 403)

# 3.4 Approuver le membre
if member_id:
    r = patch(f"/members/{member_id}/validate/", {"action": "approve"}, token=admin_token)
    test("Approuver membre", r, 200)
else:
    failed += 1
    print(f"  {RED}✗ Skip approuver : member_id introuvable{RESET}")

# 3.5 Re-valider un membre déjà traité → 400
if member_id:
    r = patch(f"/members/{member_id}/validate/", {"action": "approve"}, token=admin_token)
    test("Re-valider membre déjà traité → 400", r, 400)

# 3.6 Valider un membre inexistant → 400
r = patch("/members/99999/validate/", {"action": "approve"}, token=admin_token)
test("Valider membre inexistant → 400", r, 400)


# ════════════════════════════════════════════════════════
# 4. PROFIL MEMBRE
# ════════════════════════════════════════════════════════
header("4. PROFIL MEMBRE")

# Reconnexion pour avoir un token valide après approbation
r = post("/auth/login/", {"phone": MEMBER_PHONE, "pin": PIN})
test("Login membre après approbation", r, 200)
member_token = r.json()["data"]["tokens"]["access"]

# 4.1 Mon profil
r = get("/members/me/", token=member_token)
test("Mon profil", r, 200, "full_name")

# 4.2 Profil sans token → 401
r = get("/members/me/")
test("Mon profil sans token → 401", r, 401)

# 4.3 Annuaire membres actifs
r = get("/members/", token=member_token)
test("Annuaire membres actifs", r, 200)

# 4.4 Annuaire sans token → 401
r = get("/members/")
test("Annuaire sans token → 401", r, 401)

# 4.5 Modifier son profil
r = patch("/members/me/", {"neighborhood": "Ksar", "job_title": "Médecin"}, token=member_token)
test("Modifier profil (PATCH partiel)", r, 200, "Ksar")


# ════════════════════════════════════════════════════════
# 5. COTISATIONS — FLUX AVEC REÇU MOBILE
# ════════════════════════════════════════════════════════
header("5. COTISATIONS — FLUX AVEC REÇU MOBILE")

current_year = datetime.now().year

# 5.1 Carte membre (pending — aucun paiement)
r = get("/payments/card/", token=member_token)
test("Carte membre (pending)", r, 200, "cotisation_status")

# Prépare une fausse image de reçu Bankily
from io import BytesIO
from PIL import Image as PILImage

_img = PILImage.new("RGB", (400, 600), color=(255, 255, 255))
_img_bytes = BytesIO()
_img.save(_img_bytes, format="JPEG")
_img_bytes.seek(0)

# 5.2 Soumettre reçu Bankily (membre)
_headers_member = {"Authorization": f"Bearer {member_token}"}
r = requests.post(
    f"{BASE_URL}/payments/submit/",
    headers=_headers_member,
    data={
        "year":            str(current_year),
        "amount":          "1000.00",
        "payment_mode":    "bankily",
        "transaction_ref": "BNK20251234",
    },
    files={"receipt_image": ("receipt.jpg", _img_bytes, "image/jpeg")},
)
test("Soumettre reçu Bankily", r, 201)

# 5.3 Doublon soumission (même membre, même année) → 400
_img_bytes.seek(0)
r = requests.post(
    f"{BASE_URL}/payments/submit/",
    headers=_headers_member,
    data={
        "year":         str(current_year),
        "amount":       "1000.00",
        "payment_mode": "bankily",
    },
    files={"receipt_image": ("receipt.jpg", _img_bytes, "image/jpeg")},
)
test("Doublon soumission → 400", r, 400)

# 5.4 Liste reçus soumis (admin)
r = get("/payments/submitted/", token=admin_token)
test("Liste reçus soumis (admin)", r, 200)
payment_id = None
results = r.json().get("results", [])
if results:
    payment_id = results[0].get("id")
    print(f"  {YELLOW}  → payment_id={payment_id}{RESET}")
else:
    print(f"  {RED}  → Aucun reçu soumis trouvé{RESET}")

# 5.5 Carte membre (submitted)
r = get("/payments/card/", token=member_token)
test("Carte membre (submitted)", r, 200, "submitted")

# 5.6 Approuver le reçu (admin)
if payment_id:
    r = patch(f"/payments/{payment_id}/review/", {"action": "approve"}, token=admin_token)
    test("Approuver reçu", r, 200)
else:
    failed += 1
    print(f"  {RED}✗ Skip approbation : payment_id introuvable{RESET}")

# 5.7 Carte membre (paid)
r = get("/payments/card/", token=member_token)
test("Carte membre (paid)", r, 200, "paid")

# 5.8 Historique cotisations membre
r = get("/payments/me/", token=member_token)
test("Historique cotisations", r, 200)

# 5.9 Dashboard statistiques (admin)
r = get("/dashboard/stats/", token=admin_token)
test("Dashboard statistiques", r, 200, "total_members")

# 5.10 Export Excel (admin)
r = get("/dashboard/export/", token=admin_token)
test("Export Excel", r, 200)
if r.status_code == 200:
    print(f"  {YELLOW}  → Taille fichier : {len(r.content)} octets{RESET}")

# 5.11 Export sans token → 401
r = get("/dashboard/export/")
test("Export sans token → 401", r, 401)


# ════════════════════════════════════════════════════════
# 6. FIL D'ACTUALITÉ (BF-06)
# ════════════════════════════════════════════════════════
header("6. FIL D'ACTUALITÉ")

# 6.1 Créer un article brouillon (admin)
r = post("/posts/create/", {"title": "Bienvenue sur AJVT", "body": "Premier article de test."}, token=admin_token)
test("Créer article brouillon (admin)", r, 201)
post_id = r.json().get("data", {}).get("id")
if post_id:
    print(f"  {YELLOW}  → post_id={post_id}{RESET}")

# 6.2 Créer article sans token → 401
r = post("/posts/create/", {"title": "Test", "body": "Contenu"})
test("Créer article sans token → 401", r, 401)

# 6.3 Créer article avec token membre → 403
r = post("/posts/create/", {"title": "Test", "body": "Contenu"}, token=member_token)
test("Créer article avec token membre → 403", r, 403)

# 6.4 Lister articles publiés — vide avant publication
r = get("/posts/", token=member_token)
test("Lister articles (aucun publié)", r, 200)

# 6.5 Publier l'article (admin)
if post_id:
    r = patch(f"/posts/{post_id}/publish/", {}, token=admin_token)
    test("Publier article (admin)", r, 200)
else:
    failed += 1
    print(f"  {RED}✗ Skip publier : post_id introuvable{RESET}")

# 6.6 Lister articles publiés (membre)
r = get("/posts/", token=member_token)
test("Lister articles publiés (membre)", r, 200)
results = r.json().get("results", [])
print(f"  {YELLOW}  → {len(results)} article(s) trouvé(s){RESET}")

# 6.7 Détail article (AllowAny)
if post_id:
    r = get(f"/posts/{post_id}/")
    test("Détail article (sans token)", r, 200, "Bienvenue")

# 6.8 Republier article déjà publié → 400
if post_id:
    r = patch(f"/posts/{post_id}/publish/", {}, token=admin_token)
    test("Republier article déjà publié → 400", r, 400)

# 6.9 Supprimer article (admin)
if post_id:
    import requests as _req
    r = _req.delete(
        f"{BASE_URL}/posts/{post_id}/delete/",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    test("Supprimer article (admin)", r, 200)

# 6.10 Article supprimé introuvable → 404
if post_id:
    r = get(f"/posts/{post_id}/")
    test("Article supprimé → 404", r, 404)


# ════════════════════════════════════════════════════════
# 7. ÉVÉNEMENTS (BF-07)
# ════════════════════════════════════════════════════════
header("7. ÉVÉNEMENTS")

from datetime import timedelta
from django.utils import timezone as tz

future_start = (tz.now() + timedelta(days=7)).isoformat()
future_end   = (tz.now() + timedelta(days=7, hours=3)).isoformat()

# 7.1 Créer un événement (admin, JSON)
import requests as _req
r = _req.post(
    f"{BASE_URL}/events/create/",
    json={
        "title":            "Journée d'intégration AJVT",
        "description":      "Rencontre annuelle des membres.",
        "location":         "Nouakchott, Palais des congrès",
        "starts_at":        future_start,
        "ends_at":          future_end,
        "max_participants": 50,
    },
    headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"},
)
test("Créer événement (admin)", r, 201)
event_id = r.json().get("data", {}).get("id")
if event_id:
    print(f"  {YELLOW}  → event_id={event_id}{RESET}")

# 7.2 Créer événement avec date passée → 400
past_start = (tz.now() - timedelta(days=1)).isoformat()
past_end   = (tz.now() - timedelta(hours=1)).isoformat()
r = _req.post(
    f"{BASE_URL}/events/create/",
    json={
        "title": "Passé", "description": "Test", "location": "Ici",
        "starts_at": past_start, "ends_at": past_end,
    },
    headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"},
)
test("Créer événement date passée → 400", r, 400)

# 7.3 Lister événements (membre actif)
r = get("/events/", token=member_token)
test("Lister événements (membre)", r, 200)
results = r.json().get("results", [])
print(f"  {YELLOW}  → {len(results)} événement(s) trouvé(s){RESET}")

# 7.4 Lister événements sans token → 401
r = get("/events/")
test("Lister événements sans token → 401", r, 401)

# 7.5 Détail événement
if event_id:
    r = get(f"/events/{event_id}/", token=member_token)
    test("Détail événement", r, 200, "Journée")

# 7.6 Membre s'inscrit à l'événement
if event_id:
    r = post(f"/events/{event_id}/join/", {}, token=member_token)
    test("Inscription événement (membre)", r, 200)

# 7.7 Membre s'inscrit une 2e fois → 400
if event_id:
    r = post(f"/events/{event_id}/join/", {}, token=member_token)
    test("Double inscription → 400", r, 400)

# 7.8 participants_count vaut 1
if event_id:
    r = get(f"/events/{event_id}/", token=member_token)
    test("Détail événement (1 participant)", r, 200, "1")

# 7.9 Voir liste des participants (admin)
if event_id:
    r = get(f"/events/{event_id}/participants/", token=admin_token)
    test("Liste participants (admin)", r, 200)
    ptcp = r.json().get("data", [])
    print(f"  {YELLOW}  → {len(ptcp)} participant(s){RESET}")

# 7.10 Marquer présence (admin)
if event_id and ptcp:
    # Le champ user_id correspond à l'id du membre depuis la liste des users
    from apps.users.models import User as _User
    member_user = _User.objects.get(phone=MEMBER_PHONE)
    r = patch(
        f"/events/{event_id}/attendance/",
        {"user_id": member_user.id, "attended": True},
        token=admin_token,
    )
    test("Marquer présence (admin)", r, 200)

# 7.11 Membre se désinscrit
if event_id:
    r = _req.delete(
        f"{BASE_URL}/events/{event_id}/leave/",
        headers={"Authorization": f"Bearer {member_token}"},
    )
    test("Désinscription événement (membre)", r, 200)

# 7.12 Désinscription déjà effectuée → 400
if event_id:
    r = _req.delete(
        f"{BASE_URL}/events/{event_id}/leave/",
        headers={"Authorization": f"Bearer {member_token}"},
    )
    test("Double désinscription → 400", r, 400)


# ════════════════════════════════════════════════════════
# 8. ANNUAIRE & RECHERCHE (BF-10 à BF-13)
# ════════════════════════════════════════════════════════
header("8. ANNUAIRE & RECHERCHE")

# 8.1 Liste membres actifs
r = get("/members/", token=member_token)
test("Liste membres actifs", r, 200)

# 8.2 Recherche par nom
r = get("/members/?search=Fatima", token=member_token)
test("Recherche par nom", r, 200)

# 8.3 Recherche par spécialité
r = get("/members/?search=Medecine", token=member_token)
test("Recherche par spécialité", r, 200)

# 8.4 Filtre par situation
r = get("/members/?situation=student", token=member_token)
test("Filtre étudiants", r, 200)

# 8.5 Recherche + filtre combinés
r = get("/members/?search=Ahmed&situation=employed", token=member_token)
test("Recherche + filtre combinés", r, 200)

# 8.6 Détail membre
if member_id:
    r = get(f"/members/{member_id}/", token=member_token)
    test("Détail membre", r, 200, "full_name")
else:
    failed += 1
    print(f"  {RED}✗ Skip détail membre : member_id introuvable{RESET}")

# 8.7 Détail membre sans token → 401
if member_id:
    r = get(f"/members/{member_id}/")
    test("Détail membre sans token → 401", r, 401)

# 8.8 Recherche vide → retourne tous
r = get("/members/?search=", token=member_token)
test("Recherche vide → tous les membres", r, 200)


# ════════════════════════════════════════════════════════
# RÉSULTAT FINAL
# ════════════════════════════════════════════════════════
total = passed + failed
header("RÉSULTAT FINAL")
print(f"\n  Tests passés  : {GREEN}{BOLD}{passed}/{total}{RESET}")
print(f"  Tests échoués : {RED}{BOLD}{failed}/{total}{RESET}")
print()

if failed == 0:
    print(f"  {GREEN}{BOLD}Tous les tests passent !{RESET}\n")
else:
    print(f"  {RED}{BOLD}{failed} test(s) échoué(s) — voir les détails ci-dessus.{RESET}\n")

sys.exit(0 if failed == 0 else 1)
