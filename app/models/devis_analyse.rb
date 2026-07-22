# Analyse de rentabilité d'un devis — OUTIL INTERNE.
#
# Ces montants ne doivent JAMAIS apparaître sur un document client (PDF, mail,
# écran de présentation) : les cotisations sont à la charge de l'entreprise et
# n'ont rien à faire sur un devis ou une facture. D'où une table séparée des
# `estimations`, que les générateurs de PDF ne touchent pas.
#
# Les heures et le coût matière sont déduits du barème (Tarif / Prestation) à
# partir des surfaces déjà saisies, et restent corrigeables ligne à ligne :
# une valeur saisie l'emporte, une valeur vidée rend la main au barème.
class DevisAnalyse < ApplicationRecord
  belongs_to :estimation

  validates :estimation_id, uniqueness: true
  validates :heures_saisies, :cout_materiaux_saisi,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :autres_frais, numericality: { greater_than_or_equal_to: 0 }

  before_validation :figer_les_taux, on: :create

  # Saisie à la française ("12,5") comme partout ailleurs dans l'admin.
  %i[heures_saisies cout_materiaux_saisi autres_frais].each do |champ|
    define_method("#{champ}=") do |val|
      val = val.to_s.tr(",", ".").strip.presence if val.is_a?(String)
      super(val)
    end
  end

  # --- Valeurs retenues ------------------------------------------------------
  #
  # Ordre de priorité du coût matière : ce que Johan a saisi > ce que les
  # dépenses réelles disent > l'estimation du barème. Le réel prime sur la
  # prévision dès qu'il existe.
  def heures = heures_saisies.presence&.to_d || heures_auto

  def cout_materiaux
    return cout_materiaux_saisi.to_d if cout_materiaux_saisi.present?
    return cout_materiaux_reel if depenses_reelles?
    cout_materiaux_auto
  end

  def heures_estimees? = heures_saisies.blank?

  def materiaux_estimes? = cout_materiaux_saisi.blank? && !depenses_reelles?

  # --- Coût réellement constaté (module Dépenses) ---------------------------

  def depenses_reelles? = estimation.depenses.exists?

  # Matériaux + outillage + sous-traitance : ce qui est imputable au chantier.
  # Le carburant relève du déplacement, déjà facturé à part sur le devis.
  def cout_materiaux_reel
    estimation.depenses.where(categorie: %w[materiaux outillage sous_traitance]).sum(:montant).to_d
  end

  def depenses_total = estimation.depenses.sum(:montant).to_d

  # Écart entre ce que le barème annonçait et ce que le chantier a coûté.
  # C'est lui qui permet de recaler le barème sur la réalité.
  def ecart_materiaux
    return nil unless depenses_reelles?
    (cout_materiaux_reel - cout_materiaux_auto).round(2)
  end

  def ecart_materiaux_pct
    return nil unless depenses_reelles? && cout_materiaux_auto.positive?
    (ecart_materiaux / cout_materiaux_auto * 100).round(1)
  end

  # --- Dérivation depuis le barème ------------------------------------------

  # Un devis vient soit de lignes libres, soit de la structure pièces/murs.
  def lignes_barème
    @lignes_barème ||= estimation.devis_lignes.exists? ? lignes_depuis_devis_lignes : lignes_depuis_murs
  end

  def heures_auto         = lignes_barème.sum { |l| l[:heures] }.round(2)
  def cout_materiaux_auto = lignes_barème.sum { |l| l[:matiere] }.round(2)

  # Taux figés à la création (jamais rejoués si le barème change ensuite).
  def taux_global_fige = taux_cotisations.to_d + taux_cfp.to_d + taux_cma.to_d

  def resultats = AnalyseRentabilite.new(self).resultats

  # Rejoue la photographie des taux sur les réglages du jour — action explicite,
  # jamais automatique.
  def refiger_les_taux!
    figer_les_taux
    save!
  end

  private

  def figer_les_taux
    r = ReglageDeclaration.instance
    self.taux_cotisations   ||= r.taux_cotisations
    self.taux_cfp           ||= r.taux_cfp
    self.taux_cma           ||= r.taux_cma
    self.taux_impot         ||= r.taux_impot
    self.objectif_horaire   ||= r.objectif_horaire
    self.heures_par_jour    ||= r.heures_par_jour
    self.marge_securite_pct ||= r.marge_securite_pct
    self.seuil_marge_alerte_pct ||= r.seuil_marge_alerte_pct
    self.part_materiaux_max_pct ||= r.part_materiaux_max_pct
    self.taux_figes_at = Time.current
  end

  # Devis en lignes libres : la ligne pointe éventuellement sur une prestation
  # de la bibliothèque, qui porte le rendement et le coût matière.
  def lignes_depuis_devis_lignes
    estimation.devis_lignes.ordered.map do |ligne|
      bareme = ligne.prestation
      if ligne.forfait?
        { libelle: ligne.libelle, heures: heures_forfait, matiere: 0.to_d, source: :forfait }
      else
        quantite = ligne.quantite.to_d
        { libelle: ligne.libelle,
          heures:  heures_pour(quantite, bareme&.rendement_m2_h),
          matiere: (quantite * bareme&.cout_matiere_unite.to_d).round(2),
          source:  bareme&.rendement_m2_h.present? ? :bareme : :sans_bareme }
      end
    end
  end

  # Devis terrain : chaque mur porte une surface et une prestation dérivée
  # (PRESTATION_MAP + gamme) qui correspond à une ligne du barème Tarif.
  def lignes_depuis_murs
    lignes = []
    estimation.pieces.includes(:murs).each do |piece|
      piece.murs.each do |mur|
        next unless mur.total.to_d.positive?
        surface = mur.surface_nette.to_d
        tarif   = tarif_pour(mur)
        lignes << { libelle: "#{piece.nom} · #{mur.libelle}",
                    heures:  heures_pour(surface, tarif&.rendement_m2_h),
                    matiere: (surface * tarif&.cout_matiere_unite.to_d).round(2),
                    source:  tarif&.rendement_m2_h.present? ? :bareme : :sans_bareme }
        # Les travaux exceptionnels sont facturés au forfait : sans surface, ils
        # compteraient 0 h et gonfleraient artificiellement le taux horaire.
        %w[poncage rebouchage ratissage].each do |champ|
          next unless mur.public_send("#{champ}_forfait").to_d.positive?
          lignes << { libelle: "#{piece.nom} · #{champ}", heures: heures_forfait,
                      matiere: 0.to_d, source: :forfait }
        end
      end
    end
    lignes
  end

  def tarif_pour(mur)
    return nil if mur.prestation.blank?
    Tarif.find_by(prestation: mur.prestation, gamme: mur.gamme)
  end

  def heures_pour(quantite, rendement)
    r = rendement.to_d
    return 0.to_d unless r.positive?
    (quantite / r).round(2)
  end

  def heures_forfait = ReglageDeclaration.instance.heures_par_forfait.to_d
end
