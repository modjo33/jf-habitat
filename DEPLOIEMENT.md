# Déploiement JF Habitat

## Pré-requis

- Domaine acheté (ex: `jfhabitat.fr`) pointant vers l'IP du serveur
- Serveur Linux (Ubuntu 24.04 recommandé) — Hetzner CX22 (~5€/mois) ou équivalent
- Docker installé sur le serveur
- Compte Resend (gratuit) pour les e-mails transactionnels

## 1. Provisionner le serveur

Sur Hetzner Cloud :

1. Créer un projet, puis un serveur CX22 (Ubuntu 24.04)
2. Activer firewall (ports 22, 80, 443)
3. Récupérer l'IP publique
4. Configurer DNS du domaine : `A` record vers l'IP, `CNAME www` vers le domaine racine

## 2. Configurer Kamal

Éditer `config/deploy.yml` :

```yaml
servers:
  web:
    - <IP_DU_SERVEUR>

proxy:
  ssl: true
  host: jfhabitat.fr

registry:
  server: ghcr.io
  username: <ton-user-github>
  password:
    - KAMAL_REGISTRY_PASSWORD
```

## 3. Variables d'environnement

Copier `.env.example` puis renseigner toutes les variables nécessaires.

**Minimum bloquant pour démarrer :**

- `RAILS_MASTER_KEY` (depuis `config/master.key` local)
- `JF_HABITAT_DATABASE_PASSWORD`
- `APP_HOST=jfhabitat.fr`
- `ADMIN_USER` / `ADMIN_PASSWORD` (changer les défauts)
- `SMTP_PASSWORD` (clé Resend)
- `MAIL_FROM` / `LEAD_NOTIFICATION_EMAIL`

**Mentions légales (obligatoire France) :**

- `LEGAL_COMPANY_NAME`, `LEGAL_LEGAL_FORM`, `LEGAL_SIRET`, `LEGAL_ADDRESS`
- `LEGAL_PHONE`, `LEGAL_DIRECTOR`
- `BUSINESS_*` (téléphone, adresse, zone d'intervention)

**Optionnel — à activer plus tard :**

- `GA4_MEASUREMENT_ID` / `META_PIXEL_ID` → mesure marketing
- `TWILIO_*` → notification SMS de nouveau lead
- `CAL_COM_URL` → planning RDV embed

## 4. Push secrets via Kamal

```bash
bin/kamal env push
```

## 5. Premier déploiement

```bash
bin/kamal setup        # 1ère fois seulement
bin/kamal deploy
```

## 6. Charger les tarifs réels

```bash
bin/kamal app exec --interactive 'bin/rails db:seed'
```

Puis aller sur `/admin` (basic auth) → Tarifs → ajuster aux prix réels de Johan.

## Checklist post-déploiement

- [ ] Site accessible en HTTPS sur le domaine
- [ ] `/up` répond OK
- [ ] Soumission d'estimation test → email reçu
- [ ] Bandeau cookies s'affiche
- [ ] Mentions légales / confidentialité / CGU OK
- [ ] Sitemap accessible : `/sitemap.xml`
- [ ] `robots.txt` accessible
- [ ] Schema.org valide (test : https://search.google.com/test/rich-results)
- [ ] Google Search Console : domaine vérifié + sitemap soumis
- [ ] Google Business Profile créé
- [ ] GA4 + Meta Pixel branchés (après création comptes)

## Tâches gratuites Johan (en parallèle du dev)

1. **Créer compte Resend** → récupérer SMTP_PASSWORD
2. **Créer Google Business Profile** → fiche Maps gratuite
3. **Créer compte Google Analytics 4** → récupérer GA4_MEASUREMENT_ID
4. **Créer Meta Business Manager + Pixel** → récupérer META_PIXEL_ID
5. **Créer Google Search Console** → vérifier domaine + soumettre sitemap
6. **Demander 5–10 avis Google** aux anciens clients (levier #1 artisan local)
7. **Inscriptions gratuites** : PagesJaunes, Houzz, Habitatpresto, Travaux.com, Solvari
