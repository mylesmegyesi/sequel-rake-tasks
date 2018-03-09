require 'rake'
require 'rake/tasklib'
require 'sequel'

Sequel.extension :migration

module Sequel

  class RakeTasks < ::Rake::TaskLib
    include ::Rake::DSL if defined?(::Rake::DSL)

    def initialize(options)
      @options = options
      define_tasks
    end

    private

    def db_commands
      assert_option(:connection_config) do |connection_config|
        MysqlDbCommands.new(connection_config)
      end
    end

    def assert_option(option, &block)
      if value = get_option(option)
        yield value
      else
        raise "`#{option}` option not defined!"
      end
    end

    def get_option(option)
      @options[option]
    end

    def define_tasks
      namespace :db do
        desc 'Setup the database.'
        task :setup => [:create, :migrate]

        desc 'Reset the database.'
        task :reset => [:drop, :setup]

        desc 'Create the database.'
        task :create do
          db_commands.create_database
        end

        desc 'Drop the database.'
        task :drop do
          db_commands.drop_database
        end

        desc 'Load the seeds.'
        task :seed do
          assert_option(:seed_file) do |seed_file|
            load(seed_file)
          end
        end

        desc 'Migrate the database.'
        task :migrate do
          assert_option(:migrator) do |migrator_klass|
            assert_option(:migrations_dir) do |migrations_dir|
              db_commands.migrate(migrator_klass, migrations_dir, get_option(:migrations_opts))
              Rake::Task['db:schema:dump'].invoke if get_option(:schema_file)
            end
          end
        end

        namespace :schema do
          desc 'Dump the current database schema as a migration.'
          task :dump do
            assert_option(:schema_file) do |schema_file|
              db_commands.dump_schema(schema_file)
            end
          end

          desc 'Loads the schema_file into the current environment\'s database'
          task :load do
            assert_option(:schema_file) do |schema_file|
              db_commands.load_schema(schema_file)
            end
          end
        end

        namespace :structure do
          desc 'Load the database structure file'
          task :load do
            assert_option(:structure_file) do |structure_file|
              db_commands.load_sql_file(structure_file)
            end
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
      with_master_connection do |connection|
        connection.execute("DROP DATABASE IF EXISTS `#{database_name}`")
      end
    end

    def create_database
      with_master_connection do |connection|
        connection.execute("CREATE DATABASE IF NOT EXISTS `#{database_name}` DEFAULT CHARACTER SET #{charset} DEFAULT COLLATE #{collation}")
      end
    end

    def load_sql_file(filename)
      with_database_connection do |connection|
        connection.execute("SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1")
      end
    end

    def load_schema(schema_file)
      with_database_connection do |connection|
        eval(File.read schema_file).apply(connection, :up)
      end
    end

    def dump_schema(schema_file)
      with_database_connection do |connection|
        connection.extension :schema_dumper
        text = connection.dump_schema_migration(same_db: false)
        text = text.gsub(/ +$/, '') # remove trailing whitespace
        File.open(schema_file, 'w') { |f| f.write(text) }
      end
    end

    def migrate(migrator_klass, migrations_dir, migrations_opts)
      with_database_connection do |connection|
        args = [connection, migrations_dir]
        args << migrations_opts if migrations_opts
        migrator = migrator_klass.new(*args)
        migrator.run
      end
    end

    private

    attr_reader :connection_config

    def database_name
      connection_config[:database]
    end

    def username
      connection_config[:username]
    end

    def charset
      connection_config[:charset] || 'utf8'
    end

    def collation
      connection_config[:collation] || 'utf8_unicode_ci'
    end

    def with_database_connection(&block)
      with_connection(connection_config, &block)
    end

    def with_master_connection(&block)
      with_connection(connection_config.reject { |key, value| key.to_s == "database" }, &block)
    end

    def with_connection(config, &block)
      connection = Sequel.connect(config)
      begin
        yield connection
      ensure
        connection.disconnect
      end
    end
  end
end
