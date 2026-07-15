class Admin::DevisLignesController < Admin::BaseController
  before_action :set_estimation, only: %i[create renommer_section]
  before_action :set_ligne,      only: %i[update destroy]

  # Ajoute une ligne : vierge, ou pré-remplie depuis la bibliothèque (prestation_id).
  def create
    ligne = @estimation.devis_lignes.new(
      section:  params[:section].presence || section_courante,
      position: (@estimation.devis_lignes.maximum(:position) || 0) + 1
    )

    if (presta = Prestation.find_by(id: params[:prestation_id]))
      ligne.assign_attributes(
        prestation:    presta,
        libelle:       presta.nom,
        description:   presta.description,
        unite:         presta.unite,
        prix_unitaire: presta.prix,
        quantite:      presta.forfait? ? 1 : nil
      )
    else
      ligne.assign_attributes(libelle: "Nouvelle prestation", unite: "m2")
    end

    ligne.save!
    recompute_and_render
  end

  # Édition inline (autosave sur blur) : on met à jour la barre de total mais PAS
  # la liste (le champ garde le focus, pas de saut sur tablette).
  def update
    @ligne.update(ligne_params)
    @estimation.devis_recompute!
    @estimation.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("devis_total_bar",
          partial: "admin/devis/bar", locals: { estimation: @estimation })
      end
      format.html { redirect_to devis_lignes_admin_estimation_path(@estimation) }
    end
  end

  def destroy
    @ligne.destroy
    recompute_and_render
  end

  # Renomme une section : reporte le nouveau nom sur toutes ses lignes.
  def renommer_section
    ancienne = params[:ancienne].to_s
    nouvelle = params[:nouvelle].to_s.strip
    if nouvelle.present? && nouvelle != ancienne
      @estimation.devis_lignes.where(section: ancienne).update_all(section: nouvelle)
    end
    recompute_and_render
  end

  private

  # Ré-affiche la liste groupée + la barre de total (actions structurelles :
  # ajout / suppression / renommage — jamais pendant la frappe).
  def recompute_and_render
    @estimation.reload.devis_recompute!
    @estimation.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("devis_lignes_liste",
            partial: "admin/devis/lignes_liste", locals: { estimation: @estimation }),
          turbo_stream.replace("devis_total_bar",
            partial: "admin/devis/bar", locals: { estimation: @estimation })
        ]
      end
      format.html { redirect_to devis_lignes_admin_estimation_path(@estimation) }
    end
  end

  # Section par défaut d'une nouvelle ligne : celle de la dernière ligne, sinon « Travaux ».
  def section_courante
    @estimation.devis_lignes.ordered.last&.section.presence || "Travaux"
  end

  def set_estimation
    @estimation = Estimation.find(params[:estimation_id])
  end

  def set_ligne
    @ligne = DevisLigne.find(params[:id])
    @estimation = @ligne.estimation
  end

  def ligne_params
    params.require(:devis_ligne)
          .permit(:section, :libelle, :description, :quantite, :unite, :prix_unitaire)
  end
end
