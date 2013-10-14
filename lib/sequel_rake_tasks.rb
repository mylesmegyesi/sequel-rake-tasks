require 'rake'
require 'rake/tasklib'
require 'sequel'

Sequel.extension :migration

module Sequel

  class RakeTasks < ::Rake::TaskLib
    include ::Rake::DSL if defined?(::Rake::DSL)

    attr_reader :connection,
      :connection_config,
      :migrator_klass,
      :migrations_dir,
      :schema_file,
      :seed_file,
      :structure_file

    def initialize(options)
      @connection        = options[:connection]
      @connection_config = options[:connection_config]
      @migrator_klass    = options[:migrator]
      @migrations_dir    = options[:migrations_dir]
      @schema_file       = options[:schema_file]
      @seed_file         = options[:seed_file]
      @structure_file    = options[:structure_file]
      define_tasks
    end

    def db_commands
      @db_commands ||= MysqlDbCommands.new(connection_config)
    end

    def migrator
      @migrator ||= migrator_klass.new(connection, migrations_dir)
    end

    def define_tasks
      namespace :db do

        desc 'Setup the database.'
        task :setup => [:create, :migrate]

        desc 'Reset the database.'
        task :reset => [:drop, :setup]

        desc 'Create the database.'
        task :create do |t, args|
          db_commands.create_database
        end

        desc 'Drop the database.'
        task :drop do
          db_commands.drop_database
        end

        desc 'Load the seeds'
        task :seed do
          load(seed_file)
        end

        desc 'Migrate the database.'
        task :migrate do
          migrator.run
          Rake::Task['db:schema:dump'].invoke
        end

        namespace :schema do

          desc 'Dump the current database schema as a migration.'
          task :dump do
            connection.extension :schema_dumper
            text = connection.dump_schema_migration(same_db: false)
            text = text.gsub(/ +$/, '') # remove trailing whitespace
            File.open(schema_file, 'w') { |f| f.write(text) }
          end
        end

        namespace :structure do

          desc 'Load the database structure file'
          task :load do
            raise '`structure_file` option not defined!' unless structure_file
            db_commands.load_sql_file(structure_file)
          end

        end

      end
    end

  end

  class MysqlDbCommands

    def initialize(connection_config)
      @connection_config = connection_config
    end

    def drop_database
      execute("DROP DATABASE IF EXISTS `#{database_name}`")
    end

    def create_database
      execute("CREATE DATABASE IF NOT EXISTS `#{database_name}` DEFAULT CHARACTER SET #{charset} DEFAULT COLLATE #{collation}")
    end

    def load_sql_file(filename)
      commands = base_commands
      commands << '--execute' << %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}
      commands << '--database' << database_name
      system(*commands)
    end

    private

    attr_reader :connection_config

    def database_name
      connection_config['database']
    end

    def username
      connection_config['username']
    end

    def password
      connection_config['password']
    end

    def host
    end

    def host
      connection_config['host']
    end

    def port
      connection_config['port']
    end

    def charset
      connection_config['charset'] || 'utf8'
    end

    def collation
      connection_config['collation'] || 'utf8_unicode_ci'
    end

    def execute(statement)
      commands = base_commands
      commands << '-e' << statement
      system(*commands)
    end

    def base_commands
      commands = %w(mysql)
      commands << "--user=#{Shellwords.escape(username)}" unless username.blank?
      commands << "--password=#{Shellwords.escape(password)}" unless password.blank?
      commands << "--host=#{host}" unless host.blank?
      commands
    end

  end
end
