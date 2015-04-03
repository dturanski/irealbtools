#!/usr/bin/env ruby


# For Mac OS/X only.
#
# This script generates an iReal Pro playlist as html from a text file containg a song list.
# Requires iReal Pro installed and all the songs have been imported. It searches 
# 'UserSongs.plist' in the default installed location for each song in the list.
# 
# Usage:
#
# ./irealb_playlist.rb <setlist> <playlistName>"
#
# This will create <playlistName>.html which may be opened in iReal Pro and/or uploaded
# to http://irealb.com/forums
#
# The search matches any chart that starts with a title in the list. If no match is 
# found it treats content enclosed in parentheses as an alternate title. For example,
# 'Black Orpheus' will match 'Manha De Carnivale(Black Orpheus)'.
#
# If multiple matches are found, you will be prompted to select one or all of the matched
# items. If a title is not found, you will see a warning message and the process will continue
#
$LOAD_PATH  << './lib'
require 'erb'
require 'uri'
require 'plist'

$playlist=[]

#
# The OS/X path to iReal b User Songs. Assumes iReal Pro is installed locally 
#
$SongCatalog=ENV['HOME'] + '/Library/Containers/com.massimobiolcati.irealbookmac/Data/Library/Application Support/iReal b/UserSongs.plist'

#
# Parse the plist
def loadSongCatalog()
	File.exists?($SongCatalog) || abort("File not found #{$SongCatalog}. Is iReal Pro installed?")
	return Plist::parse_xml($SongCatalog)
end

#
#HTML ERB Template
def getTemplate() 
	%{
       <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
           <head>
            <meta name="viewport" content="width=device-width, minimum-scale=1, maximum-scale=1" />
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
            <title>iReal Pro</title>
            <style type="text/css">
                .help {
                     font-size: small;
                     color: #999999;
                }
            </style>
          </head>
          <body style="color: rgb(230, 227, 218); background-color: rgb(27, 39, 48); font-family: Helvetica,Arial,sans-serif;" alink="#b2e0ff" link="#94d5ff" vlink="#b2e0ff">
             <br /><br /><h3>
             	<a href="<%=@playlistUri%>"><%=@name%></a>(<%=@songs.size%>)<br />
             </h3>
             <br />
            <% for @song in @songs %>
            <p><%=@song.index%>.<%=' '+@song.title%> - <%=@song.composer%><br>
            <% end %>
            </p><br />
            <br />Made with iReal Pro
            <a href="http://www.irealpro.com"><img src="http://www.irealb.com/forums/images/images/misc/ireal-pro-logo-50.png" width="25" height="25" hspace="10" alt=""/></a>
            <br /><br /><span class="help">To import this song/playlist tap or click the link at the top on an iOS device, Mac or Android device with iReal Pro installed.</span><br />
          </body>
       </html>
  }
 end

#
# Holds the data used by the template
class PlayList
  include ERB::Util
  attr_accessor :name, :songs, :template, :playlistUri

  def initialize(name, songs, playlistUri,template)
  	@name = name
    @songs = songs
    @template = template
    @playlistUri = playlistUri
  end

  def render()
    ERB.new(@template,0,'>').result(binding)
  end

  def save()
    File.open("#{@name}.html", "w+") do |f|
      f.write(render)
    end
  end
end

class Song 
	Song::FIELD_SEPARATOR = "="
	attr_accessor :title, :composer, :chordProgression, :style, :index
	def initialize(data, index)
		@data = data
		@title = data['title']
		@composer = data['composer']
		@chordProgression = data['chordProgression']
		@style = data['style']
		@key = data['keySignature']
    	@index = index

	end

	#
	# format the content
	def content()
		content = ""
		content << @title << FIELD_SEPARATOR <<@composer << FIELD_SEPARATOR << FIELD_SEPARATOR
		content << @style << FIELD_SEPARATOR
		content << @key << FIELD_SEPARATOR << FIELD_SEPARATOR
		content << @chordProgression
		content << FIELD_SEPARATOR << FIELD_SEPARATOR << '0' << FIELD_SEPARATOR << '0'
		content = URI.escape(content,/[^a-zA-Z0-9\-\*\/]/)
 	end
end

#
# Build the playlist
def generatePlaylist(songCatalog, name) 
	songs = []

	playlistUri = "irealb://"

	$playlist.each_with_index {|songTitle, i|
		result = songCatalog.select{|hash| hash["title"] == songTitle }
		song = Song.new(result[0], i+1)
		songs << song
		playlistUri << song.content()
		playlistUri << "%3D%3D%3D"
	}
	playlistUri << URI.escape(name)

	list = PlayList.new(name, songs, playlistUri, getTemplate())
	list.save();
end



#
# Reformat titles to enable a match
def normalize(title) 
	normal = title
	#remove special characters
	normal = normal.gsub(/[^\w\s]/ , '')
	#format titles beginning with 'A' and 'The'
	if (title.start_with?('The ')) 
		normal = title.sub(/^The\s+/,'') + ', The'
	elsif (title.start_with?('A '))
		normal = title.sub(/^A\s+/,'') + ', A'
	end
	#remove other ','s
	if (!normal.end_with?(', The') && !normal.end_with?(', A'))
		normal = normal.gsub(/\,/,'')
	end
	#remove parenthetical content
	if normal.include? '('
  		normal = normal.gsub(/\s*(\([^)]+\))\s*/,'');
	end	

	return normal
end

#
# search the song catalog for a title
def search(title,songCatalog)
	songs = []
	songCatalog.each { |chart|
		songTitle = chart['title']
		normalTitle = normalize(title)
		normalSongTitle = normalize(songTitle)

		if (normalSongTitle.upcase.start_with?(normalTitle.upcase))
			songs << songTitle
		elsif songTitle.include?('(')
			alternate = songTitle.match(/\(([^)]+)\)/i).captures[0]
			normalSongTitle = normalize(alternate)
			if (normalSongTitle.upcase.start_with?(normalTitle.upcase))
				songs << songTitle
			end	
		end
	}
	return songs
end

#
# Prompt the user to choose if multiple songs match a title
def choose(title, songs) 
	puts "'#{title}' matches more than one chart."
	songs.each_with_index { |s,i|
		puts "#{i+1}. #{s}"
	}
	puts "Please make a selection or <RETURN> for all"
	index = 0
	while (!index.is_a?(Integer) || index < 1 || index > songs.size()) do
		index = STDIN.gets.chomp
		if (index.size() == 0) 
			return nil
		end
		index = index.to_i

		if (!index.is_a?(Integer) || index < 1 || index > songs.size())
				puts "Please enter a number between 1 and #{songs.size()}"
		end
	end
	return songs[index-1]
end

#
#
def addToPlaylist(title)
	$playlist << title
end

#
# search and narrow choices for multiple hits if necessary
def findChart(title, songCatalog)
	songs = search(title, songCatalog)
	if (songs.size() > 1) 
		title = choose(title, songs)
		if (title == nil) #user selected all
			songs.each { |s|
				addToPlaylist(s)
			}
		else
			addToPlaylist(title)
		end
	elsif (songs.size() == 1)
		addToPlaylist(songs[0])
 	end
	return songs
end

#
# Main
#
if ARGV[0] == nil || ARGV[1] == nil
    puts "Usage: ./irealb_playlist.rb <setlist> <playlistName>"
    exit
end

setlist = ARGV[0]
name = ARGV[1]
File.exists?(setlist) || abort("input file #{setlist} does not exist.")
songs = loadSongCatalog()

File.open(setlist, "r").each_line { |line| 
	title = line.rstrip
	if (title.size > 0) 
		if (findChart(title, songs).size() == 0)
			puts "No chart found for '#{title}'."
		end
	end
}

generatePlaylist(songs, name)



