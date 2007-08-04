require 'test/sphincter_test_case'
require 'sphincter/configure'

class TestSphincterConfigure < SphincterTestCase

  DEFAULT_GET_CONF_EXPECTED = {
    "mysql" =>  {
      "sql_query_pre" => [
        "SET NAMES utf8",
      ]
    },
    "sphincter" => {
      "address" => "127.0.0.1",
      "path" => "sphinx/RAILS_ENV",
      "per_page" => 10,
      "port" => 3312,
    },
    "index" => {
      "charset_type" => "utf-8",
      "docinfo" => "extern",
      "min_word_len" => 1,
      "morphology" => "stem_en",
      "stopwords" => "",
    },
    "source" => {
      "index_html_attrs" => "",
      "sql_query_post" => "",
      "sql_range_step" => 20000,
      "strip_html" => 0,
    },
    "indexer" => {
      "mem_limit" => "32M",
    },
    "searchd" => {
      "address" => "127.0.0.1",
      "log" => "log/sphinx/searchd.RAILS_ENV.log",
      "max_children" => 30,
      "max_matches" => 1000,
      "pid_file" => "sphinx/RAILS_ENV/searchd.pid",
      "port" => 3312,
      "query_log" => "log/sphinx/query.RAILS_ENV.log",
      "read_timeout" => 5,
    }
  }

  def test_self_configure
    expected = <<-EOF
indexer
{
  mem_limit = 32M
}

searchd
{
  address = 127.0.0.1
  log = log/sphinx/searchd.RAILS_ENV.log
  max_children = 30
  max_matches = 1000
  pid_file = sphinx/RAILS_ENV/searchd.pid
  port = 3312
  query_log = log/sphinx/query.RAILS_ENV.log
  read_timeout = 5
}
    EOF

    Sphincter::Configure.configure

    assert_equal expected, File.read(Sphincter::Configure.sphinx_conf)
  end

  def test_self_deep_merge
    h1 = { 'x' => { 'm' => 0 },
           'y' => { 'a' => 1, 'b' =>  2 } }
    h2 = { 'y' => {           'b' => -2, 'c' => -3 },
           'z' => { 'm' => 0 } }
    result = Sphincter::Configure.deep_merge h1, h2

    expected = {
      'x' => { 'm' => 0 },
      'y' => { 'a' => 1, 'b' => -2, 'c' => -3 },
      'z' => { 'm' => 0 },
    }

    assert_equal expected, result
  end

  def test_self_get_conf
    expected = DEFAULT_GET_CONF_EXPECTED

    assert_equal expected, Sphincter::Configure.get_conf
  end

  def test_self_get_conf_app_conf
    FileUtils.mkdir_p 'config'
    File.open 'config/sphincter.yml', 'w' do |fp|
      fp.puts "sphincter:\n  port: 3313"
    end

    expected = util_deep_clone DEFAULT_GET_CONF_EXPECTED
    expected['sphincter']['port'] = 3313
    expected['searchd']['port'] = 3313

    assert_equal expected, Sphincter::Configure.get_conf
  end

  def test_self_get_conf_env_conf
    FileUtils.mkdir_p 'config/environments'
    File.open 'config/sphincter.yml', 'w' do |fp|
      fp.puts "sphincter:\n  port: 3313"
    end
    File.open "config/environments/sphincter.#{RAILS_ENV}.yml", 'w' do |fp|
      fp.puts "sphincter:\n  port: 3314"
    end

    expected = util_deep_clone DEFAULT_GET_CONF_EXPECTED
    expected['sphincter']['port'] = 3314
    expected['searchd']['port'] = 3314

    assert_equal expected, Sphincter::Configure.get_conf
  end

  def test_self_get_conf_from
    assert_equal Hash.new, Sphincter::Configure.get_conf_from('/nonexistent')

    File.open 'foo.yml', 'w' do |fp| fp.puts "foo:\n  bar" end

    assert_equal({'foo' => 'bar'}, Sphincter::Configure.get_conf_from('foo.yml'))
  end

  def test_self_get_sources
    Sphincter::Search.indexes[Model] << { :fields => %w[text] }

    expected = {
      "models" => {
        "strip_html" => 0,
        "sql_group_column" => ["sphincter_index_id"],
        "sql_query_range" => "SELECT MIN(`id`), MAX(`id`) FROM models",
        "sql_query_info" =>
          "SELECT * FROM models WHERE models.`id` = (($id - 0) / 1)",
        "sql_date_column" => [],
        "sql_query" =>
          "SELECT (models.`id` * 1 + 0) AS `id`, " \
                 "0 AS sphincter_index_id, " \
                 "'Model' AS sphincter_klass, "\
                 "models.`text` AS `text` " \
            "FROM models WHERE models.`id` >= $start AND " \
                              "models.`id` <= $end"
      }
    }

    assert_equal expected, Sphincter::Configure.get_sources
  end

  def test_self_get_db_conf
    expected = {
      'type' => 'mysql',
      'sql_host' => 'host',
      'sql_pass' => 'password',
      'sql_db' => 'database',
      'sql_user' => 'username',
      'sql_sock' => 'socket',
    }

    assert_equal expected, Sphincter::Configure.get_db_conf
  end

  def test_self_index_count
    Sphincter::Search.indexes[Object] << { :fields => %w[title body] }
    Sphincter::Search.indexes[Object] << {
      :fields => %w[title body], :name => 'foo'
    }

    assert_equal 2, Sphincter::Configure.index_count

    expected = {
      Object => [
        { :index_id => 0, :fields => %w[title body] },
        { :index_id => 1, :fields => %w[title body], :name => 'foo' },
      ],
    }

    assert_equal expected, Sphincter::Search.indexes
  end

  def test_self_section
    heading = 'searchd'
    data = {
      'array' => %w[value1 value2],
      'empty' => '',
      'nil' => nil,
      'string' => 'value',
    }

    expected = <<-EOF.strip
searchd
{
  array = value1
  array = value2
  empty = 
  nil = 
  string = value
}
    EOF

    assert_equal expected, Sphincter::Configure.section(heading, data)
  end

  def test_self_sphinx_conf
    assert_equal File.join(RAILS_ROOT, 'sphinx/RAILS_ENV/sphinx.conf'),
                 Sphincter::Configure.sphinx_conf
  end

  def test_self_sphinx_dir
    assert_equal File.join(RAILS_ROOT, 'sphinx/RAILS_ENV'),
                 Sphincter::Configure.sphinx_dir
  end

  def test_self_write_configuration
    conf = Hash.new { |h,k| h[k] = {} }
    sources = Hash.new { |h,k| h[k] = {} }

    conf['sphincter']['path'] = 'sphinx/development'
    conf['source']['key1'] = 'value1'
    conf['index']['key1'] = 'value1'

    sources['source_1']['key2'] = 'value2'

    sources['source_2']['key1'] = 'value3'
    sources['source_2']['key2'] = 'value4'

    expected = <<-EOF
indexer
{
}

searchd
{
}

source source_1
{
  key1 = value1
  key2 = value2
}

index source_1
{
  key1 = value1
  path = #{Sphincter::Configure.sphinx_dir}/source_1
  source = source_1
}

source source_2
{
  key1 = value3
  key2 = value4
}

index source_2
{
  key1 = value1
  path = #{Sphincter::Configure.sphinx_dir}/source_2
  source = source_2
}
    EOF

    Sphincter::Configure.write_configuration conf, sources

    assert_equal expected, File.read(Sphincter::Configure.sphinx_conf)
  end

  def util_deep_clone(obj)
    Marshal.load Marshal.dump(obj)
  end

end

class Sphincter::Configure::Index
  attr_reader :fields, :where, :tables, :group
end

class TestSphincterConfigureIndex < SphincterTestCase

  def setup
    super

    @index = Sphincter::Configure::Index.new Model, {}
  end

  def test_self_add_field
    fields = []
    fields << @index.add_field('date')
    fields << @index.add_field('datetime')
    fields << @index.add_field('boolean')
    fields << @index.add_field('integer')
    fields << @index.add_field('string')
    fields << @index.add_field('time')
    fields << @index.add_field('timestamp')
    fields << @index.add_field('text')

    expected_fields = [
      "UNIX_TIMESTAMP(models.`date`) AS `date`",
      "UNIX_TIMESTAMP(models.`datetime`) AS `datetime`",
      "models.`boolean` AS `boolean`",
      "models.`integer` AS `integer`",
      "models.`string` AS `string`",
      "UNIX_TIMESTAMP(models.`time`) AS `time`",
      "UNIX_TIMESTAMP(models.`timestamp`) AS `timestamp`",
      "models.`text` AS `text`"
    ]

    assert_equal expected_fields,  fields

    assert_equal %w[sphincter_index_id boolean integer],
                 @index.source_conf['sql_group_column']
    assert_equal %w[date datetime time timestamp],
                 @index.source_conf['sql_date_column']
  end

  def test_self_add_field_unknown
    e = assert_raise Sphincter::Error do
      @index.add_field 'other'
    end

    assert_equal 'unknown column type NilClass', e.message
  end

  def test_add_include_belongs_to
    @index.add_include 'belongs_to.string'

    assert_equal ["belongs_tos.`string` AS `belongs_tos_string`"], @index.fields
    assert_equal %w[models belongs_tos], @index.tables
    assert_equal ["models.`belongs_to_id` = belongs_tos.`id`"], @index.where
    assert_equal false, @index.group
  end

  def test_add_include_has_many
    @index.add_include 'manys.string'

    assert_equal ["GROUP_CONCAT(has_manys.`string` SEPARATOR ' ') AS `has_manys_string`"], @index.fields
    assert_equal %w[models has_manys], @index.tables
    assert_equal ["models.`id` = has_manys.`manys_id`"], @index.where
    assert_equal true, @index.group
  end

  def test_add_include_nonexistent_association
    e = assert_raise Sphincter::Error do
      @index.add_include 'nonexistent.string'
    end

    assert_equal "could not find association \"nonexistent\" in Model",
                 e.message
  end

end

