# Génère un flux iCalendar (.ics) des RDV, avec une alarme (rappel) par événement
# → notifications natives une fois l'agenda ajouté/abonné sur le téléphone.
class RdvIcal
  def self.feed(rdvs) = new(rdvs).feed

  def initialize(rdvs) = @rdvs = rdvs

  def feed
    lines = [
      "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//JF Habitat//Agenda//FR",
      "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:JF Habitat — Agenda",
      "X-WR-TIMEZONE:Europe/Paris"
    ]
    @rdvs.each { |r| lines.concat(vevent(r)) }
    lines << "END:VCALENDAR"
    lines.join("\r\n") + "\r\n"
  end

  private

  def vevent(r)
    l = ["BEGIN:VEVENT", "UID:rdv-#{r.id}@jfhabitat.fr", "DTSTAMP:#{stamp(Time.current)}"]
    if r.all_day
      l << "DTSTART;VALUE=DATE:#{r.jour.strftime('%Y%m%d')}"
      l << "DTEND;VALUE=DATE:#{(r.date_fin + 1).strftime('%Y%m%d')}"
    else
      l << "DTSTART:#{stamp(r.starts_at)}"
      l << "DTEND:#{stamp(r.ends_at || r.starts_at + 3600)}"
    end
    l << "SUMMARY:#{esc("#{r.categorie_label} — #{r.titre}")}"
    l << "LOCATION:#{esc(r.adresse)}" if r.adresse.present?
    desc = [r.notes.presence, (r.client ? "Client : #{r.client.nom} · #{r.client.telephone}" : nil)].compact.join("\n")
    l << "DESCRIPTION:#{esc(desc)}" if desc.present?
    l << "STATUS:#{r.statut == 'annule' ? 'CANCELLED' : 'CONFIRMED'}"
    l.concat(["BEGIN:VALARM", "ACTION:DISPLAY",
              "DESCRIPTION:#{esc("Rappel : #{r.titre}")}",
              "TRIGGER:#{r.all_day ? '-PT12H' : '-PT1H'}", "END:VALARM"])
    l << "END:VEVENT"
    l
  end

  def stamp(t) = t.utc.strftime("%Y%m%dT%H%M%SZ")

  def esc(s)
    s.to_s.gsub(/([\\;,])/) { "\\#{Regexp.last_match(1)}" }.gsub(/\r?\n/, "\\n")
  end
end
