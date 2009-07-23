# This is a tiny utility script to update your iTunes Library's played counts to match your last.fm listening data
#  This is useful if you've had to rebuild your library for any reason.
#  The utility only updates tracks for which the last.fm play count is greater than the iTunes play count.
# Because of how cool the AppleScript hooks are, watch your iTunes libary as this script works!

username = ARGV.first

require 'open-uri'
require 'nokogiri' rescue "This script depends on the Nokogiri gem. Please run '(sudo) gem install nokogiri'."
require 'appscript' rescue "This script depends on the rb-appscript gem. Please run '(sudo) gem install rb-appscript'."
include Appscript

filename = "cached_lastfm_data.rbmarshal"
begin
  playcounts = Marshal.load(File.read(filename))
  puts "Reading cached playcount data from disk"
rescue
  puts "No cached playcount data, grabbing fresh data from Last.fm"
  playcounts = {}

  Nokogiri::HTML(open("http://ws.audioscrobbler.com/2.0/user/#{username}/weeklychartlist.xml")).search('weeklychartlist').search('chart').each do |chartinfo|
    from = chartinfo['from']
    to = chartinfo['to']
    time = Time.at(from.to_i)
    puts "Getting listening data for week of #{time.year}-#{time.month}-#{time.day}"
    sleep 0.1
    begin
      Nokogiri::HTML(open("http://ws.audioscrobbler.com/2.0/user/#{username}/weeklytrackchart.xml?from=#{from}&to=#{to}")).search('weeklytrackchart').search('track').each do |track|
        artist = track.search('artist').first.content.downcase.gsub(/[^\w]/, "").gsub("the", "")
        name = track.search('name').first.content.downcase.gsub(/[^\w]/, "").gsub("the", "")
        playcounts[artist] ||= {}
        playcounts[artist][name] ||= 0
        playcounts[artist][name] += track.search('playcount').first.content.to_i
      end
    rescue
      puts "Error getting listening data for week of #{time.year}-#{time.month}-#{time.day}"
    end
  end

  puts "Saving playcount data"
  File.open(filename, "w+") do |file|
    file.puts(Marshal.dump(playcounts))
  end
end

iTunes = app('iTunes')
iTunes.tracks.get.each do |track|
  begin
    artist = playcounts[track.artist.get.downcase.gsub(/[^\w]/, "").gsub("the", "")]
    if artist.nil?
      puts "Couldn't match up #{track.artist.get}"
      next
    end

    playcount = artist[track.name.get.downcase.gsub(/[^\w]/, "").gsub("the", "")]
    if playcount.nil?
      puts "Couldn't match up #{track.artist.get} - #{track.name.get}"
      next
    end

    if playcount > track.played_count.get
      puts "Setting #{track.artist.get} - #{track.name.get} to playcount of #{playcount} from playcount of #{track.played_count.get}"
      track.played_count.set(playcount)
    else
      puts "Track #{track.artist.get} - #{track.name.get} is chill at playcount of #{playcount}"
    end
  rescue
    puts "Encountered some kind of error on this track"
  end
end
