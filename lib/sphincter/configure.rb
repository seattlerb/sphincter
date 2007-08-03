require 'fileutils'
require 'yaml'

require 'sphincter'

##
# Configuration module for Sphincter.
#
# DEFAULT_CONF contains the default options.  They can be overridden in both a
# global config/sphincter.yml and in a per-environment
# config/environments/sphincter.RAILS_ENV.yml.
#
# The only option you should need to override is the port option of
# sphincter, so a config file for separate test and development indexes would
# look like:
#
# config/environments/sphincter.development.yml:
#
#   sphincter:
#     port: 3313
#
# config/environments/sphincter.test.yml:
#
#   sphincter:
#     port: 3314
#
# Configuration options:
#
# sphincter:: Options for serachd's and Sphinx's port and address, and
#            paths for index files.
# index:: Options for a sphinx index conf section
# indexer:: Options for the sphinx indexer
# mysql:: Options for the sphinx indexer's mysql database connection.  The
#         important ones are filled from config/database.yml
# searchd:: Options for a sphinx searchd conf section
# source:: Options for a sphinx source conf section
#
# The sphincter entry contains:
#
# address:: Which host searchd will run on, and which host Sphincter will
#           connect to.
# port:: Which port searchd and Sphincter will connect to.
# path:: Location of searchd indexes, relative to RAILS_ROOT.
# per_page:: How many items to include in a search by default.
#
# All other entries are from Sphinx.
#
# See http://www.sphinxsearch.com/doc.html#reference for details on sphinx
# conf file settings.

module Sphincter::Configure

  @env_conf = nil
  @index_count = nil

  rails_env = defined?(RAILS_ENV) ? RAILS_ENV : 'RAILS_ENV'

  ##
  # Default Sphincter configuration.

  DEFAULT_CONF = {
    'sphincter' => {
      'address' => '127.0.0.1',
      'path' => "sphinx/#{rails_env}",
      'per_page' => 10,
      'port' => 3312,
    },

    'index' => {
      'charset_type' => 'utf-8',
      'docinfo' => 'extern',
      'min_word_len' => 1,
      'morphology' => 'stem_en',
      'stopwords' => '',
    },

    'indexer' => {
      'mem_limit' => '32M',
    },

    'mysql' => {
      'sql_query_pre' => [
        'SET NAMES utf8',
      ],
    },

    'searchd' => {
      'log' => "log/sphinx/searchd.#{rails_env}.log",
      'max_children' => 30,
      'max_matches' => 1000,
      'query_log' => "log/sphinx/query.#{rails_env}.log",
      'read_timeout' => 5,
    },

    'source' => {
      'index_html_attrs' => '',
      'sql_query_post' => '',
      'sql_range_step' => 20000,
      'strip_html' => 0,
    },
  }

  ##
  # Builds and writes out a sphinx.conf file.

  def self.configure
    conf = get_conf
    db_conf = get_db_conf

    db_conf = conf[db_conf['type']].merge db_conf

    sources = get_sources

    sources.each do |name, source_conf|
      sources[name] = db_conf.merge source_conf
    end

    write_configuration conf, sources
  end

  ##
  # Merges Hashes of Hashes +mergee+ and +hash+.

  def self.deep_merge(mergee, hash)
    mergee = mergee.dup
    hash.keys.each do |key| mergee[key] ||= hash[key] end
    mergee.each do |key, value|
      next unless hash[key]
      mergee[key] = value.merge hash[key]
    end
  end

  ##
  # Builds the Sphincter configuration.
  #
  # Automatically fills in searchd address, port and pid_file from 'sphincter'
  # section.

  def self.get_conf
    return @env_conf unless @env_conf.nil?

    base_file = File.expand_path File.join(RAILS_ROOT, 'config', 'sphincter.yml')
    base_conf = deep_merge DEFAULT_CONF, get_conf_from(base_file)

    env_file = File.expand_path File.join(RAILS_ROOT, 'config', 'environments',
                                          "sphincter.#{RAILS_ENV}.yml")
    env_conf = deep_merge base_conf, get_conf_from(env_file)

    env_conf['searchd']['address'] = env_conf['sphincter']['address']
    env_conf['searchd']['port'] = env_conf['sphincter']['port']
    env_conf['searchd']['pid_file'] = File.join(env_conf['sphincter']['path'],
                                                'searchd.pid')

    @env_conf = env_conf
  end

  ##
  # Reads configuration file +file+.  Returns {} if the file does not exist.

  def self.get_conf_from(file)
    if File.exist? file then
      YAML.load File.read(file)
    else
      {}
    end
  end

  ##
  # Builds a sphinx.conf source configuration for each index.

  def self.get_sources
    load_models

    index_defaults = { :conditions => [], :fields => [], :include => [] }

    indexes = Sphincter::Search.indexes
    index_count # HACK necessary to set options[:index_id] per-index

    sources = {}

    indexes.each do |klass, model_indexes|
      model_indexes.each do |options|
        source_conf = {}
        fields = []
        where = []

        options = index_defaults.merge options
        conn = klass.connection
        table = klass.table_name
        tables = [table]
        pk = conn.quote_column_name klass.primary_key
        index_id = options[:index_id]

        source_conf['sql_date_column'] = []
        source_conf['sql_group_column'] = %w[sphincter_index_id]

        fields << "(#{table}.#{pk} * #{index_count} + #{index_id}) AS #{pk}"
        fields << "#{index_id} AS sphincter_index_id"
        fields << "'#{klass.name}' AS sphincter_klass"

        options[:fields].each do |field|
          fields << get_sources_field(source_conf, klass, field)
        end

        options[:include].each do |as_include|
          as_name, as_field = as_include.split '.', 2

          as_assoc = klass.reflect_on_all_associations.find do |assoc|
            assoc.name == as_name.intern
          end

          as_klass = as_assoc.class_name.constantize
          as_table = as_klass.table_name 
          as_pkey = conn.quote_column_name as_assoc.primary_key_name.to_s
          as_fkey = conn.quote_column_name as_klass.primary_key.to_s

          tables << as_table
          fields << get_sources_field(source_conf, as_klass, as_field, as_table)
          where << "#{table}.#{as_pkey} = #{as_table}.#{as_fkey}"
        end

        fields = fields.join ', '

        where << "#{table}.#{pk} >= $start"
        where << "#{table}.#{pk} <= $end"
        where.push(*options[:conditions])
        where = where.compact.join ' AND '

        source_conf['sql_query'] =
          "SELECT #{fields} FROM #{tables.join ', '} WHERE #{where}"
        source_conf['sql_query_info'] =
          "SELECT * FROM #{table} " \
            "WHERE #{table}.#{pk} = (($id - #{index_id}) / #{index_count})"
        source_conf['sql_query_range'] =
          "SELECT MIN(#{pk}), MAX(#{pk}) FROM #{table}"
        source_conf['strip_html'] = options[:strip_html] ? 1 : 0

        name = options[:name] || table
        sources[name] = source_conf
      end
    end

    sources
  end

  ##
  # Builds a field for a source's sql_query sphinx.conf setting.
  #
  # get_sources_field only understands :datetime, :boolean, :integer, :string
  # and :text column types.

  def self.get_sources_field(source_conf, klass, field, as_table = nil)
    conn = klass.connection
    table = klass.table_name

    quoted_field = conn.quote_column_name field

    type = case klass.columns_hash[field].type
           when :date, :datetime, :time, :timestamp then
             source_conf['sql_date_column'] << field
             "UNIX_TIMESTAMP(#{table}.#{quoted_field})"
           when :boolean, :integer then
             source_conf['sql_group_column'] << field
             "#{table}.#{quoted_field}"
           when :string, :text then
             "#{table}.#{quoted_field}"
           end

    as_name = [as_table, field].compact.join '_'
    as_name = conn.quote_column_name as_name

    "#{type} AS #{as_name}"
  end

  ##
  # Retrieves the database configuration for ActiveRecord::Base and adapts it
  # for a sphinx.conf file.

  def self.get_db_conf
    conf = {}
    ar_conf = ActiveRecord::Base.configurations[::RAILS_ENV]

    conf['type']     = ar_conf['adapter']
    conf['sql_host'] = ar_conf['host']     if ar_conf.include? 'host'
    conf['sql_user'] = ar_conf['username'] if ar_conf.include? 'username'
    conf['sql_pass'] = ar_conf['password'] if ar_conf.include? 'password'
    conf['sql_db']   = ar_conf['database'] if ar_conf.include? 'database'
    conf['sql_sock'] = ar_conf['socket']   if ar_conf.include? 'socket'

    conf
  end

  ##
  # Iterates over the searchable ActiveRecord::Base classes and assigns an
  # index to each one.  Returns the total number of indexes found.

  def self.index_count
    return @index_count unless @index_count.nil?

    @index_count = 0

    load_models

    Sphincter::Search.indexes.each do |model, model_indexes|
      model_indexes.each do |options|
        options[:index_id] = @index_count
        @index_count += 1
      end
    end
    @index_count
  end

  ##
  # Loads ActiveRecord::Base models from app/models.

  def self.load_models
    model_files = Dir[File.join(RAILS_ROOT, 'app', 'models', '*.rb')]
    model_names = model_files.map { |name| File.basename name, '.rb' }
    model_names.each { |name| name.camelize.constantize }
  end

  ##
  # Returns the pid of searchd if searchd is running, otherwise false.

  def self.searchd_running?
    pid_file = Sphincter::Configure.get_conf['searchd']['pid_file']
    return false unless File.exist? pid_file

    pid = File.read pid_file
    return false if pid.empty?

    running = `ps -p #{pid}` =~ /#{pid}.*searchd/
    running ? pid : false
  end

  ##
  # Outputs a sphinx.conf configuration section titled +heading+ using the
  # Hash +data+.  Values in +data+ may be a String or Array.  For an Array,
  # the Hash key is printed multiple times.

  def self.section(heading, data)
    section = []
    section << heading
    section << '{'
    data.sort_by { |k,| k }.each do |key, value|
      case value
      when Array then
        next if value.empty?
        value.each do |v|
          section << "  #{key} = #{v}"
        end
      else
        section << "  #{key} = #{value}"
      end
    end
    section << '}'
    section.join "\n"
  end

  ##
  # The path to sphinx.conf.

  def self.sphinx_conf
    @sphinx_conf ||= File.join sphinx_dir, 'sphinx.conf'
  end

  ##
  # The directory where sphinx's files live.

  def self.sphinx_dir
    @sphinx_dir ||= File.join(RAILS_ROOT,
                              Sphincter::Configure.get_conf['sphincter']['path'])
  end

  ##
  # Writes out a sphinx.conf configuration using +conf+ and +sources+.

  def self.write_configuration(conf, sources)
    FileUtils.mkdir_p sphinx_dir

    out = []

    out << section('indexer', conf['indexer'])
    out << nil

    out << section('searchd', conf['searchd'])
    out << nil

    sources.each do |index_name, values|
      source_data = conf['source'].merge values
      out << section("source #{index_name}", source_data)
      out << nil

      index_path = File.join sphinx_dir, index_name
      index_data = conf['index'].merge 'source' => index_name,
                                       'path' => index_path

      out << section("index #{index_name}", index_data)
      out << nil
    end

    File.open sphinx_conf, 'w' do |fp|
      fp.write out.join("\n")
    end
  end

end

