require "kemal"
require "uuid"
require "uuid/json"
require "json"

# ------- Auth ---------------

class AuthHandler < Kemal::Handler
  def call(env)
    token = env.request.headers["Authorization"]? || ""
    if !token.starts_with?("Bearer ")
      env.response.status_code = 401
      raise Kemal::Exceptions::CustomException.new env
    end

    token_value = token[("Bearer ".size)..]

    if token_value != "kemal-token"
      env.response.status_code = 403
      raise Kemal::Exceptions::CustomException.new env
    end

    call_next env
  end
end

# add_handler AuthHandler.new

# ------- CORS ---------------

before_all "/*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "*"
  env.response.headers["Access-Control-Allow-Headers"] = "*"
end

# ------- Test Router --------

get "/" do
  "hi kemal"
end

ws "/ws" do |ws|
  ws.send "hi ws"
end

# ------- Result Model -------

record Result(T),
  data : T?,
  code : Int32,
  msg : String do
  include JSON::Serializable

  def self.ok : Result(T)
    Result(T).new data: nil, code: 0, msg: ""
  end

  def self.ok(data : T?) : Result(T)
    Result(T).new data: data, code: 0, msg: ""
  end

  def self.err(code : Int32, msg : String) : Result(T?)
    Result(T?).new data: nil, code: code, msg: msg
  end
end

# ------- utils --------------

def map(s : S, to tt : T.class) : T forall S, T
  {% begin %}
    T.new(
      {% for ivar in T.instance_vars %}
        {% for jvar in S.instance_vars %}
          {% if ivar.name == jvar.name %}
            {{ ivar.name }}: s.{{ ivar.name }},
          {% end %}
        {% end %}
      {% end %}
    )
  {% end %}
end

def merge(a : A, with b : B) forall A, B
  {% begin %}
    {% for ivar in A.instance_vars %}
      {% for jvar in B.instance_vars %}
        {% if ivar.name == jvar.name %}
          if a.responds_to?(:{{ ivar.name }}=)
            a.{{ ivar.name }} = b.{{ ivar.name }}
          end
        {% end %}
      {% end %}
    {% end %}
  {% end %}
end

# ------ ORM -----------------

require "sqlite3"

# NOTE: 必须在 require "granite" 前
Granite::Connections << Granite::Adapter::Sqlite.new(name: "sqlite", url: "sqlite3://./fighter.db")

require "granite"
require "granite/adapter/sqlite"

class Fighter < Granite::Base
  connection sqlite
  table fighter

  column id : Int64, primary: true
  # column id : UUID, primary: true, auto: false
  column name : String
  column skill : Array(String) = [] of String, converter: Granite::Converters::Json(Array(String), String)
  column created_at : Time = Time.utc
  column updated_at : Time?

  validate_not_blank :name
  validate_not_nil :created_at

  include JSON::Serializable

  # def initialize(@id = UUID.random, *, @name, @skill, @created_at = Time.utc, @updated_at = nil)
  # end

  def initialize(*, @name, @skill, @created_at = Time.utc, @updated_at = nil)
  end
end

# --- 初始化数据
fighters = [
  Fighter.new(name: "隆", skill: ["波动拳"]),
  Fighter.new(name: "肯", skill: ["升龙拳"]),
]
Fighter.clear
Fighter.import(fighters, update_on_duplicate: true, columns: %w(name))

# ------- Model --------------

record FighterCreate,
  name : String,
  skill : Array(String) do
  include JSON::Serializable
end

record FighterEdit,
  name : String,
  skill : Array(String) do
  include JSON::Serializable
end


json_header = "application/json; charset=utf-8"

# ------ Baseline Router -----

get "/baseline/text" do |env|
  "lost"
end

get "/baseline/json" do |env|
  env.response.content_type = json_header
  Result.ok("lost").to_json
end

# ------- Fighter Router -----

get "/fighter" do |env|
  fighters = Fighter.all
  env.response.content_type = json_header
  Result.ok(fighters).to_json
end

get "/fighter/:name" do |env|
  name = env.params.url["name"]

  found = Fighter.find_by(name: name)

  env.response.content_type = json_header
  Result.ok(found).to_json
end

post "/fighter" do |env|
  fighter_create = FighterCreate.from_json env.request.body.not_nil!

  new_fighter = map fighter_create, to: Fighter
  new_fighter.save!

  env.response.content_type = json_header
  Result.ok(new_fighter).to_json
end

put "/fighter" do |env|
  fighter_edit = FighterEdit.from_json env.request.body.not_nil!

  found = Fighter.find_by(name: fighter_edit.name)

  unless found.nil?
    merge found, with: fighter_edit
    found.updated_at = Time.utc
    found.save!
  end

  env.response.content_type = json_header
  Result.ok(found).to_json
end

delete "/fighter/:name" do |env|
  name = env.params.url["name"]

  found = Fighter.find_by(name: name)

  unless found.nil?
    found.destroy!
  end

  env.response.content_type = json_header
  Result.ok(found).to_json
end

# ------- Logging ------------

{% if flag?(:release) %}
  logging false
{% else %}
  logging true
{% end %}

# ------- Server -------------

struct StartupInfo
  {% if flag?(:release) %}
    getter release_mode : Bool = true
  {% else %}
    getter release_mode : Bool = false
  {% end %}

  {% if flag?(:preview_mt) %}
    getter multi_threads : Bool = true
  {% else %}
    getter multi_threads : Bool = false
  {% end %}

  getter pid : Int64
  getter port : Int32

  include JSON::Serializable

  def initialize(@port : Int32, @pid : Int64)
  end
end

startup_info = StartupInfo.new port: 3000, pid: Process.pid
puts startup_info

port = startup_info.port

Kemal.run do |config|
  server = config.server.not_nil!
  server.bind_tcp "0.0.0.0", port, reuse_port: true
end
