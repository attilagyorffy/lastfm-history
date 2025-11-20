#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'time'
require 'openssl'

# Downloads complete Last.fm listening history via API
class LastfmExporter
  API_BASE_URL = 'https://ws.audioscrobbler.com/2.0/'
  TRACKS_PER_PAGE = 200
  RATE_LIMIT_DELAY = 0.25
  MAX_RETRIES = 3
  RETRY_DELAY = 2
  AUTO_SAVE_INTERVAL = 50

  attr_reader :api_key, :username, :tracks

  def initialize(api_key, username)
    @api_key = api_key
    @username = username
    @tracks = []
    @ssl_verify_mode = determine_ssl_mode
  end

  def export(output_file = 'lastfm_history.json')
    print_header(output_file)

    total_tracks = fetch_total_tracks or return
    total_pages = (total_tracks.to_f / TRACKS_PER_PAGE).ceil

    puts "Total tracks to download: #{total_tracks}"
    puts "Total pages: #{total_pages}\n\nStarting download...\n\n"

    download_pages(total_pages, output_file)
    save_to_file(output_file)

    print_footer(output_file)
  end

  private

  def determine_ssl_mode
    print 'Testing SSL connection... '

    Net::HTTP.start(*http_connection_params(OpenSSL::SSL::VERIFY_PEER)) do |http|
      http.request(Net::HTTP::Get.new(build_uri(user_info_params)))
    end

    puts '✓ Using secure SSL verification'
    OpenSSL::SSL::VERIFY_PEER
  rescue OpenSSL::SSL::SSLError
    puts '⚠ SSL certificate issue detected, using relaxed verification'
    OpenSSL::SSL::VERIFY_NONE
  ensure
    puts
  end

  def fetch_total_tracks
    puts 'Fetching user information...'

    response = make_request(recent_tracks_params(limit: 1, page: 1)) or return
    data = parse_json(response.body) or return

    return puts("Error: #{data['message']}") if data['error']

    data.dig('recenttracks', '@attr', 'total')&.to_i
  end

  def download_pages(total_pages, output_file)
    (1..total_pages).each do |page|
      break unless fetch_page(page, total_pages)

      save_to_file(output_file, partial: true) if (page % AUTO_SAVE_INTERVAL).zero?
      sleep RATE_LIMIT_DELAY unless page == total_pages
    end
  end

  def fetch_page(page, total_pages)
    with_retry(page) do
      response = make_request(recent_tracks_params(page: page, extended: 1)) or next false
      data = parse_json(response.body) or next false
      next false if data['error']

      process_tracks(data)
      display_progress(page, total_pages)
      true
    end
  end

  def with_retry(page, max_attempts: MAX_RETRIES)
    attempts = 0

    loop do
      result = yield
      return result if result

      attempts += 1
      if attempts >= max_attempts
        puts "\nFailed to fetch page #{page} after #{max_attempts} retries"
        return false
      end

      print "\rRetrying page #{page} (#{attempts}/#{max_attempts})..."
      sleep RETRY_DELAY
    end
  end

  def process_tracks(data)
    tracks = Array(data.dig('recenttracks', 'track'))
    return if tracks.empty?

    tracks.each do |track|
      processed = build_track_hash(track)
      @tracks << processed if processed
    end
  end

  def build_track_hash(track)
    return if currently_playing?(track)

    {
      artist: track.dig('artist', '#text') || track['artist'],
      artist_mbid: track.dig('artist', 'mbid'),
      album: track.dig('album', '#text'),
      album_mbid: track.dig('album', 'mbid'),
      track: track['name'],
      track_mbid: track['mbid'],
      timestamp: track.dig('date', 'uts')&.to_i,
      date: track.dig('date', '#text'),
      url: track['url'],
      image: extract_image_url(track['image']),
      loved: track['loved'] == '1'
    }
  end

  def currently_playing?(track)
    track.dig('@attr', 'nowplaying') == 'true'
  end

  def extract_image_url(images)
    return unless images.is_a?(Array)

    images.find { |img| %w[large extralarge].include?(img['size']) }
          &.fetch('#text', nil) || images.last&.fetch('#text', nil)
  end

  def make_request(params)
    Net::HTTP.start(*http_connection_params) do |http|
      http.request(Net::HTTP::Get.new(build_uri(params)))
    end
  rescue StandardError => e
    puts "\nError making request: #{e.message}"
    nil
  end

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError => e
    puts "Error parsing response: #{e.message}"
    nil
  end



  def save_to_file(filename, partial: false)
    puts "\n\nSaving to file..." unless partial

    output = {
      export_date: Time.now.utc.iso8601,
      username: username,
      total_tracks: tracks.length,
      tracks: tracks
    }

    File.write("#{filename}.tmp", JSON.pretty_generate(output))
    File.rename("#{filename}.tmp", filename)
  rescue StandardError => e
    puts "Error saving file: #{e.message}"
  end

  def display_progress(page, total_pages)
    progress = (page.to_f / total_pages * 100).round(1)
    print "\rProgress: [#{page}/#{total_pages}] #{progress}% - #{tracks.length} tracks downloaded"
  end

  def build_uri(params)
    URI(API_BASE_URL).tap { |uri| uri.query = URI.encode_www_form(params) }
  end

  def http_connection_params(verify_mode = @ssl_verify_mode)
    [
      URI(API_BASE_URL).host,
      URI(API_BASE_URL).port,
      {
        use_ssl: true,
        verify_mode: verify_mode,
        open_timeout: 10,
        read_timeout: 30
      }
    ]
  end

  def user_info_params
    {
      method: 'user.getinfo',
      user: username,
      api_key: api_key,
      format: 'json'
    }
  end

  def recent_tracks_params(page: nil, limit: TRACKS_PER_PAGE, extended: nil)
    {
      method: 'user.getrecenttracks',
      user: username,
      api_key: api_key,
      format: 'json',
      limit: limit,
      page: page,
      extended: extended
    }.compact
  end

  def print_header(output_file)
    puts '=' * 70
    puts 'Last.fm Listening History Exporter'
    puts '=' * 70
    puts "Username: #{username}"
    puts "Output file: #{output_file}\n\n"
  end

  def print_footer(output_file)
    puts "\n#{'=' * 70}"
    puts 'Export complete!'
    puts "Total tracks saved: #{tracks.length}"
    puts "Output file: #{output_file}"
    puts '=' * 70
  end
end

# Configuration
API_KEY = ENV.fetch('LASTFM_API_KEY', 'YOUR_API_KEY_HERE')
USERNAME = ENV.fetch('LASTFM_USERNAME', 'YOUR_USERNAME_HERE')
OUTPUT_FILE = ENV.fetch('LASTFM_OUTPUT_FILE', 'lastfm_history.json')

# Validation and execution
def main
  validate_credentials!
  LastfmExporter.new(API_KEY, USERNAME).export(OUTPUT_FILE)
end

def validate_credentials!
  if API_KEY.empty? || API_KEY == 'YOUR_API_KEY_HERE'
    abort <<~ERROR
      ERROR: Please set your Last.fm API key

      Option 1 - Set environment variable:
        export LASTFM_API_KEY='your_api_key_here'

      Option 2 - Edit this script and replace 'YOUR_API_KEY_HERE'

      Get your API key from: https://www.last.fm/api/account/create
    ERROR
  end

  if USERNAME.empty? || USERNAME == 'YOUR_USERNAME_HERE'
    abort <<~ERROR
      ERROR: Please set your Last.fm username

      Option 1 - Set environment variable:
        export LASTFM_USERNAME='your_username_here'

      Option 2 - Edit this script and replace 'YOUR_USERNAME_HERE'
    ERROR
  end
end

main if __FILE__ == $PROGRAM_NAME
