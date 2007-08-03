require 'test/unit'
require 'fileutils'
require 'tmpdir'

$TESTING = true

class String
  def constantize() SphincterTestCase::BelongsTo end
end

require 'sphincter'

class ActiveRecord::Base
  def self.configurations
    {
      'development' => {
        'adapter' => 'mysql',
        'host' => 'host',
        'username' => 'username',
        'password' => 'password',
        'database' => 'database',
        'socket' => 'socket',
      }
    }
  end
end

module Sphinx; end

class Sphinx::Client

  @@last_client = nil

  attr_reader :host, :port, :query, :index, :filters, :offset, :limit

  def self.last_client
    @@last_client
  end

  def initialize
    @filters = {}

    @@last_client = self
  end

  def Query(query, index)
    @query, @index = query, index

    {
      'matches' => {
        12 => { 'attrs' => { 'sphincter_index_id' => 1 }, 'index' => 3 },
        13 => { 'attrs' => { 'sphincter_index_id' => 1 }, 'index' => 1 },
        14 => { 'attrs' => { 'sphincter_index_id' => 1 }, 'index' => 2 },
      },
      'total_found' => 3
    }
  end

  def SetFilter(column, values)
    @filters[column] = values
  end

  def SetFilterRange(column, min, max)
    @filters[column] = [:range, min, max]
  end

  def SetLimits(offset, limit)
    @offset, @limit = offset, limit
  end

  def SetServer(host, port)
    @host, @port = host, port
  end

end

class SphincterTestCase < Test::Unit::TestCase

  undef_method :default_test

  class Column
    attr_accessor :type

    def initialize(type)
      @type = type
    end
  end

  class Connection
    def quote(name) "'#{name}'" end
    def quote_column_name(name) "`#{name}`" end
  end

  class Reflection
    attr_accessor :klass
    attr_reader :macro, :options, :name

    def initialize(macro, name)
      @klass = Model
      @macro = macro
      @name = name.intern
      @options = {}
    end

    def class_name() @name.to_s.sub(/s$/, '').capitalize end
    def primary_key_name() "#{@name}_id" end
  end

  class Model

    @reflections = [Reflection.new(:belongs_to, 'belongs_to'),
                    Reflection.new(:has_many, 'manys')]

    class << self; attr_accessor :reflections; end

    def self.connection() Connection.new end

    def self.columns_hash
      {
        'boolean' => Column.new(:boolean),
        'date' => Column.new(:date),
        'datetime' => Column.new(:datetime),
        'integer' => Column.new(:integer),
        'string' => Column.new(:string),
        'text' => Column.new(:text),
        'time' => Column.new(:time),
        'timestamp' => Column.new(:timestamp),
      }
    end

    def self.find(ids) ids end

    def self.name() 'Model' end

    def self.primary_key() 'id' end

    def self.reflect_on_all_associations
      @reflections
    end

    def self.table_name() 'models' end

  end

  class BelongsTo < Model
    @reflections = [Reflection.new(:belongs_to, 'something'),
                    Reflection.new(:has_many, 'models')]

    def self.table_name() 'belongs_tos' end

    def id() 42 end
  end

  class HasMany < Model
    @reflections = [Reflection.new(:belongs_to, 'models')]

    def self.table_name() 'has_manys' end

    def id() 84 end
  end

  class Model
    extend Sphincter::Search
  end

  def setup
    @temp_dir = File.join Dir.tmpdir, "sphincter_test_case_#{$$}"
    FileUtils.mkdir_p @temp_dir
    @orig_dir = Dir.pwd
    Dir.chdir @temp_dir

    @old_RAILS_ROOT = (Object.const_get :RAILS_ROOT rescue nil)
    Object.send :remove_const, :RAILS_ROOT rescue nil
    Object.const_set :RAILS_ROOT, @temp_dir

    @old_RAILS_ENV = (Object.const_get :RAILS_ENV rescue nil)
    Object.send :remove_const, :RAILS_ENV rescue nil
    Object.const_set :RAILS_ENV, 'development'

    Sphincter::Search.indexes.replace Hash.new { |h,k| h[k] = [] }

    Sphincter::Configure.instance_variable_set '@env_conf', nil if
      Sphincter::Configure.instance_variables.include? '@env_conf'
    Sphincter::Configure.instance_variable_set '@index_count', nil if
      Sphincter::Configure.instance_variables.include? '@index_count'

    BelongsTo.reflections.last.options.delete :extend
  end

  def teardown
    FileUtils.rm_rf @temp_dir
    Dir.chdir @orig_dir

    Object.send :remove_const, :RAILS_ROOT
    Object.const_set :RAILS_ROOT, @old_RAILS_ROOT

    Object.send :remove_const, :RAILS_ENV
    Object.const_set :RAILS_ENV, @old_RAILS_ENV
  end

end

