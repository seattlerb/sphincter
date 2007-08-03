require 'test/sphincter_test_case'
require 'sphincter/search'

SphincterTestCase::Model.extend Sphincter::Search

class TestSphincterSearch < SphincterTestCase

  def test_self_indexes
    assert_equal [], Sphincter::Search.indexes[Model]
  end

  def test_add_index
    Model.add_index :fields => %w[text]

    assert_equal [{ :fields => %w[text belongs_to_id] }],
                 Sphincter::Search.indexes[Model]

    belongs_to_belongs_to = BelongsTo.reflections.first
    belongs_to_has_many = BelongsTo.reflections.last

    assert_equal({}, belongs_to_belongs_to.options, 'BelongsTo belongs_to')
    assert_equal({ :extend => [Sphincter::AssociationSearcher] },
                 belongs_to_has_many.options, 'BelongsTo has_many')
  end

  def test_sphincter_convert_values
    assert_equal [0, 1], Model.sphincter_convert_values([false, true])

    now = Time.at 999_932_400
    expected = [999_932_400]

    assert_equal expected,
                 Model.sphincter_convert_values([999_932_400])
    assert_equal expected,
                 Model.sphincter_convert_values([now])
    assert_equal expected,
                 Model.sphincter_convert_values([Date.parse(now.to_s)])
    assert_equal expected,
                 Model.sphincter_convert_values([DateTime.parse(now.to_s)])
  end

  def test_search
    Model.add_index :fields => %w[text]
    Sphincter::Configure.get_conf['sphincter']['host'] = 'localhost'
    Sphincter::Configure.get_conf['sphincter']['port'] = 3312

    results = Model.search 'words'

    assert_equal [11, 13, 12], results.records
    assert_equal 3, results.total
    assert_equal 10, results.per_page

    assert_equal 'localhost', Sphinx::Client.last_client.host
    assert_equal 3312, Sphinx::Client.last_client.port
    assert_equal 'words', Sphinx::Client.last_client.query
    assert_equal 'models', Sphinx::Client.last_client.index
  end

  def test_search_between
    Model.add_index :fields => %w[text]

    now = Time.now
    ago = now - 3600
    between = {
      :created_at => [ago, now]
    }

    Model.search 'words', :between => between

    expected = { 'created_at' => [:range, ago.to_i, now.to_i] }

    assert_equal expected, Sphinx::Client.last_client.filters
  end

  def test_search_conditions
    Model.add_index :fields => %w[text]

    now = Time.now
    conditions = {
      :some_id => 1,
      :other_id => [1, 2],
      :boolean => [true, false],
    }

    Model.search 'words', :conditions => conditions

    expected = { 'some_id' => [1], 'other_id' => [1, 2], 'boolean' => [1, 0] }

    assert_equal expected, Sphinx::Client.last_client.filters
  end

  def test_search_index
    Model.add_index :fields => %w[text]

    Model.search 'words', :index => 'other'

    assert_equal 'other', Sphinx::Client.last_client.index
  end

end
