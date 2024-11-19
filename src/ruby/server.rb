require 'webrick'
require 'json'
require 'mysql2'

# Models
class UserWithProjects
  attr_accessor :id, :username, :email, :created_at, :updated_at, :projects
  def initialize(data)
    @id = data[:id]
    @username = data[:username]
    @email = data[:email]
    @created_at = data[:created_at]
    @updated_at = data[:updated_at]
    @projects = []
  end
  
  def to_json(*_args)
    {
      id: @id,
      username: @username,
      email: @email,
      created_at: @created_at,
      updated_at: @updated_at,
      projects: @projects.map(&:to_json)
    }.to_json  # Convert hash to JSON string
  end
end

class Project
  attr_accessor :id, :project_name, :description, :created_at, :updated_at, :role, :assigned_at
  def initialize(data)
    @id = data[:id]
    @project_name = data[:project_name]
    @description = data[:description]
    @created_at = data[:created_at]
    @updated_at = data[:updated_at]
    @role = data[:role]
    @assigned_at = data[:assigned_at]
  end
  
  def to_json(*_args)
    {
      id: @id,
      project_name: @project_name,
      description: @description,
      created_at: @created_at,
      updated_at: @updated_at,
      role: @role,
      assigned_at: @assigned_at
    }
  end
end

class ApiServer
  def initialize
    init_db
    setup_server
  end

  def init_db
    @db = Mysql2::Client.new(
      host: '127.0.0.1',
      username: 'root',
      password: 'admin',
      database: 'test_database',
      reconnect: true,
      symbolize_keys: true
    )
    puts 'Connected to MySQL database!'
  rescue Mysql2::Error => e
    puts "Error connecting to database: #{e.message}"
    exit 1
  end

  def get_user_with_projects(user_id)
    return nil if user_id.nil? || user_id.to_i <= 0

    query = <<-SQL
      SELECT 
        u.id, u.username, u.email, u.created_at, u.updated_at,
        COALESCE(p.id, 0) AS project_id, 
        COALESCE(p.project_name, '') AS project_name, 
        COALESCE(p.description, '') AS description,
        COALESCE(p.created_at, '') AS project_created_at, 
        COALESCE(p.updated_at, '') AS project_updated_at, 
        COALESCE(up.role, '') AS role, 
        COALESCE(up.assigned_at, '') AS assigned_at
      FROM users u
      LEFT JOIN user_projects up ON u.id = up.user_id
      LEFT JOIN projects p ON up.project_id = p.id
      WHERE u.id = ?
    SQL

    begin
      stmt = @db.prepare(query)
      results = stmt.execute(user_id)
      user_data = nil
      projects = []

      results.each do |row|
        user_data ||= UserWithProjects.new(
          id: row[:id],
          username: row[:username],
          email: row[:email],
          created_at: row[:created_at],
          updated_at: row[:updated_at]
        )
        
        next if row[:project_id].zero?
        projects << Project.new(
          id: row[:project_id],
          project_name: row[:project_name],
          description: row[:description],
          created_at: row[:project_created_at],
          updated_at: row[:project_updated_at],
          role: row[:role],
          assigned_at: row[:assigned_at]
        )
      end
      
      stmt.close
      [user_data, projects]
    rescue Mysql2::Error => e
      puts "Database error: #{e.message}"
      nil
    end
  end

  def setup_server
    @server = WEBrick::HTTPServer.new(Port: 8080, BindAddress: '0.0.0.0')
    
    @server.mount_proc '/api/user' do |req, res|
      res['Content-Type'] = 'application/json'
      
      # Extract user_id from path
      match = req.path.match(%r{^/api/user/(\d+)$})
      
      if match.nil?
        res.status = 400
        res.body = { error: "Invalid user ID format" }.to_json
        next
      end
      
      user_id = match[1].to_i
      
      if user_id <= 0
        res.status = 400
        res.body = { error: "Invalid user ID" }.to_json
        next
      end  # Removed the stray curly brace here
      
      begin
        user_data, projects = get_user_with_projects(user_id)
        
        if user_data.nil?
          res.status = 404
          res.body = { error: "User not found" }.to_json
        else
          user_data.projects = projects
          res.status = 200
          res.body = user_data.to_json
        end
      rescue StandardError => e
        res.status = 500
        res.body = { error: "Internal server error", message: e.message }.to_json
      end
    end

    trap('INT') { @server.shutdown }
    puts 'Server is running on port 8080'
  end

  def start
    @server.start
  end
end

# Start the server
server = ApiServer.new
server.start