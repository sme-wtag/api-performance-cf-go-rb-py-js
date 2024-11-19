require 'mysql2'
require 'sinatra'
require 'json'

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

  def to_json(*)
    {
      id: @id,
      username: @username,
      email: @email,
      created_at: @created_at,
      updated_at: @updated_at,
      projects: @projects
    }.to_json
  end
end

class Project
  attr_accessor :project_id, :project_name, :description, :created_at, :updated_at, :role, :assigned_at

  def initialize(data)
    @project_id = data[:id]
    @project_name = data[:project_name]
    @description = data[:description]
    @created_at = data[:created_at]
    @updated_at = data[:updated_at]
    @role = data[:role]
    @assigned_at = data[:assigned_at]
  end

  def to_json(*)
    {
      project_id: @project_id,
      project_name: @project_name,
      description: @description,
      created_at: @created_at,
      updated_at: @updated_at,
      role: @role,
      assigned_at: @assigned_at
    }.to_json
  end
end

class ApiServer
  def initialize
    init_db
    configure_sinatra
  end

  private

  def init_db
    @db = Mysql2::Client.new(
      host: '127.0.0.1',
      username: 'root',
      password: 'admin',
      database: 'test_database',
      reconnect: true,
      pool_size: 25,
      symbolize_keys: true,
      cast_booleans: true,
      cache_statements: true,
      prepare: true
    )
    puts 'Connected to MySQL database!'
  rescue Mysql2::Error => e
    puts "Error connecting to database: #{e.message}"
    exit 1
  end

  def configure_sinatra
    set :port, 8080
    set :bind, '0.0.0.0'
    set :server, 'webrick'
  end

  def get_user_with_projects(user_id)
    query = <<-SQL
      SELECT 
        u.id, u.username, u.email, u.created_at, u.updated_at,
        COALESCE(p.id, 0) as project_id, 
        COALESCE(p.project_name, '') as project_name, 
        COALESCE(p.description, '') as description,
        COALESCE(p.created_at, '') as project_created_at, 
        COALESCE(p.updated_at, '') as project_updated_at, 
        COALESCE(up.role, '') as role, 
        COALESCE(up.assigned_at, '') as assigned_at
      FROM users u
      LEFT JOIN user_projects up ON u.id = up.user_id
      LEFT JOIN projects p ON up.project_id = p.id
      WHERE u.id = ?
    SQL

    stmt = @db.prepare(query)
    results = stmt.execute(user_id)
    
    user_data = nil
    projects = []

    results.each do |row|
      unless user_data
        user_data = UserWithProjects.new(
          id: row[:id],
          username: row[:username],
          email: row[:email],
          created_at: row[:created_at],
          updated_at: row[:updated_at]
        )
      end

      if row[:project_id] > 0
        project = Project.new(
          id: row[:project_id],
          project_name: row[:project_name],
          description: row[:description],
          created_at: row[:project_created_at],
          updated_at: row[:project_updated_at],
          role: row[:role],
          assigned_at: row[:assigned_at]
        )
        projects << project
      end
    end

    stmt.close
    return user_data, projects
  end

  public

  def start
    # Error handling middleware
    error do |e|
      content_type :json
      status 500
      { error: 'Internal server error' }.to_json
    end

    # Route handler
    get '/api/user/:user_id' do
      content_type :json
      
      user_data, projects = get_user_with_projects(params['user_id'])
      
      if user_data.nil?
        status 404
        return { error: 'User not found' }.to_json
      end

      user_data.projects = projects
      user_data.to_json
    end

    # Start the server
    puts "Server is running on port 8080"
  end
end

# Initialize and start the server
server = ApiServer.new
server.start