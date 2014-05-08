#!/usr/bin/env ruby
require 'io/console'
require 'mechanize'

class MyFileSaver < Mechanize::FileSaver
  def extract_filename
    filename = super
    filename.sub!(/downloadimage\.php.file=/, '')
    puts "Downloading #{filename}..."
    filename
  end
end

class Session

  Album = Struct.new(:name, :date, :url)

  def base_uri
    "http://petalshub.com/"
  end

  def agent
    unless @agent
      agent ||= Mechanize.new
      agent.pluggable_parser.default = MyFileSaver
      @agent = agent
    end
    @agent
  end

  def login(username, password)
    page = agent.get(base_uri + "parentsfriends.php")
    form = page.form("loginFrm")
    form.login_id = username
    form.password = password
    form.submit
    self
  end

  def albums
    page = agent.get("par_viewphotos.php")
    albums = []
    page.links.select{|l| l.href =~ /par_viewalbumphotos/}.each do |link|
      url = link.href
      row = link.node.ancestors("tr").css("td")
      name = row[0].content
      date = Date.parse(row[1].content)
      albums << Album.new(name, date, url)
    end
    albums
  end

  def photos(album)
    page = agent.get(album.url)
    page.links.select{|l| l.href =~ /downloadimage.php/}
  end

  def download(photo)
    agent.get(photo.href)
  end
end

print "Login: "
login = readline.chop
print "Password: "
password = STDIN.noecho { readline.chop }

session = Session.new.login(login, password)
albums = session.albums
abort "No albums found!" unless albums.count > 0
puts "Found #{albums.count} album(s):"
albums.each_with_index do |album, idx|
  puts "%2i. %40s [%s]" % [idx + 1, album.name, album.date]
end
print "Which album number? "
nr = readline.to_i
album = albums[nr - 1]
photos = session.photos(album)
photos.each do |photo|
  session.download(photo)
end
