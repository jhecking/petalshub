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

  attr_accessor :cookies

  Album = Struct.new(:name, :date, :url)

  def initialize(cookies = "cookies.yaml")
    self.cookies = cookies
    restore
  end

  def base_uri
    "http://petalshub.com/"
  end

  def restore
    if File.exists?(cookies)
      agent.cookie_jar.load(cookies)
    end
  end

  def persist
    agent.cookie_jar.save(cookies, session: true)
  end

  def agent
    unless @agent
      agent ||= Mechanize.new
      agent.pluggable_parser.default = MyFileSaver
      agent.redirect_ok = false
      # agent.log = Logger.new(STDOUT)
      @agent = agent
    end
    @agent
  end

  def get(uri)
    response = agent.get(uri)
    if response.code =~ /302/
      login
      response = agent.get(uri)
    end
    response
  end

  def login
    print "Login: "
    username = readline.chop
    print "Password: "
    password = STDIN.noecho { readline.chop }
    puts
    page = get(base_uri + "parentsfriends.php")
    form = page.form("loginFrm")
    form.login_id = username
    form.password = password
    form.submit
    self
  end

  def albums
    page = get(base_uri + "par_viewphotos.php")
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
    page = get(album.url)
    page.links.select{|l| l.href =~ /downloadimage.php/}
  end

  def download(photo)
    get(photo.href)
  end
end


session = Session.new
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
session.persist
