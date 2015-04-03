#!/usr/bin/env ruby
require 'uri'

Dir.mkdir("songs") unless Dir.exists?("songs")

File.foreach(ARGV[0]).with_index { |line, line_num|
  if (line =~ /href=\"(.*)\"/)
     content = $1.gsub("irealb://","")
     allSongs = content.split("%3D%3D%3D")
     allSongs.each do |song|
     	title=URI.unescape(song.split("%3D")[0])
     	File.open("songs/#{title}", 'w') { |file| file.write(song) }
     end
     break
 end  
}