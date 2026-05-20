class PagesController < ApplicationController
  def home
  end

  def services
  end

  def realisations
  end

  def contact
  end

  def mentions_legales
  end

  def politique_confidentialite
  end

  def cgu
  end

  def sitemap
    @urls = [
      { loc: root_url,                       priority: 1.0, changefreq: "weekly" },
      { loc: services_url,                   priority: 0.8, changefreq: "monthly" },
      { loc: realisations_url,               priority: 0.8, changefreq: "weekly" },
      { loc: contact_url,                    priority: 0.6, changefreq: "yearly" },
      { loc: new_estimation_url,             priority: 0.9, changefreq: "monthly" },
      { loc: mentions_legales_url,           priority: 0.2, changefreq: "yearly" },
      { loc: politique_confidentialite_url,  priority: 0.2, changefreq: "yearly" },
      { loc: cgu_url,                        priority: 0.2, changefreq: "yearly" }
    ]
    respond_to { |format| format.xml }
  end
end
