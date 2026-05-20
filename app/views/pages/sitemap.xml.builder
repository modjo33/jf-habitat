xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @urls.each do |url|
    xml.url do
      xml.loc        url[:loc]
      xml.lastmod    Date.current.iso8601
      xml.changefreq url[:changefreq]
      xml.priority   url[:priority]
    end
  end
end
