#!/usr/bin/env ruby
require 'erb'
require 'uri'

$playlist=[]

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
            <p><%=@song.index%>.<%=' '+@song.title%> - <%=@song.author%><br>
            <% end %>
            </p><br />
            <br />Made with iReal Pro
            <a href="http://www.irealpro.com"><img src="http://www.irealb.com/forums/images/images/misc/ireal-pro-logo-50.png" width="25" height="25" hspace="10" alt=""/></a>
            <br /><br /><span class="help">To import this song/playlist tap or click the link at the top on an iOS device, Mac or Android device with iReal Pro installed.</span><br />
          </body>
       </html>
  }
 end

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

  def save(file)
    File.open(file, "w+") do |f|
      f.write(render)
    end
  end
end

class Song 
	attr_accessor :title, :author, :content, :index
	def initialize(title, author, content, index)
		@title = title
    	@author = author
    	@content = content
    	@index = index
	end   
end


def generatePlaylist(dir, name) 
	songs = []

	playlistUri = "irealb://"

	$playlist.each_with_index {|chart, i|
		fname = [dir,chart].join('/')
		content = (File.readlines(fname))[0]
		title,author = content.split("%3D")
		title = URI.unescape(title)
		author = URI.unescape(author)
		songs << Song.new(title,author,content, i + 1)
		playlistUri << content
		playlistUri << "%3D%3D%3D"
	}
	playlistUri << URI.escape(name)

	#puts playlistUri
	list = PlayList.new(name, songs, playlistUri, getTemplate())
	list.save(File.new("#{name}.html", "w"));
end



#
# Read a set list and create a playlist
# Search for songs in the list
#
def normalize(title) 
	normal = title
	#remove special characters
	normal = normal.gsub(/[\?']/ , '')
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
#
#
def search(songCatalog, title)
	songs = []
	songCatalog.each { |songTitle|
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
#
#
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
#
def addToPlaylist(title)
	#puts "#{title}"
	$playlist << title
end

#
#
#
def findChart(title, songCatalog)
	songs = search(songCatalog, title)
	if (songs.size() > 1) 
		title = choose(title, songs)
		if (title == nil)
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
if ARGV[0] == nil || ARGV[1] == nil || ARGV[2] == nil
    puts "Usage: ./irealb_playlist.rb <setlist> <songCatalogDirectory> <playlistName>"
    exit
end

setlist = ARGV[0]
File.exists?(setlist) || die("input file #{setlist} does not exist.")
songCatalogDir = ARGV[1]
File.directory?(songCatalogDir) || die("Song catalog not found at #{songCatalogDir}.")

songCatalog = Dir.entries(songCatalogDir)

File.open(setlist, "r").each_line { |line| 
	title = line.rstrip
	if (findChart(title, songCatalog).size() == 0)
		puts "WARNING: Cannot find #{title} in the catalog."
	end
}

name = ARGV[2]

generatePlaylist(songCatalogDir, name)



