require 'sphincter'

##
# Stub for Sphincter searching.  Extend ActiveRecord::Base with this module in
# your tests so you won't have to run a Sphinx searchd to test your searching.
#
# In test/testHelper.rb:
#
#   require 'sphincter/search_stub'
#   ActiveRecord::Base.extend Sphincter::SearchStub
#
# Before running a search, you'll need to populate the stub's accessors:
#
#   def test_search
#     Model.search_args = []
#     Model.search_results = [Model.find(1, 2, 3)]
#
#     records = Model.search 'query'
#
#     assert_equal 1, Model.search_args.length
#     assert_equal [...], Model.search_args
#     assert_equal 0, Model.search_results.length
#   end
#
# Since both search_args and search_results are an Array you can call #search
# multiple times and get back different results per call.  #search will raise
# an exception if you don't supply enough results.

module Sphincter::SearchStub

  ##
  # An Array that records arguments #search was called with.  search_args
  # isn't set to anything by default, so do that in your test setup.

  attr_accessor :search_args

  ##
  # A pre-populated Array of search results for queries.  search_results isn't
  # set to anything by default, so do that in your test setup.

  attr_accessor :search_results

  ##
  # Overrides Sphincter::Search#search to use the search_args and
  # search_results values instead of connecting to Sphinx.

  def search(query, options = {})
    unless @search_args and @search_results then
      raise 'need to set up Sphincter::SearchStub#search_results and/or Sphincter::SearchStub#search_args in test setup'
    end

    @search_args << [query, options]

    raise 'no more search results in search stub' if @search_results.empty?

    @search_results.shift
  end

end

