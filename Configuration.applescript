---- Core configuration ----

-- Configurable options --

-- limit number of songs to improve efficiency
property songLimit : 9
-- whether or not to retrieve album artwork for each result
property albumArtEnabled : true

-- Script parameters (do not change these) --

-- paths to important directories
property homeFolder : (path to home folder as text)
property libraryFolder : (path to library folder from user domain as text)
property cacheFolder : (libraryFolder & "Caches:")
property alfredWorkflowDataFolder : (cacheFolder & "com.runningwithcrayons.Alfred-2:Workflow Data:")
property bundleId : "com.calebevans.playsong"
property workflowDataFolder : (alfredWorkflowDataFolder & bundleId & ":") as text
property artworkCacheFolderName : "Album Artwork"
property artworkCachePath : (workflowDataFolder & artworkCacheFolderName & ":")
property songArtworkNameSep : " | "
property defaultIconName : "icon-noartwork.png"
-- the name of the playlist this workflow uses for playing songs
property workflowPlaylistName : "Alfred Play Song"
-- the text used to determine if a track is an audio file
property songDescriptor : "audio"

-- replaces substring in string with another substring
on replace(replaceThis, replaceWith, originalStr)
	set AppleScript's text item delimiters to replaceThis
	set strItems to text items of originalStr
	set AppleScript's text item delimiters to replaceWith
	return strItems as text
end replace

-- encodes XML reserved characters in the given string
on encodeXmlChars(str)
	set str to replace("&", "&amp;", str)
	set str to replace("<", "&lt;", str)
	set str to replace(">", "&gt;", str)
	set str to replace("\"", "&quot;", str)
	set str to replace("'", "&apos;", str)
	return str
end encodeXmlChars

-- decodes XML reserved characters in the given string
on decodeXmlChars(str)
	set str to replace("&amp;", "&", str)
	set str to replace("&lt;", "<", str)
	set str to replace("&gt;", ">", str)
	set str to replace("&quot;", "\"", str)
	set str to replace("&apos;", "'", str)
	return str
end decodeXmlChars

-- builds Alfred result item as XML
on createXmlItem(itemUid, itemArg, itemValid, itemTitle, itemSubtitle, itemIcon)
	
	-- encode reserved XML characters
	set itemUid to encodeXmlChars(itemUid)
	set itemArg to encodeXmlChars(itemArg)
	set itemTitle to encodeXmlChars(itemTitle)
	set itemSubtitle to encodeXmlChars(itemSubtitle)
	if itemIcon contains ":" then
		set itemIcon to POSIX path of itemIcon
		set itemIcon to encodeXmlChars(itemIcon)
	end if
	
	return tab & "<item uid='" & itemUid & "' arg='" & itemArg & "' valid='" & itemValid & "'>
		<title>" & itemTitle & "</title>
		<subtitle>" & itemSubtitle & "</subtitle>
		<icon>" & itemIcon & "</icon>
	</item>" & return & return
	
end createXmlItem

-- creates XML declaration for Alfred results
on createXmlHeader()
	return "<?xml version='1.0'?>" & return & "<items>" & return & return
end createXmlHeader

-- creates XML footer for Alfred results
on createXmlFooter()
	return "</items>"
end createXmlFooter

-- reads the given file
on fileRead(theFile)
	set fileRef to open for access theFile
	set theContent to (read theFile)
	close access fileRef
	return theContent
end fileRead

-- writes the given content to the given file
on fileWrite(theFile, theContent)
	set fileRef to open for access theFile with write permission
	set eof of fileRef to 0
	write theContent to fileRef starting at eof
	close access fileRef
end fileWrite

-- appends the given content to the given file
on fileAppend(theFile, theContent)
	try
		set fileRef to open for access theFile with write permission
		write theContent to fileRef starting at eof
		close access fileRef
	on error
		close access fileRef
	end try
end fileAppend

-- builds path to album art for the given song
on getSongArtworkPath(theSong)
	if albumArtEnabled is false then
		set songArtworkPath to defaultIconName
	else
		tell application "iTunes"
			set songArtist to artist of theSong
			set songAlbum to album of theSong
			-- generate a unique identifier for that album
			set songArtworkName to (songArtist & songArtworkNameSep & songAlbum) as text
			-- remove forbidden path characters
			set songArtworkName to replace(":", "", songArtworkName) of me
			set songArtworkName to replace("/", "", songArtworkName) of me
			set songArtworkName to replace(".", "", songArtworkName) of me
			set songArtworkPath to (artworkCachePath & songArtworkName & ".jpg")
		end tell
		
		tell application "Finder"
			-- cache artwork if it's not already cached
			if not (songArtworkPath exists) then
				tell application "iTunes"
					set songArtworks to artworks of theSong
					-- only save artwork if artwork exists for this song
					if (length of songArtworks) is 0 then
						-- use default iTunes itemIcon if song has no artwork
						set songArtworkPath to defaultIconName
					else
						-- save artwork to file
						set songArtwork to data of (item 1 of songArtworks)
						fileWrite(songArtworkPath, songArtwork) of me
					end if
				end tell
			end if
		end tell
	end if
	return songArtworkPath
	
end getSongArtworkPath

-- creates folder for workflow data if it does not exist
on createWorkflowDataFolder()
	tell application "Finder"
		if not (alias workflowDataFolder exists) then
			make new folder in alfredWorkflowDataFolder with properties {name:bundleId}
		end if
	end tell
end createWorkflowDataFolder

-- creates folder for album artwork cache if it does not exist
on createArtworkCache()
	createWorkflowDataFolder()
	if albumArtEnabled is true then
		tell application "Finder"
			if not (alias artworkCachePath exists) then
				make new folder in workflowDataFolder with properties {name:artworkCacheFolderName}
			end if
		end tell
	end if
end createArtworkCache

-- creates album artwork cache
on createWorkflowPlaylist()
	tell application "iTunes"
		if not (playlist workflowPlaylistName exists) then
			make new playlist with properties {name:workflowPlaylistName, shuffle:false}
		end if
	end tell
end createWorkflowPlaylist

-- plays the given songs in the workflow playlist
on playSongs(theSongs)
	tell application "iTunes"
		-- empty workflow playlist
		delete tracks of playlist workflowPlaylistName
		-- add songs to playlist
		repeat with theSong in theSongs
			duplicate theSong to playlist workflowPlaylistName
		end repeat
		-- beginning playing songs in playlist if not empty
		if number of tracks in playlist workflowPlaylistName is greater than 0 then
			play playlist workflowPlaylistName
		end if
	end tell
end playSongs

-- disables shuffle mode for songs
on disableShuffle()
	tell application "System Events"
		tell process "iTunes"
			click menu item 2 of menu 1 of menu item "Shuffle" of menu 1 of menu bar item "Controls" of menu bar 1
		end tell
	end tell
end disableShuffle

-- retrieve list of artist names for the given genre 
on getGenreArtists(genreName)
	
	tell application "iTunes"
		set theSongs to every track of playlist 2 whose genre is genreName and kind contains songDescriptor
		set artistNames to {}
		repeat with theSong in theSongs
			if (artist of theSong) is not in artistNames then
				set artistNames to artistNames & (artist of theSong)
			end if
		end repeat
	end tell
	return artistNames
	
end getGenreArtists

-- retrieve list of songs within the given genre, sorted by artist
on getGenreSongs(genreName)
	
	set artistNames to getGenreArtists(genreName) of me
	set theSongs to {}
	repeat with artistName in artistNames
		set theSongs to theSongs & getArtistSongs(artistName) of me
	end repeat
	return theSongs
	
end getGenreSongs

-- retrieve list of album names for the given artist 
on getArtistAlbums(artistName)
	
	tell application "iTunes"
		set theSongs to every track of playlist 2 whose artist is artistName and kind contains songDescriptor
		set albumNames to {}
		repeat with theSong in theSongs
			if (album of theSong) is not in albumNames then
				set albumNames to albumNames & (album of theSong)
			end if
		end repeat
	end tell
	return albumNames
	
end getArtistAlbums

-- retrieve list of songs by the given artist, sorted by album
on getArtistSongs(artistName)
	
	tell application "iTunes"
		set albumNames to getArtistAlbums(artistName) of me
		set theSongs to {}
		repeat with albumName in albumNames
			set albumSongs to (every track of playlist 2 whose artist is artistName and album is albumName)
			set albumSongs to sortSongsByAlbumOrder(albumSongs) of me
			set theSongs to theSongs & albumSongs
		end repeat
	end tell
	return theSongs
	
end getArtistSongs

-- retrieve list of songs in the given album
on getAlbumSongs(albumName)
	tell application "iTunes"
		set theSongs to every track of playlist 2 whose album is albumName and kind contains songDescriptor
		set theSongs to sortSongsByAlbumOrder(theSongs) of me
	end tell
	return theSongs
end getAlbumSongs

-- Sort songs from the same album by track number
on sortSongsByAlbumOrder(theSongs)
	tell application "iTunes"
		set theSongsSorted to {} as list
		if length of theSongs is greater than 1 then
			set trackCount to track count of (item 1 of theSongs)
			repeat with songIndex from 1 to trackCount
				repeat with theSong in theSongs
					if track number of theSong is songIndex then
						set nextSong to theSong
						copy nextSong to the end of theSongsSorted
					end if
				end repeat
			end repeat
		else
			set theSongsSorted to theSongs
		end if
	end tell
	return theSongsSorted
end sortSongsByAlbumOrder

-- retrieves the song with the given ID
on getSong(songId)
	tell application "iTunes"
		get first track whose database ID is songId and kind contains songDescriptor
	end tell
end getSong