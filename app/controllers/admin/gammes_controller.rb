class Admin::GammesController < Admin::BaseController
  # Comparatif des prestations × gammes pour argumenter face au client
  # (« pourquoi choisir telle gamme »). Alimenté par la table Tarif → reste
  # synchro avec /admin/tarifs.
  def index
    tarifs = Tarif.actifs.index_by { |t| [t.prestation, t.gamme] }

    # { "peinture" => [ [prestation_key, {label,...}], ... ], ... }
    @par_categorie = Tarif::PRESTATIONS_CHOISISSABLES
                       .group_by { |_key, meta| meta[:categorie] }

    # Accès aux prix/descriptions : @tarif.call(prestation, gamme) → Tarif | nil
    @tarif = ->(prestation, gamme) { tarifs[[prestation, gamme]] }
  end
end
