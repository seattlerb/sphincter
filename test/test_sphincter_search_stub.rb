require 'test/sphincter_test_case'
require 'sphincter/search_stub'

class TestSphincterSearchStub < SphincterTestCase

  class StubbedModel
    extend Sphincter::SearchStub
  end

  def test_search
    StubbedModel.search_args = []
    StubbedModel.search_results = [:blah]

    result = StubbedModel.search 'words', :conditions => { :foo_id => 1 }

    assert_equal :blah, result

    assert_equal 1, StubbedModel.search_args.length
    assert_equal ['words', { :conditions => { :foo_id => 1 } }],
                 StubbedModel.search_args.first

    assert_equal 0, StubbedModel.search_results.length
  end

  def test_search_no_setup
    expected = 'need to set up Sphincter::SearchStub#search_results and/or Sphincter::SearchStub#search_args in test setup'

    StubbedModel.search_args = nil
    StubbedModel.search_results = nil
    e = assert_raise RuntimeError do StubbedModel.search 'words' end
    assert_equal expected, e.message

    StubbedModel.search_args = []
    StubbedModel.search_results = nil
    e = assert_raise RuntimeError do StubbedModel.search 'words' end
    assert_equal expected, e.message

    StubbedModel.search_args = nil
    StubbedModel.search_results = []
    e = assert_raise RuntimeError do StubbedModel.search 'words' end
    assert_equal expected, e.message

    StubbedModel.search_args = []
    StubbedModel.search_results = []
    e = assert_raise RuntimeError do StubbedModel.search 'words' end
    assert_equal 'no more search results in search stub', e.message
  end

end

