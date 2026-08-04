#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "sqlite3"
require "uri"
require "fileutils"
require "time"

BASE_URL = "https://app.railbox.cn"
MANIFEST_PATH = "/data/manifest.json"
RUNTIME_DATA_PATH = "/runtime_data.json"
DATABASE_PATH = File.expand_path("../Approaching/Database/metro.sqlite", __dir__)
USER_AGENT = "Approaching-Railbox-Importer/1.0 (+https://app.railbox.cn)"
REQUEST_INTERVAL = 0.15

class RailboxClient
  def initialize(base_url)
    @base_url = base_url
    @last_request_at = nil
  end

  def get_json(path)
    sleep REQUEST_INTERVAL if @last_request_at
    escaped_path = URI::DEFAULT_PARSER.escape(path)
    uri = URI.parse("#{@base_url}#{escaped_path}")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/json"
    request["User-Agent"] = USER_AGENT

    attempts = 0
    begin
      attempts += 1
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
      @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      unless response.is_a?(Net::HTTPSuccess)
        raise "GET #{uri} failed with HTTP #{response.code}"
      end

      JSON.parse(response.body)
    rescue StandardError => error
      raise if attempts >= 4

      warn "Retrying #{uri} after attempt #{attempts}: #{error.message}"
      sleep attempts * 1.0
      retry
    end
  end
end

def create_schema(db)
  db.execute_batch <<~SQL
    PRAGMA foreign_keys = ON;

    DROP TABLE IF EXISTS departure;
    DROP TABLE IF EXISTS service_schedule;
    DROP TABLE IF EXISTS direction;
    DROP TABLE IF EXISTS station;
    DROP TABLE IF EXISTS line;
    DROP TABLE IF EXISTS import_metadata;

    CREATE TABLE line (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE station (
      id INTEGER PRIMARY KEY,
      line_id INTEGER NOT NULL REFERENCES line(id),
      name TEXT NOT NULL,
      city TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      timetable_url TEXT,
      station_index INTEGER NOT NULL,
      UNIQUE(line_id, station_index)
    );

    CREATE TABLE direction (
      id INTEGER PRIMARY KEY,
      station_id INTEGER NOT NULL REFERENCES station(id),
      name TEXT NOT NULL,
      UNIQUE(station_id, name)
    );

    CREATE TABLE service_schedule (
      id INTEGER PRIMARY KEY,
      direction_id INTEGER NOT NULL REFERENCES direction(id),
      service_type_key TEXT NOT NULL,
      service_type_label TEXT NOT NULL,
      UNIQUE(direction_id, service_type_key)
    );

    CREATE TABLE departure (
      id INTEGER PRIMARY KEY,
      schedule_id INTEGER NOT NULL REFERENCES service_schedule(id),
      sequence INTEGER NOT NULL,
      departure_time TEXT NOT NULL,
      UNIQUE(schedule_id, sequence)
    );

    CREATE TABLE import_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );

    CREATE INDEX station_location_index ON station(latitude, longitude);
    CREATE INDEX station_line_index ON station(line_id, station_index);
    CREATE INDEX direction_station_index ON direction(station_id);
    CREATE INDEX schedule_direction_index ON service_schedule(direction_id);
    CREATE INDEX departure_schedule_time_index ON departure(schedule_id, departure_time);
  SQL
end

client = RailboxClient.new(BASE_URL)
manifest = client.get_json(MANIFEST_PATH)
runtime_data = client.get_json(RUNTIME_DATA_PATH)
lines = manifest.is_a?(Array) ? manifest : manifest.fetch("lines")
raise "manifest contains no lines" if lines.empty?

FileUtils.mkdir_p(File.dirname(DATABASE_PATH))
tmp_path = "#{DATABASE_PATH}.tmp-#{Process.pid}"
FileUtils.rm_f(tmp_path)

db = SQLite3::Database.new(tmp_path)
db.results_as_hash = true
begin
  create_schema(db)

  line_id = 0
  station_id = 0
  direction_id = 0
  schedule_id = 0
  departure_id = 0
  counts = { stations: 0, directions: 0, schedules: 0, departures: 0 }
  statements = []

  db.transaction
  begin
    insert_line = db.prepare("INSERT INTO line(id, name) VALUES (?, ?)")
    statements << insert_line
    insert_station = db.prepare(<<~SQL)
      INSERT INTO station(id, line_id, name, city, latitude, longitude, timetable_url, station_index)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    SQL
    statements << insert_station
    insert_direction = db.prepare("INSERT INTO direction(id, station_id, name) VALUES (?, ?, ?)")
    statements << insert_direction
    insert_schedule = db.prepare(<<~SQL)
      INSERT INTO service_schedule(id, direction_id, service_type_key, service_type_label)
      VALUES (?, ?, ?, ?)
    SQL
    statements << insert_schedule
    insert_departure = db.prepare(<<~SQL)
      INSERT INTO departure(id, schedule_id, sequence, departure_time)
      VALUES (?, ?, ?, ?)
    SQL
    statements << insert_departure

    lines.each do |manifest_line|
      line_id += 1
      line_name = manifest_line.fetch("line")
      line_data = client.get_json(manifest_line.fetch("dataFile"))
      raise "line mismatch: #{line_name}" unless line_data.fetch("line") == line_name

      insert_line.execute(line_id, line_name)
      line_data.fetch("stations").each do |line_station|
        station_id += 1
        coords = line_station.fetch("coords")
        insert_station.execute(
          station_id,
          line_id,
          line_station.fetch("name"),
          "北京",
          coords.fetch("lat"),
          coords.fetch("lon"),
          line_station["timetableUrl"],
          line_station.fetch("stationIndex")
        )
        counts[:stations] += 1

        line_station.fetch("directions", []).each do |direction|
          direction_id += 1
          insert_direction.execute(direction_id, station_id, direction.fetch("name"))
          counts[:directions] += 1

          direction.fetch("schedules", []).each do |schedule|
            schedule_id += 1
            insert_schedule.execute(
              schedule_id,
              direction_id,
              schedule.fetch("serviceTypeKey"),
              schedule.fetch("serviceTypeLabel")
            )
            counts[:schedules] += 1

            schedule.fetch("times").each_with_index do |time, sequence|
              departure_id += 1
              insert_departure.execute(departure_id, schedule_id, sequence, time)
              counts[:departures] += 1
            end
          end
        end
      end
    end

    statements.each(&:close)
    statements.clear

    metadata = {
      "source" => BASE_URL,
      "manifest_path" => MANIFEST_PATH,
      "runtime_data_path" => RUNTIME_DATA_PATH,
      "source_version" => runtime_data.fetch("version", "unknown"),
      "imported_at_utc" => Time.now.utc.iso8601,
      "line_count" => line_id.to_s,
      "station_count" => counts[:stations].to_s,
      "departure_count" => counts[:departures].to_s
    }
    metadata.each { |key, value| db.execute("INSERT INTO import_metadata(key, value) VALUES (?, ?)", key, value) }
    db.commit
  rescue StandardError
    db.rollback
    raise
  end
ensure
  statements.each { |statement| statement.close rescue nil }
  db.close
end

FileUtils.mv(tmp_path, DATABASE_PATH)
puts "Imported #{line_id} lines, #{counts[:stations]} stations, #{counts[:directions]} directions, #{counts[:schedules]} schedules, #{counts[:departures]} departures into #{DATABASE_PATH}"
