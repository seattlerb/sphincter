require 'test/sphincter_test_case'
require 'sphincter/association_searcher'

class TestSphincterAssociationSearcher < SphincterTestCase

  class Proxy
    include Sphincter::AssociationSearcher

    attr_accessor :reflection

    def initialize
      @reflection = SphincterTestCase::BelongsTo.reflections.last
      klass = Object.new
      def klass.search_args() @search_args end
      def klass.search(*args) @search_args = args; :searched end
      @reflection.klass = klass
    end

    def proxy_reflection()
      @reflection
    end

    def proxy_owner()
      SphincterTestCase::BelongsTo.new
    end
  end

  def test_search
    proxy = Proxy.new

    results = proxy.search 'words'

    assert_equal :searched, results
    assert_equal ['words', { :conditions => { 'models_id' => 42 } } ],
                 proxy.proxy_reflection.klass.search_args
  end

end

