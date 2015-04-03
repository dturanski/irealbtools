# IRealb tools

NOTE: For Mac OS/X only.

This script generates an iReal Pro playlist as html from a text file containg a song list.

This must be run from a machine that has iReal Pro installed and requires songs have been imported. The script searches `UserSongs.plist` in the default installed location for each song in the list.

## Usage:

```
$ ./irealb_playlist.rb <setlist> <playlistName>
```

This will create a file in the current directory named `<playlistName>.html` which may be opened in iReal Pro and/or uploaded to [http://irealb.com/forums]()

The search matches any chart that starts with a title in the list. If no match is found it treats content enclosed in parentheses as an alternate title. For example,
'Black Orpheus' will match 'Manha De Carnivale(Black Orpheus)'.

Also this will convert titles to a normalized format, ignoring parenthetical content, common punctuation marks which appear in song titles, such as `?` or `'` (with the exception of the above) and reformatting titles that start with `A` and `The` to move them to the end, preceded by `,`. For example, `The Entertainer` will match `Entertainer, The`

If multiple matches are found, you will be prompted to select one or all of the matched items. If a title is not found, you will see a warning message and the process will continue.
