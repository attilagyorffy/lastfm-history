# Last.fm Listening History Exporter

Download your complete Last.fm listening history to JSON format.

## Features

- Downloads entire scrobble history via Last.fm API
- Automatic pagination and rate limiting
- Smart SSL detection (tests once, uses working method)
- Auto-save every 50 pages to prevent data loss
- Progress tracking

## Requirements

- Ruby 2.7+
- Last.fm API key (free)

## Setup

1. Get your API key from https://www.last.fm/api/account/create

2. Set your credentials:
   ```bash
   export LASTFM_API_KEY="your_api_key_here"
   export LASTFM_USERNAME="your_username"
   ```

   Or edit the script directly and replace `YOUR_API_KEY_HERE` and `YOUR_USERNAME_HERE`

## Usage

```bash
ruby lastfm_exporter.rb
```

Output will be saved to `lastfm_history.json`

## Output Format

```json
{
  "export_date": "2025-11-20T23:14:40Z",
  "username": "LQDAudio",
  "total_tracks": 119447,
  "tracks": [
    {
      "artist": {
        "url": "https://www.last.fm/music/Music+Instructor",
        "name": "Music Instructor",
        "image": [
          {
            "size": "small",
            "#text": "https://lastfm.freetls.fastly.net/i/u/34s/2a96cbd8b46e442fc41c2b86b821562f.png"
          },
          {
            "size": "medium",
            "#text": "https://lastfm.freetls.fastly.net/i/u/64s/2a96cbd8b46e442fc41c2b86b821562f.png"
          },
          {
            "size": "large",
            "#text": "https://lastfm.freetls.fastly.net/i/u/174s/2a96cbd8b46e442fc41c2b86b821562f.png"
          },
          {
            "size": "extralarge",
            "#text": "https://lastfm.freetls.fastly.net/i/u/300x300/2a96cbd8b46e442fc41c2b86b821562f.png"
          }
        ],
        "mbid": ""
      },
      "artist_mbid": "",
      "album": "Super Fly (Upper MC)",
      "album_mbid": "",
      "track": "Super Fly (Maxi Version)",
      "track_mbid": "7e838de3-9597-474d-b479-d9c4a7b910d8",
      "timestamp": 1763330391,
      "date": "16 Nov 2025, 21:59",
      "url": "https://www.last.fm/music/Music+Instructor/_/Super+Fly+(Maxi+Version)",
      "image": "https://lastfm.freetls.fastly.net/i/u/174s/2a96cbd8b46e442fc41c2b86b821562f.png",
      "loved": false
    }
  ]
}
```

## Troubleshooting

**SSL certificate errors**: The script automatically detects SSL issues and uses the appropriate method. You may see one warning at startup, but the download will proceed normally.

**API errors**: The script retries failed requests up to 3 times before giving up. Check your internet connection and API key if you see repeated failures.

**Rate limiting**: Built-in 250ms delay between requests respects Last.fm's rate limits.